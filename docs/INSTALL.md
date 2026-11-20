# Full Install Guide: Backend auf Unraid + App auf allen Geräten

Ziel-Architektur:

```
   UNRAID SERVER (24/7)                    deine Geräte
 ┌───────────────────────────┐      ┌────────────────────────────┐
 │  Docker                    │      │  Android TV / Fire TV      │◄─┐
 │  ├─ openiptv-db (Postgres) │      │  iPhone / iPad / Apple TV  │◄─┤ REST/JWT
 │  └─ openiptv-sync (:8080)  │◄─────┤  macOS (Intel/Apple Sil.)  │◄─┘
 └───────────────────────────┘      └────────────────────────────┘
```

Der Server speichert Accounts, Profile, Favoriten und Fortschritt; die Geräte
verbinden sich über `http://<server-ip>:8080`.

---

# Teil 1 — Backend auf Unraid

## 1.1 Code auf den Server holen

Per Secure-Shell (Benutzername `root`) oder über das Terminal in der Unraid-WebUI:

```bash
git clone https://github.com/ccx5000/openiptv.git /mnt/user/appdata/openiptv-src
```

> Falls `git` auf Unraid fehlt: Plugin **NerdTools** installieren und `git`
> nachziehen — oder das Repo als ZIP von GitHub laden und auf eine Freigabe entpacken.

## 1.2 Variante A — Docker Compose Manager (empfohlen)

1. **Plugin installieren:** Unraid → **Apps** → **„Docker Compose Manager"** suchen → installieren.
2. **Stack anlegen:** *Settings → Docker Compose Manager → Add Compose Stack*:
   - Name: `openiptv`
   - Compose-Datei: `/mnt/user/appdata/openiptv-src/docker/docker-compose.yml`
3. **Unraid-Spezialität — Volumes nach Appdata umstellen**, damit Backups/Shares greifen.
   In `docker/docker-compose.yml` die Volumes/Environment für `db` und `sync` ändern:

   ```yaml
   services:
     db:
       volumes:
         - /mnt/user/appdata/openiptv/db:/var/lib/postgresql/data
         - /mnt/user/appdata/openiptv-src/docker/initdb:/docker-entrypoint-initdb.d:ro
       environment:
         POSTGRES_USER: openiptv
         POSTGRES_PASSWORD: <stabiles-zufalls-passwort>
         POSTGRES_DB: openiptv
     sync:
       environment:
         DATABASE_URL: postgres://openiptv:<stabiles-zufalls-passwort>@db:5432/openiptv
         JWT_SECRET: <langes-zufalls-geheimnis-min-32-zeichen>
   ```

   Zufallswerte z. B. mit `openssl rand -hex 32` im Unraid-Terminal erzeugen.
4. **Hochfahren:** Stack starten, Logs prüfen:
   `docker logs -f openiptv-sync-1` → endet auf `OpenIPTV sync server listening :8080`.
5. **Autostart** für beide Container aktivieren.

## 1.3 Variante B — Manuelle Container ohne Compose-Plugin

Zwei `docker run`-Befehle im Unraid-Terminal; danach erscheinen beide Container
ganz normal in Unraids Docker-Übersicht:

```bash
# 1) Internes Netzwerk
docker network create openiptv

# 2) Postgres (Daten liegen in Appdata)
docker run -d --name openiptv-db --network openiptv --restart unless-stopped \
  -e POSTGRES_USER=openiptv \
  -e POSTGRES_PASSWORD=<stabiles-zufalls-passwort> \
  -e POSTGRES_DB=openiptv \
  -v /mnt/user/appdata/openiptv/db:/var/lib/postgresql/data \
  postgres:16-alpine

sleep 10   # Datenbank hochfahren lassen

# 3) Schema einmalig einspielen
docker exec -i openiptv-db psql -U openiptv -d openiptv \
  < /mnt/user/appdata/openiptv-src/docker/initdb/001-schema.sql

# 4) Sync-Server-Image bauen + Container starten
docker build -t openiptv-sync /mnt/user/appdata/openiptv-src/docker/server
docker run -d --name openiptv-sync --network openiptv --restart unless-stopped \
  -p 8080:8080 \
  -e DATABASE_URL=postgres://openiptv:<stabiles-zufalls-passwort>@openiptv-db:5432/openiptv \
  -e JWT_SECRET=<langes-zufalls-geheimnis-min-32-zeichen> \
  openiptv-sync
```

