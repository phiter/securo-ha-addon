#!/usr/bin/with-contenv bashio
# =============================================================================
# Securo Finance — Home Assistant Add-on startup script
# =============================================================================
set -euo pipefail

DATA_DIR=/data
PG_DATA_DIR="${DATA_DIR}/postgres"
PG_LOG_DIR="${DATA_DIR}/logs"
SECURO_DIR=/opt/securo
VENV="${SECURO_DIR}-venv"
SECRET_KEY_FILE="${DATA_DIR}/.secret_key"

# ---------------------------------------------------------------------------- #
# Helpers
# ---------------------------------------------------------------------------- #

log() { bashio::log.info "$*"; }
warn() { bashio::log.warning "$*"; }
err() { bashio::log.error "$*"; }

wait_for_postgres() {
    log "Waiting for PostgreSQL to accept connections..."
    local retries=30
    while ! su -s /bin/bash postgres -c "pg_isready -q" 2>/dev/null; do
        retries=$((retries - 1))
        if [[ ${retries} -le 0 ]]; then
            err "PostgreSQL did not become ready in time. Check ${PG_LOG_DIR}/postgresql.log"
            exit 1
        fi
        sleep 1
    done
    log "PostgreSQL is ready."
}

# ---------------------------------------------------------------------------- #
# Read configuration from HA options
# ---------------------------------------------------------------------------- #

log "Reading add-on configuration..."

# bashio::config exits 1 for null/empty optional fields — always pass a default
SECRET_KEY="$(bashio::config 'secret_key' '')"
if bashio::var.is_empty "${SECRET_KEY}"; then
    # Auto-generate and persist a secret key across restarts
    if [[ -f "${SECRET_KEY_FILE}" ]]; then
        SECRET_KEY="$(cat "${SECRET_KEY_FILE}")"
        log "Using persisted secret key."
    else
        SECRET_KEY="$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 64)"
        echo "${SECRET_KEY}" > "${SECRET_KEY_FILE}"
        chmod 600 "${SECRET_KEY_FILE}"
        warn "No secret_key configured — generated a random key. Set a static key in options to persist sessions across reinstalls."
    fi
fi

FRONTEND_URL="$(bashio::config 'frontend_url' '')"
FRONTEND_PORT="$(bashio::config 'frontend_port' '3000')"

PLUGGY_CLIENT_ID="$(bashio::config 'pluggy_client_id' '')"
PLUGGY_CLIENT_SECRET="$(bashio::config 'pluggy_client_secret' '')"

ENABLE_BANKING_APP_ID="$(bashio::config 'enable_banking_app_id' '')"
ENABLE_BANKING_OAUTH_REDIRECT_URI="$(bashio::config 'enable_banking_oauth_redirect_uri' '')"
ENABLE_BANKING_API_URL="$(bashio::config 'enable_banking_api_url' 'https://api.enablebanking.com')"

# Look for the Enable Banking PEM key in the addon config directory
ENABLE_BANKING_PRIVATE_KEY_FILE=""
if [[ -f "/addon_config/enable_banking_private.pem" ]]; then
    ENABLE_BANKING_PRIVATE_KEY_FILE="/addon_config/enable_banking_private.pem"
    log "Found Enable Banking private key at /addon_config/enable_banking_private.pem"
fi

SIMPLEFIN_ENABLED="$(bashio::config 'simplefin_enabled' 'false')"
SIMPLEFIN_API_URL="$(bashio::config 'simplefin_api_url' 'https://beta-bridge.simplefin.org')"

