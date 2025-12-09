# ShoppingAppDatabase

This container starts a PostgreSQL instance configured for the Shopping App.

Defaults:
- POSTGRES_DB: myapp
- POSTGRES_USER: appuser
- POSTGRES_PASSWORD: dbuser123
- PGPORT/POSTGRES_PORT: 3002 (listens on 0.0.0.0)

Startup behavior:
- Initializes data directory at /var/lib/postgresql/data if missing.
- Configures postgresql.conf with:
  - listen_addresses = '0.0.0.0'
  - port = PGPORT (defaults to 3002)
- Updates pg_hba.conf to allow password (md5) auth from all IPv4/IPv6 hosts.
- Creates DB and user and grants necessary privileges.
- Writes db_connection.txt with a psql connection string.
- Writes db_visualizer/postgres.env for the Node visualizer.

Health check:
- Use healthcheck.sh (pg_isready) to verify readiness:
  ./healthcheck.sh

Environment variables:
- POSTGRES_DB
- POSTGRES_USER
- POSTGRES_PASSWORD
- PGPORT (preferred) or POSTGRES_PORT
- POSTGRES_HOST (optional, defaults to 127.0.0.1 for healthcheck)

Connection:
- psql postgresql://appuser:dbuser123@localhost:3002/myapp
