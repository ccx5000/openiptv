# Guide: Self-hosted Supabase-Server mit Docker (Datenbank, Auth, Sync)

Diese Anleitung startet das komplette Backend von OpenIPTV **lokal oder auf deinem eigenen
Server in Docker** — Postgres-Datenbank, Auth-API, REST-API und die Studio-Weboberfläche.
Die App läuft dann komplett gegen deinen eigenen Server, keine Cloud nötig.

---

## 1. Voraussetzungen

- **Docker Desktop** ([docker.com](https://docs.docker.com/desktop/)) oder Docker Engine ≥ 24
- **Supabase CLI** — Installationswege:
  - macOS: `brew install supabase/tap/supabase`
  - Linux: `brew install supabase/tap/supabase` (via Homebrew) oder Binary von
    [github.com/supabase/cli/releases](https://github.com/supabase/cli/releases)
  - Alternativ ohne globalen Install: `npx supabase@latest --version`

## 2. Stack starten (3 Befehle)

Im Projektordner:

```bash
./tool/local-backend.sh start
```

Das Skript macht automatisch:
1. `supabase init` — legt `supabase/config.toml` an (nur beim ersten Mal)
2. `supabase start` — zieht alle Container und startet sie:

| Container | Zweck |
|---|---|
| `supabase-db` | PostgreSQL 15+ — die eigentliche Datenbank |
| `supabase-auth` | GoTrue — E-Mail-Login/Registrierung für die App |
| `supabase-rest` | PostgREST — die REST-API, mit der die App spricht |
| `supabase-studio` | Web-UI zum Ansehen der Daten (Tabellen, User, SQL) |

3. `supabase db reset` + Schema einspielen — `supabase/schema.sql` landet automatisch in der DB
   (Profile, Favoriten, Watch-Progress, Views inkl. Row-Level-Security und Auto-Profil-Trigger)
4. Ausgabe der Zugangsdaten in genau dem Format, das die App braucht:

```
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=eyJhb...
```

## 3. App gegen den lokalen Server bauen/starten

```bash
# Entwicklung
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<dein-anon-key>

# Release-Builds (Werte genauso anhängen)
flutter build macos --release \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<dein-anon-key>
```

Registriere dich in der App mit einer beliebigen E-Mail + Passwort (der lokale Auth-Server
sendet keine Bestätigungsmails — Login funktioniert direkt). Die Tabellen kannst du im Studio
unter `http://127.0.0.1:54323` inspizieren.

> **Achtung bei Android-Geräten/Emulatoren:** `127.0.0.1` zeigt auf das Gerät selbst.
> Nutze stattdessen die LAN-IP deines Macs (z. B. `http://192.168.1.50:54321`) —
> und darauf achten, dass Port 54321 nicht nur an `127.0.0.1` gebunden ist
> (in `supabase/config.toml` unter `[api] port`/`host` einstellbar).

## 4. Auf einem eigenen/virtuellen Linux-Server

```bash
ssh dein-server
git clone https://github.com/ccx5000/openiptv.git && cd openiptv
./tool/local-backend.sh start
# Port 54321 in der Firewall öffnen, z. B.:
sudo ufw allow 54321/tcp
```

Dann in der App überall `SUPABASE_URL=http://<server-ip>:54321` verwenden.
**Zum öffentlichen Betrieb** zwingend: HTTPS davor schalten (z. B. Caddy):

```
deine-domain.de {
    reverse_proxy 127.0.0.1:54321
    reverse_proxy /_studio/* 127.0.0.1:54323
}
```

und in der App `SUPABASE_URL=https://deine-domain.de` setzen. Ohne HTTPS reist
E-Mail/Passwort im Klartext.

## 5. Nützliche Befehle

```bash
./tool/local-backend.sh status    # URLs + Keys zeigen
./tool/local-backend.sh stop      # Container stoppen (Daten bleiben)
./tool/local-backend.sh reset     # DB komplett zurücksetzen + Schema neu einspielen
supabase studio                   # Studio öffnen
docker ps | grep supabase         # laufende Container
```

## 6. Datensicherung

Die Daten liegen im Docker-Volume `supabase_db_<projekt>`:

```bash
docker exec supabase-db pg_dump -U postgres postgres > backup-$(date +%F).sql
# Restore:
cat backup-2026-11-20.sql | docker exec -i supabase-db psql -U postgres postgres
```

## 7. Was dieses Setup NICHT ist

- Kein fremder Cloud-Host — nur dein eigener Sync-Server (das ist der Sinn)
- Die App nutzt Auth + REST + Postgres; genau das liefern die Container
- Schema-Änderungen machst du über `supabase/schema.sql` + `./tool/local-backend.sh reset`
