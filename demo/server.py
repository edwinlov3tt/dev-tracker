#!/usr/bin/env python3
"""
FastAPI Server for Development Tracker Dashboard
Serves the dashboard and provides data API endpoints
"""

import json
import csv
import sqlite3
import io
from datetime import datetime, timedelta
from pathlib import Path
from fastapi import FastAPI, Query
from fastapi.responses import HTMLResponse, FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Development Tracker Dashboard")

# Enable CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Paths
BASE_DIR = Path(__file__).parent
DEMO_DATA_PATH = BASE_DIR / "demo_data.json"
LIVE_DATA_PATH = BASE_DIR / "live_data.json"
DB_PATH = Path.home() / "dev-tracker" / "dev_tracker.db"


def load_json_file(path: Path) -> dict:
    """Load and parse a JSON file"""
    if not path.exists():
        return {"error": f"File not found: {path.name}"}
    with open(path) as f:
        return json.load(f)


@app.get("/", response_class=HTMLResponse)
async def serve_dashboard():
    """Serve the main dashboard HTML"""
    html_path = BASE_DIR / "index.html"
    if html_path.exists():
        return html_path.read_text()
    return "<h1>Dashboard not found</h1><p>Run setup first.</p>"


@app.get("/steps", response_class=HTMLResponse)
async def serve_steps():
    """Serve the How It Works documentation page"""
    html_path = BASE_DIR / "steps.html"
    if html_path.exists():
        return html_path.read_text()
    return "<h1>Page not found</h1><p>steps.html not found.</p>"


@app.get("/api/steps/download")
async def download_steps_markdown():
    """Download the documentation as a markdown file"""
    md_path = BASE_DIR / "steps.md"
    if md_path.exists():
        return FileResponse(
            path=md_path,
            filename="dev-tracker-guide.md",
            media_type="text/markdown"
        )
    return {"error": "steps.md not found"}


@app.get("/api/data")
async def get_data(mode: str = Query("demo", pattern="^(demo|live)$")):
    """
    Get dashboard data

    Args:
        mode: 'demo' for static demo data, 'live' for real data
    """
    if mode == "live":
        data = load_json_file(LIVE_DATA_PATH)
        if "error" in data:
            # Try to generate live data
            try:
                from data_collector import generate_dashboard_data, save_data
                data = generate_dashboard_data()
                save_data(data)
            except Exception as e:
                return {"error": f"Failed to generate live data: {str(e)}"}
        data["data_mode"] = "live"
    else:
        data = load_json_file(DEMO_DATA_PATH)
        data["data_mode"] = "demo"

    return data


@app.post("/api/refresh")
async def refresh_data():
    """Re-run data collector and update live_data.json"""
    try:
        from data_collector import generate_dashboard_data, save_data
        data = generate_dashboard_data()
        save_data(data)
        return {
            "success": True,
            "message": "Data refreshed successfully",
            "generated_at": data.get("generated_at"),
            "summary": data.get("summary")
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


@app.get("/api/export/csv")
async def export_csv(
    days: int = Query(30, description="Number of days to include"),
    include_details: bool = Query(False, description="Include daily breakdown")
):
    """
    Export time tracking data as CSV for accounting.

    Returns a CSV with columns:
    - Date, Project, Phase, Hours, Commits, Lines Changed, Capitalizable
    """
    # Check if database exists
    if not DB_PATH.exists():
        # Return demo data as CSV
        data = load_json_file(DEMO_DATA_PATH)
        output = io.StringIO()
        writer = csv.writer(output)

        # Header
        writer.writerow([
            "Date", "Project", "Phase", "Hours", "Commits",
            "Lines Added", "Lines Deleted", "Capitalizable"
        ])

        # Write demo daily activity
        for day in data.get("daily_activity", []):
            writer.writerow([
                day.get("date", ""),
                "Demo Project",
                "development",
                round(day.get("hours", 0), 2),
                day.get("commits", 0),
                day.get("lines_changed", 0) // 2,  # Approximate split
                day.get("lines_changed", 0) // 2,
                "Yes"
            ])

        output.seek(0)
        filename = f"dev-tracker-export-{datetime.now().strftime('%Y%m%d')}.csv"
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )

    # Use real database
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        # Query with phase and capitalization logic
        cur.execute("""
            SELECT
                ds.date,
                COALESCE(pm.project_name, 'Unlinked') as project_name,
                COALESCE(pm.phase, 'unknown') as phase,
                ds.total_dev_hours as hours,
                ds.total_commits as commits,
                ds.total_insertions as additions,
                ds.total_deletions as deletions,
                CASE
                    WHEN pm.phase IN ('development', 'beta') THEN 'Yes'
                    ELSE 'No'
                END as capitalizable
            FROM daily_summaries ds
            LEFT JOIN project_mappings pm ON ds.repo_path = pm.repo_path
            WHERE ds.date >= date('now', ?)
            ORDER BY ds.date DESC, pm.project_name
        """, (f"-{days} days",))

        rows = cur.fetchall()
        conn.close()

        # Generate CSV
        output = io.StringIO()
        writer = csv.writer(output)

        # Header
        writer.writerow([
            "Date", "Project", "Phase", "Hours", "Commits",
            "Lines Added", "Lines Deleted", "Capitalizable"
        ])

        # Data rows
        for row in rows:
            writer.writerow([
                row["date"],
                row["project_name"],
                row["phase"],
                round(row["hours"] or 0, 2),
                row["commits"] or 0,
                row["additions"] or 0,
                row["deletions"] or 0,
                row["capitalizable"]
            ])

        # Add summary row
        if rows:
            total_hours = sum(r["hours"] or 0 for r in rows)
            total_commits = sum(r["commits"] or 0 for r in rows)
            total_additions = sum(r["additions"] or 0 for r in rows)
            total_deletions = sum(r["deletions"] or 0 for r in rows)
            cap_hours = sum(r["hours"] or 0 for r in rows if r["capitalizable"] == "Yes")

            writer.writerow([])  # Empty row
            writer.writerow(["TOTALS", "", "", round(total_hours, 2), total_commits,
                           total_additions, total_deletions, ""])
            writer.writerow(["Capitalizable Hours", "", "", round(cap_hours, 2), "", "", "", ""])
            writer.writerow(["Expensed Hours", "", "", round(total_hours - cap_hours, 2), "", "", "", ""])

        output.seek(0)
        filename = f"dev-tracker-export-{datetime.now().strftime('%Y%m%d')}.csv"
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )

    except Exception as e:
        return {"error": f"Database error: {str(e)}"}


@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "demo_data_available": DEMO_DATA_PATH.exists(),
        "live_data_available": LIVE_DATA_PATH.exists(),
        "database_available": DB_PATH.exists()
    }


@app.get("/api/config")
async def get_config():
    """Get configuration status (without exposing secrets)"""
    from config import GITHUB_TOKEN, ROADMAP_API_TOKEN

    return {
        "github_configured": bool(GITHUB_TOKEN),
        "roadmap_configured": bool(ROADMAP_API_TOKEN)
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8080,
        reload=True
    )
