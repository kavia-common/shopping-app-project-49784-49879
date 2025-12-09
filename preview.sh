#!/usr/bin/env bash
# PUBLIC_INTERFACE
# Preview launcher for ShoppingAppDatabase without Docker.
# - Starts PostgreSQL via ShoppingAppDatabase/startup.sh
# - Verifies readiness on 0.0.0.0:3002 with pg_isready
# - Runs healthcheck.sh for consistent readiness signal and clearer logs
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
  echo "[preview] HINT: On Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y postgresql-client"
  echo "[preview] Current PATH: ${PATH}"
  exit 1
fi

echo "[preview] Verifying readiness on 0.0.0.0:${PGPORT} with ${PG_ISREADY} ..."
for i in {1..30}; do
  if sudo -u postgres "${PG_ISREADY}" -h 0.0.0.0 -p "${PGPORT}" >/dev/null 2>&1 || \
     "${PG_ISREADY}" -h 0.0.0.0 -p "${PGPORT}" >/dev/null 2>&1; then
     echo "[preview] PostgreSQL is ready on 0.0.0.0:${PGPORT}"
     # Also run healthcheck for a stable readiness indicator used by CI/preview systems
     if bash "${ROOT_DIR}/ShoppingAppDatabase/healthcheck.sh" >/dev/null 2>&1; then
       echo "[preview] Healthcheck succeeded."
       exit 0
     else
       echo "[preview] WARNING: healthcheck.sh did not report ready despite pg_isready. Will continue retrying..."
     fi
  fi
  echo "[preview] waiting... ($i/30)"
  sleep 2
done

echo "[preview] ERROR: PostgreSQL did not become ready on 0.0.0.0:${PGPORT}"
echo "[preview] Try running manually:"
echo "  bash ShoppingAppDatabase/startup.sh"
echo "  bash ShoppingAppDatabase/healthcheck.sh"
exit 1