OIDC_ENABLED="$(bashio::config 'oidc_enabled' 'false')"
OIDC_PROVIDER_NAME="$(bashio::config 'oidc_provider_name' 'OIDC')"
OIDC_DISCOVERY_URL="$(bashio::config 'oidc_discovery_url' '')"
OIDC_CLIENT_ID="$(bashio::config 'oidc_client_id' '')"
OIDC_CLIENT_SECRET="$(bashio::config 'oidc_client_secret' '')"
OIDC_REDIRECT_URI="$(bashio::config 'oidc_redirect_uri' '')"
OIDC_SCOPES="$(bashio::config 'oidc_scopes' 'openid email profile')"
OIDC_AUTO_REGISTER="$(bashio::config 'oidc_auto_register' 'true')"
OIDC_REQUIRE_VERIFIED_EMAIL="$(bashio::config 'oidc_require_verified_email' 'true')"
OIDC_SYNC_ROLES="$(bashio::config 'oidc_sync_roles' 'false')"
OIDC_ROLES_CLAIM="$(bashio::config 'oidc_roles_claim' 'groups')"
OIDC_ADMIN_ROLES="$(bashio::config 'oidc_admin_roles' '')"
OIDC_WORKSPACE_ROLE_MAP="$(bashio::config 'oidc_workspace_role_map' '')"

OPENEXCHANGERATES_APP_ID="$(bashio::config 'openexchangerates_app_id' '')"
FX_SYNC_MODE="$(bashio::config 'fx_sync_mode' 'on_demand')"

TESOURO_DIRETO_ENABLED="$(bashio::config 'tesouro_direto_enabled' 'true')"

WEBAUTHN_RP_ID="$(bashio::config 'webauthn_rp_id' '')"
WEBAUTHN_RP_NAME="$(bashio::config 'webauthn_rp_name' 'Securo')"

AGENTS_ENABLED="$(bashio::config 'agents_enabled' 'false')"
AGENTS_DEFAULT_PROVIDER="$(bashio::config 'agents_default_provider' 'ollama')"
AGENTS_DEFAULT_MODEL="$(bashio::config 'agents_default_model' '')"
AGENTS_OLLAMA_BASE_URL="$(bashio::config 'agents_ollama_base_url' 'http://ollama:11434')"
AGENTS_OPENAI_API_KEY="$(bashio::config 'agents_openai_api_key' '')"
AGENTS_ANTHROPIC_API_KEY="$(bashio::config 'agents_anthropic_api_key' '')"
AGENTS_OPENAI_COMPAT_BASE_URL="$(bashio::config 'agents_openai_compat_base_url' '')"
AGENTS_OPENAI_COMPAT_API_KEY="$(bashio::config 'agents_openai_compat_api_key' '')"

# Internal fixed values
DATABASE_URL="postgresql+asyncpg://securo:securo@localhost:5432/securo"
REDIS_URL="redis://localhost:6379/0"
STORAGE_LOCAL_PATH="${DATA_DIR}/attachments"
AGENTS_KNOWLEDGE_STORAGE_PATH="${DATA_DIR}/agent_knowledge"
AGENTS_EMBEDDING_MODELS_PATH="${DATA_DIR}/embedding_models"
AGENTS_MCP_JWT_SECRET="$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 64)"

# ---------------------------------------------------------------------------- #
# Export all env vars (supervisord child processes will inherit these)
# ---------------------------------------------------------------------------- #

export SECRET_KEY FRONTEND_URL FRONTEND_PORT
export DATABASE_URL REDIS_URL
export STORAGE_LOCAL_PATH AGENTS_KNOWLEDGE_STORAGE_PATH AGENTS_EMBEDDING_MODELS_PATH
export PLUGGY_CLIENT_ID PLUGGY_CLIENT_SECRET
export ENABLE_BANKING_APP_ID ENABLE_BANKING_OAUTH_REDIRECT_URI ENABLE_BANKING_API_URL ENABLE_BANKING_PRIVATE_KEY_FILE
export SIMPLEFIN_ENABLED SIMPLEFIN_API_URL
export OIDC_ENABLED OIDC_PROVIDER_NAME OIDC_DISCOVERY_URL OIDC_CLIENT_ID OIDC_CLIENT_SECRET
export OIDC_REDIRECT_URI OIDC_SCOPES OIDC_AUTO_REGISTER OIDC_REQUIRE_VERIFIED_EMAIL
export OIDC_SYNC_ROLES OIDC_ROLES_CLAIM OIDC_ADMIN_ROLES OIDC_WORKSPACE_ROLE_MAP
export OPENEXCHANGERATES_APP_ID FX_SYNC_MODE TESOURO_DIRETO_ENABLED
export WEBAUTHN_RP_ID WEBAUTHN_RP_NAME
export AGENTS_ENABLED AGENTS_DEFAULT_PROVIDER AGENTS_DEFAULT_MODEL AGENTS_OLLAMA_BASE_URL
export AGENTS_OPENAI_API_KEY AGENTS_ANTHROPIC_API_KEY
export AGENTS_OPENAI_COMPAT_BASE_URL AGENTS_OPENAI_COMPAT_API_KEY AGENTS_MCP_JWT_SECRET

