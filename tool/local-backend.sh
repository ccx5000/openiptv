#!/usr/bin/env bash
# Self-hosted Supabase stack (Docker) for OpenIPTV — see docker/GUIDE.md
#
#   ./tool/local-backend.sh start   init + start + schema + print credentials
#   ./tool/local-backend.sh status  print URLs + anon key
#   ./tool/local-backend.sh reset   wipe DB, replay schema
#   ./tool/local-backend.sh stop    stop containers
set -euo pipefail

command -v supabase >/dev/null || {
  echo "Supabase CLI fehlt.  macOS:  brew install supabase/tap/supabase"
  exit 1
}
docker info >/dev/null 2>&1 || {
  echo "Docker läuft nicht. Docker Desktop starten und erneut versuchen."
  exit 1
}
cd "$(dirname "$0")/.."

SCHEMA_FILE="supabase/schema.sql"
STATUS_OUT="$(mktemp)"
trap 'rm -f "$STATUS_OUT"' EXIT

init_and_start() {
  [ -f supabase/config.toml ] || supabase init
  supabase start >"$STATUS_OUT" 2>&1
}

apply_schema() {
  supabase db reset >/dev/null 2>&1
  until docker ps --format '{{.Names}}' | grep -q '^supabase-db$'; do
    sleep 2
  done
  docker exec -i supabase-db psql -U postgres -d postgres <"$SCHEMA_FILE" >/dev/null
  echo "Schema eingespielt ($SCHEMA_FILE)"
}

print_status() {
  # `supabase status` prints colored box output; strip the escape codes.
  supabase status -o env 2>/dev/null ||
    sed -e 's/\x1b\[[0-9;]*m//g' "$STATUS_OUT"
}

case "${1:-start}" in
  start)
    echo "==> Starte Supabase-Stack in Docker (init falls nötig)…"
    init_and_start
    echo "==> Spiele Schema ein…"
    apply_schema
    echo ""
    echo "✅ Backend läuft. App so starten:"
    echo ""
    print_status | awk -F= '
      /SUPABASE_URL/    { url=$NF }
      /ANON_KEY/        { key=$NF }
      END {
        gsub(/^[ \t]+|[ \t]+$/, "", url); gsub(/^[ \t]+|[ \t]+$/, "", key)
        print "SUPABASE_URL=" url
        print "SUPABASE_ANON_KEY=" key
        print ""
        print "flutter run --dart-define=SUPABASE_URL=" url \
              " --dart-define=SUPABASE_ANON_KEY=" key
      }'
    echo ""
    echo "Studio:        http://127.0.0.1:54323"
    echo "Stoppen:       ./tool/local-backend.sh stop"
    ;;
  status)
    print_status
    ;;
  reset)
    echo "==> Reset: ganze DB zurücksetzen + Schema neu…"
    apply_schema
    ;;
  stop)
    supabase stop
    echo "==> Gestoppt (Daten bleiben im Docker-Volume)."
    ;;
  *)
    echo "Usage: $0 {start|status|reset|stop}"
    exit 1
    ;;
esac
