# Securo — Home Assistant Add-on

Open-source personal finance manager. Self-hosted, privacy-first.

## Features

- Multi-account management with running balances
- Transaction management with search, filters, and CSV export
- File import (OFX, QIF, CAMT, CSV)
- Auto-categorization rules engine
- Recurring transactions and budgets
- Goals and savings targets with progress tracking
- Asset management with valuation tracking
- Reports: Net Worth and Income vs Expenses
- Bank sync (Pluggy for Brazilian banks, Enable Banking for European PSD2 banks, SimpleFIN for US banks)
- Multi-currency support with automatic FX conversion
- Multi-user with admin panel and registration controls
- Two-factor authentication (TOTP)
- OIDC login (Authentik, Pocket ID, any standard provider)
- AI Agents (optional) — self-hosted LLM chat over your data

---

## First Run

After installing and starting the add-on, open the web UI via the sidebar or navigate to `http://<ha-ip>:3000`. Create your first account — that's it.

The first startup takes a few extra seconds to initialize the database.

---

## Configuration

### Secret Key

A cryptographic secret used to sign sessions. If you leave it empty, the add-on generates one automatically and persists it in `/data/.secret_key`. Set a static value if you want sessions to survive reinstallation.

### Frontend URL

Set this when accessing Securo via a domain name and HTTPS reverse proxy (e.g. `https://securo.example.com`). This is required for:

- **Passkeys (WebAuthn)** — passkeys cannot be used over plain HTTP except on `localhost`.
- **OIDC login** — the OAuth callback URI must match exactly.
- **CORS** — the backend allows requests only from this origin.

Leave empty if you only access Securo via the HA ingress or `http://localhost:3000`.

---

## Bank Sync Setup

### Pluggy (Brazilian banks)

1. Sign up at [dashboard.pluggy.ai](https://dashboard.pluggy.ai).
2. Add `http://<ha-ip>:3000/oauth/callback` as an allowed redirect URI.
3. Copy your **Client ID** and **Client Secret** into the add-on config.

### Enable Banking (European PSD2 banks)

1. Sign up at [enablebanking.com](https://enablebanking.com) and create a Production application.
2. Add `http://<ha-ip>:3000/oauth/callback` as an allowed redirect URL.
3. Download the PEM private key and upload it to:
   `/addon_configs/securo/enable_banking_private.pem`
4. Copy your **Application ID** into the add-on config.

> **Note:** The Enable Banking free tier requires you to pre-link accounts in the EB portal before connecting from Securo.

### SimpleFIN (US and international banks)

1. Enable **Enable SimpleFIN** in the add-on config.
2. In Securo: **Accounts → Connect Bank → SimpleFIN**.
3. Paste a Setup Token from [bridge.simplefin.org](https://bridge.simplefin.org).

No API key needed — each connection brings its own credentials via a single-use token.

---

## OIDC Login Setup (Authentik, Pocket ID, etc.)

1. Create a **confidential / web application** in your OIDC provider.
2. Register this redirect URI:
   ```
   https://your-securo-host/api/auth/oidc/callback
   ```
3. Fill in the OIDC fields in the add-on config and enable **OIDC Login**.

---

## AI Agents (Optional)

AI agents let you chat with your Securo data using a local or cloud LLM. They are off by default and cost nothing when off.

1. Set **Enable AI Agents** to `true`.
2. Choose your **AI Default Provider** (`ollama`, `openai`, `anthropic`, or `openai_compatible`).
3. Fill in the matching URL / API key.
4. Restart the add-on.
5. Go to **Settings → AI Agents** inside Securo to configure agent personas and a RAG knowledge base.

**Ollama tip:** If you run Ollama as another HA add-on or on the same machine, set the Ollama Base URL to `http://172.30.32.1:11434` (the HA host IP visible inside add-on containers).

---

## Persistent Data

All data is stored in `/data` (HA add-on persistent storage) and survives restarts and updates:

| Path | Contents |
|------|----------|
| `/data/postgres/` | PostgreSQL database files |
| `/data/redis/` | Redis snapshots |
| `/data/attachments/` | Uploaded receipt/document attachments |
| `/data/agent_knowledge/` | AI agent RAG knowledge base |
| `/data/logs/` | Service logs |

---

## Passkeys

Passkeys (Touch ID, Face ID, Windows Hello, security keys) work out of the box on `http://localhost:3000`. For any other address you must:

1. Serve Securo on a domain over HTTPS.
2. Set `frontend_url` to that domain in the add-on config.

Plain HTTP addresses and IP addresses cannot be used for passkeys — this is a WebAuthn standard requirement, not an add-on limitation.

---

## Support

- [Securo project](https://github.com/securo-finance/securo)
- [Securo documentation](https://usesecuro.com)