# ---------------------------------------------------------------------------- #
# Create persistent data directories
# ---------------------------------------------------------------------------- #

mkdir -p \
    "${DATA_DIR}/attachments" \
    "${DATA_DIR}/agent_knowledge" \
    "${DATA_DIR}/embedding_models" \
    "${DATA_DIR}/logs" \
    "${DATA_DIR}/redis"

# ---------------------------------------------------------------------------- #
# PostgreSQL — initialize data directory if first run
# ---------------------------------------------------------------------------- #

PG_BIN="$(find /usr/lib/postgresql -name "pg_ctl" 2>/dev/null | sort -V | tail -1 | xargs dirname)"
export PATH="${PG_BIN}:${PATH}"

if [[ ! -d "${PG_DATA_DIR}/base" ]]; then
    log "Initializing PostgreSQL data directory..."
    mkdir -p "${PG_DATA_DIR}"
    chown -R postgres:postgres "${PG_DATA_DIR}"
    su -s /bin/bash postgres -c "initdb -D '${PG_DATA_DIR}' --auth-host=md5 --auth-local=trust"
    log "PostgreSQL initialized."
fi

chown -R postgres:postgres "${PG_DATA_DIR}"

log "Starting PostgreSQL..."
su -s /bin/bash postgres -c \
    "pg_ctl -D '${PG_DATA_DIR}' -l '${PG_LOG_DIR}/postgresql.log' start"

wait_for_postgres

# Create role and database on first run (errors ignored on subsequent runs)
su -s /bin/bash postgres -c "psql -c \"CREATE USER securo WITH PASSWORD 'securo';\"" 2>/dev/null || true
su -s /bin/bash postgres -c "psql -c \"CREATE DATABASE securo OWNER securo;\"" 2>/dev/null || true
# Enable pgvector extension (required for agents RAG feature)
su -s /bin/bash postgres -c \
    "psql -d securo -c 'CREATE EXTENSION IF NOT EXISTS vector;'" 2>/dev/null || \
    warn "pgvector extension not available — AI agents RAG feature will not work."

# ---------------------------------------------------------------------------- #
# Redis — start standalone
# ---------------------------------------------------------------------------- #

log "Starting Redis..."
redis-server \
    --daemonize yes \
    --dir "${DATA_DIR}/redis" \
    --logfile "${PG_LOG_DIR}/redis.log" \
    --save 3600 1 \
    --save 300 100 \
    --save 60 10000

# ---------------------------------------------------------------------------- #
# Run database migrations
# ---------------------------------------------------------------------------- #

log "Running Alembic migrations..."
cd "${SECURO_DIR}/backend"
"${VENV}/bin/alembic" upgrade head
log "Migrations complete."

# ---------------------------------------------------------------------------- #
# Update nginx frontend port configuration
# ---------------------------------------------------------------------------- #

sed -i "s/__FRONTEND_PORT__/${FRONTEND_PORT}/g" \
    /etc/nginx/sites-available/securo

# ---------------------------------------------------------------------------- #
# Hand off to supervisord (manages backend, celery-worker, celery-beat, nginx)
# ---------------------------------------------------------------------------- #

log "Starting Securo services via supervisord..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/securo.conf
