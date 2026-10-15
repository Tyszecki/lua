--[[
  telemetry.lua – odczyt telemetrii natywnej CRSF i pasywne parsowanie ramek
  passthrough ArduPilot (CRSF custom telemetry).

  ZRODLO PROTOKOLU (zweryfikowane w kodzie zrodlowym ArduPilot i w oficjalnym
  arkuszu specyfikacji, NIE przepisane z Yaapu):
    - libraries/AP_RCTelemetry/AP_CRSF_Telem.h / .cpp
    - libraries/RC_Channel/RC_Channel.h (RC_Channels::Option)
    - arkusz: FrSky_Passthrough_protocol.xlsx (linkowany z ardupilot.org,
      common-frsky-passthrough.html) – ten sam uklad bitow jest uzywany
      przez AP_CRSF_Telem dla ramek passthrough po CRSF.

  UWAGA BEZPIECZENSTWA: kazde pole ma znacznik czasu ostatniej aktualizacji.
  Interfejs (ui_*.lua) MA OBOWIAZEK sprawdzac swiezosc danych i pokazywac
  "—" zamiast zera, gdy dane sa nieaktualne albo nigdy nie przyszly.
--]]

local cfg  = loadScript("/WIDGETS/OKTOTEL/config.lua")()
local lang = loadScript("/WIDGETS/OKTOTEL/lang.lua")()
local modes = loadScript("/WIDGETS/OKTOTEL/modes.lua")()

local T = {}

-- ======================= STAN TELEMETRII =======================

local function nowyStan()
  return {
    -- znaczniki czasu (getTime(), w setnych sekundy) dla kazdej kategorii
    t_link   = 0,
    t_native = 0,
    t_pt     = 0,   -- dowolna ramka passthrough (0x80)
    t_status = 0,

    source_active = "none", -- "native" | "passthrough" | "none"

    link = {
      rss1 = nil, rss2 = nil, rqly = nil, rsnr = nil,
      ant = nil, rfmd = nil, tpwr = nil,
      trss = nil, tqly = nil, tsnr = nil,
    },

    -- dane bazowe (natywne, nadpisywane przez passthrough gdy swiezsze)
    flightModeNum  = nil,   -- numer trybu (tylko z passthrough 0x5001)
    flightModeText = nil,   -- tekst trybu (natywne pole FM, lub z numeru)
    armed          = nil,   -- true/false/nil
    landComplete   = nil,
    simpleMode     = nil,
    battFailsafe   = nil,
    ekfFailsafe    = nil,   -- 0..3 albo nil

    battery = {
      voltage = nil,       -- V (suma pakietu)
      current = nil,       -- A
      mah     = nil,       -- mAh zuzyte
      percent = nil,       -- %
    },
    battery2 = {
      voltage = nil, current = nil, mah = nil, percent = nil,
      widziany = false,    -- czy KIEDYKOLWIEK przyszla osobna ramka battery2
    },

    gps = {
      sats = nil, fix = nil, hdop = nil, advFix = nil, altMSL = nil,
    },

    home = {
      distance = nil, bearing = nil, altRel = nil,
    },

    vel = {
      vspd = nil, gspd = nil, yaw = nil,
    },

    att = {
      roll = nil, pitch = nil, rangefinder = nil,
    },

    params = {
      batCapacityMah = nil, batFailsafeMah = nil, batFailsafeVolt = nil, mavType = nil,
    },

    -- historia komunikatow STATUSTEXT: {t=, sev=, text=}
    historia = {},
    ostatniKomunikat = nil,

    -- statystyki (strona 3)
    maks = { prad = 0, wysokosc = 0, odleglosc = 0, predkosc = 0 },

    -- bufor wykresu (bufor kolowy)
    wykres = { v = {}, a = {}, idx = 1, pelny = false, t_ostatnia_probka = 0 },
  }
end

T.stan = nowyStan()

function T.reset()
  T.stan = nowyStan()
end

-- ======================= NARZEDZIA BITOWE =======================

