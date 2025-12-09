#!/usr/bin/env bash
# PUBLIC_INTERFACE
# ShoppingAppDatabase preview/start entrypoint (non-Docker)
# This script ensures platforms that expect a start.sh will execute the non-Docker preview.
# It simply shells out to the canonical preview launcher.

set -euo pipefail

# Default PGPORT if not provided by environment
export PGPORT="${PGPORT:-3002}"

# Delegate to the canonical preview launcher
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/preview.sh"
