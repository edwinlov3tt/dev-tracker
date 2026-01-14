#!/usr/bin/env python3
"""
Quick CLI Dashboard for Development Tracker
Run: python3 dashboard.py [days]
"""

import sqlite3
import os
import sys
from pathlib import Path
from datetime import datetime

DB_PATH = os.environ.get("DEV_TRACKER_DB", Path.home() / "dev-tracker" / "dev_tracker.db")
HOURLY_RATE = float(os.environ.get("DEV_TRACKER_HOURLY_RATE", "75"))

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def format_duration(hours):
    if hours is None:
        return "-"
    h = int(hours)
    m = int((hours - h) * 60)
    return f"{h}h {m}m"

def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    
    conn = get_db()
    cur = conn.cursor()
    
    print("\n" + "="*60)
    print("📊 DEVELOPMENT TRACKER DASHBOARD")
    print("="*60)
    print(f"Period: Last {days} days | Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print("="*60)
    
    # Overall stats
    cur.execute("""
        SELECT 
            SUM(total_dev_hours) as hours,
            SUM(total_commits) as commits,
            SUM(total_insertions) as adds,
            SUM(total_deletions) as dels
        FROM daily_summaries
        WHERE date >= date('now', ?)
    """, (f"-{days} days",))
    
    row = cur.fetchone()
    hours = row['hours'] or 0
    commits = row['commits'] or 0
    adds = row['adds'] or 0
    dels = row['dels'] or 0
    
    print(f"\n📈 TOTALS")
    print(f"   Dev Hours:      {format_duration(hours)}")
    print(f"   Commits:        {commits}")
    print(f"   Lines Changed:  +{adds:,} / -{dels:,}")
    print(f"   Velocity:       {(commits/max(hours,1)):.2f} commits/hr")
    
    # ROI calculation (HOURLY_RATE from config/env)
    MULTIPLIER = 2.5
    time_saved = hours * (MULTIPLIER - 1)
    savings = time_saved * HOURLY_RATE
    
    print(f"\n💰 ROI ESTIMATE")
    print(f"   Time Saved:     {format_duration(time_saved)}")
    print(f"   Cost Savings:   ${savings:,.2f}")
    
    # By project
    cur.execute("""
        SELECT 
            COALESCE(pm.project_name, 'Unlinked') as project,
            SUM(ds.total_dev_hours) as hours,
            SUM(ds.total_commits) as commits
        FROM daily_summaries ds
        LEFT JOIN project_mappings pm ON ds.project_api_key = pm.project_api_key
        WHERE ds.date >= date('now', ?)
        GROUP BY pm.project_name
        ORDER BY hours DESC
        LIMIT 5
    """, (f"-{days} days",))
    
    projects = cur.fetchall()
    if projects:
        print(f"\n📁 BY PROJECT")
        for p in projects:
            print(f"   {p['project'][:25]:<25} {format_duration(p['hours']):>8} | {p['commits']} commits")
    
    # Recent commits
    cur.execute("""
        SELECT 
            datetime(timestamp, 'unixepoch') as time,
            message,
            insertions,
            deletions
        FROM commits
        ORDER BY timestamp DESC
        LIMIT 5
    """)
    
    recent = cur.fetchall()
    if recent:
        print(f"\n🔄 RECENT COMMITS")
        for c in recent:
            msg = c['message'][:40] + "..." if len(c['message']) > 40 else c['message']
            print(f"   {c['time']} | {msg}")
    
    # Active sessions
    cur.execute("""
        SELECT COUNT(*) as active
        FROM sessions
        WHERE status = 'active'
    """)
    active = cur.fetchone()['active']
    if active > 0:
        print(f"\n⚡ {active} active session(s)")
    
    print("\n" + "="*60 + "\n")
    conn.close()

if __name__ == "__main__":
    main()
