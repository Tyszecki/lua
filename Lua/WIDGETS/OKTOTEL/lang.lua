--[[
  lang.lua – wszystkie napisy widgetu w jednym miejscu (PL).
  Zeby zmienic jezyk, wystarczy podmienic wartosci w tej tabeli.
--]]

local L = {}

-- Ogolne
L.app_name        = "OKTOTEL"
L.brak_danych     = "—"
L.strona          = "Strona"

-- Pasek gorny
L.armed           = "UZBROJONY"
L.disarmed        = "ROZBROJONY"
L.zrodlo_pt       = "PT"      -- passthrough aktywny
L.zrodlo_nat      = "NAT"     -- tylko telemetria natywna

-- Nawigacja
L.nav_tytul       = "NAWIGACJA"
L.sat             = "SAT"
L.hdop            = "HDOP"
L.dom             = "DOM"
L.fix_brak        = "BRAK"
L.fix_2d          = "2D"
L.fix_3d          = "3D"
L.fix_dgps        = "DGPS"
L.fix_rtk_float   = "RTK-F"
L.fix_rtk_fixed   = "RTK-X"

-- Bateria
L.bat_tytul       = "BATERIA"
L.bat_na_ogniwo   = "V/ogn."
L.bat_prad        = "PRAD"
L.bat_zuzyte      = "ZUZYTE"
L.bat_procent     = "%"
L.pakiet_1        = "P1"
L.pakiet_2        = "P2"
L.pakiet_brak     = "BRAK"

-- System / lacze
L.sys_tytul       = "SYSTEM"
L.lacze_tytul     = "LACZE"
L.ekf             = "EKF"
L.failsafe        = "FAILSAFE"
L.w_locie         = "W LOCIE"
L.wyladowany      = "WYLADOWANY"
L.komunikaty      = "KOMUNIKATY"

-- Alarmy / bannery
L.brak_telemetrii = "BRAK TELEMETRII"
L.bat_niska       = "BATERIA NISKA"
L.bat_krytyczna   = "BATERIA KRYTYCZNA"
L.lacze_slabe     = "SLABE LACZE"
L.failsafe_aktywny= "FAILSAFE!"
L.ekf_blad        = "BLAD EKF"
L.brak_gps        = "BRAK GPS"

-- Glosowe komunikaty (nazwy plikow .wav w /SOUNDS/pl/ – bez rozszerzenia)
-- Uwaga: dokladne nazwy plikow pakietu polskiego trzeba zweryfikowac na karcie SD.
L.snd_armed       = "armed"
L.snd_disarmed    = "disarm"
L.snd_bat_niska   = "batlow"
L.snd_bat_kryt    = "batcrit"
L.snd_telem_brak  = "notlm"
L.snd_failsafe    = "fsafe"
L.snd_ekf         = "ekferr"

-- Strona bateria/lot
L.wykres_tytul    = "NAPIECIE / PRAD"
L.maksima         = "MAKSIMA"
L.czas_do_niskiej = "CZAS DO REZERWY"

return L
