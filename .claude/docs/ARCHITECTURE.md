# Architecture Overview

Development Tracker system for tracking AI-assisted development time, commits, and syncing updates to a Roadmap API.

## Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| MCP Server | Python + MCP SDK | Claude Code tool integration |
| Backend | Python + httpx | Roadmap API client |
| Database | SQLite | Local data persistence |
| Hook System | Bash | Claude Code event capture |
| Dashboard API | FastAPI (demo) | Web dashboard server |
| Dashboard CLI | Python | Quick stats viewer |

## Directory Structure

```
dev-tracker/
├── server.py              # MCP Server - main integration with Claude Code
├── dashboard.py           # CLI dashboard for quick stats
├── schema.sql             # SQLite database schema
├── setup.sh               # Installation script
├── requirements.txt       # Python dependencies (mcp, httpx, pydantic)
├── claude_hooks.json      # Claude Code hook configuration
├── mcp_config.json        # MCP server configuration
├── hooks/
│   └── track.sh           # Bash script for event logging
├── demo/
│   ├── server.py          # FastAPI dashboard server
│   ├── data_collector.py  # Dashboard data aggregation
│   └── config.py          # Demo configuration
└── .claude/
    ├── commands/          # Slash commands
    └── docs/              # Documentation (this folder)
```

## Key Components

### MCP Server (`server.py`)
- **Purpose**: Provides Claude Code tools for project tracking and Roadmap API integration
- **Location**: `server.py` (563 lines)
- **Dependencies**: `mcp`, `httpx`, `pydantic`, `sqlite3`
- **Tools exposed**: 12 tools for project management, updates, analytics, and sessions

### Hook Script (`hooks/track.sh`)
- **Purpose**: Captures Claude Code events and logs to SQLite
- **Location**: `hooks/track.sh` (282 lines)
- **Triggers**: PreToolUse, PostToolUse, Stop, Notification (commit)
- **Features**: Session management, tool event tracking, commit logging, daily summaries

### Dashboard CLI (`dashboard.py`)
- **Purpose**: Quick CLI view of development stats and ROI
- **Location**: `dashboard.py` (126 lines)
- **Usage**: `python3 dashboard.py [days]`

### Database Schema (`schema.sql`)
- **Tables**: `sessions`, `tool_events`, `commits`, `project_mappings`, `daily_summaries`, `roadmap_sync_log`
- **Views**: `v_session_durations`, `v_active_coding_time`, `v_commit_velocity`, `v_commit_gaps`
- **Indexes**: On repo_path, session_id, timestamps for query performance

## Data Flow

```
Claude Code Hooks (claude_hooks.json)
    │
    ├── PreToolUse  ─┐
    ├── PostToolUse ─┼──► track.sh ──► SQLite (dev_tracker.db)
    └── Stop        ─┘
                                            │
Git Hooks (post-commit) ────────────────────┘
                                            │
MCP Server (server.py) ◄────────────────────┘
    │
    └──► Roadmap API (feedback.edwinlovett.com)
```

### Data Flow Details
1. Claude Code hooks fire on tool use events → `track.sh` logs to SQLite
2. Git post-commit hook → `track.sh commit` logs commits with diff stats
3. MCP server reads from SQLite for stats/analytics
4. MCP server pushes updates to Roadmap API via httpx
5. Daily summaries aggregate session/commit data for reporting

## External Services

| Service | Purpose | Docs |
|---------|---------|------|
| Roadmap API | Project updates and tracking | `.claude/docs/services/roadmap.md` |

## Environment Variables

| Variable | Purpose | Required | Default |
|----------|---------|----------|---------|
| `ROADMAP_API_TOKEN` | 64-char API token for Roadmap authentication | Yes | - |
| `DEV_TRACKER_DB` | Path to SQLite database | No | `~/dev-tracker/dev_tracker.db` |
| `DEV_TRACKER_LOG` | Path to log file | No | `~/dev-tracker/tracker.log` |
| `GITHUB_TOKEN` | GitHub API token (demo dashboard) | No | - |

## Deployment

### Local Installation
- **Platform**: Local machine
- **Setup**: `chmod +x ~/dev-tracker/setup.sh && ~/dev-tracker/setup.sh`
- **MCP Config**: Add to Claude Code via `mcp_config.json`

### Claude Code Integration
- Copy `claude_hooks.json` to `~/.claude/hooks.json`
- Add MCP server configuration to Claude settings

## Security Considerations

- **Authentication**: Bearer token for Roadmap API (`ROADMAP_API_TOKEN`)
- **Secrets management**: Environment variables for all sensitive data
- **SQL Injection**: Parameterized queries in `server.py`, but shell escaping in `track.sh` should be reviewed

## Performance Notes

- **Database**: SQLite with indexes on common query paths
- **Async HTTP**: httpx AsyncClient for non-blocking API calls
- **Views**: Pre-computed views for session durations and commit gaps
- **Sampling**: Daily summaries reduce need for full table scans
