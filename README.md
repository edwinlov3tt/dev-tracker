# Development Tracker

> 📊 Track your AI-assisted development time, commits, and automatically push updates to your Roadmap

## The Pitch

As a "vibe coder" leveraging AI extensively, you need to quantify your productivity gains for leadership. This system:

1. **Tracks development sessions** via Claude Code hooks
2. **Logs all commits** with time-between-commit analysis
3. **Connects to your Roadmap API** for automatic updates
4. **Generates ROI reports** showing time savings

### Key Metrics Tracked

| Metric | Formula | Why It Matters |
|--------|---------|----------------|
| Dev Hours | `session_end - session_start` | Total time in Claude Code |
| Active Coding | `Σ(tool_end - tool_start)` | Time Claude was actually working |
| Efficiency | `active_time / dev_hours × 100` | How much is productive vs idle |
| Commit Velocity | `commits / dev_hours` | Output rate |
| Time Between Commits | `commit[i].ts - commit[i-1].ts` | Development rhythm |
| Time Saved | `dev_hours × (2.5 - 1)` | Estimated manual hours saved |
| Cost Savings | `time_saved × hourly_rate` | Dollar value of AI assistance |

---

## Quick Start

```bash
# 1. Run setup
chmod +x ~/dev-tracker/setup.sh
~/dev-tracker/setup.sh

# 2. Set your API token
export ROADMAP_API_TOKEN='your_token_here'

# 3. Add MCP server to Claude Code
# Copy contents of mcp_config.json to your Claude settings

# 4. Link a repo to a project
~/dev-tracker/hooks/track.sh link 'project-api-key' 'Project Name'

# 5. Install git hook
cp ~/dev-tracker/hooks/post-commit /path/to/repo/.git/hooks/
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT TRACKER                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Claude Code Hooks          Git Hooks          MCP Server        │
│  ┌─────────────┐           ┌──────────┐       ┌──────────────┐  │
│  │ PreToolUse  │──────────▶│          │       │              │  │
│  │ PostToolUse │──────────▶│ track.sh │──────▶│ dev_tracker  │  │
│  │ Stop        │──────────▶│          │       │    .db       │  │
│  └─────────────┘           └──────────┘       └──────┬───────┘  │
│                                                       │          │
│                            ┌──────────┐               │          │
│                            │ post-    │───────────────┘          │
│                            │ commit   │                          │
│                            └──────────┘                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    MCP Server (Python)                       ││
│  │                                                              ││
│  │  Tools:                                                      ││
│  │  • list_roadmap_projects      • get_dev_stats                ││
│  │  • get_project_details        • get_recent_commits           ││
│  │  • push_project_update        • link_repo_to_project         ││
│  │  • generate_roi_report        • push_commit_to_roadmap       ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│                              ▼                                   │
│                    ┌──────────────────┐                         │
│                    │   Roadmap API    │                         │
│                    │ feedback.edwin   │                         │
│                    │ lovett.com       │                         │
│                    └──────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Claude Code Hooks (`claude_hooks.json`)

Automatically tracks when Claude uses tools:

```json
{
  "hooks": {
    "PreToolUse": [{ "command": "track.sh tool_start $TOOL_NAME" }],
    "PostToolUse": [{ "command": "track.sh tool_end $TOOL_NAME $EXIT_CODE" }],
    "Stop": [{ "command": "track.sh end" }]
  }
}
```

### 2. Tracking Script (`hooks/track.sh`)

Bash script that logs events to SQLite:

```bash
# Start a session
./track.sh start

# Log a commit
./track.sh commit

