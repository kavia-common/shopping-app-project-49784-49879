#!/usr/bin/env bash
# PUBLIC_INTERFACE
# Preview launcher for ShoppingAppDatabase without Docker.
# - Starts PostgreSQL via ShoppingAppDatabase/startup.sh
# - Verifies readiness on 0.0.0.0:3002 with pg_isready
# Env: PGPORT can be overridden; defaults to 3002.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PGPORT="${PGPORT:-3002}"

echo "[preview] Starting ShoppingAppDatabase on port ${PGPORT}..."
bash "${ROOT_DIR}/ShoppingAppDatabase/startup.sh"

# Locate pg_isready
PG_ISREADY=""
if PG_VERSION_DIR=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1) && [ -n "${PG_VERSION_DIR}" ] && [ -x "/usr/lib/postgresql/${PG_VERSION_DIR}/bin/pg_isready" ]; then
  PG_ISREADY="/usr/lib/postgresql/${PG_VERSION_DIR}/bin/pg_isready"
elif command -v pg_isready >/dev/null 2>&1; then
  PG_ISREADY="$(command -v pg_isready)"
else
  echo "[preview] ERROR: pg_isready not found. Install PostgreSQL client tools."
  exit 1
fi

echo "[preview] Verifying readiness on 0.0.0.0:${PGPORT}..."
for i in {1..30}; do
  if sudo -u postgres "${PG_ISREADY}" -h 0.0.0.0 -p "${PGPORT}" >/dev/null 2>&1 || \
     "${PG_ISREADY}" -h 0.0.0.0 -p "${PGPORT}" >/dev/null 2>&1; then
     echo "[preview] PostgreSQL is ready on 0.0.0.0:${PGPORT}"
     exit 0
  fi
  echo "[preview] waiting... ($i/30)"
  sleep 2
done

echo "[preview] ERROR: PostgreSQL did not become ready on 0.0.0.0:${PGPORT}"
exit 1
