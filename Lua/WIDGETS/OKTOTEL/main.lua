--[[
  main.lua – widget telemetrii oktokoptera ArduPilot/ELRS dla EdgeTX (App Mode).

  Struktura: patrz telemetry.lua / alerts.lua / ui_*.lua. Ten plik tylko
  spina modoly, definiuje opcje widgetu (limit 10 w EdgeTX 2.11+) i obsluguje
  nawigacje miedzy stronami (przesuniecie palcem).

  DO ZWERYFIKOWANIA W COMPANION / NA RADIU (patrz tez README):
   - dokladna skladnia typu opcji CHOICE dla "zrodlo" (ponizej uzyty VALUE
     0/1/2 jako bezpieczny, pewny wariant zamiast CHOICE),
   - pola touchState (nazwy x/y/swipeLeft/swipeRight/swipeUp/swipeDown),
   - czy refresh() w App Mode (bez wejscia w "Full screen" z menu) dostaje
     juz zdarzenia dotyku, czy trzeba dodatkowo wejsc w pelny ekran.
--]]

local telemetry = loadScript("/WIDGETS/OKTOTEL/telemetry.lua")()
local alerts     = loadScript("/WIDGETS/OKTOTEL/alerts.lua")()
local uiFlight   = loadScript("/WIDGETS/OKTOTEL/ui_flight.lua")()
local uiSystem   = loadScript("/WIDGETS/OKTOTEL/ui_system.lua")()
local uiBattery  = loadScript("/WIDGETS/OKTOTEL/ui_battery.lua")()

-- ======================= OPCJE WIDGETU (max 10) =======================
-- Wartosci VALUE sa liczbami calkowitymi; progi napiecia trzymamy *100
-- (centiwolty na ogniwo), zeby uniknac zalamkowych w opcjach EdgeTX.
local function opcjeWidgetu()
  return {
    { "OGNIWA",   VALUE, 12,    1,   14 },   -- liczba ogniw pakietu
    { "POJEMN",   VALUE, 58000, 0,   99000 },-- pojemnosc laczna [mAh]
    { "PROGNISK", VALUE, 360,   300, 420 },  -- prog niski  [V/ogniwo x100]
    { "PROGKRYT", VALUE, 350,   300, 420 },  -- prog krytyczny [V/ogniwo x100]
    { "REZERWA",  VALUE, 20,    0,   50 },   -- rezerwa [%]
    { "MINRQLY",  VALUE, 70,    0,   100 },  -- prog ostrzegawczy RQly [%]
    { "TOTLM",    VALUE, 5,     1,   30 },   -- czas do banera "brak telemetrii" [s]
    { "GLOS",     BOOL,  1 },                -- komunikaty glosowe wl/wyl
    { "ZRODLO",   VALUE, 0,     0,   2 },    -- 0=Auto, 1=Natywne, 2=Passthrough
    { "LEDWIB",   BOOL,  1 },                -- LED (przez GV) + wibracje wl/wyl
  }
end

-- Przeklada surowe opcje EdgeTX na semantyczna tabele uzywana w reszcie kodu.
local function przetlumaczOpcje(raw)
  return {
    liczbaOgniw      = raw.OGNIWA or 12,
    pojemnoscMah     = raw.POJEMN or 0,
    progNiskiV       = (raw.PROGNISK or 360) / 100.0,
    progKrytV        = (raw.PROGKRYT or 350) / 100.0,
    rezerwaProcent   = raw.REZERWA or 20,
    minRQly          = raw.MINRQLY or 70,
    timeoutTelemetrii= raw.TOTLM or 5,
    glosWlaczony     = (raw.GLOS == nil) or (raw.GLOS == 1) or (raw.GLOS == true),
    zrodloWymuszone  = raw.ZRODLO or 0, -- 0=Auto,1=Natywne,2=PT (uzyte w telemetry, do rozszerzenia)
    ledWibracje      = (raw.LEDWIB == nil) or (raw.LEDWIB == 1) or (raw.LEDWIB == true),
  }
end

-- ======================= CYKL ZYCIA WIDGETU =======================

local function create(zone, options)
  local ctx = {
    ekran = { strona = 1 },
    opcje = przetlumaczOpcje(options or {}),
    ostatniaZmianaStrony = 0,
    zbudowano = false,
  }
  return ctx
end

