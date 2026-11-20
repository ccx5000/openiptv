# OpenIPTV

Cross-platform IPTV-Player für **Android / Android TV, iOS und macOS (Intel & Apple Silicon)**.

## Features

- **Multiple Subscriptions, eine Plattform**: beliebig viele Playlisten kombiniert
- **Xtream Codes API** (Server/User/Pass) und **M3U/M3U8-URLs** mit separater EPG-URL
- **EPG / TV-Guide** (XMLTV) mit Zeitleiste, plus „Jetzt läuft"-Banner im Player
- **Live-TV, Filme, Serien** mit Kategorien, Logos, Grid-Ansicht
- **Globale Suche** Live + VOD + Serien
- **Favoriten, ausblenden, Content-Manager**
- **Weiter schauen / Continue Watching** inkl. Fortsetzpositions-Sync
- **Parental Control** mit PIN über gesperrte Kategorien
- **Multi-User-Profile** (Netflix-Prinzip) pro Konto — jedes Profil hat eigene Favoriten, Historie, Playlists
- **Cross-Device-Sync** über Supabase: Auth (E-Mail), Profile, Favoriten, Playlisten, Watch-History — läuft zwischen Android TV ↔ iPhone/iPad ↔ Intel-Mac ↔ Apple-Silicon-Mac
- **Player**: `media_kit` (libmpv) — Hardware-Decoding, HLS, HDR/Dolby-Vision-Container auf allen Plattformen, TV-Fokus-Navigation

## Schnellstart

Voraussetzung: [Flutter](https://docs.flutter.dev/get-started/install) ≥ 3.24 (macOS-Developer-Tools
für iOS/macOS, Android SDK für Android/TV).

```bash
git clone <repo-url> openiptv && cd openiptv
./tool/setup.sh          # Plattform-Projekte generieren, Deps, Codegen
flutter run              # erster Start (App wählt Zielgerät)
```

Das Setup-Skript erstellt die nativen `android/`-, `ios/`- und `macos/`-Projekte (Standard-Flutter-Workflow)
und patcht das Android-Manifest für Leanback/Android TV. macOS-Intel-Builds werden automatisch
von Flutter unterstützt.

## Releases: APK, IPA und DMG fertigmachen

Unter **Actions → "Build Releases (APK / IPA / DMG)"** lassen sich alle drei Artefakte per Knopfdruck
bauen (oder automatisch bei jedem `v*`-Tag):

| Artefakt | Runner | Ergebnis |
|---|---|---|
| `OpenIPTV-android-arm64.apk` (+ armeabi-v7a, universal) | ubuntu-latest | `flutter build apk --release` (+ `--split-per-abi`) |
| `OpenIPTV-macOS.dmg` + gezippte `OpenIPTV.app` | macos-latest | `flutter build macos --release` + `hdiutil` |
| `OpenIPTV-ios-unsigned.ipa` | macos-latest | `flutter build ipa --release --no-codesign` |

Hinweise:
- Die **Android-TV-APK** ist die normale Release-APK (Leanback-Feature ist deklariert, `android:required="false"`);
  sie läuft auf Phones und TV-Geräten.
- Die **IPA ist unsigniert** — zum Installieren auf iPhone/Apple TV mit Xcode bzw. einem
  Verteilzertifikat signieren (`flutter build ipa --export-options-plist=…`, siehe Flutter-Doku).
- Für den **App Store / TestFlight** brauchst du einen Apple Developer Account und Codesigning;
  der macOS-Bauschritt liefert zusätzlich eine gezippte `.app` für direkte Verteilung (Gatekeeper: Rechtsklick → Öffnen).

## Supabase einrichten (Sync)

1. Neues Projekt auf [supabase.com](https://supabase.com) anlegen.
2. `supabase/schema.sql` komplett in den **SQL-Editor** kopieren und ausführen.
   (Erstellt Profile-, Favoriten-, Progress-Tabellen, RLS und Auto-Profil-Trigger.)
3. URL + anon Key rein ins Projekt: `lib/core/config.dart` oder per `--dart-define`:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=ey...
   ```
4. Optional: Apple Sign-In in der Supabase-Console aktivieren (iOS/macOS), sonst E-Mail-Login.

**Sync-Ablauf (offline-first):** Favoriten/Fortschritt/Playlisten werden zuerst in der lokalen
SQLite-DB (Drift) geschrieben und dann asynchron nach Supabase repliziert; beim Start und
regelmäßig läuft der Rückweg (Pull). Offline bleibt alles funktional.

Anmeldedaten der IPTV-Anbieter verlassen das Gerät nicht — im Sync werden nur Metadaten
(Name, Kategorien, IDs) geteilt, nichts Kritisches im Klartext.

## Projektstruktur

```
lib/
  app/            App-Shell, Theme, Widgets
  core/
    config.dart   Supabase-URL/-Key (dart-define oder Default)
    database/     Drift-Schema (lokale SQLite-DB)
    models/       Channel, EpgEntry, Playlist, MediaKind ...
    services/     Xtream-Client, M3U-, XMLTV-Parser, Auth, Sync
  features/
    auth/         Login/Registrierung
    profiles/     Profil-Auswahl & Verwaltung
    playlists/    Playlisten hinzufügen/verwalten
    home/         Home-Dashboard
    live/         Live-TV Kanäle
    guide/        EPG-TV-Guide
    vod/          Filme & Serien
    search/       Globale Suche
    player/       media_kit-Player mit Overlay-UI
    settings/     Sync-Status, Parental Control, Abmelden
supabase/         Schema.sql (Backend)
tool/setup.sh     Bootstrap-Skript
.github/workflows Release-Builds (APK / IPA / DMG)
```

## Performance

Flüssig laufen die Apps überall durch: Release-Builds in CI, `LazyDatabase` im Hintergrund-Isolate,
Hardware-Decoding via libmpv, gepufferte Logos (`gaplessPlayback` statt Flackern beim Scrollen)
und Grid-Virtualisierung — auch 40.000+ Kanäle werden virtuell gerendert.

## Rechtliches

Der Player liefert **keinen Content**. Alle Streams, Server und Anmeldedaten kommen vom Anwender.
Bitte nur legale Inhalte nutzen.
