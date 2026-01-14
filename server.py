#!/usr/bin/env python3
"""
Development Tracker MCP Server
Integrates Claude Code time tracking with the Roadmap API

This MCP server provides tools for:
- Tracking development sessions and commits
- Viewing productivity metrics
- Pushing updates to the Roadmap API
- Managing project-repo mappings
"""

import os
import json
import sqlite3
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
import httpx
from mcp.server import Server
from mcp.types import Tool, TextContent
from pydantic import BaseModel

# Configuration
DB_PATH = os.environ.get("DEV_TRACKER_DB", Path.home() / "dev-tracker" / "dev_tracker.db")
ROADMAP_API_BASE = "https://feedback.edwinlovett.com/roadmap/api/v1"
ROADMAP_API_TOKEN = os.environ.get("ROADMAP_API_TOKEN", "")
HOURLY_RATE = float(os.environ.get("DEV_TRACKER_HOURLY_RATE", "75"))

# Initialize MCP server
server = Server("dev-tracker")


def get_db_connection():
    """Get SQLite database connection"""
    return sqlite3.connect(DB_PATH)


def dict_factory(cursor, row):
    """Convert SQLite rows to dictionaries"""
    return {col[0]: row[idx] for idx, col in enumerate(cursor.description)}


def query_db(sql: str, params: tuple = ()) -> list:
    """Execute a query and return results as list of dicts"""
    conn = get_db_connection()
    conn.row_factory = dict_factory
    cursor = conn.cursor()
    cursor.execute(sql, params)
    results = cursor.fetchall()
    conn.close()
    return results


