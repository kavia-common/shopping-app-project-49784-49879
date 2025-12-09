#!/bin/bash
set -euo pipefail

# Minimal PostgreSQL startup script with env-driven configuration (non-Docker)
# Safe defaults; allow overriding via environment

DB_NAME="${POSTGRES_DB:-${DB_NAME:-myapp}}"
DB_USER="${POSTGRES_USER:-${DB_USER:-appuser}}"
DB_PASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD:-dbuser123}}"
# Prefer PGPORT if provided by the environment, fallback to POSTGRES_PORT, else 3002
DB_PORT="${PGPORT:-${POSTGRES_PORT:-3002}}"
DB_HOST="0.0.0.0"
DATA_DIR="/var/lib/postgresql/data"

echo "Starting PostgreSQL setup (non-Docker)..."
echo "Config -> DB: ${DB_NAME}, USER: ${DB_USER}, PORT: ${DB_PORT}, HOST: ${DB_HOST}"

# Locate PostgreSQL binaries
PG_BIN=""
if PG_VERSION_DIR=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1) && [ -n "${PG_VERSION_DIR}" ] && [ -x "/usr/lib/postgresql/${PG_VERSION_DIR}/bin/postgres" ]; then
  PG_BIN="/usr/lib/postgresql/${PG_VERSION_DIR}/bin"
elif command -v postgres >/dev/null 2>&1; then
  PG_BIN="$(dirname "$(command -v postgres)")"
fi

# Verify required binaries
REQUIRED_BINS=("initdb" "postgres" "pg_ctl" "pg_isready" "psql" "createdb")
MISSING=()
for b in "${REQUIRED_BINS[@]}"; do
  if [ -n "${PG_BIN}" ] && [ -x "${PG_BIN}/${b}" ]; then
    continue
  fi
  if ! command -v "${b}" >/dev/null 2>&1; then
    MISSING+=("${b}")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "ERROR: Missing PostgreSQL binaries: ${MISSING[*]}"
  echo "Please install PostgreSQL server/client tools. Example (Debian/Ubuntu):"
  echo "  sudo apt-get update && sudo apt-get install -y postgresql postgresql-contrib"
  echo "Alternatively, ensure postgres binaries are in PATH."
  exit 1
fi

# Helper to run a postgres binary regardless of path
pgbin() {
  local cmd="$1"; shift
  if [ -n "${PG_BIN}" ] && [ -x "${PG_BIN}/${cmd}" ]; then
    "${PG_BIN}/${cmd}" "$@"
  else
    "${cmd}" "$@"
  fi
}

# Ensure data directory exists and has proper owner
if [ ! -d "${DATA_DIR}" ]; then
  echo "Creating data directory ${DATA_DIR}..."
  sudo mkdir -p "${DATA_DIR}"
  sudo chown -R postgres:postgres "${DATA_DIR}"
fi

# Initialize PostgreSQL data directory if it doesn't exist
if [ ! -f "${DATA_DIR}/PG_VERSION" ]; then
    echo "Initializing PostgreSQL data directory at ${DATA_DIR}..."
    sudo -u postgres pgbin initdb -D "${DATA_DIR}"
fi

# Ensure postgresql.conf listens on 0.0.0.0 and correct port
POSTGRESQL_CONF="${DATA_DIR}/postgresql.conf"
PG_HBA_CONF="${DATA_DIR}/pg_hba.conf"

# Update postgresql.conf settings (idempotent)
if ! grep -q "^listen_addresses" "${POSTGRESQL_CONF}" 2>/dev/null; then
  echo "listen_addresses = '${DB_HOST}'" | sudo tee -a "${POSTGRESQL_CONF}" >/dev/null
else
  sudo sed -i "s/^#*\s*listen_addresses\s*=.*/listen_addresses = '${DB_HOST}'/g" "${POSTGRESQL_CONF}"
fi

if ! grep -q "^port\s*=\s*${DB_PORT}" "${POSTGRESQL_CONF}" 2>/dev/null; then
  if grep -q "^#*\s*port\s*=" "${POSTGRESQL_CONF}" 2>/dev/null; then
    sudo sed -i "s/^#*\s*port\s*=.*/port = ${DB_PORT}/g" "${POSTGRESQL_CONF}"
  else
    echo "port = ${DB_PORT}" | sudo tee -a "${POSTGRESQL_CONF}" >/dev/null
  fi
