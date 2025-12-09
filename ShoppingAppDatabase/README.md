# ShoppingAppDatabase

This container starts a PostgreSQL instance configured for the Shopping App WITHOUT Docker. It uses local PostgreSQL binaries (initdb, postgres, pg_ctl, pg_isready) and falls back to system installation if needed.

Defaults:
- POSTGRES_DB: myapp
- POSTGRES_USER: appuser
- POSTGRES_PASSWORD: dbuser123
- PGPORT/POSTGRES_PORT: 3002 (listens on 0.0.0.0)

How to start (non-Docker):
- Ensure the preview/start command runs the startup script directly:
  - bash ShoppingAppDatabase/startup.sh
  - or from the ShoppingAppDatabase directory: ./startup.sh
- Do NOT use docker run. This project no longer relies on Docker for database startup.

Startup behavior:
- Detects PostgreSQL binaries at /usr/lib/postgresql/<version>/bin.
- If not initialized:
  - Runs initdb to initialize /var/lib/postgresql/data.
  - Configures postgresql.conf:
    - listen_addresses = '0.0.0.0'
    - port = PGPORT (defaults to 3002)
  - Updates pg_hba.conf to allow password (md5) auth from IPv4/IPv6 hosts.
- Starts postgres bound to 0.0.0.0 with port from PGPORT/POSTGRES_PORT.
- Creates DB and user and grants necessary privileges.
- Writes db_connection.txt with a psql connection string.
- Writes db_visualizer/postgres.env for the Node visualizer.

Health check:
- Use healthcheck.sh (pg_isready) to verify readiness:
  ./healthcheck.sh
- Expects pg_isready to respond on 127.0.0.1:3002 (or PGPORT).

Environment variables:
- POSTGRES_DB
- POSTGRES_USER
- POSTGRES_PASSWORD
- PGPORT (preferred) or POSTGRES_PORT
- POSTGRES_HOST (optional, defaults to 127.0.0.1 for healthcheck)

Binary requirements and fallback:
- Required: initdb, postgres, pg_ctl, pg_isready
- The startup.sh script checks for these in /usr/lib/postgresql/<version>/bin and exits with a clear error if missing.
- If binaries are missing in your environment, install PostgreSQL (e.g., apt-get install postgresql) or use system-provided equivalents available in PATH.
- If installation is not possible in your environment, you can temporarily stub your development using SQLite with the db_visualizer (see db_visualizer/README if present), but the application expects PostgreSQL.

Connection:
- psql postgresql://appuser:dbuser123@localhost:3002/myapp

Troubleshooting:
- Permission denied on /var/lib/postgresql/data:
  - Ensure the directory exists and is accessible by the postgres user.
- Binaries not found:
  - Install PostgreSQL server packages appropriate for your OS or configure PATH to include postgres binaries.
- Health check failing:
  - Check logs from startup.sh output.
  - Verify port (PGPORT) and that no other service is occupying it.
