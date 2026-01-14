# Roadmap API Integration

## Overview

| | |
|---|---|
| **Service** | Roadmap API |
| **Purpose** | Project updates, status tracking, and progress reporting |
| **Documentation** | Internal API |
| **Dashboard** | https://feedback.edwinlovett.com |

## Configuration

### Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `ROADMAP_API_TOKEN` | 64-character API authentication token | Yes |

### Initial Setup
1. Obtain API token from Roadmap admin
2. Set environment variable: `export ROADMAP_API_TOKEN='your_token_here'`
3. Verify with `list_roadmap_projects` MCP tool

## Implementation

### Files
- `server.py` - API client and MCP tools (`call_roadmap_api()` function)
- `hooks/track.sh` - Commit logging (stores project_api_key for sync)

### SDK/Library
- **Package**: `httpx`
- **Version**: `>=0.27.0`

### Client Initialization
```python
# From server.py
import httpx

ROADMAP_API_BASE = "https://feedback.edwinlovett.com/roadmap/api/v1"
ROADMAP_API_TOKEN = os.environ.get("ROADMAP_API_TOKEN", "")

async def call_roadmap_api(method: str, endpoint: str, data: dict = None) -> dict:
    headers = {
        "Authorization": f"Bearer {ROADMAP_API_TOKEN}",
        "Content-Type": "application/json"
    }
    url = f"{ROADMAP_API_BASE}{endpoint}"

    async with httpx.AsyncClient() as client:
        if method == "GET":
            response = await client.get(url, headers=headers)
        elif method == "POST":
            response = await client.post(url, headers=headers, json=data)
        return response.json()
```

## API Endpoints

### GET /projects
List all projects for the authenticated user.

**Response:**
```json
{
  "projects": [
    {
      "name": "Project Name",
      "status": "In Progress",
      "api_key": "abc123...",
      "current_version": "1.0.0",
      "update_count": 15
    }
  ]
}
```

### GET /projects/{identifier}
Get project details by API key or name.

**Response:**
```json
{
  "project": {
    "name": "Project Name",
    "status": "In Progress",
    "api_key": "abc123...",
    "description": "...",
    "updates": [...]
  }
}
```

### POST /projects/{identifier}/updates
Push a status update to a project.

**Request:**
```json
{
  "notes": "Implemented feature X",
  "status": "In Progress",
  "update_date": "2025-01-14T12:00:00Z"
}
```

## Usage Examples

### List Projects (MCP Tool)
```python
# Via Claude Code
await list_roadmap_projects()
```

### Push Update (MCP Tool)
```python
# Via Claude Code
await push_project_update(
    project_identifier="abc123...",
    notes="Completed authentication module",
    status="In Progress"
)
```

### Link Repository
```python
# Via Claude Code
await link_repo_to_project(
    project_api_key="abc123...",
    project_name="My Project",
    auto_push=True
)
```

## Rate Limits & Quotas

| Operation | Limit | Notes |
|-----------|-------|-------|
| API calls | Unknown | No documented limits |
| Updates | Unknown | Check with admin |

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| "ROADMAP_API_TOKEN not set" | Missing env var | Set `ROADMAP_API_TOKEN` |
| 401 | Invalid token | Verify token is correct |
| 404 | Project not found | Check project identifier |

## Monitoring

- **Logs**: Sync attempts logged to `roadmap_sync_log` table
- **Status**: Check `pushed_to_roadmap` flag on commits table

## Cost

- **Tier**: Internal service
- **Cost Drivers**: N/A

## Known Issues

- No retry logic for failed API calls
- Token validation happens per-request (no caching)
- API responses not fully validated against schema

## Changelog

- 2025-01-14: Initial documentation