# View stats
./track.sh stats /path/to/repo 7
```

### 3. MCP Server (`server.py`)

Python server that Claude can use to:

- List and manage Roadmap projects
- Push updates automatically
- Generate ROI reports
- View development stats

### 4. SQLite Database

Tables:
- `sessions` - Claude Code working sessions
- `tool_events` - Individual tool usage
- `commits` - Git commits with stats
- `project_mappings` - Repo-to-project links
- `daily_summaries` - Aggregated metrics

---

## MCP Tools Reference

### Project Management

| Tool | Description |
|------|-------------|
| `list_roadmap_projects` | List all projects from Roadmap API |
| `get_project_details` | Get details for a specific project |
| `link_repo_to_project` | Link a git repo to a Roadmap project |
| `get_linked_projects` | Show all repo-project mappings |

### Updates & Sync

| Tool | Description |
|------|-------------|
| `push_project_update` | Push an update to a project |
| `push_commit_to_roadmap` | Push a specific commit as an update |

### Analytics

| Tool | Description |
|------|-------------|
| `get_dev_stats` | Get development statistics |
| `get_recent_commits` | List commits with time gaps |
| `generate_roi_report` | Generate ROI report for leadership |

### Session Management

| Tool | Description |
|------|-------------|
| `log_session_start` | Manually start a session |
| `log_session_end` | Manually end a session |

---

## Example Workflows

### Auto-Update on Significant Progress

Tell Claude:
> "Hey Claude, I just finished the authentication module. Push an update to the GTM Helper project noting that auth is complete and we're moving to the tracking implementation."

Claude will use `push_project_update` to add this to your Roadmap.

### Weekly ROI Report

Tell Claude:
> "Generate an ROI report for the last 30 days that I can share with leadership."

Claude will use `generate_roi_report` to produce a formatted report with time savings and cost calculations.

### Link a New Project

Tell Claude:
> "Link this repo to the 'Canvas Editor' project on the roadmap. The API key is abc123-def456."

Claude will use `link_repo_to_project` to create the mapping.

---

## Configuration

### Environment Variables

```bash
# Required
export ROADMAP_API_TOKEN='your_64_char_token'

# Optional
export DEV_TRACKER_DB="$HOME/dev-tracker/dev_tracker.db"
export DEV_TRACKER_LOG="$HOME/dev-tracker/tracker.log"
```

### Claude Code Settings

Add to your Claude Code MCP configuration:

```json
{
  "mcpServers": {
    "dev-tracker": {
      "command": "python3",
      "args": ["/Users/edwinlovettiii/dev-tracker/server.py"],
      "env": {
        "ROADMAP_API_TOKEN": "${ROADMAP_API_TOKEN}"
      }
    }
  }
}
```

---

## ROI Calculations

### Formula Breakdown

```
┌─────────────────────────────────────────────────────────────────┐
│ TIME SAVED                                                      │
│                                                                  │
│   Estimated Manual Hours = Dev Hours × Manual Multiplier        │
│   Time Saved = Estimated Manual Hours - Actual Dev Hours        │
│                                                                  │
│   Example:                                                       │
│   - 40 hours of AI-assisted dev                                  │
│   - Manual Multiplier: 2.5x                                      │
│   - Estimated Manual: 40 × 2.5 = 100 hours                       │
│   - Time Saved: 100 - 40 = 60 hours                              │
├─────────────────────────────────────────────────────────────────┤
│ COST SAVINGS                                                     │
│                                                                  │
│   Cost Savings = Time Saved × Hourly Rate                        │
│                                                                  │
│   Example:                                                       │
│   - Time Saved: 60 hours                                         │
│   - Hourly Rate: $75                                             │
│   - Cost Savings: 60 × $75 = $4,500/month                        │
├─────────────────────────────────────────────────────────────────┤
│ VELOCITY METRICS                                                 │
│                                                                  │
│   Commits per Hour = Total Commits / Dev Hours                   │
│   Lines per Hour = (Insertions + Deletions) / Dev Hours          │
│   Avg Commit Gap = Σ(commit_gaps) / (commits - 1)               │
│   Efficiency = Active Coding Time / Total Dev Time × 100         │
└─────────────────────────────────────────────────────────────────┘
```

### Industry Benchmarks

| Metric | Traditional Dev | AI-Assisted | Your Target |
|--------|-----------------|-------------|-------------|
| Commits/Hour | 0.5-1.0 | 2-4 | Track yours! |
| Lines/Hour | 50-100 | 200-500 | Track yours! |
| Time to Feature | Baseline | 40-60% faster | Measure it! |

---

## Troubleshooting

### Hooks not firing

```bash
# Check Claude hooks config
cat ~/.claude/hooks.json

# Test hook script manually
~/dev-tracker/hooks/track.sh start
~/dev-tracker/hooks/track.sh stats
```

### Database issues

```bash
# Reinitialize database
rm ~/dev-tracker/dev_tracker.db
sqlite3 ~/dev-tracker/dev_tracker.db < ~/dev-tracker/schema.sql
```

### MCP server not connecting

```bash
# Test server directly
python3 ~/dev-tracker/server.py

# Check for Python dependencies
pip3 install -r ~/dev-tracker/requirements.txt
```

---

## License

MIT - Built for Edwin Lovett's marketing tech workflow.
