--[[
  ui_common.lua – wspolne stale i funkcje pomocnicze dla stron UI (LVGL).
--]]

local lang = loadScript("/WIDGETS/OKTOTEL/lang.lua")()

local U = {}

-- Kolory (ciemne tlo, wysoki kontrast, czytelne w slonku)
U.KOL_TLO        = lvgl.color(10, 10, 14)
U.KOL_PANEL      = lvgl.color(22, 24, 30)
U.KOL_TEKST      = lvgl.color(235, 235, 240)
U.KOL_TEKST_SZARY= lvgl.color(150, 152, 160)
U.KOL_ZIELONY    = lvgl.color(40, 200, 90)
U.KOL_ZOLTY      = lvgl.color(245, 190, 30)
U.KOL_CZERWONY   = lvgl.color(230, 50, 50)
U.KOL_NIEBIESKI  = lvgl.color(60, 140, 230)

-- Rozmiary czcionek – NIEPEWNE: w trakcie researchu trafiono na SPRZECZNE
-- informacje o dokladnych nazwach stalych (FONT_XS..FONT_XXL kontra
-- STDSIZE/SMLSIZE/MIDSIZE/DBLSIZE/XXLSIZE ze starszego API lcd.*).
-- Ponizej proba obu wariantow z fallbackiem na "nil" (LVGL uzyje wtedy
-- domyslnej czcionki) – ZWERYFIKUJ w Companion i ew. podmien na pewne
-- wartosci znalezione w swojej wersji dokumentacji/API.
local function pierwszyIstniejacy(...)
  for _, nazwa in ipairs({...}) do
    if _G[nazwa] ~= nil then return _G[nazwa] end
  end
  return nil
end

U.F_XXS = pierwszyIstniejacy("FONT_XXS", "SMLSIZE")
U.F_XS  = pierwszyIstniejacy("FONT_XS", "SMLSIZE")
U.F_S   = pierwszyIstniejacy("FONT_S", "STDSIZE")
U.F_M   = pierwszyIstniejacy("FONT_M", "STDSIZE")
U.F_L   = pierwszyIstniejacy("FONT_L", "MIDSIZE", "DBLSIZE")
U.F_XL  = pierwszyIstniejacy("FONT_XL", "DBLSIZE")
U.F_XXL = pierwszyIstniejacy("FONT_XXL", "XXLSIZE")

-- ===================== FORMATOWANIE (nil-safe) =====================

function U.fmt(value, decimals, jednostka)
  if value == nil then return lang.brak_danych end
  local mnoznik = 10 ^ (decimals or 0)
  local v = math.floor(value * mnoznik + 0.5) / mnoznik
  local s
  if decimals and decimals > 0 then
    s = string.format("%." .. decimals .. "f", v)
  else
    s = string.format("%d", v)
  end
  if jednostka then s = s .. jednostka end
  return s
end

function U.fmtInt(value, jednostka)
  if value == nil then return lang.brak_danych end
  local s = string.format("%d", math.floor(value + 0.5))
  if jednostka then s = s .. jednostka end
  return s
end

function U.fmtCzas(sekundy)
  if sekundy == nil then return lang.brak_danych end
  local m = math.floor(sekundy / 60)
  local s = math.floor(sekundy % 60)
  return string.format("%02d:%02d", m, s)
end

-- Kolor wedlug progow (mniejsze = gorsze); zwraca kolor LVGL
function U.kolorProg(value, progOstrz, progKryt, odwrocony)
  if value == nil then return U.KOL_TEKST_SZARY end
  if odwrocony then
    -- dla wartosci, gdzie WIEKSZA = gorsza (np. prad)
    if value >= progKryt then return U.KOL_CZERWONY end
    if value >= progOstrz then return U.KOL_ZOLTY end
    return U.KOL_ZIELONY
  else
    if value <= progKryt then return U.KOL_CZERWONY end
    if value <= progOstrz then return U.KOL_ZOLTY end
    return U.KOL_ZIELONY
  end
end

return U
