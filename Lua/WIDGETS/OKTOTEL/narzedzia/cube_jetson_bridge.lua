--[[
  cube_jetson_bridge.lua – OPCJONALNY skrypt AP_SCRIPTING (uruchamiany NA
  Cube Orange+, nie na aparaturze!). To jest inny silnik Lua niz EdgeTX.

  PO CO: ArduPilot kolejkuje do passthrough/CRSF przede wszystkim komunikaty
  STATUSTEXT wygenerowane WLASNYM gcs():send_text(). Nie jest pewne
  (DO ZWERYFIKOWANIA w locie/na ziemi), czy STATUSTEXT wyslany bezposrednio
  z Jetsona (inny sysid/compid) po MAVLink trafia do tej samej kolejki.
  Ten skrypt nasluchuje komunikatow przychodzacych od Jetsona i jesli trzeba,
  WYSYLA JE PONOWNIE przez gcs:send_text() z poziomu samego FC – to gwarantuje,
  ze trafia do kolejki passthrough i pojawi sie w widgetcie (strona SYSTEM /
  pasek dolny strony LOT).

  WYMAGANIA:
    - SCR_ENABLE = 1
    - plik w /APM/scripts/ na karcie SD Cube
    - Jetson wysyla STATUSTEXT (MAV_SEVERITY, tekst) do Cube po TELEM2

  Jesli STATUSTEXT z Jetsona JEST juz widoczny w widgetcie bez tego mostka
  (do sprawdzenia w praktyce), ten plik mozna pominac.
--]]

local ZRODLO_SYSID_JETSON = nil -- jesli chcesz filtrowac tylko komunikaty z konkretnego sysid, wpisz tutaj

function update()
  local msg = mavlink_statustext and mavlink_statustext:receive() or nil
  -- UWAGA: dokladne API do odbioru surowych STATUSTEXT w AP_Scripting rozni
  -- sie miedzy wersjami ArduPilot (np. mavlink:init()/mavlink:receive_chan()).
  -- Powyzsza linia to SZKIELET do uzupelnienia wg wersji firmware -
  -- zobacz dokumentacje AP_Scripting (bindings mavlink) dla Twojej wersji.
  if msg ~= nil then
    gcs:send_text(msg.severity, "JETSON: " .. msg.text)
  end
  return update, 200 -- wywolaj ponownie za 200 ms
end

return update, 1000
