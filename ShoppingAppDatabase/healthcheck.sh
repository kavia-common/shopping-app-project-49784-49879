#!/bin/bash
# Basic health check for PostgreSQL service using pg_isready.
# Uses PGPORT/POSTGRES_PORT and defaults to 3002, localhost host for readiness.
set -euo pipefail

PORT="${PGPORT:-${POSTGRES_PORT:-3002}}"
HOST="${POSTGRES_HOST:-127.0.0.1}"

# Determine pg_isready path: prefer standard /usr/lib path, fallback to PATH
if PG_VERSION_DIR=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1) && [ -n "${PG_VERSION_DIR}" ] && [ -x "/usr/lib/postgresql/${PG_VERSION_DIR}/bin/pg_isready" ]; then
  PG_ISREADY="/usr/lib/postgresql/${PG_VERSION_DIR}/bin/pg_isready"
elif command -v pg_isready >/dev/null 2>&1; then
  PG_ISREADY="$(command -v pg_isready)"
else
  echo "not ready"
  echo "pg_isready not found. Ensure PostgreSQL client tools are installed."
  exit 1
fi

if sudo -u postgres "${PG_ISREADY}" -h "${HOST}" -p "${PORT}" >/dev/null 2>&1 || "${PG_ISREADY}" -h "${HOST}" -p "${PORT}" >/dev/null 2>&1; then
  echo "ready"
  exit 0
else
  echo "not ready"
  exit 1
fi
