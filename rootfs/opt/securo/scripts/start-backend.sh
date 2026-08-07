#!/usr/bin/env bash
# Wrapper that runs alembic migrations then starts uvicorn.
# This file is executed by supervisord for the "backend" program.
set -euo pipefail

SECURO_DIR=/opt/securo
VENV="${SECURO_DIR}-venv"

cd "${SECURO_DIR}/backend"
exec "${VENV}/bin/uvicorn" app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 1 \
    --no-access-log