local function update(ctx, options)
  ctx.opcje = przetlumaczOpcje(options or {})

  -- Przebudowujemy drzewo LVGL od zera (update() wywolywane rzadko –
  -- tylko przy zmianie opcji/rozmiaru, wiec koszt jest akceptowalny).
  -- UWAGA: dokladna sygnatura lvgl.clear() (czy czysci caly ekran widgetu
  -- bez argumentow) jest przyjeta jako najbardziej typowy wzorzec - do
  -- zweryfikowania w Companion.
  lvgl.clear()

  local alertStan = ctx.alertStan or { baner = nil, kolor = nil, poziom = 0 }
  ctx.alertStan = alertStan

  -- parent = nil => obiekt najwyzszego poziomu (pelny ekran widgetu).
  -- Przechowujemy referencje do kontenerow stron: dynamiczna wlasciwosc
  -- `hidden = function() ... end` moze NIE byc wspierana (niepewne w
  -- dokumentacji) - dlatego w refresh() dodatkowo ustawiamy ja JAWNIE.
  ctx.paginy = {
    flight  = uiFlight.build(nil, telemetry, ctx.opcje, ctx.ekran, alertStan),
    system  = uiSystem.build(nil, telemetry, ctx.opcje, ctx.ekran, alertStan),
    battery = uiBattery.build(nil, telemetry, ctx.opcje, ctx.ekran, alertStan),
  }

  ctx.zbudowano = true
end

-- Jawnie ustawia widocznosc stron wg ctx.ekran.strona (patrz komentarz w update()).
local function wymusWidocznoscStron(ctx)
  if ctx.paginy == nil then return end
  local function ustaw(obj, widoczna)
    if obj == nil then return end
    local ok = pcall(function() obj.hidden = not widoczna end)
    -- nil-safe: jesli wlasciwosc "hidden" nie jest zapisywalna w ten sposob,
    -- po prostu polegamy na dynamicznej funkcji przekazanej w ui_*.lua.
  end
  ustaw(ctx.paginy.flight,  ctx.ekran.strona == 1)
  ustaw(ctx.paginy.system,  ctx.ekran.strona == 2)
  ustaw(ctx.paginy.battery, ctx.ekran.strona == 3)
end

-- Obsluga przesuniecia palcem miedzy stronami (z debounce, zeby jedno
-- przesuniecie nie przelaczylo kilku stron naraz).
local function obslugaDotyku(ctx, touchState)
  if touchState == nil then return end
  local teraz = getTime() / 100.0
  if (teraz - ctx.ostatniaZmianaStrony) < 0.4 then return end

  -- UWAGA: nazwy pol touchState (swipeLeft/swipeRight) zgodnie z dokumentacja
  -- EdgeTX LUA – zweryfikuj w symulatorze, nazwy mogly sie zmienic miedzy
  -- wersjami.
  if touchState.swipeLeft then
    ctx.ekran.strona = math.min(3, ctx.ekran.strona + 1)
    ctx.ostatniaZmianaStrony = teraz
  elseif touchState.swipeRight then
    ctx.ekran.strona = math.max(1, ctx.ekran.strona - 1)
    ctx.ostatniaZmianaStrony = teraz
  elseif touchState.tapCount and touchState.tapCount > 0 then
    -- dotkniecie ekranu w obszarze banera alarmu = wyciszenie glosu na 30s
    if ctx.alertStan and ctx.alertStan.baner ~= nil then
      local y = touchState.startY or touchState.y
      if y ~= nil and y >= 150 and y <= 290 then
        alerts.wyciszGlos(30)
      end
    end
  end
end

local function refresh(ctx, event, touchState)
  local telem = telemetry.update()
  local alertStan = alerts.update(telem, ctx.opcje)
  ctx.alertStan = alertStan

  obslugaDotyku(ctx, touchState)

  -- Obsluga przyciskow PAGE/fizycznych, jesli App Mode je przekazuje jako
  -- zdarzenia klawiszy (event). EVT_PAGE_* / EVT_ROT_* zaleza od sprzetu —
  -- do zweryfikowania na TX16S MK3 (pokretlo/przyciski).
  if event == EVT_PAGEDN_FIRST or event == EVT_PAGEUP_FIRST then
    local teraz = getTime() / 100.0
    if (teraz - ctx.ostatniaZmianaStrony) >= 0.3 then
      if event == EVT_PAGEDN_FIRST then
        ctx.ekran.strona = math.min(3, ctx.ekran.strona + 1)
      else
        ctx.ekran.strona = math.max(1, ctx.ekran.strona - 1)
      end
      ctx.ostatniaZmianaStrony = teraz
    end
  end

  -- Na samym koncu, po wszystkich mozliwych zmianach ctx.ekran.strona
  wymusWidocznoscStron(ctx)
end

-- Gdy widget nie jest widoczny, nadal odczytujemy telemetrie (rzadziej),
-- zeby po powrocie dane nie byly mocno nieaktualne i by alarmy dzialaly
-- w tle (np. glos przy rozbrojeniu, gdy uzytkownik jest na innym ekranie).
local function background(ctx)
  local telem = telemetry.update()
  alerts.update(telem, ctx.opcje)
end

return {
  name    = "OKTOTEL",
  options = opcjeWidgetu(),
  create  = create,
  update  = update,
  refresh = refresh,
  background = background,
  useLvgl = true,
}
