# How Development Tracker Works

A comprehensive guide to installing, configuring, and understanding the Development Tracker system for Claude Code.

---

## Table of Contents

1. [Installation Guide](#1-installation-guide)
2. [System Architecture](#2-system-architecture)
3. [Hook Execution Flow](#3-hook-execution-flow)
4. [Database Schema](#4-database-schema)
5. [ROI Calculations](#5-roi-calculations)
6. [MCP Server Tools](#6-mcp-server-tools)
7. [Configuration](#7-configuration)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Installation Guide

Follow these steps to set up Development Tracker with Claude Code.

### Step 1: Clone or Download the Repository

```bash
git clone https://github.com/edwinlov3tt/dev-tracker.git ~/dev-tracker
cd ~/dev-tracker
```

### Step 2: Run the Setup Script

This initializes the database, installs dependencies, and configures Claude Code hooks.

```bash
chmod +x setup.sh
./setup.sh
```

### Step 3: Set Environment Variables

Add these to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
# Required for Roadmap API integration
export ROADMAP_API_TOKEN="your_64_character_token"

# Optional: Custom hourly rate for ROI calculations (default: $75)
export DEV_TRACKER_HOURLY_RATE="100"

# Optional: Custom database location
export DEV_TRACKER_DB="$HOME/dev-tracker/dev_tracker.db"
```

### Step 4: Configure MCP Server in Claude Code

Add the MCP server to your Claude Code configuration:

**~/.claude/config.json**
```json
{
  "mcpServers": {
    "dev-tracker": {
      "command": "python3",
      "args": ["$HOME/dev-tracker/server.py"],
      "env": {
        "ROADMAP_API_TOKEN": "your_token_here"
      }
    }
  }
}
```

### Step 5: Install Git Hooks (Per Repository)

For each repository you want to track commits:

```bash
cp ~/dev-tracker/hooks/post-commit /path/to/your/repo/.git/hooks/
chmod +x /path/to/your/repo/.git/hooks/post-commit
```

### Step 6: Verify Installation

```bash
# Check that hooks are configured
cat ~/.claude/hooks.json

# Test the tracking script
~/dev-tracker/hooks/track.sh stats

# Start the dashboard
cd ~/dev-tracker/demo && ./run.sh
```

---

## 2. System Architecture

Development Tracker consists of four main components that work together to capture, store, and visualize your development metrics.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DEVELOPMENT TRACKER SYSTEM                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌──────────────────┐                                                          │
│   │   CLAUDE CODE    │                                                          │
│   │                  │                                                          │
│   │  ┌────────────┐  │     ┌─────────────┐      ┌──────────────────┐           │
│   │  │ PreToolUse │──┼────▶│             │      │                  │           │
│   │  └────────────┘  │     │  track.sh   │─────▶│   SQLite DB      │           │
│   │  ┌────────────┐  │     │             │      │  dev_tracker.db  │           │
│   │  │PostToolUse │──┼────▶│  (Bash)     │      │                  │           │
│   │  └────────────┘  │     │             │      │  • sessions      │           │
│   │  ┌────────────┐  │     └─────────────┘      │  • tool_events   │           │
│   │  │   Stop     │──┼────────────┘             │  • commits       │           │
│   │  └────────────┘  │                          │  • summaries     │           │
│   └──────────────────┘                          └────────┬─────────┘           │
│                                                          │                      │
│   ┌──────────────────┐                                   │                      │
│   │    GIT REPO      │                                   │                      │
│   │  ┌────────────┐  │     ┌─────────────┐              │                      │
│   │  │post-commit │──┼────▶│  track.sh   │──────────────┘                      │
│   │  │   hook     │  │     │  commit     │                                      │
│   │  └────────────┘  │     └─────────────┘                                      │
│   └──────────────────┘                                                          │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │                         MCP SERVER (server.py)                           │  │
│   │                                                                          │  │
│   │   Reads from SQLite DB                                                   │  │
│   │                                                                          │  │
│   │   Tools:  • get_dev_stats        • list_roadmap_projects                │  │
│   │           • get_recent_commits   • push_project_update                  │  │
│   │           • generate_roi_report  • link_repo_to_project                 │  │
│   │                                                                          │  │
│   └────────────────────────────────────┬────────────────────────────────────┘  │
│                                        │                                        │
│                                        ▼                                        │
│                           ┌──────────────────────┐                             │
│                           │    ROADMAP API       │                             │
│                           │ feedback.edwinlovett │                             │
│                           │      .com            │                             │
│                           └──────────────────────┘                             │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Component Overview

| Component | File | Purpose |
|-----------|------|---------|
| Hook Script | `hooks/track.sh` | Captures events from Claude Code and Git, writes to SQLite |
| MCP Server | `server.py` | Exposes tools to Claude Code for querying stats and pushing updates |
| Database | `dev_tracker.db` | SQLite database storing all tracking data |
| Dashboard | `demo/server.py` | Web UI for visualizing metrics |
| Data Collector | `demo/data_collector.py` | Aggregates data from multiple sources into JSON |

---

## 3. Hook Execution Flow

Claude Code hooks are the primary data collection mechanism. They fire automatically during your coding sessions.

### Claude Code Hooks

These are configured in `~/.claude/hooks.json` and execute automatically:

#### PreToolUse
- **When:** Fires **before** Claude executes any tool (Read, Write, Edit, Bash, etc.)
- **Command:** `track.sh tool_start "Read"`
- **Records:** session_id, tool_name, timestamp, event_type='start'

#### PostToolUse
- **When:** Fires **after** Claude completes any tool execution
- **Command:** `track.sh tool_end "Read" 0`
- **Records:** session_id, tool_name, exit_code, timestamp, event_type='end'

#### Stop
- **When:** Fires when a Claude Code session ends (user exits or timeout)
- **Command:** `track.sh end`
- **Records:** session end time, total tool calls, status='completed'

### Git Hook

#### post-commit
- **When:** Fires after every successful `git commit`
- **Command:** `track.sh commit`
- **Records:** commit_hash, message, author, branch, files_changed, insertions, deletions, timestamp

### Hook Configuration File

**~/.claude/hooks.json**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/dev-tracker/hooks/track.sh tool_start \"$TOOL_NAME\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/dev-tracker/hooks/track.sh tool_end \"$TOOL_NAME\" \"$EXIT_CODE\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/dev-tracker/hooks/track.sh end"
          }
        ]
      }
    ]
  }
}
```

### Session ID Generation

Sessions are uniquely identified by combining the date and a hash of the working directory:

```bash
# Format: session_YYYYMMDD_XXXXXXXX
# Example: session_20250114_a3b8c9d2

session_id = "session_" + date(YYYYMMDD) + "_" + md5(pwd).substring(0,8)
```

This ensures that:
- Each day starts a new session per project
- Different directories have different sessions
- Sessions can be resumed throughout the day

---

## 4. Database Schema

All data is stored in a local SQLite database at `~/dev-tracker/dev_tracker.db`

### Tables

#### sessions
Tracks Claude Code working sessions

| Column | Type | Description |
|--------|------|-------------|
| session_id | TEXT PK | Unique session identifier |
| repo_path | TEXT | Working directory path |
| project_api_key | TEXT | Linked Roadmap project (if any) |
| started_at | INTEGER | Unix timestamp of session start |
| ended_at | INTEGER | Unix timestamp of session end |
| status | TEXT | 'active' or 'completed' |
| total_tool_calls | INTEGER | Count of tools used in session |

#### tool_events
Individual tool execution events within sessions

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment ID |
| session_id | TEXT FK | Parent session |
| tool_name | TEXT | Name of tool (Read, Write, Bash, etc.) |
| event_type | TEXT | 'start' or 'end' |
| exit_code | INTEGER | Tool exit code (for 'end' events) |
| timestamp | INTEGER | Unix timestamp |

#### commits
Git commits captured by post-commit hook

| Column | Type | Description |
|--------|------|-------------|
| commit_hash | TEXT PK | Git commit SHA |
| repo_path | TEXT | Repository path |
| session_id | TEXT | Associated session (if any) |
| message | TEXT | Commit message |
| author | TEXT | Commit author name |
| branch | TEXT | Branch name |
| timestamp | INTEGER | Commit timestamp |
| files_changed | INTEGER | Number of files changed |
| insertions | INTEGER | Lines added |
| deletions | INTEGER | Lines deleted |
| pushed_to_roadmap | INTEGER | 1 if synced to Roadmap |

#### daily_summaries
Aggregated metrics per day per repository

| Column | Type | Description |
|--------|------|-------------|
| date | TEXT | Date (YYYY-MM-DD) |
| repo_path | TEXT | Repository path |
| total_sessions | INTEGER | Number of sessions |
| total_dev_hours | REAL | Total development hours |
| active_coding_hours | REAL | Active coding time |
| total_commits | INTEGER | Number of commits |
| total_insertions | INTEGER | Lines added |
| total_deletions | INTEGER | Lines deleted |
| commits_per_hour | REAL | Commit velocity |
| lines_per_hour | REAL | Coding velocity |

### Useful Views

| View | Purpose |
|------|---------|
| `v_session_durations` | Calculates session length from start/end timestamps |
| `v_active_coding_time` | Sums time between tool_start and tool_end events |
| `v_commit_gaps` | Uses LAG() to calculate time between consecutive commits |

---

## 5. ROI Calculations

The ROI (Return on Investment) calculations estimate the value generated by AI-assisted development compared to traditional manual coding.

### Core Formulas

```
Time Saved = Dev Hours × (Multiplier - 1)
```
Where Multiplier represents how much longer the same work would take manually.

```
Cost Savings = Time Saved × Hourly Rate
```
Converts time saved into monetary value.

### Default Values

| Parameter | Default | Source |
|-----------|---------|--------|
| Multiplier | 2.5x | Industry research on AI coding assistants (30-60% productivity gain) |
| Hourly Rate | $75/hour | Configurable via `DEV_TRACKER_HOURLY_RATE` env var |

### Example Calculation

**Monthly Report Example:**

| Metric | Value |
|--------|-------|
| Input: Dev Hours (with AI) | 40 hours |
| Multiplier | 2.5x |
| Estimated Manual Hours | 40 × 2.5 = **100 hours** |
| Time Saved | 100 - 40 = **60 hours** |
| Hourly Rate | $75/hour |
| Cost Savings | 60 × $75 = **$4,500** |

### Why 2.5x Multiplier?

The 2.5x multiplier is based on multiple industry studies:

- **GitHub Copilot Study (2022):** Developers completed tasks 55% faster with AI assistance
- **McKinsey Report (2023):** AI tools can improve developer productivity by 30-50%
- **Google Internal Study:** Code generation tools reduced time-to-completion by 40%

The 2.5x multiplier (150% time savings) is a *conservative* estimate that accounts for:
- Time spent reviewing AI-generated code
- Context switching overhead
- Tasks where AI provides less benefit

### Adjusting the Multiplier

You can adjust the multiplier in the dashboard's ROI Calculator panel based on your experience:

- **2.0x** - Conservative (tasks with significant manual oversight needed)
- **2.5x** - Balanced (general development work)
- **3.0x** - Optimistic (routine/boilerplate-heavy tasks)
- **4.0x+** - High-automation (bulk refactoring, code generation)

---

## 6. MCP Server Tools

The MCP (Model Context Protocol) server exposes tools that Claude Code can use to interact with your tracking data and external services.

### Analytics Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_dev_stats` | Get development statistics for a time period | days (default: 7) |
| `get_recent_commits` | List recent commits with diff stats | limit (default: 20) |
| `generate_roi_report` | Generate a formatted ROI report | days (default: 30) |

### Project Management Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `list_roadmap_projects` | List all projects from Roadmap API | none |
| `get_project_details` | Get details for a specific project | identifier (api_key or name) |
| `link_repo_to_project` | Link current repo to a Roadmap project | project_api_key, project_name, auto_push |
| `get_linked_projects` | Show all repo-to-project mappings | none |

### Update Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `push_project_update` | Push a status update to Roadmap | project_identifier, notes, status |
| `push_commit_to_roadmap` | Sync a specific commit to Roadmap | commit_hash |

### Session Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `log_session_start` | Manually start a tracking session | none |
| `log_session_end` | Manually end a tracking session | none |

### Example Usage in Claude Code

```
# Ask Claude to show your stats
"Show me my development stats for the last 14 days"

# Generate an ROI report
"Generate an ROI report for this month"

# Push an update to Roadmap
"Push an update to the Canvas Editor project: Completed zoom controls feature"

# Link current repo
"Link this repository to the Marketing Dashboard project"
```

---

## 7. Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ROADMAP_API_TOKEN` | Yes* | - | 64-character API token for Roadmap integration |
| `DEV_TRACKER_DB` | No | ~/dev-tracker/dev_tracker.db | Path to SQLite database file |
| `DEV_TRACKER_LOG` | No | ~/dev-tracker/tracker.log | Path to log file for debugging |
| `DEV_TRACKER_HOURLY_RATE` | No | 75 | Hourly rate ($) for ROI calculations |
| `GITHUB_TOKEN` | No | - | GitHub PAT for fetching repo data in dashboard |

*Required only for Roadmap API integration features

### File Locations

| File | Location | Purpose |
|------|----------|---------|
| Claude Hooks Config | `~/.claude/hooks.json` | Hook definitions for Claude Code |
| MCP Config | `~/.claude/config.json` | MCP server configuration |
| Database | `~/dev-tracker/dev_tracker.db` | SQLite database |
| Track Script | `~/dev-tracker/hooks/track.sh` | Main tracking script |
| MCP Server | `~/dev-tracker/server.py` | MCP server for Claude Code tools |

---

## 8. Troubleshooting

### Hooks not firing

**Symptom:** No data being recorded in the database

**Solution:**
1. Verify hooks.json exists: `cat ~/.claude/hooks.json`
2. Check track.sh is executable: `ls -la ~/dev-tracker/hooks/track.sh`
3. Test manually: `~/dev-tracker/hooks/track.sh start`
4. Check logs: `tail -f ~/dev-tracker/tracker.log`

### Database errors

**Symptom:** "no such table" or database locked errors

**Solution:**
1. Reinitialize database: `sqlite3 ~/dev-tracker/dev_tracker.db < ~/dev-tracker/schema.sql`
2. Check permissions: `ls -la ~/dev-tracker/dev_tracker.db`
3. Verify no other processes: `lsof ~/dev-tracker/dev_tracker.db`

### MCP server not connecting

**Symptom:** Claude Code can't find dev-tracker tools

**Solution:**
1. Verify config.json is correct: `cat ~/.claude/config.json`
2. Test server directly: `python3 ~/dev-tracker/server.py`
3. Check Python dependencies: `pip3 install mcp httpx`
4. Restart Claude Code

### Roadmap API errors

**Symptom:** "401 Unauthorized" or "Token not set" errors

**Solution:**
1. Verify token is set: `echo $ROADMAP_API_TOKEN`
2. Check token length (should be 64 characters)
3. Test API directly: `curl -H "Authorization: Bearer $ROADMAP_API_TOKEN" https://feedback.edwinlovett.com/roadmap/api/v1/projects`

### macOS: md5sum not found

**Symptom:** Session IDs fail to generate on macOS

**Solution:** The latest track.sh automatically detects and uses `md5` on macOS. If you have an older version, update from the repository.

### Dashboard shows no data

**Symptom:** Dashboard loads but all values show "--"

**Solution:**
1. Make sure you're in "Demo Data" mode for testing
2. For live data, ensure data_collector.py has run: `python3 ~/dev-tracker/demo/data_collector.py`
3. Check browser console for JavaScript errors (F12)

---

## Links

- **GitHub Repository:** https://github.com/edwinlov3tt/dev-tracker
- **Dashboard:** http://localhost:8080

---

*Development Tracker - Built for tracking AI-assisted development with Claude Code*