fi

# Harden pg_hba.conf with md5 password auth for all IPv4/IPv6 and local connections (idempotent add)
if ! grep -q "host\s\+all\s\+all\s\+0.0.0.0/0\s\+md5" "${PG_HBA_CONF}" 2>/dev/null; then
  {
    echo "host    all             all             0.0.0.0/0               md5"
    echo "host    all             all             ::/0                    md5"
    # Keep peer for local socket access by postgres
    if ! grep -q "^local\s\+all\s\+all\s\+peer" "${PG_HBA_CONF}" 2>/dev/null; then
      echo "local   all             all                                     peer"
    fi
  } | sudo tee -a "${PG_HBA_CONF}" >/dev/null
fi

# If PostgreSQL is already running on the specified port and host, skip start
if sudo -u postgres pgbin pg_isready -h 127.0.0.1 -p "${DB_PORT}" >/dev/null 2>&1 || pgbin pg_isready -h 127.0.0.1 -p "${DB_PORT}" >/dev/null 2>&1; then
    echo "PostgreSQL is already running on 127.0.0.1:${DB_PORT}"
else
    # Start PostgreSQL server in background; explicitly set port and host
    echo "Starting PostgreSQL server on ${DB_HOST}:${DB_PORT}..."
    # Use nohup to ensure process persists beyond shell if environment requires
    sudo -u postgres nohup bash -c "exec $(command -v pgbin) postgres -D '${DATA_DIR}' -p '${DB_PORT}' -h '${DB_HOST}'" >/tmp/postgres.out 2>&1 & disown || {
      # Fallback to direct execution without nohup wrapper
      sudo -u postgres pgbin postgres -D "${DATA_DIR}" -p "${DB_PORT}" -h "${DB_HOST}" &
    }
    sleep 2
fi

# Wait for PostgreSQL to become ready
echo "Waiting for PostgreSQL to become ready on port ${DB_PORT}..."
READY=0
for i in {1..30}; do
    if sudo -u postgres pgbin pg_isready -h 127.0.0.1 -p "${DB_PORT}" >/dev/null 2>&1 || pgbin pg_isready -h 127.0.0.1 -p "${DB_PORT}" >/dev/null 2>&1; then
        echo "PostgreSQL is ready!"
        READY=1
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

if [ "${READY}" -ne 1 ]; then
  echo "ERROR: PostgreSQL did not become ready on port ${DB_PORT}."
  exit 1
fi

# Create/ensure database and user
echo "Ensuring database and user exist..."
# Create/alter user with password
sudo -u postgres pgbin psql -p "${DB_PORT}" -d postgres -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}'; END IF; ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}'; END \$\$;"
# Create database if not exists
if ! sudo -u postgres pgbin psql -p "${DB_PORT}" -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  sudo -u postgres pgbin createdb -p "${DB_PORT}" "${DB_NAME}"
fi

# Grant permissions in target DB
sudo -u postgres pgbin psql -p "${DB_PORT}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 << EOF
GRANT USAGE ON SCHEMA public TO ${DB_USER};
GRANT CREATE ON SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
EOF

# Save connection command to a file
echo "psql postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}" > db_connection.txt
echo "Connection string saved to db_connection.txt"

# Save environment variables to a file for visualizer
cat > db_visualizer/postgres.env << EOF
export POSTGRES_URL="postgresql://localhost:${DB_PORT}/${DB_NAME}"
export POSTGRES_USER="${DB_USER}"
export POSTGRES_PASSWORD="${DB_PASSWORD}"
export POSTGRES_DB="${DB_NAME}"
export POSTGRES_PORT="${DB_PORT}"
EOF

echo "PostgreSQL setup complete!"
echo "Database: ${DB_NAME}"
echo "User: ${DB_USER}"
echo "Port: ${DB_PORT}"
echo "Listening on: ${DB_HOST}"
echo ""
echo "Healthcheck: bash ShoppingAppDatabase/healthcheck.sh  # or: pg_isready -h 127.0.0.1 -p ${DB_PORT}"
echo "To connect: psql -h localhost -U ${DB_USER} -d ${DB_NAME} -p ${DB_PORT}"
echo "$(cat db_connection.txt)"
