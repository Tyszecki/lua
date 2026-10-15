# OKTOTEL – widget telemetrii EdgeTX dla oktokoptera ArduPilot/ELRS

Widget App Mode (pełny ekran) dla RadioMaster TX16S MK3 MAX, EdgeTX 2.12.4,
dron: oktokopter ArduCopter na Cube Orange+, łącze ELRS (XR4 Gemini, crossband).

## 1. Instalacja

1. Skopiuj cały folder `WIDGETS/OKTOTEL/` (łącznie z podfolderem `snd/`,
   jeśli wygenerowałeś dźwięki – patrz punkt 6) na kartę SD aparatury,
   do `/WIDGETS/OKTOTEL/`.
2. Na aparaturze: **Model → Ekrany → Dodaj widok → Układ "1 widget"**
   (albo dowolny inny układ pełnoekranowy).
3. Wybierz pole widgetu → **Widget: OKTOTEL**.
4. Wejdź w ustawienia widgetu i ustaw opcje (liczba ogniw, pojemność,
   progi napięcia, próg RQly, czas do alarmu braku telemetrii, głos,
   źródło, LED/wibracje).
5. Z menu kontekstowego widgetu wybierz **App Mode** (albo „Pełny ekran",
   w zależności od wersji – u Ciebie, jak potwierdziłeś, działa to tak, że
   przytrzymanie palca rozwija widget na cały ekran i pozostaje reaktywny
   na dotyk/zmianę trybu).
6. Jeśli chcesz komunikaty głosowe: uruchom
   `narzedzia/generuj_dzwieki.ps1` w PowerShell na komputerze z Windows
   i zainstalowanym polskim głosem TTS, a wynikowy folder `snd/` skopiuj
   do `/WIDGETS/OKTOTEL/snd/` na karcie SD. Bez tego widget nadal działa,
   po prostu komunikaty głosowe się nie odtworzą (próba odtworzenia
   nieistniejącego pliku jest przechwycona i nie wywali skryptu).

## 2. Wykrycie sensorów w EdgeTX

1. Model → Telemetria → **Wykryj nowe sensory**.
2. Sprawdź dokładne nazwy wykrytych sensorów łącza i baterii (np. `1RSS`,
   `RQly`, `RxBt`, `Curr`, `Capa`, `Bat%`, `Sats`, `FM`...).
3. Jeśli nazwy różnią się od tych w kodzie, popraw tabelę
   `NATIVE_FIELDS` na górze `telemetry.lua` (to jedyne miejsce, które
   trzeba tam zmienić).

## 3. Parametry ArduPilot (Mission Planner / parametry pełne)

| Parametr | Wartość | Po co |
|---|---|---|
| `SERIALx_PROTOCOL` | `23` (RCIN) | port, do którego podłączony jest odbiornik ELRS |
| `RSSI_TYPE` | `3` | RSSI/LQ z protokołu odbiornika |
| `RC_OPTIONS` | dodaj **+256** (bit 8 – passthrough/custom telemetry) | włącza pełną telemetrię (tryb B z planu) |
| `RC_OPTIONS` | dodaj **+512** (bit 9) | wycisza komunikat trybu/rate ELRS (zalecane przez dokumentację ExpressLRS) |
| `RC_OPTIONS` | dodaj **+4096** (bit 12) | dopisuje `*` do nazwy trybu przy rozbrojeniu – **wymagane**, żeby tryb natywny (bez passthrough) w ogóle pokazywał stan rozbrojenia |
| `RC_OPTIONS` | dodaj **+8192** (bit 13) | 420 kbaud – zgodnie z zaleceniem ExpressLRS dla ELRS po CRSF |

**Sumowanie bitów:** `RC_OPTIONS` to maska bitowa – dodaj do obecnej
wartości `256 + 512 + 4096 + 8192 = 13056`, o ile żaden z tych bitów nie
jest już ustawiony z innego powodu. Sprawdź obecną wartość przed zmianą.

