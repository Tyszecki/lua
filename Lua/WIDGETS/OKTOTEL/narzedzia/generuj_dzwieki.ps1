# generuj_dzwieki.ps1
# Generuje polskie komunikaty glosowe (WAV) przy uzyciu wbudowanego
# syntezatora mowy Windows (System.Speech). Wymaga zainstalowanego
# polskiego glosu (Ustawienia -> Czas i jezyk -> Mowa -> Dodaj glosy).
#
# EdgeTX oczekuje plikow WAV: PCM, mono, 16-bit, czestotliwosc 32000 Hz
# (niektore radia akceptuja tez 16000/8000 Hz - sprawdz w swojej wersji).
# Ten skrypt generuje pliki 16-bit PCM mono; jesli EdgeTX ich nie odtworzy,
# przekonwertuj je np. przez ffmpeg: ffmpeg -i in.wav -ar 32000 -ac 1 out.wav

Add-Type -AssemblyName System.Speech

$wyjscie = Join-Path $PSScriptRoot "..\snd"
New-Item -ItemType Directory -Force -Path $wyjscie | Out-Null

$komunikaty = @{
    "armed"   = "Uzbrojony"
    "disarm"  = "Rozbrojony"
    "batlow"  = "Bateria niska"
    "batcrit" = "Bateria krytyczna"
    "notlm"   = "Brak telemetrii"
    "fsafe"   = "Failsafe"
    "ekferr"  = "Blad EKF"
}

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$glosPl = $synth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -like "pl*" } | Select-Object -First 1
if ($glosPl) {
    $synth.SelectVoice($glosPl.VoiceInfo.Name)
    Write-Host "Uzyto glosu: $($glosPl.VoiceInfo.Name)"
} else {
    Write-Warning "Nie znaleziono polskiego glosu TTS w systemie - tekst zostanie przeczytany domyslnym glosem (prawdopodobnie po angielsku). Zainstaluj polski pakiet glosowy Windows, zeby uzyskac poprawna wymowe."
}

foreach ($klucz in $komunikaty.Keys) {
    $sciezka = Join-Path $wyjscie ("$klucz.wav")
    $synth.SetOutputToWaveFile($sciezka, (New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(
        16000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono
    )))
    $synth.Speak($komunikaty[$klucz])
    $synth.SetOutputToNull()
    Write-Host "Zapisano: $sciezka"
}

Write-Host "`nGotowe. Skopiuj zawartosc folderu 'snd' do /WIDGETS/OKTOTEL/snd/ na karcie SD aparatury."
