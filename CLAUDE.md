# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Development Tracker is a system for tracking AI-assisted development time, commits, and syncing updates to a Roadmap API. It consists of:

- **MCP Server** (`server.py`) - Python server providing tools for Claude Code to interact with tracking data and Roadmap API
- **Hook Script** (`hooks/track.sh`) - Bash script that logs Claude Code events to SQLite
- **SQLite Database** - Stores sessions, tool events, commits, and project mappings
- **Dashboard** (`dashboard.py`) - CLI tool for viewing stats

## Commands

```bash
# Setup
chmod +x ~/dev-tracker/setup.sh && ~/dev-tracker/setup.sh

# Install Python dependencies
pip3 install -r ~/dev-tracker/requirements.txt

# Initialize/reset database
sqlite3 ~/dev-tracker/dev_tracker.db < ~/dev-tracker/schema.sql

# Test MCP server directly
python3 ~/dev-tracker/server.py

# Track commands
~/dev-tracker/hooks/track.sh start              # Start session
~/dev-tracker/hooks/track.sh end                # End session
~/dev-tracker/hooks/track.sh commit             # Log git commit
~/dev-tracker/hooks/track.sh stats [repo] [days] # View stats
~/dev-tracker/hooks/track.sh link <api_key> <name> # Link repo to project

# View dashboard
python3 ~/dev-tracker/dashboard.py [days]
```

## Architecture

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

### Data Flow

1. Claude Code hooks fire on tool use → `track.sh` logs to SQLite
2. Git post-commit hook → `track.sh commit` logs commits
3. MCP server reads from SQLite and pushes to Roadmap API
4. Daily summaries aggregate session/commit data

### Database Schema (schema.sql)

Key tables:
- `sessions` - Claude Code working sessions with start/end timestamps
- `tool_events` - Individual tool calls within sessions
- `commits` - Git commits with diff stats
- `project_mappings` - Links repos to Roadmap projects
- `daily_summaries` - Aggregated daily metrics

Key views:
- `v_session_durations` - Session length calculations
- `v_active_coding_time` - Time between tool start/end events
- `v_commit_gaps` - Time between commits using LAG()

## Environment Variables

```bash
ROADMAP_API_TOKEN        # Required: 64-char API token for Roadmap
DEV_TRACKER_DB           # Optional: Path to SQLite DB (default: ~/dev-tracker/dev_tracker.db)
DEV_TRACKER_LOG          # Optional: Path to log file
DEV_TRACKER_HOURLY_RATE  # Optional: Hourly rate for ROI calculations (default: 75)
```

## MCP Server Tools

The server exposes these tools to Claude Code:

**Project Management**: `list_roadmap_projects`, `get_project_details`, `link_repo_to_project`, `get_linked_projects`

**Updates**: `push_project_update`, `push_commit_to_roadmap`

**Analytics**: `get_dev_stats`, `get_recent_commits`, `generate_roi_report`

**Sessions**: `log_session_start`, `log_session_end`

## ROI Calculations

The system uses these formulas:
- Manual Multiplier: 2.5x (industry standard for AI-assisted dev)
- Time Saved = Dev Hours × (Multiplier - 1)
- Cost Savings = Time Saved × $75/hour

---

# Documentation Protocol

This project uses an automated documentation system. Follow these protocols to keep documentation current and accurate.

---

## Quick Reference

| Command | When to Use | Example |
|---------|-------------|---------|
| `/doc` | After every coding session | `/doc` |
| `/issue` | When you find a bug or edge case | `/issue API timeout on large payloads` |
| `/decision` | When you make a technical choice | `/decision Using Redis over Memcached` |
| `/service` | When you add/modify external service | `/service Stripe` |
| `/audit` | Full project analysis (periodic) | `/audit` |
| `/doc-status` | Check documentation health | `/doc-status` |
| `/handoff` | Before sharing with another dev | `/handoff` |

---

## Documentation Locations

| Document | Purpose | Update Frequency |
|----------|---------|------------------|
| `.claude/docs/CHANGELOG.md` | What changed and when | Every session |
| `.claude/docs/KNOWN_ISSUES.md` | Bugs, edge cases, tech debt | When discovered |
| `.claude/docs/DECISIONS.md` | Why things were built this way | When deciding |
| `.claude/docs/ARCHITECTURE.md` | System overview, env vars | When structure changes |
| `.claude/docs/services/*.md` | External service integrations | When services change |
| `.claude/docs/components/*.md` | Internal component docs | When components change |

---

## Workflow Rules

### After Every Coding Session
Run `/doc` to:
- Update CHANGELOG.md with what was done
- Flag any new issues discovered
- Update affected service/component docs

### When You Encounter a Bug or Edge Case
Run `/issue [description]` immediately. Don't trust your memory.

### When You Make a Non-Obvious Technical Decision
Run `/decision [what you decided]` to capture context for future developers.

### When You Add or Modify External Services
Run `/service [service name]` to document the integration.

### Before Handing Off to Another Developer
Run `/handoff` to generate a comprehensive onboarding document.

---

## Issue Severity Guide

| Level | Description | Example |
|-------|-------------|---------|
| CRITICAL | System unusable, data loss risk | Auth completely broken |
| HIGH | Major feature broken, no workaround | Checkout fails silently |
| MEDIUM | Feature impaired, workaround exists | Export works but slow |
| LOW | Minor inconvenience | Typo in error message |

---

## Decision Recording Guide

Record a decision when:
- Choosing between technologies (e.g., "Why Cloudflare over Vercel")
- Designing data models or APIs
- Setting up infrastructure
- Establishing patterns that will be repeated
- Making tradeoffs that won't be obvious later

Don't record:
- Obvious choices (standard patterns)
- Temporary implementations
- Personal preferences without project impact
