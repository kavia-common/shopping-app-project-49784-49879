# shopping-app-project-49784-49879

Preview/Startup notes (Non-Docker):
- This project does NOT use Docker to start PostgreSQL. Do not run `docker run ... postgres`.
- Database (ShoppingAppDatabase): start without Docker using any of the following entry points:
  - Canonical preview launcher: `bash preview.sh`
  - Direct startup (no launcher): `bash ShoppingAppDatabase/startup.sh`
  - Platforms that expect a start file can use: `bash start.sh` (delegates to preview.sh)
  - Platforms that consume YAML may use: `preview.yml` which points to `bash preview.sh`
  - Procfile-based environments use: `Procfile` with `web: bash preview.sh`
  - preview.json is also provided with `"start": "bash preview.sh"`

Health check:
- Run: `bash ShoppingAppDatabase/healthcheck.sh` (expects PGPORT 3002 by default) or `pg_isready -h 0.0.0.0 -p 3002`
- The preview will bind PostgreSQL to 0.0.0.0 on PGPORT and verify readiness with pg_isready and healthcheck.

Behavior:
- The database startup script will initialize and launch PostgreSQL using system binaries and bind to 0.0.0.0 on PGPORT.
- Default PGPORT is 3002. Override by setting environment variable `PGPORT`.