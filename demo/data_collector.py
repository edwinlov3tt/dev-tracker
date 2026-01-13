#!/usr/bin/env python3
"""
Data Collector for Development Tracker Dashboard
Aggregates data from SQLite, GitHub API, and Roadmap API
"""

import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
import httpx

from config import (
    GITHUB_TOKEN, GITHUB_API_BASE, GITHUB_USERNAME,
    ROADMAP_API_TOKEN, ROADMAP_API_BASE,
    DB_PATH, DEFAULT_HOURLY_RATE, DEFAULT_MULTIPLIER,
    DEFAULT_DAYS, REPO_ACTIVITY_DAYS
)


def get_db_connection():
    """Get SQLite database connection"""
    if not Path(DB_PATH).exists():
        return None
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def query_db(sql: str, params: tuple = ()) -> list:
    """Execute a query and return results as list of dicts"""
    conn = get_db_connection()
    if not conn:
        return []
    cursor = conn.cursor()
    cursor.execute(sql, params)
    results = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return results


# =============================================================================
# SQLite Data Functions
# =============================================================================

def get_sqlite_stats(days: int = DEFAULT_DAYS) -> dict:
    """Get development statistics from local SQLite database"""

    # Get daily summaries
    daily = query_db("""
        SELECT
            date,
            SUM(total_dev_hours) as hours,
            SUM(active_coding_hours) as active_hours,
            SUM(total_commits) as commits,
            SUM(total_insertions) as insertions,
            SUM(total_deletions) as deletions,
            AVG(commits_per_hour) as commits_per_hour,
            AVG(lines_per_hour) as lines_per_hour
        FROM daily_summaries
        WHERE date >= date('now', ?)
        GROUP BY date
        ORDER BY date DESC
    """, (f"-{days} days",))

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
        WHERE date >= date('now', ?)
    """, (f"-{days} days",))

    # Get recent commits from local DB
    commits = query_db("""
        SELECT
            commit_hash,
            repo_path,
            message,
            author,
            datetime(timestamp, 'unixepoch') as timestamp,
            insertions,
            deletions,
            branch,
            pushed_to_roadmap
        FROM commits
        WHERE timestamp >= strftime('%s', 'now', ?)
        ORDER BY timestamp DESC
        LIMIT 50
    """, (f"-{days} days",))

    # Get commit gaps
    gaps = query_db("""
        SELECT
            commit_hash,
            gap_minutes
        FROM v_commit_gaps
        WHERE commit_time >= strftime('%s', 'now', ?)
        ORDER BY commit_time DESC
    """, (f"-{days} days",))

    gap_map = {g['commit_hash']: g['gap_minutes'] for g in gaps}

    # Add gap info to commits
    for c in commits:
        c['gap_minutes'] = gap_map.get(c['commit_hash'])
        # Extract repo name from path
        if c['repo_path']:
            c['repo'] = Path(c['repo_path']).name
        else:
            c['repo'] = 'unknown'

    # Get project mappings
    mappings = query_db("""
        SELECT
            repo_path,
            project_api_key,
            project_name,
            auto_push_updates
        FROM project_mappings
    """)

    # Get active sessions
    active = query_db("""
        SELECT COUNT(*) as count
        FROM sessions
        WHERE status = 'active'
    """)

    t = totals[0] if totals else {}

    return {
        "daily_activity": [
            {
                "date": d['date'],
                "hours": round(d['hours'] or 0, 2),
                "active_hours": round(d['active_hours'] or 0, 2),
                "commits": d['commits'] or 0,
                "lines_changed": (d['insertions'] or 0) + (d['deletions'] or 0)
            }
            for d in daily
        ],
        "totals": {
            "total_hours": round(t.get('total_hours') or 0, 2),
            "active_hours": round(t.get('active_hours') or 0, 2),
            "commits": t.get('commits') or 0,
            "insertions": t.get('insertions') or 0,
            "deletions": t.get('deletions') or 0,
            "avg_commits_hr": round(t.get('avg_commits_hr') or 0, 2),
            "avg_lines_hr": round(t.get('avg_lines_hr') or 0, 0)
        },
        "commits": commits,
        "project_mappings": [
            {
                "repo_path": m['repo_path'],
                "repo": Path(m['repo_path']).name if m['repo_path'] else 'unknown',
                "project_name": m['project_name'],
                "project_api_key": m['project_api_key'],
                "auto_push": bool(m['auto_push_updates'])
            }
            for m in mappings
        ],
        "active_sessions": active[0]['count'] if active else 0
    }


# =============================================================================
# GitHub API Functions
# =============================================================================

def github_request(endpoint: str) -> dict | list | None:
    """Make a request to the GitHub API"""
    if not GITHUB_TOKEN:
        return None

    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }

    try:
        response = httpx.get(
            f"{GITHUB_API_BASE}{endpoint}",
            headers=headers,
            timeout=30
        )
        if response.status_code == 200:
            return response.json()
        return None
    except Exception:
        return None


def get_github_repos() -> list:
    """Auto-discover repos from GitHub, filter to recently active"""
    repos = github_request(f"/users/{GITHUB_USERNAME}/repos?sort=pushed&per_page=100")

    if not repos:
        return []

    cutoff = datetime.utcnow() - timedelta(days=REPO_ACTIVITY_DAYS)
    active_repos = []

    for repo in repos:
        pushed_at = repo.get('pushed_at')
        if pushed_at:
            push_date = datetime.fromisoformat(pushed_at.replace('Z', '+00:00'))
            if push_date.replace(tzinfo=None) >= cutoff:
                active_repos.append({
                    "name": repo['name'],
                    "full_name": repo['full_name'],
                    "description": repo.get('description') or '',
                    "last_push": pushed_at,
                    "default_branch": repo.get('default_branch', 'main'),
                    "html_url": repo.get('html_url', ''),
                    "private": repo.get('private', False)
                })

    return active_repos


def get_github_commits(repos: list, days: int = DEFAULT_DAYS) -> list:
    """Fetch recent commits from GitHub repos"""
    if not GITHUB_TOKEN:
        return []

    since = (datetime.utcnow() - timedelta(days=days)).isoformat() + "Z"
    all_commits = []

    for repo in repos[:10]:  # Limit to 10 repos to avoid rate limits
        repo_name = repo['full_name'] if isinstance(repo, dict) else repo

        commits = github_request(
            f"/repos/{repo_name}/commits?since={since}&per_page=50"
        )

        if commits:
            for c in commits:
                # Get detailed commit info for stats
                detail = github_request(f"/repos/{repo_name}/commits/{c['sha']}")
                stats = detail.get('stats', {}) if detail else {}

                all_commits.append({
                    "hash": c['sha'][:8],
                    "full_hash": c['sha'],
                    "repo": repo_name.split('/')[-1],
                    "message": c['commit']['message'].split('\n')[0],
                    "timestamp": c['commit']['author']['date'],
                    "author": c['commit']['author']['name'],
                    "additions": stats.get('additions', 0),
                    "deletions": stats.get('deletions', 0)
                })

    # Sort by timestamp and calculate gaps
    all_commits.sort(key=lambda x: x['timestamp'], reverse=True)

    for i, commit in enumerate(all_commits):
        if i < len(all_commits) - 1:
            curr = datetime.fromisoformat(commit['timestamp'].replace('Z', '+00:00'))
            prev = datetime.fromisoformat(all_commits[i + 1]['timestamp'].replace('Z', '+00:00'))
            gap = (curr - prev).total_seconds() / 60
            commit['gap_minutes'] = round(gap, 1)
        else:
            commit['gap_minutes'] = None

    return all_commits[:50]


# =============================================================================
# Roadmap API Functions
# =============================================================================

def roadmap_request(method: str, endpoint: str, data: dict = None) -> dict | None:
    """Make a request to the Roadmap API"""
    if not ROADMAP_API_TOKEN:
        return None

    headers = {
        "Authorization": f"Bearer {ROADMAP_API_TOKEN}",
        "Content-Type": "application/json"
    }

    url = f"{ROADMAP_API_BASE}{endpoint}"

    try:
        if method == "GET":
            response = httpx.get(url, headers=headers, timeout=30)
        elif method == "POST":
            response = httpx.post(url, headers=headers, json=data, timeout=30)
        else:
            return None

        if response.status_code == 200:
            return response.json()
        return None
    except Exception:
        return None


def get_roadmap_projects() -> list:
    """Get all projects from Roadmap API"""
    result = roadmap_request("GET", "/projects")

    if not result:
        return []

    projects = result.get('projects', [])

    return [
        {
            "name": p['name'],
            "api_key": p['api_key'],
            "status": p.get('status', 'Unknown'),
            "current_version": p.get('current_version'),
            "update_count": p.get('update_count', 0),
            "description": p.get('description', '')
        }
        for p in projects
    ]


def get_roadmap_project_details(identifier: str) -> dict | None:
    """Get detailed info for a specific project"""
    result = roadmap_request("GET", f"/projects/{identifier}")

    if not result:
        return None

    project = result.get('project', {})
    updates = project.get('updates', [])

    return {
        "name": project.get('name'),
        "api_key": project.get('api_key'),
        "status": project.get('status'),
        "current_version": project.get('current_version'),
        "description": project.get('description'),
        "recent_updates": [
            {
                "date": u.get('update_date', u.get('created_at', ''))[:10],
                "status": u.get('status'),
                "notes": u.get('raw_notes', '')[:200]
            }
            for u in updates[:5]
        ]
    }


# =============================================================================
# ROI Calculation
# =============================================================================

def calculate_roi(
    dev_hours: float,
    hourly_rate: float = DEFAULT_HOURLY_RATE,
    multiplier: float = DEFAULT_MULTIPLIER
) -> dict:
    """Calculate ROI metrics"""
    estimated_manual = dev_hours * multiplier
    time_saved = estimated_manual - dev_hours
    cost_savings = time_saved * hourly_rate

    return {
        "dev_hours": round(dev_hours, 2),
        "multiplier": multiplier,
        "estimated_manual_hours": round(estimated_manual, 2),
        "time_saved": round(time_saved, 2),
        "hourly_rate": hourly_rate,
        "cost_savings": round(cost_savings, 2),
        "efficiency_gain_percent": round((multiplier - 1) * 100, 0)
    }


# =============================================================================
# Main Data Generation
# =============================================================================

def generate_dashboard_data(days: int = DEFAULT_DAYS) -> dict:
    """Generate complete dashboard data from all sources"""

    # Get SQLite data
    sqlite_data = get_sqlite_stats(days)

    # Get GitHub data
    github_repos = get_github_repos()
    github_commits = get_github_commits(github_repos, days) if github_repos else []

    # Get Roadmap data
    roadmap_projects = get_roadmap_projects()

    # Calculate totals - prefer SQLite, fallback to GitHub
    totals = sqlite_data['totals']
    if totals['total_hours'] == 0 and github_commits:
        # Estimate hours from commits (rough: 30 min per commit)
        totals['commits'] = len(github_commits)
        totals['total_hours'] = len(github_commits) * 0.5
        totals['insertions'] = sum(c.get('additions', 0) for c in github_commits)
        totals['deletions'] = sum(c.get('deletions', 0) for c in github_commits)

    # Calculate ROI
    roi = calculate_roi(totals['total_hours'])

    # Merge commits - prefer SQLite, add GitHub for additional context
    all_commits = sqlite_data['commits']
    if not all_commits:
        all_commits = github_commits

    # Add sync status to commits
    mapping_keys = {m['project_api_key'] for m in sqlite_data['project_mappings']}
    for commit in all_commits:
        commit['synced_to_roadmap'] = commit.get('pushed_to_roadmap', False)

    # Calculate commit velocity
    gaps = [c['gap_minutes'] for c in all_commits if c.get('gap_minutes')]
    avg_gap = sum(gaps) / len(gaps) if gaps else 0

    # Add repo counts to github_repos
    for repo in github_repos:
        repo['commit_count_30d'] = len([
            c for c in github_commits
            if c.get('repo') == repo['name']
        ])

    # Link roadmap projects to repos
    repo_project_map = {
        Path(m['repo_path']).name: m['project_name']
        for m in sqlite_data['project_mappings']
        if m['repo_path']
    }
    for project in roadmap_projects:
        project['linked_repo'] = next(
            (repo for repo, pname in repo_project_map.items()
             if pname == project['name']),
            None
        )

    data = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "data_mode": "live",
        "period_days": days,
        "summary": {
            "total_dev_hours": totals['total_hours'],
            "total_commits": totals['commits'],
            "total_lines_added": totals['insertions'],
            "total_lines_deleted": totals['deletions'],
            "time_saved_hours": roi['time_saved'],
            "cost_savings": roi['cost_savings'],
            "efficiency_percent": round(
                (totals['active_hours'] / max(totals['total_hours'], 0.01)) * 100, 1
            ) if totals['total_hours'] > 0 else 0,
            "avg_commits_per_hour": totals['avg_commits_hr']
        },
        "roi_calculation": roi,
        "daily_activity": sqlite_data['daily_activity'][:14],  # Last 14 days
        "recent_commits": [
            {
                "hash": c.get('hash') or c.get('commit_hash', '')[:8],
                "repo": c.get('repo', 'unknown'),
                "message": c.get('message', ''),
                "timestamp": c.get('timestamp', ''),
                "additions": c.get('additions') or c.get('insertions', 0),
                "deletions": c.get('deletions', 0),
                "gap_minutes": c.get('gap_minutes'),
                "synced_to_roadmap": c.get('synced_to_roadmap', False)
            }
            for c in all_commits[:25]
        ],
        "github_repos": github_repos[:10],
        "roadmap_projects": roadmap_projects,
        "project_mappings": sqlite_data['project_mappings'],
        "active_sessions": sqlite_data['active_sessions'],
        "commit_velocity": {
            "avg_gap_minutes": round(avg_gap, 1),
            "commits_per_hour": totals['avg_commits_hr'],
            "lines_per_hour": totals['avg_lines_hr']
        }
    }

    return data


def save_data(data: dict, filename: str = "live_data.json"):
    """Save data to JSON file"""
    output_path = Path(__file__).parent / filename
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2, default=str)
    print(f"Data saved to {output_path}")


if __name__ == "__main__":
    print("Collecting dashboard data...")
    data = generate_dashboard_data()
    save_data(data)
    print(f"Generated at: {data['generated_at']}")
    print(f"Summary: {data['summary']['total_dev_hours']}h, {data['summary']['total_commits']} commits")
