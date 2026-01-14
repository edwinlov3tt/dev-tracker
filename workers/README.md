# Dev Tracker - Cloudflare Workers

Serverless backend for Development Tracker using Cloudflare Workers and D1.

## Prerequisites

- Node.js 18+
- Cloudflare account
- Wrangler CLI (`npm install -g wrangler`)

## Setup

### 1. Install dependencies

```bash
cd workers
npm install
```

### 2. Login to Cloudflare

```bash
wrangler login
```

### 3. Create D1 database

```bash
npm run db:create
```

This will output a database ID. Copy it and update `wrangler.toml`:

```toml
[[d1_databases]]
binding = "DB"
database_name = "dev-tracker"
database_id = "YOUR_DATABASE_ID_HERE"
```

### 4. Run migrations

```bash
npm run db:migrate
```

### 5. Set API token secret

Generate a secure token and set it as a secret:

```bash
# Generate a token
openssl rand -hex 32

# Set it as a secret
wrangler secret put API_TOKEN
```

### 6. Deploy

```bash
npm run deploy
```

Note your worker URL (e.g., `https://dev-tracker.YOUR_SUBDOMAIN.workers.dev`)

## Local Development

```bash
# Run migrations on local D1
npm run db:migrate:local

# Start local dev server
npm run dev
```

## Configure Hooks

Set environment variables:

```bash
export DEV_TRACKER_API_URL="https://dev-tracker.YOUR_SUBDOMAIN.workers.dev"
export DEV_TRACKER_API_TOKEN="your_api_token"
```

Use the cloud hooks configuration:

```bash
cp ~/dev-tracker/claude_hooks_cloud.json ~/.claude/hooks.json
```

## API Endpoints

### Public (no auth)
- `GET /` - API info
- `GET /api/health` - Health check
- `GET /api/data` - Dashboard data
- `GET /api/export/csv` - CSV export
- `GET /api/mappings` - Project mappings

### Authenticated (Bearer token required)
- `POST /api/sessions/start` - Start session
- `POST /api/sessions/end` - End session
- `POST /api/events` - Log tool event
- `POST /api/commits` - Log commit
- `POST /api/mappings` - Create/update mapping

## Dashboard

The dashboard can be deployed to Cloudflare Pages:

```bash
cd ../demo
npx wrangler pages deploy . --project-name=dev-tracker-dashboard
```

Or serve locally while using the cloud API by setting:

```javascript
// In demo/index.html, change the API base URL:
const API_BASE = 'https://dev-tracker.YOUR_SUBDOMAIN.workers.dev';
```
