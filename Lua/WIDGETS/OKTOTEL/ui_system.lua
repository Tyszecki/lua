--[[
  ui_system.lua – Strona 2: SYSTEM (szczegoly lacza, EKF/failsafe, historia komunikatow).
--]]

local U    = loadScript("/WIDGETS/OKTOTEL/ui_common.lua")()
local lang = loadScript("/WIDGETS/OKTOTEL/lang.lua")()
local cfg  = loadScript("/WIDGETS/OKTOTEL/config.lua")()

local M = {}

local function wiersz(kont, x, y, w, etykieta, wartoscFn)
  lvgl.label(kont, { x = x, y = y, w = w*0.45, h = 26, font = U.F_S, color = U.KOL_TEKST_SZARY, text = etykieta })
  lvgl.label(kont, { x = x + w*0.45, y = y, w = w*0.55, h = 26, font = U.F_M, color = U.KOL_TEKST, text = wartoscFn })
end

-- `telemetry` – patrz komentarz w ui_flight.lua: musi to byc ta sama
-- instancja modulu co w main.lua, przekazana jako parametr.
function M.build(parent, telemetry, opcje, ekran, alertStan)
  local s = telemetry.stan

  local kont = lvgl.rectangle(parent, {
    x = 0, y = 0, w = LCD_W, h = LCD_H, color = U.KOL_TLO,
    hidden = function() return ekran.strona ~= 2 end,
  })

  lvgl.rectangle(kont, { x = 0, y = 0, w = LCD_W, h = 48, color = U.KOL_PANEL })
  lvgl.label(kont, { x = 16, y = 10, w = 300, h = 30, font = U.F_L, color = U.KOL_TEKST, text = lang.sys_tytul })

  -- ---------- LEWA: LACZE + STATUS ----------
  local lx, lw = 16, 380
  lvgl.label(kont, { x = lx, y = 60, w = lw, h = 24, font = U.F_M, color = U.KOL_TEKST_SZARY, text = lang.lacze_tytul })

  local y = 90
  wiersz(kont, lx, y, lw, "1RSS", function() return s.link.rss1 and U.fmtInt(s.link.rss1, " dBm") or lang.brak_danych end); y=y+30
  wiersz(kont, lx, y, lw, "2RSS", function() return s.link.rss2 and U.fmtInt(s.link.rss2, " dBm") or lang.brak_danych end); y=y+30
  wiersz(kont, lx, y, lw, "RQly", function() return s.link.rqly and U.fmtInt(s.link.rqly, " %") or lang.brak_danych end); y=y+30
  wiersz(kont, lx, y, lw, "RSNR", function() return s.link.rsnr and U.fmtInt(s.link.rsnr, " dB") or lang.brak_danych end); y=y+30
  wiersz(kont, lx, y, lw, "ANT",  function() return s.link.ant  and U.fmtInt(s.link.ant) or lang.brak_danych end); y=y+30
  wiersz(kont, lx, y, lw, "RFMD", function() return s.link.rfmd and U.fmtInt(s.link.rfmd) or lang.brak_danych end); y=y+30
  wiersz(kont, lx, y, lw, "TPWR", function() return s.link.tpwr and U.fmtInt(s.link.tpwr, " mW") or lang.brak_danych end); y=y+30
  wiersz(kont, lx, y, lw, "TQly", function() return s.link.tqly and U.fmtInt(s.link.tqly, " %") or lang.brak_danych end); y=y+30
  wiersz(kont, lx, y, lw, "TSNR", function() return s.link.tsnr and U.fmtInt(s.link.tsnr, " dB") or lang.brak_danych end); y=y+30

  y = y + 20
  lvgl.rectangle(kont, { x = lx, y = y, w = lw, h = 1, color = U.KOL_TEKST_SZARY })
  y = y + 16

  wiersz(kont, lx, y, lw, lang.ekf, function()
    if s.ekfFailsafe == nil then return lang.brak_danych end
    return (s.ekfFailsafe == 0) and "OK" or ("BLAD " .. s.ekfFailsafe)
  end); y = y + 30
  wiersz(kont, lx, y, lw, lang.failsafe, function()
    if s.battFailsafe == nil then return lang.brak_danych end
    return s.battFailsafe and lang.failsafe_aktywny or "OK"
  end); y = y + 30
  wiersz(kont, lx, y, lw, lang.w_locie, function()
    if s.landComplete == nil then return lang.brak_danych end
    return s.landComplete and lang.wyladowany or lang.w_locie
  end); y = y + 30

  -- ---------- PRAWA: HISTORIA KOMUNIKATOW ----------
  local rx, rw = 420, LCD_W - 420 - 16
  lvgl.label(kont, { x = rx, y = 60, w = rw, h = 24, font = U.F_M, color = U.KOL_TEKST_SZARY, text = lang.komunikaty })

  -- Statyczna liczba "slotow" tekstu (cfg.historia_komunikatow), kazdy slot
  -- czyta dynamicznie s.historia[i] – bez tworzenia nowych obiektow w locie.
  for i = 1, cfg.historia_komunikatow do
    local yy = 90 + (i-1) * 24
    if yy < LCD_H - 20 then
      lvgl.label(kont, {
        x = rx, y = yy, w = 90, h = 22, font = U.F_XS, color = U.KOL_TEKST_SZARY,
        text = function()
          local m = s.historia[i]
          if m == nil then return "" end
          return U.fmtCzas(m.t)
        end,
      })
      lvgl.label(kont, {
        x = rx + 90, y = yy, w = rw - 90, h = 22, font = U.F_XS,
        color = function()
          local m = s.historia[i]
          if m == nil then return U.KOL_TEKST_SZARY end
          if m.sev <= 2 then return U.KOL_CZERWONY end
          if m.sev <= 4 then return U.KOL_ZOLTY end
          return U.KOL_TEKST_SZARY
        end,
        text = function()
          local m = s.historia[i]
          return m and m.text or ""
        end,
      })
    end
  end

  for i = 1, 3 do
    lvgl.circle(kont, {
      x = LCD_W/2 - 24 + (i-1)*24, y = LCD_H - 10, r = 5,
      color = function() return (ekran.strona == i) and U.KOL_TEKST or U.KOL_TEKST_SZARY end,
    })
  end

  return kont
end

return M
