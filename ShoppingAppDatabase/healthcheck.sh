#!/bin/bash
# Basic health check for PostgreSQL service using pg_isready.
# Uses PGPORT/POSTGRES_PORT and defaults to 3002, localhost host for readiness.
set -euo pipefail

PG_VERSION=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1)
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"

PORT="${PGPORT:-${POSTGRES_PORT:-3002}}"
HOST="${POSTGRES_HOST:-127.0.0.1}"

if sudo -u postgres ${PG_BIN}/pg_isready -h "${HOST}" -p "${PORT}" >/dev/null 2>&1; then
  echo "ready"
  exit 0
else
  echo "not ready"
  exit 1
fi
