#!/usr/bin/env bash
# PUBLIC_INTERFACE
# Ensures execute permissions on launcher and database scripts for non-Docker preview environments.
# Safe to run multiple times (idempotent).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

chmod +x "${ROOT_DIR}/preview.sh" || true
chmod +x "${ROOT_DIR}/start.sh" || true
chmod +x "${ROOT_DIR}/ShoppingAppDatabase/startup.sh" || true
chmod +x "${ROOT_DIR}/ShoppingAppDatabase/healthcheck.sh" || true
chmod +x "${ROOT_DIR}/ShoppingAppDatabase/backup_db.sh" || true
chmod +x "${ROOT_DIR}/ShoppingAppDatabase/restore_db.sh" || true

echo "[ensure_perms] Executable permissions ensured."