-- Wyciaga `nbits` bitow zaczynajac od bitu `startBit` (LSB = bit 0).
-- Dziala na nieujemnych liczbach calkowitych (do 32 bitow).
local function bits(value, startBit, nbits)
  if value == nil then return 0 end
  local shifted = math.floor(value / (2 ^ startBit))
  return shifted % (2 ^ nbits)
end

-- Dekoduje pole typu mantysa+wykladnik (10^x), tak jak w specyfikacji
-- ArduPilot passthrough: najpierw `expBits` bitow wykladnika, potem
-- `mantBits` bitow mantysy.
local function dekodujPow10(value, startBit, expBits, mantBits)
  local exp  = bits(value, startBit, expBits)
  local mant = bits(value, startBit + expBits, mantBits)
  return mant * (10 ^ exp)
end

-- ======================= DEKODERY RAMEK PASSTHROUGH =======================
-- appid (dziesietnie) = wartosc hex z arkusza specyfikacji (0x5000 = 20480 itd.)

local APPID_STATUSTEXT   = 0x5000
local APPID_AP_STATUS    = 0x5001
local APPID_GPS_STATUS   = 0x5002
local APPID_BATT1        = 0x5003
local APPID_HOME         = 0x5004
local APPID_VELANDYAW    = 0x5005
local APPID_ATTIANDRNG   = 0x5006
local APPID_PARAMS       = 0x5007
-- APPID_BATT2 (0x5008) – DO ZWERYFIKOWANIA: nie wystepuje w oficjalnym
-- arkuszu ArduPilot dostepnym publicznie w chwili pisania tego kodu.
-- Jesli Twoja wersja ArduPilot wysyla ja, dopisz dekoder analogiczny do
-- dekodujBatt1 nizej. Dopoki nie potwierdzone, battery2 bedzie pokazywane
-- jako "BRAK" (patrz lang.pakiet_brak).
local APPID_BATT2        = 0x5008

local function czasTeraz()
  return getTime() / 100.0 -- getTime() zwraca setne sekundy
end

local function dekodujApStatus(s, value, t)
  s.flightModeNum = bits(value, 0, 5)
  s.simpleMode    = bits(value, 5, 2)
  s.landComplete  = bits(value, 7, 1) == 1
  s.armed         = bits(value, 8, 1) == 1
  s.battFailsafe  = bits(value, 9, 1) == 1
  s.ekfFailsafe   = bits(value, 10, 2)
  s.flightModeText = modes.nazwa(s.flightModeNum)
  s.t_native = t -- traktujemy jak "swiezy status" rowniez dla trybu natywnego fallback
end

local function dekodujGpsStatus(s, value, t)
  s.gps.sats   = bits(value, 0, 4)
  s.gps.fix    = bits(value, 4, 2)
  s.gps.hdop   = dekodujPow10(value, 6, 1, 7) / 10.0  -- decymetry -> metry
  s.gps.advFix = bits(value, 14, 2)
  local altDm  = dekodujPow10(value, 22, 2, 7)
  local sign   = bits(value, 31, 1) == 1 and -1 or 1
  s.gps.altMSL = sign * altDm / 10.0 -- decymetry -> metry
end

local function dekodujBatt1(s, value, t)
  s.battery.voltage = bits(value, 0, 9) / 10.0
  s.battery.current = dekodujPow10(value, 9, 1, 7) / 10.0
  s.battery.mah     = bits(value, 17, 15)
end

local function dekodujHome(s, value, t)
  s.home.distance = dekodujPow10(value, 0, 2, 10)
  s.home.bearing  = bits(value, 12, 7) * 3.0 -- jednostki po 3 stopnie
  local altDm     = dekodujPow10(value, 19, 2, 10)
  local sign      = bits(value, 31, 1) == 1 and -1 or 1
  s.home.altRel   = sign * altDm / 10.0
end

local function dekodujVelYaw(s, value, t)
  local vspdDm   = dekodujPow10(value, 0, 1, 7)
  local vspdSign = bits(value, 8, 1) == 1 and -1 or 1
  s.vel.vspd = vspdSign * vspdDm / 10.0
  s.vel.gspd = dekodujPow10(value, 9, 1, 7) / 10.0
  s.vel.yaw  = bits(value, 17, 11) * 0.2