**Konflikt do uniknięcia:** żaden port szeregowy nie może mieć
`SERIALx_PROTOCOL = 10` (Passthrough) jednocześnie z `RC_OPTIONS` bit 8 –
dokumentacja ArduPilot wprost ostrzega przed konfliktem i niestabilną
telemetrią.

Jeśli skonfigurujesz drugi czujnik Mauch jako `BATT2_MONITOR`, widget
spróbuje odczytać go z ramki passthrough `0x5008` (appid). **To pole NIE
jest potwierdzone w oficjalnym arkuszu specyfikacji ArduPilot dostępnym
publicznie** – jeśli po skonfigurowaniu BATT2 widget dalej pokazuje
„P2 BRAK", trzeba zweryfikować rzeczywisty appid w Twojej wersji firmware
(przeszukaj `AP_Frsky_SPort_Passthrough.cpp` Twojej gałęzi ArduCopter).

## 4. Ustawienia ELRS

- **Współczynnik telemetrii:** cel to efektywna częstotliwość telemetrii
  **≥ 25 Hz, najlepiej ≥ 50 Hz** (częstotliwość pakietów ÷ współczynnik).
  Przykłady: 100 Hz + 1:2 = 50 Hz (dobry wybór), 250 Hz + 1:4 = 62,5 Hz.
  Unikaj np. 100 Hz + 1:8 (12,5 Hz – za mało, komunikaty tekstowe i strony
  2/3 będą się odświeżać bardzo wolno).
- Przy masie 20–24 kg i module Gemini 2,4+900 MHz zalecany jest wyższy
  pakiet (np. 150–250 Hz) kosztem współczynnika telemetrii – dobierz tak,
  by spełnić próg powyżej.

## 5. Test w symulatorze EdgeTX Companion

1. Otwórz model w Companion, wgraj do niego widget tak jak na radiu
   (Companion czyta ten sam folder `WIDGETS/`).
2. Companion **nie generuje** prawdziwych ramek CRSF passthrough – do
   testu logiki telemetrii:
   - w symulatorze telemetrii Companion możesz ręcznie ustawiać wartości
     sensorów natywnych (1RSS, RxBt, Sats...) i sprawdzić **tryb natywny**
     (okrojony) – to przetestujesz w pełni.
   - **tryb passthrough nie da się sensownie przetestować w samym
     Companion** bez realnego strumienia CRSF z ArduPilot (SITL + most
     CRSF, albo nagranie ramek). Najprostszy pierwszy test: podłącz radio
     do SITL ArduCopter przez prawdziwy moduł ELRS (albo do drona na
     ziemi, śmigła zdjęte, silniki bez zasilania) i obserwuj realne dane.
3. Sprawdź w Companion przede wszystkim: czy strony się przełączają
   (swipe / przyciski PAGE), czy UI się nie zawiesza, czy brak danych
   pokazuje „—" a nie błąd/0.
4. Dopiero po tym teście wgrywaj na prawdziwą aparaturę.

## 6. Znane ograniczenia (świadomie, zgodnie z zadaniem)

- **Prądy poszczególnych pakietów LiPo z Mauch 031** – widoczne jako dwie
  oddzielne wartości TYLKO jeśli skonfigurujesz `BATT2_MONITOR` na Cube,
  i tylko jeśli appid `0x5008` faktycznie istnieje w Twojej wersji FW
  (patrz pkt. 3). W przeciwnym razie zawsze suma na jeden pakiet, a panel
  „P2" pokazuje „BRAK".
- **Telemetria poszczególnych ESC/silników** – niedostępna, port CAN ESC
  nie jest podłączony (zgodnie z planem na przyszłość).
