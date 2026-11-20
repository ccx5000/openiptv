# OpenIPTV

Cross-platform IPTV-Player für **Android / Android TV, iOS und macOS (Intel & Apple Silicon)**.

Eine Flutter-Codebase mit allen Kernfunktionen eines modernen IPTV-Players plus
echter Multi-Account-Synchronisation zwischen allen Geräten:

## Features

- **Multiple Subscriptions, eine Plattform**: beliebig viele Playlisten kombiniert
- **Xtream Codes API** (Server/User/Pass) und **M3U/M3U8-URLs** mit separater EPG-URL
- **EPG / TV-Guide** (XMLTV) mit Zeitleiste, plus „Jetzt läuft"-Banner im Player
- **Live-TV, Movies, Serien** mit Kategorien, Logos, Grid-Ansicht
- **Globale Suche** Live + VOD + Serien
- **Favoriten, ausblenden, Content-Manager**
- **Weiter schauen / Continue Watching** inkl. Fortsetzpositions-Sync
- **Parental Control** mit PIN über gesperrte Kategorien
- **Multi-User-Profile** (Netflix-Prinzip) pro Konto — jedes Profil hat eigene
  Favoriten, Historie, Playlists
- **Cross-Device-Sync (optional)**: Konto nur mit Benutzername, Profile, Favoriten, Playlisten,
  Watch-History — läuft zwischen Android TV ↔ iPhone/iPad ↔ Intel-Mac ↔
  Apple-Silicon-Mac
- **Player**: `media_kit` (libmpv) — Hardware-Decoding, HLS, TV-Fokus-Navigation,
  PiP auf iOS/macOS

## Dokumentation

| Guide | Inhalt |
|---|---|
| **[docs/INSTALL.md](docs/INSTALL.md)** | **Komplett-Installationsanleitung**: Backend-Container auf dem **Unraid-Server** (Docker Compose Manager oder manuelles `docker run`), Geräte-Anbindung, Backups, Fernzugriff, Troubleshooting |
| **[docs/BUILD.md](docs/BUILD.md)** | **Kompilieren auf dem Mac**: Voraussetzungen (Xcode, Android SDK, Flutter), `./tool/setup.sh`, Release-Builds — macOS `.app`/`.dmg`, Android-TV-`.apk`, iOS-`.ipa` inkl. Signing-Optionen |
| **[docker/GUIDE.md](docker/GUIDE.md)** | Kurz-Guide zum eigenständigen Docker-Stack (PostgreSQL 16 + Sync-Server) |

## Schnellstart (Entwicklung auf dem Mac)

Voraussetzung: [Flutter](https://docs.flutter.dev/get-started/install) ≥ 3.24
(siehe auch [docs/BUILD.md](docs/BUILD.md) für die volle Umgebung).

```bash
git clone <repo-url> openiptv && cd openiptv
./tool/setup.sh          # Plattform-Projekte generieren, Deps, Codegen
flutter run -d macos     # erster Start
```

Das Setup-Skript erstellt die nativen `android/`-, `ios/`- und `macos/`-Projekte
(bewusst nicht eingechecked — Standard-Flutter-Workflow), patcht das
Android-Manifest für Leanback/Android TV und die macOS-Netzwerk-Entitlements.
Intel-Mac-Builds werden nativ unterstützt (Universal Binary).

Die App startet **komplett offline** — ohne Konto, ohne Server. Favoriten,
Historie und Playlisten liegen lokal. Der Sync zu anderen Geräten wird optional
**in den Einstellungen** eingerichtet (Benutzername genügt, Passwort ist
optional).

## Sync-Server einrichten (optional) — eigener Docker-Host

**A) Eigenständiger Docker-Server (Standard, keine Cloud):**
PostgreSQL 16 + mitgelieferter Sync-Server (Node: JWT-Auth, Multi-User-Profile,
bidirektionaler Sync). Für **Unraid/non-USB-Server**:
[docs/INSTALL.md](docs/INSTALL.md); für alle anderen Hosts: [docker/GUIDE.md](docker/GUIDE.md).

```bash
cd docker && docker compose up -d --build   # DB + Server starten
# App startet offline; Sync wird in der App unter Einstellungen → Geräte-Sync
# mit der Server-URL + Benutzername aktiviert
```

**B) Supabase-Cloud (optional):**

1. Projekt auf [supabase.com](https://supabase.com) anlegen.
2. `supabase/schema.sql` komplett im SQL-Editor ausführen
   (Profile-, Favoriten-, Progress-Tabellen, RLS, Auto-Profil-Trigger).
3. App mit `--dart-define=BACKEND=supabase --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
   starten (oder Werte in `lib/core/config.dart`).

**Sync-Ablauf (offline-first):** Favoriten/Fortschritt/Playlisten werden zuerst
in der lokalen SQLite-DB (Drift) geschrieben und dann asynchron zum Backend
repliziert; beim Start und regelmäßig läuft der Rückweg (Pull). Offline voll
funktional.

Anmeldedaten der IPTV-Anbieter verlassen das Gerät nicht — im Sync werden nur
Metadaten (Name, Kategorien, IDs) geteilt, nichts Klartext-Kritisches.

## Projektstruktur

```
lib/
  app/            App-Shell, Theme, adaptive Navigation (Rail TV/Desktop, Bar Mobile)
  core/
    config.dart   Backend-Wahl (rest/supabase) + URLs per dart-define
    backend/      Backend-Interface + Rest/Supabase-Adapter
    database/     Drift-Schema (lokale SQLite-DB)
    models/       Channel, EpgEntry, Playlist, MediaKind ...
    services/     Xtream-Client, M3U-/XMLTV-Parser, Auth, Sync, Library
  features/
    auth/         Login/Registrierung
    profiles/     Profil-Auswahl & Verwaltung
    playlists/    Playlisten hinzufügen/verwalten
    home/         Continue Watching, Favoriten, Navigation
    live/         Live-TV Kanäle
    guide/        EPG-TV-Guide
    vod/          Movies & Serien
    search/       Globale Suche
    player/       media_kit-Player mit Overlay-UI
    settings/     Parental Control, Sync-Status, Profil
docker/           Eigenständiger Docker-Stack (Postgres + Sync-Server) + Guide
supabase/         Schema.sql für Cloud-Variante
tool/setup.sh     Bootstrap-Skript (Plattform-Projekte, Codegen, Patches)
```

## Roadmap nach MVP

- Catch-up/Replay bei unterstützten Anbietern
- Aufnahme via Companion-Server
- VPN-Integration, externe Player (VLC/Just Player deeplink)
- Watch-together, Trailer, Trending-Content

## Rechtliches

Der Player liefert **keinen Content**. Alle Streams, Server und Anmeldedaten
kommen vom Anwender. Nur legale Inhalte nutzen.
