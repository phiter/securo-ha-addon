ARG BUILD_FROM
FROM $BUILD_FROM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---------------------------------------------------------------------------- #
# System dependencies
# ---------------------------------------------------------------------------- #
# Install PostgreSQL APT repository for version 16 (required for pgvector)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gnupg \
        curl \
        lsb-release \
        ca-certificates \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] \
        https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # PostgreSQL 16 + pgvector (required for AI agents RAG feature)
        postgresql-16 \
        postgresql-16-pgvector \
        # Redis
        redis-server \
        # Python
        python3 \
        python3-venv \
        python3-pip \
        python3-dev \
        # Build tools for native Python extensions
        build-essential \
        libpq-dev \
        libffi-dev \
        libssl-dev \
        # Nginx (frontend static files + reverse proxy)
        nginx \
        # Process supervisor
        supervisor \
        # Utilities
        git \
        gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 (for building the React frontend)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------- #
# Clone Securo and build backend
# ---------------------------------------------------------------------------- #
WORKDIR /opt/securo

ARG SECURO_REF=v0.14.0
RUN git clone --depth=1 --branch "${SECURO_REF}" \
        https://github.com/securo-finance/securo.git . \
    && git log --oneline -1

# Copy frontend patches (base-path support; to be removed once merged upstream)
COPY patches/frontend/ /opt/securo-patches/frontend/
RUN cp /opt/securo-patches/frontend/base-path.ts frontend/src/lib/base-path.ts \
    && cp /opt/securo-patches/frontend/App.tsx       frontend/src/App.tsx \
    && cp /opt/securo-patches/frontend/api.ts        frontend/src/lib/api.ts \
    && cp /opt/securo-patches/frontend/login.tsx     frontend/src/pages/login.tsx \
    && cp /opt/securo-patches/frontend/vite.config.ts frontend/vite.config.ts

# Create Python virtual environment and install backend
RUN python3 -m venv /opt/securo-venv \
    && /opt/securo-venv/bin/pip install --upgrade --no-cache-dir pip \
    && cd backend \
    && /opt/securo-venv/bin/pip install --no-cache-dir -e .

# ---------------------------------------------------------------------------- #
# Build frontend
# ---------------------------------------------------------------------------- #
# VITE_BASE_PATH=./ makes all asset paths relative so they resolve correctly
# through HA ingress (which prefixes a dynamic token path). The nginx
# sub_filter always injects <base href="..."> so relative paths land correctly
# for both ingress and direct :3000 access.
RUN cd frontend \
    && npm ci --no-audit --no-fund \
    && VITE_BASE_PATH=./ npm run build \
    && rm -rf node_modules

# ---------------------------------------------------------------------------- #
# Copy overlay files and startup script
# ---------------------------------------------------------------------------- #
COPY rootfs /
COPY run.sh /run.sh

# Configure nginx
RUN rm -f /etc/nginx/sites-enabled/default \
    && ln -sf /etc/nginx/sites-available/securo /etc/nginx/sites-enabled/securo

# Nginx and supervisor log directories
RUN mkdir -p \
        /var/log/supervisor \
        /var/log/nginx \
        /run/nginx

# Make scripts executable
RUN chmod +x /run.sh /opt/securo/scripts/start-backend.sh

CMD ["/run.sh"]
