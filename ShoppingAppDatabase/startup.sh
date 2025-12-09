#!/bin/bash
set -euo pipefail

# Minimal PostgreSQL startup script with env-driven configuration
# Safe defaults; allow overriding via environment
DB_NAME="${POSTGRES_DB:-${DB_NAME:-myapp}}"
DB_USER="${POSTGRES_USER:-${DB_USER:-appuser}}"
DB_PASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD:-dbuser123}}"
# Prefer PGPORT if provided by the environment, fallback to POSTGRES_PORT, else 3002
DB_PORT="${PGPORT:-${POSTGRES_PORT:-3002}}"
DB_HOST="0.0.0.0"
DATA_DIR="/var/lib/postgresql/data"

echo "Starting PostgreSQL setup..."
echo "Config -> DB: ${DB_NAME}, USER: ${DB_USER}, PORT: ${DB_PORT}, HOST: ${DB_HOST}"

# Find PostgreSQL version and set paths
PG_VERSION=$(ls /usr/lib/postgresql/ | head -1)
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"

echo "Found PostgreSQL version: ${PG_VERSION}"

# Initialize PostgreSQL data directory if it doesn't exist
if [ ! -f "${DATA_DIR}/PG_VERSION" ]; then
    echo "Initializing PostgreSQL data directory at ${DATA_DIR}..."
    sudo -u postgres ${PG_BIN}/initdb -D "${DATA_DIR}"
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
    echo "local   all             all                                     peer"
  } | sudo tee -a "${PG_HBA_CONF}" >/dev/null
fi

# If PostgreSQL is already running on the specified port and host, exit gracefully
if sudo -u postgres ${PG_BIN}/pg_isready -h 127.0.0.1 -p "${DB_PORT}" >/dev/null 2>&1; then
    echo "PostgreSQL is already running on 127.0.0.1:${DB_PORT}"
else
    # Start PostgreSQL server in background; explicitly set port and host
    echo "Starting PostgreSQL server on ${DB_HOST}:${DB_PORT}..."
    sudo -u postgres ${PG_BIN}/postgres -D "${DATA_DIR}" -p "${DB_PORT}" -h "${DB_HOST}" &
    sleep 2
fi

# Wait for PostgreSQL to become ready
echo "Waiting for PostgreSQL to become ready on port ${DB_PORT}..."
for i in {1..30}; do
    if sudo -u postgres ${PG_BIN}/pg_isready -h 127.0.0.1 -p "${DB_PORT}" >/dev/null 2>&1; then
        echo "PostgreSQL is ready!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Create/ensure database and user
echo "Ensuring database and user exist..."
# Create/alter user with password
sudo -u postgres ${PG_BIN}/psql -p "${DB_PORT}" -d postgres -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}'; END IF; ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}'; END \$$;"
# Create database if not exists
if ! sudo -u postgres ${PG_BIN}/psql -p "${DB_PORT}" -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  sudo -u postgres ${PG_BIN}/createdb -p "${DB_PORT}" "${DB_NAME}"
fi

# Grant permissions in target DB
sudo -u postgres ${PG_BIN}/psql -p "${DB_PORT}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 << EOF
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
echo "Healthcheck: pg_isready -h 127.0.0.1 -p ${DB_PORT}"
echo "To connect: psql -h localhost -U ${DB_USER} -d ${DB_NAME} -p ${DB_PORT}"
echo "$(cat db_connection.txt)"
