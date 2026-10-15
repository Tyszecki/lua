--[[
  config.lua – progi i parametry, ktore NIE sa wystawione jako opcje widgetu
  (EdgeTX 2.12 pozwala na max. 10 opcji na widget, wiec reszta jest tutaj).

  Wszystkie wartosci mozna zmieniac bezposrednio w tym pliku.
--]]

local C = {}

-- Czasy, po ktorych dana kategoria telemetrii uznawana jest za "nieswieza" [s]
C.timeout_passthrough   = 3.0   -- po tylu sek. bez ramki 0x80 przelaczamy na natywne (tryb Auto)
C.timeout_telemetria    = 5.0   -- po tylu sek. bez ZADNEJ ramki -> baner "BRAK TELEMETRII"
C.timeout_link          = 2.0   -- po tylu sek. bez ramki lacza -> pola lacza pokazuja "—"

-- Histereza / czas trwania warunku przed wejsciem w alarm [s]
C.alarm_czas_wejscia    = 2.0
C.alarm_histereza_V     = 0.05  -- V/ogniwo, o ile musi wzrosnac napiecie, by wyjsc z alarmu
C.alarm_powtorz_ostrz   = 30    -- [s] powtorz komunikat glosowy (poziom ostrzegawczy)
C.alarm_powtorz_kryt    = 10    -- [s] powtorz komunikat glosowy (poziom krytyczny)

-- Usrednianie napiecia/pradu do alarmow (okno czasowe) [s]
C.usrednianie_okno      = 3.0

-- Minimalna jakosc lacza (RQly, %) ponizej ktorej alarm "SLABE LACZE"
C.rqly_ostrzezenie      = 70
C.rqly_krytyczny        = 50

-- Progi RSSI (dBm) jako dodatkowa informacja (opcjonalnie)
C.rssi_slaby            = -90

-- Bufor wykresu (strona 3): liczba probek i odstep miedzy nimi [s]
C.wykres_probek         = 120
C.wykres_odstep         = 5

-- Okno usredniania pradu do szacowania czasu lotu [s]
C.szac_czasu_okno       = 60

-- Wzorce tekstow STATUSTEXT, ktore maja byc wyrozniane jako "ADS-B / kolizja"
-- (dopasowanie tekstowe, wielkosc liter bez znaczenia)
C.wzorce_adsb = {
  "ADSB",
  "traffic",
  "collision",
}

-- Wzorce tekstow pochodzacych z Jetsona (jesli beda przekazywane jako STATUSTEXT
-- przez maly posrednik na Cube — patrz instrukcja instalacji, punkt o Jetsonie)
C.wzorce_jetson = {
  "JETSON",
  "ZED",
}

-- Liczba komunikatow STATUSTEXT trzymanych w historii (strona 2)
C.historia_komunikatow  = 15

-- Numery trybow ArduCopter oznaczajace "na ziemi" / szczegolne dla logiki alarmow
C.tryb_land             = 9   -- LAND
C.tryb_rtl              = 6   -- RTL

return C
