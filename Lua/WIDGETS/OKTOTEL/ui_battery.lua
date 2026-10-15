--[[
  ui_battery.lua – Strona 3: BATERIA / LOT (wykres, maksima, szacowany czas lotu).
--]]

local U    = loadScript("/WIDGETS/OKTOTEL/ui_common.lua")()
local lang = loadScript("/WIDGETS/OKTOTEL/lang.lua")()
local cfg  = loadScript("/WIDGETS/OKTOTEL/config.lua")()

local M = {}

-- Bufor usredniania pradu do szacowania czasu lotu (okno cfg.szac_czasu_okno)
local buforPrad = {}

local function szacujCzasDoRezerwy(s, opcje)
  if s.battery.current == nil or s.battery.mah == nil then return nil end
  local t = getTime() / 100.0
  table.insert(buforPrad, { t = t, mah = s.battery.mah })
  while #buforPrad > 0 and (t - buforPrad[1].t) > cfg.szac_czasu_okno do
    table.remove(buforPrad, 1)
  end
  if #buforPrad < 2 then return nil end
  local pierwszy, ostatni = buforPrad[1], buforPrad[#buforPrad]
  local dt = ostatni.t - pierwszy.t
  if dt < 5 then return nil end -- za krotkie okno, niewiarygodne
  local zuzycieNaSek = (ostatni.mah - pierwszy.mah) / dt
  if zuzycieNaSek <= 0 then return nil end

  local pojemnosc = opcje.pojemnoscMah or 0
  local rezerwaMah = pojemnosc * (opcje.rezerwaProcent or 20) / 100.0
  local progMah = math.max(0, pojemnosc - rezerwaMah)
  local pozostaleMah = progMah - s.battery.mah
  if pozostaleMah <= 0 then return 0 end
  return pozostaleMah / zuzycieNaSek
end

-- `telemetry` – patrz komentarz w ui_flight.lua: musi to byc ta sama
-- instancja modulu co w main.lua, przekazana jako parametr.
function M.build(parent, telemetry, opcje, ekran, alertStan)
  local s = telemetry.stan

  local kont = lvgl.rectangle(parent, {
    x = 0, y = 0, w = LCD_W, h = LCD_H, color = U.KOL_TLO,
    hidden = function() return ekran.strona ~= 3 end,
  })

  lvgl.rectangle(kont, { x = 0, y = 0, w = LCD_W, h = 48, color = U.KOL_PANEL })
  lvgl.label(kont, { x = 16, y = 10, w = 300, h = 30, font = U.F_L, color = U.KOL_TEKST, text = lang.wykres_tytul })

  -- ---------- WYKRES (lvgl.chart – natywny, wydajniejszy niz lvgl.line do historii) ----------
  -- UWAGA: dokladna skladnia lvgl.chart (seria, skala osi) do zweryfikowania
  -- w Companion – ponizej uzywamy najbardziej typowego wzorca z dokumentacji
  -- LVGL (seria danych + funkcja zwracajaca tabele wartosci).
  local chartY, chartH = 60, 220
  local wykres = lvgl.chart(kont, {
    x = 16, y = chartY, w = LCD_W - 32, h = chartH,
    color = U.KOL_PANEL,
    data = function()
      -- zwracamy kopie biezacego bufora napiecia na ogniwo (tylko gdy sie zmienia,
      -- LVGL samo wykryje brak zmian i nie przerysuje)
      local liczbaOgniw = opcje.liczbaOgniw or 1
      local out = {}
      for i = 1, cfg.wykres_probek do
        local v = s.wykres.v[i]
        out[i] = v and (v / liczbaOgniw) or 0
      end
      return out
    end,
  })

  -- ---------- MAKSIMA ----------
  local my = chartY + chartH + 20
  local kolW = (LCD_W - 32) / 4

  local function kafel(i, etykieta, wartoscFn)
    local x = 16 + (i-1) * kolW
    lvgl.rectangle(kont, { x = x, y = my, w = kolW - 10, h = 90, color = U.KOL_PANEL })
    lvgl.label(kont, { x = x+10, y = my+8, w = kolW-30, h = 22, font = U.F_S, color = U.KOL_TEKST_SZARY, text = etykieta })
    lvgl.label(kont, { x = x+10, y = my+34, w = kolW-30, h = 44, font = U.F_L, color = U.KOL_TEKST, text = wartoscFn })
  end

  kafel(1, "MAKS PRAD", function() return U.fmt(s.maks.prad, 1, " A") end)
  kafel(2, "MAKS WYS.", function() return U.fmt(s.maks.wysokosc, 1, " m") end)
  kafel(3, "MAKS ODL.", function() return U.fmtInt(s.maks.odleglosc, " m") end)
  kafel(4, "MAKS PRED", function() return U.fmt(s.maks.predkosc, 1, " m/s") end)

  -- ---------- SZACOWANY CZAS DO REZERWY ----------
  local y2 = my + 110
  lvgl.label(kont, { x = 16, y = y2, w = 400, h = 28, font = U.F_M, color = U.KOL_TEKST_SZARY, text = lang.czas_do_niskiej })
  lvgl.label(kont, {
    x = 16, y = y2 + 30, w = 400, h = 50, font = U.F_XXL, color = U.KOL_TEKST,
    text = function()
      local sek = szacujCzasDoRezerwy(s, opcje)
      if sek == nil then return lang.brak_danych end
      return U.fmtCzas(sek)
    end,
  })

  for i = 1, 3 do
    lvgl.circle(kont, {
      x = LCD_W/2 - 24 + (i-1)*24, y = LCD_H - 10, r = 5,
      color = function() return (ekran.strona == i) and U.KOL_TEKST or U.KOL_TEKST_SZARY end,
    })
  end

  return kont
end

return M
