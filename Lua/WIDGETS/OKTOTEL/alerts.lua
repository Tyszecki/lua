--[[
  alerts.lua – maszyna stanow alarmow: kolor, dzwiek/glos, wibracje, GV dla LED.

  Kazdy alarm ma 3 poziomy: OK -> OSTRZEZENIE -> KRYTYCZNY.
  Wejscie w wyzszy poziom wymaga, by warunek trwal cfg.alarm_czas_wejscia [s]
  (odpornosc na chwilowe spadki napiecia pod obciazeniem, szumy GPS itd.).
  Wyjscie z poziomu wymaga histerezy (patrz config.lua).

  LED RGB: EdgeTX nie udostepnia w Lua widgetow bezposredniego API do
  sterowania dioda RGB przyciskow (potwierdzone - brak w sandboxie).
  Dlatego poziom alarmu jest zapisywany do zmiennej globalnej modelu (GV),
  ktora nastepnie sterowana jest kolorem LED przez Funkcje Specjalna /
  Przelacznik logiczny skonfigurowany w EdgeTX (patrz instrukcja instalacji).
--]]

local cfg  = loadScript("/WIDGETS/OKTOTEL/config.lua")()
local lang = loadScript("/WIDGETS/OKTOTEL/lang.lua")()

local A = {}

-- Indeks GV uzywany do sygnalizacji poziomu alarmu (0=OK,1=OSTRZ,2=KRYT).
-- Zmien jesli ten GV jest juz zajety w Twoim modelu.
local GV_ALARM_INDEX = 8

-- Poziomy
local OK, WARN, CRIT = 0, 1, 2

local function nowyAlarm()
  return {
    poziom = OK,
    od_kiedy = 0,      -- czas (s) od kiedy warunek spelnia wyzszy poziom (debounce)
    ostatni_komunikat = 0,
  }
end

A.stany = {
  bateria   = nowyAlarm(),
  lacze     = nowyAlarm(),
  telemetria= nowyAlarm(),
  failsafe  = nowyAlarm(),
  ekf       = nowyAlarm(),
  gps       = nowyAlarm(),
}

A.kolejkaGlosu = {}   -- {priorytet, plik}
A.ostatniTryb = nil
A.ostatnioUzbrojony = nil
A.wyciszoneDo = 0     -- czas (s) do ktorego uzytkownik wyciszyl glos (dotkniecie banera)

local function t() return getTime() / 100.0 end

local function dodajGlos(priorytet, plik)
  if plik == nil then return end
  table.insert(A.kolejkaGlosu, { p = priorytet, f = plik })
  table.sort(A.kolejkaGlosu, function(a, b) return a.p < b.p end)
end

-- Odtwarza maks. jeden plik na cykl (ograniczenie obciazenia / kolizji audio)
local function przetworzKolejkeGlosu(opcje)
  if #A.kolejkaGlosu == 0 then return end
  if opcje.glosWlaczony == false then
    A.kolejkaGlosu = {}
    return
  end
  if t() < A.wyciszoneDo then
    A.kolejkaGlosu = {}
    return
  end
  local el = table.remove(A.kolejkaGlosu, 1)
  local ok = pcall(playFile, "/WIDGETS/OKTOTEL/snd/" .. el.f .. ".wav")
  if not ok then
    pcall(playFile, el.f) -- fallback: wbudowany plik systemowy o tej samej nazwie
  end
end

local function wibruj(mocno)
  pcall(playHaptic, mocno and 200 or 80, 0)
end

local function ustawGvAlarmu(poziom)
  local ok = pcall(model.setGlobalVariable, GV_ALARM_INDEX, 0, poziom)
  -- jesli API niedostepne w tej wersji firmware, po prostu pomijamy (nil-safe)
end

-- Generyczna aktualizacja jednego alarmu 2-progowego (warn/crit = funkcje
-- zwracajace true/false dla aktualnej, USREDNIONEJ wartosci).
local function aktualizujAlarm(stan, czasTeraz, jestWarn, jestCrit, interwalWarn, interwalKryt, sndWarn, sndKryt)
  local docelowy = OK
  if jestCrit then docelowy = CRIT
  elseif jestWarn then docelowy = WARN end

  if docelowy > stan.poziom then
    if stan.od_kiedy == 0 then
      stan.od_kiedy = czasTeraz
    elseif (czasTeraz - stan.od_kiedy) >= cfg.alarm_czas_wejscia then
      stan.poziom = docelowy
      stan.od_kiedy = 0
      stan.ostatni_komunikat = 0 -- wymus natychmiastowy komunikat
    end
  elseif docelowy < stan.poziom then
    -- histereza jest juz uwzgledniona przez wywolujacego (przekazuje stan "z zapasem")
    stan.poziom = docelowy
    stan.od_kiedy = 0
  else
    stan.od_kiedy = 0
  end

  if stan.poziom ~= OK then
    local interwal = (stan.poziom == CRIT) and interwalKryt or interwalWarn
    if (czasTeraz - stan.ostatni_komunikat) >= interwal then
      stan.ostatni_komunikat = czasTeraz
      dodajGlos(stan.poziom == CRIT and 0 or 1, stan.poziom == CRIT and sndKryt or sndWarn)
      wibruj(stan.poziom == CRIT)
    end
  end

  return stan.poziom
end