end

-- UWAGA: offsety roll/pitch (180 / 90) sa WYPROWADZONE z zakresu kodowania
-- (11/10 bitow * 0.2 stopnia), a nie zacytowane wprost ze zrodla ArduPilot.
-- Do zweryfikowania w symulatorze lub na realnym locie (poziomy lot = roll/pitch ~ 0).
local function dekodujAttiAndRng(s, value, t)
  s.att.roll  = bits(value, 0, 11) * 0.2 - 180.0
  s.att.pitch = bits(value, 11, 10) * 0.2 - 90.0
  s.att.rangefinder = dekodujPow10(value, 21, 1, 10) / 100.0 -- cm -> m
end

local function dekodujParams(s, value, t)
  local id = bits(value, 0, 8)
  local rest = bits(value, 8, 24)
  if id == 1 then
    s.params.mavType = bits(value, 8, 8)
  elseif id == 2 then
    s.params.batCapacityMah = rest
  elseif id == 3 then
    s.params.batFailsafeMah = rest
  elseif id == 4 then
    s.params.batFailsafeVolt = rest / 100.0
  end
end

local function dodajKomunikat(s, sev, text, t)
  s.ostatniKomunikat = { t = t, sev = sev, text = text }
  table.insert(s.historia, 1, s.ostatniKomunikat)
  while #s.historia > cfg.historia_komunikatow do
    table.remove(s.historia)
  end
end

-- ======================= ODBIOR RAMEK CRSF (passthrough) =======================
--
-- Identyfikatory typu ramki i podtypow - patrz AP_CRSF_Telem.h:
--   CRSF_FRAMETYPE_AP_CUSTOM_TELEM         = 0x7F (starsze FW) / 0x80 (nowsze)
-- Podtypy (pierwszy bajt danych) – DO ZWERYFIKOWANIA na Twoim FW (patrz
-- plan/README, pkt. "do zweryfikowania"):
local SUBTYPE_SINGLE = 0xF0
local SUBTYPE_TEXT   = 0xF1
local SUBTYPE_MULTI  = 0xF2

local function rozlozApid(s, appid, value, t)
  if appid == APPID_AP_STATUS then
    dekodujApStatus(s, value, t)
  elseif appid == APPID_GPS_STATUS then
    dekodujGpsStatus(s, value, t)
  elseif appid == APPID_BATT1 then
    dekodujBatt1(s, value, t)
  elseif appid == APPID_BATT2 then
    s.battery2.widziany = true
    s.battery2.voltage = bits(value, 0, 9) / 10.0
    s.battery2.current = dekodujPow10(value, 9, 1, 7) / 10.0
    s.battery2.mah     = bits(value, 17, 15)
  elseif appid == APPID_HOME then
    dekodujHome(s, value, t)
  elseif appid == APPID_VELANDYAW then
    dekodujVelYaw(s, value, t)
  elseif appid == APPID_ATTIANDRNG then
    dekodujAttiAndRng(s, value, t)
  elseif appid == APPID_PARAMS then
    dekodujParams(s, value, t)
  end
end

