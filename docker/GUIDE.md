# Guide: Eigenständiger Docker-Server (PostgreSQL + Sync-Server)

Das ganze Backend in **eigenständigen Containern** — ohne Supabase-Cloud, ohne CLI:

```
┌──────────────────── docker compose ────────────────────┐
│  ┌──────────────────┐        ┌──────────────────────┐  │
│  │ postgres:16      │ ◄────── │ openiptv-sync        │  │
│  │ DB + Schema      │         │ (Node: Auth + REST)  │  │
│  └──────────────────┘        └──────────▲───────────┘  │
└─────────────────────────────────────────┼──────────────┘
                                          │ :8080
                      TV / Handy / Mac ───┘  (REST + JWT)
```

Enthalten:
- **`docker-compose.yml`** — PostgreSQL 16 + Sync-Server, beide mit persistentem Volume
- **`initdb/001-schema.sql`** — Datenbankschema (Users, Profile, Playlists, Favoriten, Watch-Progress, Views), wird beim ersten Start automatisch geladen
- **`server/`** — der Sync-Server (Plain Node 20, keine Frameworks): JWT-Login/Registrierung, Multi-User-Profile, bidirektionaler Sync mit `updated_at`-Watermarks

---

## 1. Starten

Voraussetzung: Docker (Desktop oder Engine). Dann im Projektordner:

```bash
cd docker
docker compose up -d --build
docker compose logs -f sync     # bis "OpenIPTV sync server listening :8080"
```

Prüfen (Schnittstelle antwortet, wenn der Server lebt):

```bash
http -v GET http://127.0.0.1:8080/          # → {"error":"not found"}
# oder im Browser http://127.0.0.1:8080/ öffnen
```

## 2. App verbinden

Das Standard-Backend der App ist dieser REST-Server (`BACKEND=rest`).
Auf dem selben Mac reicht:

```bash
flutter run -d macos
```

Von anderen Geräten (iPhone, Android TV) aus die LAN-IP des Macs/Servers verwenden:

```bash
# Beispiel: Server läuft auf 192.168.1.50
flutter run \
  --dart-define=BACKEND=rest \
  --dart-define=BACKEND_URL=http://192.168.1.50:8080
```

In der App: Registrieren (E-Mail + Passwort ab 6 Zeichen) → Profil wählen → Playlist hinzufügen.
Der Login läuft komplett gegen deinen Postgres-Container (Passwort als scrypt-Hash, nie im
Klartext), das JWT gilt 365 Tage.

## 3. Ports / Firewall

| Port | Dienst |
|---|---|
| 8080 | Sync-Server (REST) — muss für alle Geräte erreichbar sein |
| 5432 | PostgreSQL — **nicht** nach außen freigeben (bleibt im internen Compose-Netz) |

Linux-Server: `sudo ufw allow 8080/tcp` — oder HTTPS-Proxy (Abschnitt 5).

## 4. Admin / Wartung

```bash
# In die Daten schauen:
docker compose exec db psql -U openiptv -d openiptv -c 'select * from profiles;'

# Backup:
docker compose exec db pg_dump -U openiptv openiptv > backup-$(date +%F).sql
# Restore:
cat backup-2026-01-01.sql | docker compose exec -T db psql -U openiptv openiptv

# Alles platt + frisches Schema:
docker compose down -v && docker compose up -d --build

# Nur den Sync-Server aktualisieren (nach Code-Änderung):
docker compose up -d --build sync
```

## 5. Produktiv betreiben (Checkliste)

- [ ] `POSTGRES_PASSWORD` und `JWT_SECRET` in `docker-compose.yml` auf starke Zufallswerte ändern
- [ ] HTTPS davor schalten, sonst sind Login-Daten im Klartext unterwegs. Beispiel Caddy
      (stellt automatisch Zertifikate aus): `deine-domain.de { reverse_proxy 127.0.0.1:8080 }`
      → in der App dann `BACKEND_URL=https://deine-domain.de`
- [ ] Postgres-Port **nicht** öffnen; nur 8080 bzw. 443
- [ ] Backups (Abschnitt 4) z. B. täglich per Cron

## 6. Architektur-Notizen für Entwickler

- Die App kennt zwei Backends über `lib/core/backend/backend.dart`:
  `RestBackend` (dieser Server, Standard) und `SupabaseBackend` (Cloud, optional via
  `--dart-define=BACKEND=supabase --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`).
- Sync-Protokoll: Push = `POST /sync/:profileId` mit Upsert-Payloads; Pull = `GET /sync/:profileId`
  mit `since_…`-Timestamps (Watermark), lokal per Drift-`insertOnConflictUpdate`. Konflikte
  werden last-write-wins über `updated_at` aufgelöst.
- Auth: `POST /auth/register|login` → JWT (Bearer) → jede Sync-/Profil-Route prüft in SQL die
  Besitzerschaft (Profil ↔ `user_id`).

## 7. Alternative: Supabase-Cloud

Wer lieber Supabase-Cloud nutzt: `supabase/schema.sql` im SQL-Editor der Cloud ausführen,
dann `--dart-define=BACKEND=supabase --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`.
Das lokale Supabase-Stack via `supabase start` (Supabase CLI) funktioniert genauso.
