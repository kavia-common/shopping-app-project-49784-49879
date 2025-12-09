# shopping-app-project-49784-49879

Preview/Startup notes:
- Database (ShoppingAppDatabase): start without Docker using:
  - bash ShoppingAppDatabase/startup.sh
  - Or run the preview launcher: bash preview.sh
  - Health check: bash ShoppingAppDatabase/healthcheck.sh (expects PGPORT 3002 by default)
- The database startup script will initialize and launch PostgreSQL using system binaries and bind to 0.0.0.0 on PGPORT.