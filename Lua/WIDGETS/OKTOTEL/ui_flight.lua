--[[
  ui_flight.lua – Strona 1: LOT (domyslna).

  Buduje drzewo LVGL RAZ (wywolywane z main.lua w funkcji update()).
  Wszystkie wartosci sa aktualizowane przez WLASCIWOSCI DYNAMICZNE (funkcje
  zwracajace aktualna wartosc) – zgodnie z dokumentacja EdgeTX LVGL ("whenever
  the function returns a new value the object's property is automatically
  changed"). Dzieki temu NIE tworzymy nowych obiektow/tabel w kazdej klatce.

  telem  – referencja do telemetry.stan (tabela, mutowana w miejscu)
  opcje  – referencja do tabeli opcji widgetu (patrz main.lua)
  ekran  – wspolny stan { strona = 1..3 } z main.lua, uzywany do ukrywania
--]]

local U     = loadScript("/WIDGETS/OKTOTEL/ui_common.lua")()
local lang  = loadScript("/WIDGETS/OKTOTEL/lang.lua")()

local M = {}

-- WAZNE: `telemetry` MUSI byc ta sama instancja modulu, co ta uzywana w
-- main.lua (ktora faktycznie wywoluje telemetry.update()). Gdyby kazdy
-- plik ui_*.lua robil wlasny loadScript(".../telemetry.lua")(), powstalaby
-- OSOBNA kopia stanu i UI nigdy nie zobaczyloby aktualizacji z main.lua.
-- Dlatego main.lua laduje telemetry.lua RAZ i przekazuje referencje tutaj.
function M.build(parent, telemetry, opcje, ekran, alertStan)
  local s = telemetry.stan -- referencja (mutowana w telemetry.update())

  -- hidden jako funkcja dynamiczna (NIEPEWNE czy wspierane dla tej
  -- wlasciwosci - patrz main.lua: dla pewnosci strona jest DODATKOWO
  -- ukrywana jawnie w refresh() przez ctx.paginy.flight.hidden = ...)
  local kont = lvgl.rectangle(parent, {
    x = 0, y = 0, w = LCD_W, h = LCD_H,
    color = U.KOL_TLO,
    hidden = function() return ekran.strona ~= 1 end,
  })

  -- ---------- PASEK GORNY ----------
  lvgl.rectangle(kont, { x = 0, y = 0, w = LCD_W, h = 64, color = U.KOL_PANEL })

  lvgl.label(kont, {
    x = 16, y = 8, w = 260, h = 48,
    font = U.F_XL,
    color = function()
      if s.armed == nil then return U.KOL_TEKST_SZARY end
      return s.armed and U.KOL_CZERWONY or U.KOL_ZIELONY
    end,
    text = function() return s.flightModeText or lang.brak_danych end,
  })

  lvgl.label(kont, {
    x = 290, y = 8, w = 160, h = 24, font = U.F_M,
    color = function()
      if s.armed == nil then return U.KOL_TEKST_SZARY end
      return s.armed and U.KOL_CZERWONY or U.KOL_ZIELONY
    end,
    text = function()
      if s.armed == nil then return lang.brak_danych end
      return s.armed and lang.armed or lang.disarmed
    end,
  })

  lvgl.label(kont, {
    x = 290, y = 34, w = 160, h = 22, font = U.F_S, color = U.KOL_TEKST_SZARY,
    text = function()
      return s.source_active == "passthrough" and lang.zrodlo_pt
          or (s.source_active == "native" and lang.zrodlo_nat or lang.brak_danych)
    end,
  })

  lvgl.label(kont, {
    x = 600, y = 8, w = 190, h = 24, font = U.F_M,
    color = function() return U.kolorProg(s.link.rqly, 70, 50, false) end,
    text = function()
      if s.link.rqly == nil then return lang.brak_danych end
      return "RQ " .. U.fmtInt(s.link.rqly, "%")
    end,
  })
  lvgl.label(kont, {
    x = 600, y = 34, w = 190, h = 22, font = U.F_S, color = U.KOL_TEKST_SZARY,
    text = function()
      if s.link.rss1 == nil then return lang.brak_danych end
      return U.fmtInt(s.link.rss1, "dBm")
    end,
  })

  -- ---------- LEWA KOLUMNA: NAWIGACJA ----------
  local navX, navW = 0, 200
  lvgl.rectangle(kont, { x = navX, y = 64, w = navW, h = LCD_H - 64 - 44, color = U.KOL_PANEL })
  lvgl.label(kont, { x = navX+12, y = 72, w = navW-24, h = 20, font = U.F_S, color = U.KOL_TEKST_SZARY, text = lang.nav_tytul })

  lvgl.label(kont, {
    x = navX+12, y = 96, w = navW-24, h = 36, font = U.F_L,
    color = function() return U.kolorProg(s.gps.sats, 10, 6, true) end,
    text = function() return lang.sat .. " " .. (s.gps.sats and U.fmtInt(s.gps.sats) or lang.brak_danych) end,
  })
  lvgl.label(kont, {
    x = navX+12, y = 134, w = navW-24, h = 22, font = U.F_S, color = U.KOL_TEKST_SZARY,
    text = function() return telemetry.tekstFix(s.gps.fix) .. (telemetry.tekstAdvFix(s.gps.advFix) and (" " .. telemetry.tekstAdvFix(s.gps.advFix)) or "") end,
  })
  lvgl.label(kont, {
    x = navX+12, y = 160, w = navW-24, h = 22, font = U.F_S, color = U.KOL_TEKST_SZARY,
    text = function() return lang.hdop .. " " .. U.fmt(s.gps.hdop, 1) end,
  })

  -- Strzalka do domu: trojkat obracany wg s.home.bearing (0 = przod drona)
  -- UWAGA: bez kompasu/kursu drona bezwzglednego (Hdg) strzalka pokazuje
  -- kierunek wzgledem dziobu drona (tak jak dostarcza go ramka 0x5004).
  local cx, cy, r = navX + navW/2, 250, 50
  lvgl.triangle(kont, {
    color = U.KOL_NIEBIESKI,
    pts = function()
      local brg = (s.home.bearing or 0) * math.pi / 180
      local function pt(ang, rad)
        return { cx + rad * math.sin(ang), cy - rad * math.cos(ang) }
      end
      local p1 = pt(brg, r)
      local p2 = pt(brg + 2.7, r * 0.45)
      local p3 = pt(brg - 2.7, r * 0.45)
      return { p1, p2, p3 }
    end,
  })

  lvgl.label(kont, {
    x = navX+12, y = 320, w = navW-24, h = 28, font = U.F_M, color = U.KOL_TEKST,
    text = function() return lang.dom .. " " .. (s.home.distance and U.fmtInt(s.home.distance, "m") or lang.brak_danych) end,
  })
  lvgl.label(kont, {
    x = navX+12, y = 350, w = navW-24, h = 24, font = U.F_S, color = U.KOL_TEKST_SZARY,
    text = function()
      local alt = s.home.altRel or s.gps.altMSL
      return "ALT " .. (alt and U.fmt(alt, 1, "m") or lang.brak_danych)
    end,
  })

  -- ---------- SRODEK: SZTUCZNY HORYZONT + DANE LOTU ----------
  local midX, midW = navW, LCD_W - navW - 240
  local hx, hy, hw, hh = midX + 40, 70, midW - 80, 240

  lvgl.label(kont, {
    x = midX+16, y = 64, w = midW-32, h = 56, font = U.F_XXL, color = U.KOL_TEKST,
    text = function()
      local alt = s.home.altRel or s.gps.altMSL
      return alt and U.fmt(alt, 1, "m") or lang.brak_danych
    end,
  })
  lvgl.label(kont, {
    x = midX+16, y = 120, w = midW-32, h = 24, font = U.F_S, color = U.KOL_TEKST_SZARY,
    text = function()
      return "VS " .. (s.vel.vspd and U.fmt(s.vel.vspd, 1, " m/s") or lang.brak_danych)
    end,
  })

  -- Ramka horyzontu
  lvgl.rectangle(kont, { x = hx, y = hy+30, w = hw, h = hh, color = U.KOL_PANEL })

  -- "Ziemia" – linia pozioma reprezentujaca roll/pitch (uproszczona drabinka)
  -- Linia przechyla sie wg roll, a jej wysokosc (y) przesuwa sie wg pitch.
  lvgl.line(kont, {
    color = U.KOL_ZOLTY, width = 4,
    pts = function()
      local roll = (s.att.roll or 0) * math.pi / 180
      local pitch = s.att.pitch or 0
      local cxh, cyh = hx + hw/2, hy + 30 + hh/2 + pitch * 2 -- 2 px/stopien
      local half = hw * 0.4
      local dx = half * math.cos(roll)
      local dy = half * math.sin(roll)
      return { { cxh - dx, cyh - dy }, { cxh + dx, cyh + dy } }
    end,
  })
  -- Znacznik srodka (statyczny, nie zalezy od danych)
  lvgl.line(kont, {
    color = U.KOL_TEKST, width = 3,
    pts = { { hx + hw/2 - 20, hy + 30 + hh/2 }, { hx + hw/2 + 20, hy + 30 + hh/2 } },
  })

  lvgl.label(kont, {
    x = hx, y = hy + hh + 34, w = hw/2, h = 28, font = U.F_M, color = U.KOL_TEKST_SZARY,
    text = function()
      return "KURS " .. (s.vel.yaw and U.fmtInt(s.vel.yaw, "st") or lang.brak_danych)
    end,
  })
  lvgl.label(kont, {
    x = hx + hw/2, y = hy + hh + 34, w = hw/2, h = 28, font = U.F_M, color = U.KOL_TEKST_SZARY,
    text = function()
      return "GS " .. (s.vel.gspd and U.fmt(s.vel.gspd, 1, " m/s") or lang.brak_danych)
    end,
  })

  -- ---------- PRAWA KOLUMNA: BATERIA ----------
  local batX, batW = LCD_W - 240, 240
  lvgl.rectangle(kont, { x = batX, y = 64, w = batW, h = LCD_H - 64 - 44, color = U.KOL_PANEL })
  lvgl.label(kont, { x = batX+12, y = 72, w = batW-24, h = 20, font = U.F_S, color = U.KOL_TEKST_SZARY, text = lang.bat_tytul })

  lvgl.label(kont, {
    x = batX+12, y = 96, w = batW-24, h = 44, font = U.F_XL,
    color = function()
      local vc = s.battery.voltage and opcje.liczbaOgniw and (s.battery.voltage / opcje.liczbaOgniw) or nil
      return U.kolorProg(vc, opcje.progNiskiV, opcje.progKrytV, false)
    end,
    text = function() return s.battery.voltage and U.fmt(s.battery.voltage, 1, " V") or lang.brak_danych end,
  })
  lvgl.label(kont, {
    x = batX+12, y = 142, w = batW-24, h = 24, font = U.F_S, color = U.KOL_TEKST_SZARY,
    text = function()
      if s.battery.voltage == nil or opcje.liczbaOgniw == nil or opcje.liczbaOgniw == 0 then return lang.brak_danych end
      return U.fmt(s.battery.voltage / opcje.liczbaOgniw, 2, " V/ogn.")
    end,
  })
  lvgl.label(kont, {
    x = batX+12, y = 176, w = batW-24, h = 28, font = U.F_M, color = U.KOL_TEKST,
    text = function() return lang.bat_prad .. " " .. (s.battery.current and U.fmt(s.battery.current, 1, " A") or lang.brak_danych) end,
  })
  lvgl.label(kont, {
    x = batX+12, y = 210, w = batW-24, h = 28, font = U.F_M, color = U.KOL_TEKST,
    text = function() return s.battery.mah and U.fmtInt(s.battery.mah, " mAh") or lang.brak_danych end,
  })
  lvgl.label(kont, {
    x = batX+12, y = 244, w = batW-24, h = 28, font = U.F_M, color = U.KOL_TEKST,
    text = function()
      if s.battery.percent then return U.fmtInt(s.battery.percent, "%") end
      -- jesli brak procentu z telemetrii, policz z pojemnosci skonfigurowanej
      if s.battery.mah and opcje.pojemnoscMah and opcje.pojemnoscMah > 0 then
        local proc = 100 * (1 - s.battery.mah / opcje.pojemnoscMah)
        if proc < 0 then proc = 0 end
        return U.fmtInt(proc, "% *")
      end
      return lang.brak_danych
    end,
  })

  -- pasek baterii
  lvgl.rectangle(kont, { x = batX+12, y = 282, w = batW-24, h = 18, color = U.KOL_TEKST_SZARY })
  lvgl.rectangle(kont, {
    x = batX+12, y = 282, h = 18,
    w = function()
      local proc = s.battery.percent
      if proc == nil and s.battery.mah and opcje.pojemnoscMah and opcje.pojemnoscMah > 0 then
        proc = 100 * (1 - s.battery.mah / opcje.pojemnoscMah)
      end
      if proc == nil then proc = 0 end
      if proc < 0 then proc = 0 end
      if proc > 100 then proc = 100 end
      return math.floor((batW - 24) * proc / 100)
    end,
    color = function()
      local vc = s.battery.voltage and opcje.liczbaOgniw and (s.battery.voltage / opcje.liczbaOgniw) or nil
      return U.kolorProg(vc, opcje.progNiskiV, opcje.progKrytV, false)
    end,
  })

  lvgl.label(kont, {
    x = batX+12, y = 312, w = (batW-24)/2, h = 24, font = U.F_S, color = U.KOL_TEKST_SZARY,
    text = function()
      if s.battery.voltage then return lang.pakiet_1 .. " OK" end
      return lang.pakiet_1 .. " " .. lang.pakiet_brak
    end,
  })
  lvgl.label(kont, {
    x = batX+12+(batW-24)/2, y = 312, w = (batW-24)/2, h = 24, font = U.F_S,
    color = function() return s.battery2.widziany and U.KOL_TEKST_SZARY or U.KOL_TEKST_SZARY end,
    text = function() return lang.pakiet_2 .. " " .. (s.battery2.widziany and U.fmt(s.battery2.voltage, 1, "V") or lang.pakiet_brak) end,
  })

  -- ---------- PASEK DOLNY: OSTATNI KOMUNIKAT ----------
  local dolY = LCD_H - 44
  lvgl.rectangle(kont, { x = 0, y = dolY, w = LCD_W, h = 44, color = U.KOL_PANEL })
  lvgl.label(kont, {
    x = 16, y = dolY+8, w = LCD_W - 180, h = 28, font = U.F_M,
    color = function()
      local m = s.ostatniKomunikat
      if m == nil then return U.KOL_TEKST_SZARY end
      if m.sev <= 2 then return U.KOL_CZERWONY end
      if m.sev <= 4 then return U.KOL_ZOLTY end
      return U.KOL_TEKST_SZARY
    end,
    text = function()
      local m = s.ostatniKomunikat
      return m and m.text or lang.brak_danych
    end,
  })

  -- ---------- BANER ALARMU (nad wszystkim, na tej stronie) ----------
  local baner = lvgl.rectangle(kont, {
    x = 0, y = 150, w = LCD_W, h = 140,
    color = function()
      if alertStan.kolor == "red" then return U.KOL_CZERWONY end
      if alertStan.kolor == "yellow" then return U.KOL_ZOLTY end
      return U.KOL_TLO
    end,
    hidden = function() return alertStan.baner == nil end,
  })
  lvgl.label(baner, {
    x = 0, y = 40, w = LCD_W, h = 60, font = U.F_XXL, color = U.KOL_TEKST,
    align = "center",
    text = function() return alertStan.baner or "" end,
    hidden = function() return alertStan.baner == nil end,
  })

  -- ---------- WSKAZNIK STRONY ----------
  for i = 1, 3 do
    lvgl.circle(kont, {
      x = LCD_W/2 - 24 + (i-1)*24, y = LCD_H - 10, r = 5,
      color = function() return (ekran.strona == i) and U.KOL_TEKST or U.KOL_TEKST_SZARY end,
    })
  end

  return kont
end

return M
