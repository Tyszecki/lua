--[[
  modes.lua – numery trybow lotu ArduCopter -> nazwa.

  Numery pochodza z ArduCopter/mode.h (enum Number). Sa stabilne od wielu
  wersji ArduCopter, ale PRZED LOTEM zweryfikuj je wzgledem wersji
  oprogramowania na Twoim Cube Orange+ (Mission Planner -> dokladna wersja
  ArduCopter -> porownaj z https://github.com/ArduPilot/ardupilot/blob/master/ArduCopter/mode.h).
--]]

local M = {}

M.nazwy = {
  [0]  = "STABILIZE",
  [1]  = "ACRO",
  [2]  = "ALTHOLD",
  [3]  = "AUTO",
  [4]  = "GUIDED",
  [5]  = "LOITER",
  [6]  = "RTL",
  [7]  = "CIRCLE",
  [9]  = "LAND",
  [11] = "DRIFT",
  [13] = "SPORT",
  [14] = "FLIP",
  [15] = "AUTOTUNE",
  [16] = "POSHOLD",
  [17] = "BRAKE",
  [18] = "THROW",
  [19] = "AVOID_ADSB",
  [20] = "GUIDED_NOGPS",
  [21] = "SMART_RTL",
  [22] = "FLOWHOLD",
  [23] = "FOLLOW",
  [24] = "ZIGZAG",
  [25] = "SYSTEMID",
  [26] = "AUTOROTATE",
  [27] = "AUTO_RTL",
  [28] = "TURTLE",
}

function M.nazwa(numer)
  if numer == nil then return nil end
  return M.nazwy[numer] or ("TRYB " .. tostring(numer))
end

return M
