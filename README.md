# Weeb Radar v2

Aplikacja na **Androida i Windowsa** (Flutter), która wyszukuje koncerty, trasy, konwenty i mniejsze eventy z japońską muzyką, vocaloidami i vtuberami, a potem podświetla te z artystami, których słuchasz.

| Telefon | Windows |
|---|---|
| ![Radar](docs/screenshots/phone_radar.png) | ![Windows](docs/screenshots/windows_radar.png) |
| ![Kalendarz](docs/screenshots/phone_calendar.png) | ![Wygląd](docs/screenshots/phone_look.png) |

> Zrzuty są generowane w teście bez internetu, więc japońskie znaki wyglądają tam jak kwadraciki. W aplikacji działa font M PLUS Rounded 1c z pełnym japońskim.

## Co umie

- **Radar**: karuzela poleceń, statystyki, wyszukiwarka, filtry (Dla mnie / Wszystko, rodzaj, kraj), sortowanie po dacie albo dopasowaniu, odświeżanie przeciągnięciem.
- **Kalendarz**: każdy przystanek trasy osobno, pogrupowany miesiącami, z filtrem „tylko mój kraj”.
- **Ulubione**: gwiazdka przy evencie.
- **Artyści**: lista startowa z Twojego Spotify plus słowa kluczowe (vocaloid, miku, vtuber, j-core...). Edytujesz ją w aplikacji.
- **Źródła**:
  - feed [`weeb-radar/events.json`](https://github.com/Alexsydfq/weeb-radar) (zapisywany w pamięci, działa offline),
  - VocaDB (eventy vocaloidowe, domyślnie tylko Europa),
  - dodatkowe feedy JSON w tym samym formacie,
  - skróty do małych eventów bez API (Vocafest UK & Ireland, MIKU EXPO, JaME, Tokyo Noizu) i własne eventy dodawane ręcznie.
- **Wygląd**: własne tło z pliku **PNG, JPG, GIF (animowany), WebP, BMP**, z rozmyciem, przyciemnieniem, trybem wypełnij/zmieść/kafelki, przezroczystością kart, 10 kolorami akcentu (Miku, Teto, Luka...), motywem jasnym/ciemnym i Twoim krajem.

## Pobieranie

GitHub Actions buduje oba warianty przy każdym pushu:

- Zakładka **Actions** → ostatni udany run „Build” → artefakty `WeebRadar-android` (APK) i `WeebRadar-windows` (zip, rozpakuj i uruchom `weeb_radar.exe`).
- Po wypchnięciu taga `v*` (np. `v1.0.0`) pliki lądują też w **Releases**.

APK jest podpisany kluczem debug, więc Android poprosi o zgodę na instalację z nieznanego źródła.

## Budowanie lokalnie

```bash
flutter pub get
flutter run                     # telefon / emulator
flutter run -d windows          # Windows (wymaga Visual Studio z C++)
flutter build apk --release
flutter build windows --release
flutter test test/
flutter test tool/screenshots/screenshots_test.dart --update-goldens   # odświeża zrzuty
```

## Format feedu

```json
{
  "updated": "2026-10-03T00:00:00Z",
  "events": [
    {
      "id": "unikalne-id",
      "artist": "Hatsune Miku",
      "title": "MIKU EXPO 2026 Europe",
      "kind": "trasa | koncert | konwent | rave | vocaloid",
      "tier": 3,
      "dateStart": "2026-11-12",
      "dateEnd": "2026-11-29",
      "note": "opis",
      "stops": [{ "cc": "PL", "city": "Warszawa", "date": "2026-11-20", "venue": "Klub" }],
      "url": "https://...",
      "tickets": "https://...",
      "foundAt": "2026-10-02"
    }
  ]
}
```

`tier` (1–3) to dopasowanie do gustu nadane przez skan; aplikacja dolicza do niego bonus za Twoich artystów, słowa kluczowe i Twój kraj.
