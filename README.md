# OpenIPTV

Cross-platform IPTV-Player für **Android / Android TV, iOS und macOS (Intel & Apple Silicon)** —
inspiriert von [SwiptV](https://www.swiptv.app/) und [UHF](https://getuhf.com/).

Die Referenz-Apps sind beide Apple-only; dieses Projekt kombiniert ihre Kernfunktionen in **einer**
Flutter-Codebase und erweitert sie um Android/Android-TV sowie echte Multi-Account-Synchronisation:

## Features

- **Multiple Subscriptions, eine Plattform** (SwiptV-Prinzip): beliebig viele Playlisten kombiniert
- **Xtream Codes API** (Server/User/Pass) und **M3U/M3U8-URLs** mit separater EPG-URL
- **EPG / TV-Guide** (XMLTV) mit Zeitleiste, plus „Jetzt läuft"-Banner im Player
- **Live-TV, Movies, Serien** mit Kategorien, Logos, Grid-Ansicht
- **Globale Suche** Live + VOD + Serien (SwiptV-Feature)
- **Favoriten, ausblenden, Content-Manager** (beide Referenz-Apps)
- **Weiter schauen / Continue Watching** inkl. Fortsetzpositions-Sync
- **Parental Control** mit PIN über gesperrte Kategorien (SwiptV-Feature)
- **Multi-User-Profile** (Netflix-Prinzip) pro Konto — jedes Profil hat eigene Favoriten, Historie, Playlists
- **Cross-Device-Sync** über Supabase: Auth (E-Mail), Profile, Favoriten, Playlisten, Watch-History — läuft zwischen Android TV ↔ iPhone/iPad ↔ Intel-Mac ↔ Apple-Silicon-Mac
- **Player**: `media_kit` (libmpv) — Hardware-Decoding, HLS, HDR/Dolby-Vision-Container auf allen drei Plattformen, TV-Fokus-Navigation, PiP auf iOS/macOS

## Schnellstart

Voraussetzung: [Flutter](https://docs.flutter.dev/get-started/install) ≥ 3.24 (macOS-Developer-Tools
für iOS/macOS, Android SDK für Android/TV).

```bash
git clone <repo-url> openiptv && cd openiptv
./tool/setup.sh          # Plattform-Projekte generieren, Deps, Codegen
flutter run              # erster Start (App wählt Zielgerät)
```

Das Setup-Skript erstellt die nativen `android/`-, `ios/`- und `macos/`-Projekte (bewusst nicht
eingecheckt — Standard-Flutter-Workflow) und patcht das Android-Manifest für Leanback/Android TV.
macOS-Intel-Builds werden automatisch von Flutter unterstützt (kein Extra-Schritt nötig).

## Backend einrichten (Sync) — zwei Wege

**A) Eigenständiger Docker-Server (Standard, keine Cloud):**
PostgreSQL 16 + ein mitgelieferter Sync-Server (Node: JWT-Auth, Multi-User-Profile,
bidirektionaler Sync). Komplette Anleitung: [docker/GUIDE.md](docker/GUIDE.md).

```bash
cd docker && docker compose up -d --build   # DB + Server starten
flutter run -d macos                        # App verbindet sich auf localhost:8080
```

Andere Geräte: `--dart-define=BACKEND_URL=http://<server-ip>:8080`.

**B) Supabase-Cloud (optional):**

1. Projekt auf [supabase.com](https://supabase.com) anlegen.
2. `supabase/schema.sql` komplett im SQL-Editor ausführen
   (Profile-, Favoriten-, Progress-Tabellen, RLS, Auto-Profil-Trigger).
3. App mit `--dart-define=BACKEND=supabase --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
   starten (oder Werte in `lib/core/config.dart`).

**Sync-Ablauf (offline-first):** Favoriten/Fortschritt/Playlisten werden zuerst in der lokalen
SQLite-DB (Drift) geschrieben und dann asynchron nach Supabase repliziert; beim Start und
regelmäßig läuft der Rückweg (Pull). Offline funktional.

Anmeldedaten der IPTV-Anbieter verlassen das Gerät nicht — im Sync werden nur Metadaten
(Name, Kategorien, IDs) geteilt, nichts Klartext-Kritisches.

## Projektstruktur

```
lib/
  app/            App-Shell, Theme, Routing
  core/
    config.dart   Backend-Wahl (rest/supabase) + URLs per dart-define
    database/     Drift-Schema (lokale SQLite-DB)
    models/       Channel, EpgEntry, Playlist, MediaKind ...
    services/     Xtream-Client, M3U-, XMLTV-Parser, Auth, Sync, Library
  features/
    backend/      Backend-Interface + Rest/Supabase-Adapter
    auth/         Login/Registrierung
    profiles/     Profil-Auswahl & Verwaltung
    playlists/    Playlisten hinzufügen/verwalten
    home/         Adaptive Shell (Nav-Rail TV/Desktop, BottomBar Mobile)
    live/         Live-TV Kanäle
    guide/        EPG-TV-Guide
    vod/          Movies & Serien
    search/       Globale Suche
    player/       media_kit-Player mit Overlay-UI
    settings/     Parental Control, Sync-Status, Profil
docker/           Eigenständiger Docker-Stack (Postgres + Sync-Server) + Guide
server/           — (liegt unter docker/server)
supabase/         Schema.sql für Cloud-Variante
tool/setup.sh     Bootstrap-Skript
```

## Roadmap nach MVP

- Catch-up/Replay bei unterstützten Anbietern (UHF-Feature)
- Aufnahme via Companion-Server (UHF-Server-Feature)
- VPN-Integration, externe Player (VLC/Just Player deeplink)
- Watch-together, Trailer, Trending-Content

## Rechtliches

Der Player liefert **keinen Content**. Alle Streams, Server und Anmeldedaten kommen vom Anwender.
Nur legale Inhalte nutzen (Guideline 5.2.3-konform, siehe UHF).