def execute_db(sql: str, params: tuple = ()) -> int:
    """Execute a write query and return last row id"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(sql, params)
    conn.commit()
    last_id = cursor.lastrowid
    conn.close()
    return last_id


async def call_roadmap_api(method: str, endpoint: str, data: dict = None) -> dict:
    """Make a request to the Roadmap API"""
    if not ROADMAP_API_TOKEN:
        return {"error": "ROADMAP_API_TOKEN not set"}
    
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
        else:
            return {"error": f"Unsupported method: {method}"}
        
        return response.json()


# =============================================================================
# MCP Tools
# =============================================================================

@server.tool()
async def list_roadmap_projects() -> list[TextContent]:
    """
    List all projects from the Roadmap API.
    Returns project names, API keys, status, and update counts.
    """
    result = await call_roadmap_api("GET", "/projects")
    
    if "error" in result:
        return [TextContent(type="text", text=f"Error: {result['error']}")]
    
    projects = result.get("projects", [])
    
    output = "# Roadmap Projects\n\n"
    output += f"Total: {len(projects)} projects\n\n"
    output += "| Project | Status | Version | Updates | API Key |\n"
    output += "|---------|--------|---------|---------|----------|\n"
    
    for p in projects:
        output += f"| {p['name']} | {p['status']} | {p.get('current_version', '-')} | {p.get('update_count', 0)} | `{p['api_key'][:8]}...` |\n"
    
    return [TextContent(type="text", text=output)]


@server.tool()
async def get_project_details(identifier: str) -> list[TextContent]:
    """
    Get detailed information about a specific project.
    
    Args:
        identifier: Project API key or exact project name
    """
    result = await call_roadmap_api("GET", f"/projects/{identifier}")
    
    if "error" in result:
        return [TextContent(type="text", text=f"Error: {result['error']}")]
    
    project = result.get("project", {})
    
    output = f"# {project['name']}\n\n"
    output += f"**Status:** {project['status']}\n"
    output += f"**Version:** {project.get('current_version', 'N/A')}\n"
    output += f"**API Key:** `{project['api_key']}`\n\n"
    output += f"**Description:** {project.get('description', 'N/A')}\n\n"
    
    updates = project.get("updates", [])
    if updates:
        output += "## Recent Updates\n\n"
        for update in updates[:5]:
            date = update.get("update_date", update.get("created_at", ""))[:10]
            notes = update.get("raw_notes", "No notes")
            output += f"- **{date}** [{update.get('status', 'N/A')}]: {notes[:100]}...\n"
    
    return [TextContent(type="text", text=output)]


@server.tool()
async def push_project_update(
    project_identifier: str,
    notes: str,
    status: str = "In Progress"
) -> list[TextContent]:
    """
    Push an update to a project on the Roadmap.
    
    Args:
        project_identifier: Project API key or name
        notes: Update notes (can be multi-line with \\n)
        status: Update status (In Progress, Completed, etc.)
    """
    data = {
        "notes": notes,
        "status": status,
        "update_date": datetime.utcnow().isoformat() + "Z"
    }
    
    result = await call_roadmap_api("POST", f"/projects/{project_identifier}/updates", data)
    
    if "error" in result:
        return [TextContent(type="text", text=f"Error: {result['error']}")]
    
    # Log to sync table
    execute_db(
        "INSERT INTO roadmap_sync_log (project_api_key, sync_type, payload, response_status) VALUES (?, ?, ?, ?)",
        (project_identifier, "update", json.dumps(data), 200)
    )
    
    output = f"✅ Update pushed to **{result.get('project_name', project_identifier)}**\n\n"
    output += f"- Status: {status}\n"
    output += f"- Notes: {notes}\n"
    output += f"- Update ID: {result.get('update', {}).get('id', 'N/A')}"
    
    return [TextContent(type="text", text=output)]


@server.tool()
async def get_dev_stats(
    repo_path: Optional[str] = None,
    days: int = 7
) -> list[TextContent]:
    """
    Get development statistics for a repository.
    
    Args:
        repo_path: Path to git repo (defaults to current directory)
        days: Number of days to look back (default 7)
    """
    if repo_path is None:
        repo_path = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True
        ).stdout.strip() or os.getcwd()
    
    # Get daily summaries
    summaries = query_db("""
        SELECT * FROM daily_summaries 
        WHERE repo_path = ? AND date >= date('now', ?)
        ORDER BY date DESC
    """, (repo_path, f"-{days} days"))
    
    # Get totals
    totals = query_db("""
        SELECT 
            SUM(total_dev_hours) as total_hours,
            SUM(active_coding_hours) as active_hours,
            SUM(total_commits) as commits,
            SUM(total_insertions) as insertions,
            SUM(total_deletions) as deletions,
            AVG(commits_per_hour) as avg_commits_hr,
            AVG(lines_per_hour) as avg_lines_hr
        FROM daily_summaries 
        WHERE repo_path = ? AND date >= date('now', ?)
    """, (repo_path, f"-{days} days"))
    
    t = totals[0] if totals else {}
    
    output = f"# Development Stats\n\n"
    output += f"**Repository:** `{repo_path}`\n"
    output += f"**Period:** Last {days} days\n\n"
    
    output += "## Totals\n\n"
    output += f"- **Dev Hours:** {t.get('total_hours', 0):.2f}\n"
    output += f"- **Active Coding:** {t.get('active_hours', 0):.2f}\n"
    output += f"- **Efficiency:** {(t.get('active_hours', 0) / max(t.get('total_hours', 1), 0.01) * 100):.1f}%\n"
    output += f"- **Commits:** {t.get('commits', 0)}\n"
    output += f"- **Lines Changed:** +{t.get('insertions', 0)} / -{t.get('deletions', 0)}\n"
    output += f"- **Avg Commits/Hour:** {t.get('avg_commits_hr', 0):.2f}\n"
    output += f"- **Avg Lines/Hour:** {t.get('avg_lines_hr', 0):.0f}\n\n"
    
    if summaries:
        output += "## Daily Breakdown\n\n"
        output += "| Date | Hours | Active | Commits | +/- | Commits/Hr |\n"
        output += "|------|-------|--------|---------|-----|------------|\n"
        for s in summaries:
            output += f"| {s['date']} | {s['total_dev_hours']:.1f} | {s['active_coding_hours']:.1f} | {s['total_commits']} | +{s['total_insertions']}/-{s['total_deletions']} | {s['commits_per_hour']:.2f} |\n"
    
    return [TextContent(type="text", text=output)]


@server.tool()
async def get_recent_commits(
    repo_path: Optional[str] = None,
    limit: int = 10
) -> list[TextContent]:
    """
    Get recent commits with time gaps analysis.
    
    Args:
        repo_path: Path to git repo
        limit: Number of commits to show
    """
    if repo_path is None:
        repo_path = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True
        ).stdout.strip() or os.getcwd()
    
    commits = query_db("""
        SELECT 
            commit_hash,
            message,
            datetime(timestamp, 'unixepoch') as commit_time,
            insertions,
            deletions,
            pushed_to_roadmap
        FROM commits 
        WHERE repo_path = ?
        ORDER BY timestamp DESC
        LIMIT ?
    """, (repo_path, limit))
    
    gaps = query_db("""
        SELECT 
            commit_hash,
            gap_minutes
        FROM v_commit_gaps
        WHERE repo_path = ?
        ORDER BY commit_time DESC
        LIMIT ?
    """, (repo_path, limit))
    
    gap_map = {g['commit_hash']: g['gap_minutes'] for g in gaps}
    
    output = f"# Recent Commits\n\n"
    output += f"**Repository:** `{repo_path}`\n\n"
    
    output += "| Time | Message | Changes | Gap | Synced |\n"
    output += "|------|---------|---------|-----|--------|\n"
    
    for c in commits:
        gap = gap_map.get(c['commit_hash'])
        gap_str = f"{gap:.0f}m" if gap else "-"
        synced = "✅" if c['pushed_to_roadmap'] else "❌"
        msg = c['message'][:40] + "..." if len(c['message']) > 40 else c['message']
        output += f"| {c['commit_time']} | {msg} | +{c['insertions']}/-{c['deletions']} | {gap_str} | {synced} |\n"
    
    return [TextContent(type="text", text=output)]


@server.tool()
async def link_repo_to_project(
    project_api_key: str,
    project_name: str,
    repo_path: Optional[str] = None,
    auto_push: bool = True
) -> list[TextContent]:
    """
    Link a git repository to a Roadmap project for automatic updates.
    
    Args:
        project_api_key: The project's API key from the Roadmap
        project_name: Human-readable project name
        repo_path: Path to the git repo (defaults to current directory)
        auto_push: Whether to auto-push updates on commits
    """
    if repo_path is None:
        repo_path = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True
        ).stdout.strip() or os.getcwd()
    
    execute_db("""
        INSERT OR REPLACE INTO project_mappings 
        (repo_path, project_api_key, project_name, auto_push_updates)
        VALUES (?, ?, ?, ?)
    """, (repo_path, project_api_key, project_name, 1 if auto_push else 0))
    
    output = f"✅ Linked repository to project\n\n"
    output += f"- **Repository:** `{repo_path}`\n"
    output += f"- **Project:** {project_name}\n"
    output += f"- **API Key:** `{project_api_key}`\n"
    output += f"- **Auto-push:** {'Enabled' if auto_push else 'Disabled'}"
    
    return [TextContent(type="text", text=output)]


@server.tool()
async def get_linked_projects() -> list[TextContent]:
    """
    Show all repository-to-project mappings.
    """
    mappings = query_db("SELECT * FROM project_mappings ORDER BY created_at DESC")
    
    if not mappings:
        return [TextContent(type="text", text="No projects linked yet. Use `link_repo_to_project` to link a repo.")]
    
    output = "# Linked Projects\n\n"
    output += "| Repository | Project | Auto-Push | API Key |\n"
    output += "|------------|---------|-----------|----------|\n"
    
    for m in mappings:
        auto = "✅" if m['auto_push_updates'] else "❌"
        output += f"| `{m['repo_path']}` | {m['project_name']} | {auto} | `{m['project_api_key'][:8]}...` |\n"
    
    return [TextContent(type="text", text=output)]


@server.tool()
async def log_session_start(repo_path: Optional[str] = None) -> list[TextContent]:
    """
    Manually start tracking a development session.
    Usually called automatically by Claude Code hooks.
    
    Args:
        repo_path: Path to the repository
    """
    if repo_path is None:
        repo_path = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True
        ).stdout.strip() or os.getcwd()
    
    session_id = f"session_{datetime.now().strftime('%Y%m%d')}_{hash(repo_path) % 100000000:08x}"
    ts = int(datetime.now().timestamp())
    
    # Get project mapping
    mappings = query_db("SELECT project_api_key FROM project_mappings WHERE repo_path = ?", (repo_path,))
    project_key = mappings[0]['project_api_key'] if mappings else None
    
    execute_db("""
        INSERT OR IGNORE INTO sessions (session_id, repo_path, project_api_key, started_at, status)
        VALUES (?, ?, ?, ?, 'active')
    """, (session_id, repo_path, project_key, ts))
    
    return [TextContent(type="text", text=f"✅ Session started: `{session_id}`")]


@server.tool()
async def log_session_end(session_id: Optional[str] = None) -> list[TextContent]:
    """
    Manually end a development session.
    Usually called automatically by Claude Code hooks.
    
    Args:
        session_id: Optional session ID (defaults to most recent)
    """
    ts = int(datetime.now().timestamp())
    
    if session_id:
        execute_db("""
            UPDATE sessions SET ended_at = ?, status = 'completed'
            WHERE session_id = ? AND ended_at IS NULL
        """, (ts, session_id))
    else:
        execute_db("""
            UPDATE sessions SET ended_at = ?, status = 'completed'
            WHERE ended_at IS NULL
            ORDER BY started_at DESC LIMIT 1
        """, (ts,))
    
    return [TextContent(type="text", text=f"✅ Session ended")]


@server.tool()
async def generate_roi_report(days: int = 30) -> list[TextContent]:
    """
    Generate an ROI report for leadership showing time savings and productivity.
    
    Args:
        days: Number of days to analyze
    """
    # Get aggregated stats
    stats = query_db("""
        SELECT 
            pm.project_name,
            SUM(ds.total_dev_hours) as dev_hours,
            SUM(ds.active_coding_hours) as active_hours,
            SUM(ds.total_commits) as commits,
            SUM(ds.total_insertions + ds.total_deletions) as lines_changed,
            AVG(ds.commits_per_hour) as velocity
        FROM daily_summaries ds
        LEFT JOIN project_mappings pm ON ds.project_api_key = pm.project_api_key
        WHERE ds.date >= date('now', ?)
        GROUP BY pm.project_name
        ORDER BY dev_hours DESC
    """, (f"-{days} days",))
    
    totals = query_db("""
        SELECT 
            SUM(total_dev_hours) as total_hours,
            SUM(total_commits) as total_commits,
            SUM(total_insertions + total_deletions) as total_lines
        FROM daily_summaries
        WHERE date >= date('now', ?)
    """, (f"-{days} days",))
    
    t = totals[0] if totals else {}
    
    # Assumptions for ROI calculation (HOURLY_RATE from config/env)
    MANUAL_MULTIPLIER = 2.5  # How much longer it would take without AI
    
    total_hours = t.get('total_hours', 0) or 0
    estimated_manual_hours = total_hours * MANUAL_MULTIPLIER
    time_saved = estimated_manual_hours - total_hours
    cost_savings = time_saved * HOURLY_RATE
    
    output = f"# AI Development ROI Report\n\n"
    output += f"**Period:** Last {days} days\n"
    output += f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n"
    
    output += "## Executive Summary\n\n"
    output += f"- **Total Dev Hours with AI:** {total_hours:.1f} hours\n"
    output += f"- **Estimated Manual Hours:** {estimated_manual_hours:.1f} hours\n"
    output += f"- **Time Saved:** {time_saved:.1f} hours\n"
    output += f"- **Cost Savings:** ${cost_savings:,.2f}\n"
    output += f"- **Efficiency Gain:** {((MANUAL_MULTIPLIER - 1) * 100):.0f}%\n\n"
    
    output += "## Productivity Metrics\n\n"
    output += f"- **Total Commits:** {t.get('total_commits', 0)}\n"
    output += f"- **Lines of Code Changed:** {t.get('total_lines', 0):,}\n"
    output += f"- **Commits per Hour:** {(t.get('total_commits', 0) / max(total_hours, 1)):.2f}\n\n"
    
    if stats:
        output += "## By Project\n\n"
        output += "| Project | Hours | Commits | Lines | Velocity |\n"
        output += "|---------|-------|---------|-------|----------|\n"
        for s in stats:
            name = s['project_name'] or 'Unlinked'
            output += f"| {name} | {s['dev_hours']:.1f} | {s['commits']} | {s['lines_changed']:,} | {s['velocity']:.2f}/hr |\n"
    
    output += "\n## Formulas Used\n\n"
    output += "```\n"
    output += "Time Saved = (Dev Hours × Manual Multiplier) - Dev Hours\n"
    output += "Cost Savings = Time Saved × Hourly Rate\n"
    output += f"Manual Multiplier = {MANUAL_MULTIPLIER}x (industry standard for AI-assisted development)\n"
    output += f"Hourly Rate = ${HOURLY_RATE}\n"
    output += "```"
    
    return [TextContent(type="text", text=output)]


@server.tool()
async def push_commit_to_roadmap(
    commit_hash: Optional[str] = None,
    include_stats: bool = True
) -> list[TextContent]:
    """
    Push a specific commit as an update to the linked Roadmap project.
    
    Args:
        commit_hash: Git commit hash (defaults to HEAD)
        include_stats: Include line change stats in the update
    """
    # Get commit from DB or git
    if commit_hash:
        commits = query_db("SELECT * FROM commits WHERE commit_hash = ?", (commit_hash,))
    else:
        commits = query_db("SELECT * FROM commits ORDER BY timestamp DESC LIMIT 1")
    
    if not commits:
        return [TextContent(type="text", text="❌ No commits found")]
    
    commit = commits[0]
    project_key = commit.get('project_api_key')
    
    if not project_key:
        return [TextContent(type="text", text="❌ This commit's repo is not linked to a project. Use `link_repo_to_project` first.")]
    
    notes = commit['message']
    if include_stats:
        notes += f"\n\n+{commit['insertions']} / -{commit['deletions']} lines changed"
    
    result = await call_roadmap_api("POST", f"/projects/{project_key}/updates", {
        "notes": notes,
        "status": "In Progress"
    })
    
    if "error" in result:
        return [TextContent(type="text", text=f"❌ Error: {result['error']}")]
    
    # Mark as pushed
    execute_db("UPDATE commits SET pushed_to_roadmap = 1 WHERE commit_hash = ?", (commit['commit_hash'],))
    
    return [TextContent(type="text", text=f"✅ Pushed commit `{commit['commit_hash'][:8]}` to {result.get('project_name', 'project')}")]


# =============================================================================
# Server Entry Point
# =============================================================================

if __name__ == "__main__":
    import asyncio
    from mcp.server.stdio import stdio_server
    
    async def main():
        async with stdio_server() as (read_stream, write_stream):
            await server.run(read_stream, write_stream, server.create_initialization_options())
    
    asyncio.run(main())