-- Sklada bajty tekstu statusu (7-bitowe znaki, 4 na ramke * do 11 ramek wg
-- specyfikacji 0x5000). Upraszczamy: jesli crossfireTelemetryPop zwraca juz
-- caly string (ramka CRSF STATUS_TEXT z AP_CRSF_Telem jest WIEKSZA niz SPort
-- i przenosi caly tekst na raz, patrz StatusTextFrame w AP_CRSF_Telem.h),
-- to korzystamy z tego bezposrednio. Rozbicie na appid=0x5000 (SPort-owe)
-- zostawiamy jako fallback na wypadek starszego FW mostkujacego SPort->CRSF.
local function przetworzRamkeCrsf(s, command, data)
  if data == nil or #data < 1 then return end
  local t = czasTeraz()
  s.t_pt = t
  s.source_active = "passthrough"

  local subtype = data[1]

  if subtype == SUBTYPE_TEXT then
    -- StatusTextFrame: [subtype][severity][tekst...0]
    local sev = data[2] or 0
    local txt = {}
    for i = 3, #data do
      local b = data[i]
      if b == 0 or b == nil then break end
      txt[#txt + 1] = string.char(b)
    end
    dodajKomunikat(s, sev, table.concat(txt), t)

  elseif subtype == SUBTYPE_SINGLE then
    -- PassthroughSinglePacketFrame: [subtype][appid_lo][appid_hi][data 4B LE]
    if #data >= 7 then
      local appid = data[2] + data[3] * 256
      local value = data[4] + data[5] * 256 + data[6] * 65536 + data[7] * 16777216
      rozlozApid(s, appid, value, t)
    end

  elseif subtype == SUBTYPE_MULTI then
    -- PassthroughMultiPacketFrame: [subtype][size][ {appid16,data32} * size ]
    local size = data[2] or 0
    local idx = 3
    for i = 1, size do
      if idx + 5 > #data + 1 then break end
      local appid = data[idx] + data[idx + 1] * 256
      local value = data[idx + 2] + data[idx + 3] * 256 + data[idx + 4] * 65536 + data[idx + 5] * 16777216
      rozlozApid(s, appid, value, t)
      idx = idx + 6
    end
  end
end

-- ======================= ODCZYT TELEMETRII NATYWNEJ =======================
-- Nazwy pol zgodne z typowym nazewnictwem sensorow CRSF w EdgeTX.
-- PRZED LOTEM zweryfikuj je przez Model -> Telemetria -> Wykryj nowe sensory
-- i w razie potrzeby popraw ponizsza liste (jest to jedyne miejsce, ktore
-- trzeba zmienic).
local NATIVE_FIELDS = {
  rss1 = "1RSS", rss2 = "2RSS", rqly = "RQly", rsnr = "RSNR",
  ant  = "ANT",  rfmd = "RFMD", tpwr = "TPWR",
  trss = "TRSS", tqly = "TQly", tsnr = "TSNR",
  rxbt = "RxBt", curr = "Curr", capa = "Capa", batpct = "Bat%",
  gspd = "GSpd", hdg = "Hdg", alt = "Alt", sats = "Sats",
  ptch = "Ptch", roll = "Roll", yaw = "Yaw", fm = "FM",
}

local function czytajNatywne(s, t)
  -- pcall na wypadek braku danego sensora (brak = blad w starszych rdzeniach)
  local function v(name)
    local ok, val = pcall(getValue, name)
    if ok and val ~= nil and val ~= 0 then return val end
    if ok then return val end
    return nil
  end

  local any = false

  local rss1 = v(NATIVE_FIELDS.rss1)
  local rqly = v(NATIVE_FIELDS.rqly)
  if rss1 ~= nil or rqly ~= nil then
    s.link.rss1 = rss1
    s.link.rss2 = v(NATIVE_FIELDS.rss2)
    s.link.rqly = rqly
    s.link.rsnr = v(NATIVE_FIELDS.rsnr)
    s.link.ant  = v(NATIVE_FIELDS.ant)
    s.link.rfmd = v(NATIVE_FIELDS.rfmd)
    s.link.tpwr = v(NATIVE_FIELDS.tpwr)
    s.link.trss = v(NATIVE_FIELDS.trss)
    s.link.tqly = v(NATIVE_FIELDS.tqly)
    s.link.tsnr = v(NATIVE_FIELDS.tsnr)
    s.t_link = t
    any = true
  end

  local rxbt = v(NATIVE_FIELDS.rxbt)
  if rxbt ~= nil then
    -- tylko jesli NIE mamy swiezszych danych z passthrough
    if (t - s.t_pt) > cfg.timeout_passthrough then
      s.battery.voltage = rxbt
      s.battery.current = v(NATIVE_FIELDS.curr)
      s.battery.mah     = v(NATIVE_FIELDS.capa)
      s.battery.percent = v(NATIVE_FIELDS.batpct)
    end
    any = true
  end

  local sats = v(NATIVE_FIELDS.sats)
  if sats ~= nil and (t - s.t_pt) > cfg.timeout_passthrough then
    s.gps.sats = sats
    any = true
  end

  local fm = v(NATIVE_FIELDS.fm)
  if fm ~= nil and (t - s.t_pt) > cfg.timeout_passthrough then
    -- ArduPilot dopisuje "*" do nazwy trybu gdy rozbrojony, TYLKO jesli
    -- ustawiony RC_OPTIONS bit 12 (CRSF_FM_DISARM_STAR). Patrz README.
    if type(fm) == "string" then
      s.flightModeText = fm
      if string.sub(fm, -1) == "*" then
        s.armed = false
      end
    end
    any = true
  end

  if any then
    s.t_native = t
  end
  return any
end

-- ======================= GLOWNA FUNKCJA AKTUALIZACJI =======================

function T.update()
  local s = T.stan
  local t = czasTeraz()

  -- 1) wyciagnij wszystkie dostepne ramki passthrough z kolejki CRSF
  --    (limit na cykl, zeby nie przekroczyc czasu wykonania skryptu)
  local pobrane = 0
  while pobrane < 8 do
    local command, data = crossfireTelemetryPop()
    if command == nil then break end
    przetworzRamkeCrsf(s, command, data)
    pobrane = pobrane + 1
  end

  -- 2) telemetria natywna (zawsze czytana – lacze i fallback)
  czytajNatywne(s, t)

  -- 3) ustal aktywne zrodlo
  if (t - s.t_pt) <= cfg.timeout_passthrough then
    s.source_active = "passthrough"
  elseif (t - s.t_native) <= cfg.timeout_telemetria then
    s.source_active = "native"
  else
    s.source_active = "none"
  end

  -- 4) aktualizuj maksima (tylko gdy mamy sensowne dane)
  if s.battery.current and s.battery.current > s.maks.prad then
    s.maks.prad = s.battery.current
  end
  local wys = s.home.altRel or s.gps.altMSL
  if wys and wys > s.maks.wysokosc then s.maks.wysokosc = wys end
  if s.home.distance and s.home.distance > s.maks.odleglosc then
    s.maks.odleglosc = s.home.distance
  end
  if s.vel.gspd and s.vel.gspd > s.maks.predkosc then
    s.maks.predkosc = s.vel.gspd
  end

  -- 5) probka do wykresu (bufor kolowy, co cfg.wykres_odstep sekund)
  if (t - s.wykres.t_ostatnia_probka) >= cfg.wykres_odstep then
    s.wykres.t_ostatnia_probka = t
    local idx = s.wykres.idx
    local vcell = nil
    if s.battery.voltage then
      vcell = s.battery.voltage -- normalizacja na ogniwo robiona w UI (zna liczbe ogniw)
    end
    s.wykres.v[idx] = vcell
    s.wykres.a[idx] = s.battery.current
    s.wykres.idx = idx + 1
    if s.wykres.idx > cfg.wykres_probek then
      s.wykres.idx = 1
      s.wykres.pelny = true
    end
  end

  return s
end

-- ======================= FUNKCJE POMOCNICZE DLA UI =======================

function T.swiezyPT(t)
  return (czasTeraz() - T.stan.t_pt) <= cfg.timeout_passthrough
end

function T.jestTelemetria()
  return (czasTeraz() - math.max(T.stan.t_pt, T.stan.t_native)) <= cfg.timeout_telemetria
end

function T.tekstFix(fix)
  if fix == nil then return lang.brak_danych end
  if fix == 0 then return lang.fix_brak end
  if fix == 1 then return lang.fix_brak end
  if fix == 2 then return lang.fix_2d end
  return lang.fix_3d
end

function T.tekstAdvFix(advFix)
  if advFix == 1 then return lang.fix_dgps end
  if advFix == 2 then return lang.fix_rtk_float end
  if advFix == 3 then return lang.fix_rtk_fixed end
  return nil
end

return T