-- Usredniona wartosc napiecia na ogniwo z ostatnich cfg.usrednianie_okno [s]
local buforV = {}
local function usrednijNapiecie(vTotal, liczbaOgniw, czasTeraz)
  if vTotal == nil or liczbaOgniw == nil or liczbaOgniw <= 0 then return nil end
  local vCell = vTotal / liczbaOgniw
  table.insert(buforV, { t = czasTeraz, v = vCell })
  while #buforV > 0 and (czasTeraz - buforV[1].t) > cfg.usrednianie_okno do
    table.remove(buforV, 1)
  end
  local suma, n = 0, 0
  for _, el in ipairs(buforV) do suma = suma + el.v; n = n + 1 end
  if n == 0 then return vCell end
  return suma / n
end

--[[
  A.update(telem, opcje)
    telem  – aktualny T.stan z telemetry.lua
    opcje  – tabela z opcjami widgetu (progi, liczba ogniw, glos wl/wył...)

  Zwraca: { poziomGlobalny, baner = string/nil, kolorBanera = "red"/"yellow"/nil }
--]]
function A.update(telem, opcje)
  local czasTeraz_ = t()
  local wynik = { baner = nil, kolor = nil, poziom = OK }

  -- --- Brak telemetrii ---
  local brak = not (czasTeraz_ - math.max(telem.t_pt, telem.t_native) <= opcje.timeoutTelemetrii)
  local poziomTelem = aktualizujAlarm(
    A.stany.telemetria, czasTeraz_,
    brak, brak, -- warn i crit to ten sam warunek (binarny)
    cfg.alarm_powtorz_ostrz, cfg.alarm_powtorz_kryt,
    lang.snd_telem_brak, lang.snd_telem_brak
  )
  if poziomTelem >= WARN then
    wynik.baner = lang.brak_telemetrii
    wynik.kolor = "red"
    wynik.poziom = CRIT
  end

  -- --- Bateria (napiecie na ogniwo, usrednione) ---
  local vCellSr = usrednijNapiecie(telem.battery.voltage, opcje.liczbaOgniw, czasTeraz_)
  if vCellSr ~= nil then
    local warnTh = opcje.progNiskiV
    local critTh = opcje.progKrytV
    local jestWarn = vCellSr <= warnTh
    local jestCrit = vCellSr <= critTh
    -- histereza: jesli juz w alarmie, trzeba przekroczyc prog + histereza by wyjsc
    if A.stany.bateria.poziom == WARN and vCellSr > (warnTh + cfg.alarm_histereza_V) then
      jestWarn = false
    end
    if A.stany.bateria.poziom == CRIT and vCellSr > (critTh + cfg.alarm_histereza_V) then
      jestCrit = false
    end
    local poziomBat = aktualizujAlarm(
      A.stany.bateria, czasTeraz_, jestWarn, jestCrit,
      cfg.alarm_powtorz_ostrz, cfg.alarm_powtorz_kryt,
      lang.snd_bat_niska, lang.snd_bat_kryt
    )
    if poziomBat == CRIT and wynik.poziom < CRIT then
      wynik.baner = lang.bat_krytyczna
      wynik.kolor = "red"
      wynik.poziom = CRIT
    elseif poziomBat == WARN and wynik.poziom < WARN then
      wynik.baner = lang.bat_niska
      wynik.kolor = "yellow"
      wynik.poziom = WARN
    end
  end

  -- --- Jakosc lacza (RQly) ---
  if telem.link.rqly ~= nil then
    local jestWarn = telem.link.rqly < cfg.rqly_ostrzezenie
    local jestCrit = telem.link.rqly < cfg.rqly_krytyczny
    local poziomLink = aktualizujAlarm(
      A.stany.lacze, czasTeraz_, jestWarn, jestCrit,
      cfg.alarm_powtorz_ostrz, cfg.alarm_powtorz_kryt,
      nil, nil -- brak dedykowanego komunikatu glosowego (tylko wizualnie)
    )
    if poziomLink == CRIT and wynik.poziom < CRIT then
      wynik.baner = lang.lacze_slabe
      wynik.kolor = "red"
      wynik.poziom = CRIT
    end
  end

  -- --- Failsafe / EKF / GPS – tylko po uzbrojeniu ---
  if telem.armed then
    if telem.battFailsafe then
      wynik.baner = lang.failsafe_aktywny
      wynik.kolor = "red"
      wynik.poziom = CRIT
      dodajGlos(0, lang.snd_failsafe)
    end
    if telem.ekfFailsafe ~= nil and telem.ekfFailsafe > 0 then
      if wynik.poziom < CRIT then
        wynik.baner = lang.ekf_blad
        wynik.kolor = "red"
        wynik.poziom = CRIT
      end
      dodajGlos(0, lang.snd_ekf)
    end
    if telem.gps.fix ~= nil and telem.gps.fix < 2 and wynik.poziom < WARN then
      wynik.baner = lang.brak_gps
      wynik.kolor = "yellow"
      wynik.poziom = WARN
    end
  end

  -- --- Zmiana trybu / uzbrojenie (ogloszenia glosowe, bez banera) ---
  if telem.flightModeText ~= nil and telem.flightModeText ~= A.ostatniTryb then
    A.ostatniTryb = telem.flightModeText
    -- celowo BEZ dzwieku pliku trybu (brak gwarancji nazw plikow dla kazdego
    -- trybu w polskim pakiecie) – mozna podlaczyc playNumber lub dedykowane
    -- pliki, patrz README.
  end
  if telem.armed ~= nil and telem.armed ~= A.ostatnioUzbrojony then
    A.ostatnioUzbrojony = telem.armed
    dodajGlos(2, telem.armed and lang.snd_armed or lang.snd_disarmed)
  end

  ustawGvAlarmu(wynik.poziom)
  przetworzKolejkeGlosu(opcje)

  return wynik
end

function A.wyciszGlos(sekund)
  A.wyciszoneDo = t() + (sekund or 30)
end

return A