- **Szczegóły Jetsona/ZED** (FPS, temperatura GPU itd.) – widoczne tylko,
  jeśli Jetson wyśle je jako `STATUSTEXT` do Cube, a Cube przekaże je
  dalej do kolejki passthrough. To **nie jest pewne** (patrz
  `narzedzia/cube_jetson_bridge.lua` jako obejście, jeśli się okaże że
  bezpośrednio nie działa).
- **Ruch lotniczy ADS-B** – widget wyłapuje tylko pasujące teksty
  `STATUSTEXT` (wzorce w `config.lua` → `wzorce_adsb`), nie ma dedykowanej
  ramki ADS-B w passthrough.
- **Surowe współrzędne GPS (lat/lon)** – celowo NIE dekodowane z ramki
  `0x0800` (skomplikowany format ze znakiem/naprzemiennością lat/lon); do
  nawigacji na ekranie LOT wystarcza odległość+kierunek z ramki `0x5004`
  (HOME). Jeśli kiedyś potrzebne będą surowe współrzędne, trzeba dopisać
  dekoder tej ramki.
- **Offsety roll/pitch w dekoderze `0x5006`** (−180°/−90°) są
  WYPROWADZONE z zakresu kodowania bitowego, nie zacytowane wprost ze
  źródła ArduPilot – zweryfikuj w poziomym locie (roll/pitch powinny
  pokazywać ~0°).
- **Podtypy ramki CRSF custom telemetry** (`0xF0`/`0xF1`/`0xF2`) pochodzą
  z wtórnych źródeł (fora/community), nie z pliku nagłówkowego
  `AP_CRSF_Protocol.h` wprost (ten plik nie był publicznie dostępny pod
  sprawdzonym adresem w trakcie pisania tego kodu) – jeśli passthrough nie
  działa mimo poprawnego `RC_OPTIONS`, to pierwsze miejsce do sprawdzenia.
- **Sterowanie diodami RGB przycisków z poziomu Lua widgetu** – brak
  bezpośredniego API w sandboxie EdgeTX (potwierdzone). Widget ustawia
  tylko zmienną globalną (GV8 domyślnie, do zmiany w `alerts.lua`), którą
  musisz podpiąć pod Funkcję specjalną / Przełącznik logiczny sterujący
  kolorem LED (Model → Specjalne funkcje, warunek na GV8).
- **Nazwy plików dźwiękowych polskiego pakietu systemowego EdgeTX** – nie
  były weryfikowane; `alerts.lua` najpierw próbuje odtworzyć własne pliki
  z `/WIDGETS/OKTOTEL/snd/`, a dopiero w razie błędu próbuje nazwy
  systemowej jako fallback (który i tak prawdopodobnie nie istnieje pod
  tą samą nazwą – fallback jest tylko siatką bezpieczeństwa, nie
  gwarancją).
- **Dokładna składnia opcji CHOICE, pól `touchState` i zdarzeń
  PAGE/rotacji** w `main.lua` – oznaczone komentarzami „DO ZWERYFIKOWANIA",
  bo nie udało się ich potwierdzić 1:1 z publicznej dokumentacji; kod
  używa bezpiecznych odpowiedników (VALUE zamiast CHOICE) tam, gdzie to
  możliwe.

## 7. Co jeszcze warto zrobić przed pierwszym lotem

1. Przelecieć w trybie Stabilize/AltHold na dworze z pełnym GPS fixem i
   sprawdzić, czy odległość/kierunek do domu oraz wysokość są sensowne.
2. Celowo wywołać alarm niskiego napięcia (np. obniżając próg w opcjach
   na czas testu) i sprawdzić kolor/dźwięk/wibrację.
3. Sprawdzić zachowanie przy **utracie telemetrii** (wyłącz nadajnik na
   chwilę w bezpiecznych warunkach naziemnych) – baner powinien pojawić
   się po skonfigurowanym czasie (`TOTLM`, domyślnie 5 s).
4. Zweryfikować numery trybów lotu z `modes.lua` względem swojej wersji
   ArduCopter (link w komentarzu w tym pliku).
