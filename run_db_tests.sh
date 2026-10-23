#!/usr/bin/env bash
# يشغّل الهجرات واختبارات RLS على PostgreSQL حقيقي.
# الخيار أ (Docker فقط): ./scripts/run_db_tests.sh docker
# الخيار ب (Supabase CLI): supabase start && ./scripts/run_db_tests.sh supabase
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-docker}"
run() { psql "$URL" -v ON_ERROR_STOP=1 "$@"; }
if [ "$MODE" = "docker" ]; then
  docker run -d --rm --name rayhana-pg -e POSTGRES_PASSWORD=test -p 54329:5432 postgres:15 >/dev/null
  trap 'docker stop rayhana-pg >/dev/null' EXIT
  URL="postgresql://postgres:test@127.0.0.1:54329/postgres"
  until pg_isready -h 127.0.0.1 -p 54329 >/dev/null 2>&1; do sleep 1; done; sleep 2
  run -f tests/db/00_supabase_shim.sql
else
  URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
  supabase db reset
fi
[ "$MODE" = "docker" ] && for f in supabase/migrations/*.sql; do echo "== $f"; run -f "$f"; done
run -f tests/db/rls_test.sql