## 1.4 Erreichbarkeit prüfen

```bash
docker logs openiptv-sync | tail -2    # "OpenIPTV sync server listening :8080"
```

Von einem anderen Gerät im Heimnetz im Browser `http://<UNRAID-IP>:8080/` öffnen —
die JSON-Antwort `{"error":"not found"}` bestätigt: der Server lebt.

Falls „connection refused" von außen, obwohl Unraid selbst erreichbar ist: Im
Compose-File kontrollieren, dass `ports: - "8080:8080"` existiert (Variante B hat
das via `-p 8080:8080`). Unraid blockiert eingehende Ports standardmäßig nicht.

## 1.5 Updates

```bash
cd /mnt/user/appdata/openiptv-src && git pull
# Compose:
docker compose -p openiptv up -d --build sync
# manuell:
docker build -t openiptv-sync docker/server && docker restart openiptv-sync
```

## 1.6 Backups

```bash
docker exec openiptv-db pg_dump -U openiptv openiptv \
  > /mnt/user/backups/openiptv-$(date +%F).sql
```

Per **User Scripts**-Plugin als täglicher Cron. Restore:

```bash
cat /mnt/user/backups/openiptv-<datum>.sql \
  | docker exec -i openiptv-db psql -U openiptv -d openiptv
```

## 1.7 Fernzugriff außerhalb des Heimnetzes (optional)

- **Am einfachsten:** Tailscale/WireGuard (Unraid-Plugin) installieren und in der App
  `BACKEND_URL=http://<tailscale-ip>:8080` verwenden — nichts wird exponiert.
- **Öffentlich:** nur via HTTPS-Reverseproxy (Nginx Proxy Manager, SWAG oder Caddy)
  mit Domain + Let's Encrypt. Portweiterleitung direkt auf 8080 ist tabu
  (Login-Daten laufen sonst im Klartext).

---

# Teil 2 — Geräte verbinden

Egal welches Gerät — die Backend-Adresse ist überall gleich:

```
http://<UNRAID-IP>:8080
```

Die App startet danach **komplett offline** — kein Login nötig. Sync wird
optional in der App aktiviert:

1. App öffnen — sie läuft sofort (Profil „Ich“ ist schon da)
2. **Einstellungen → Geräte-Sync** → Server-URL `http://<UNRAID-IP>:8080` +
   **Benutzername** eintragen (das Konto wird automatisch erstellt; Passwort
   optional) → Verbinden
3. Auf dem **zweiten Gerät** dieselbe URL + denselben Benutzernamen eintragen
   — fertig: Favoriten/Historie/Playlisten laufen jetzt zwischen allen
   Geräten dieses Benutzernamens synchron
4. **Profil wählen** — ein Profil pro Person (Kinderprofile optional)
5. **Einstellungen → Playlisten → Playlist hinzufügen**:
   - **Xtream Codes** (Standard bei IPTV-Abos): `server:port`, Nutzer, Passwort
   - **M3U**: M3U-URL + optionale XMLTV-EPG-URL (für den TV-Guide)
4. Live TV: Stern = Favorit, Auge-durchgestrichen = ausblenden, Schloss = Kategorie
   mit PIN sperren (Parental Control)

Favoriten und „Weiter schauen" werden über alle Geräte und Profile hinweg
synchronisiert.

---

# Teil 3 — Troubleshooting

| Symptom | Ursache / Lösung |
|---|---|
| „Verbindung fehlgeschlagen" beim Login | `BACKEND_URL` beim Build falsch oder Server nicht gestartet (`docker logs openiptv-sync`) |
| Sync verbindet am Mac, nicht am TV | Im Sync-Dialog am TV die Unraid-IP statt `127.0.0.1` eintragen (kein Neubau nötig) |
| Kanäle leer, Login ok | Playlist-Refresh: Einstellungen → Playlisten → Aktualisieren; bei Xtream `host:port` prüfen |
| EPG fehlt bei M3U | XMLTV-URL fehlt — Playlisteintrag neu anlegen |
| Sync-Fehler in Einstellungen | JWT abgelaufen (365 Tage) → Sync trennen + neu verbinden |
| macOS: „kann nicht geöffnet werden" | Rechtsklick → Öffnen; alternativ `xattr -dr com.apple.quarantine` |

Weiter mit dem Kompilieren: **[docs/BUILD.md](BUILD.md)**
