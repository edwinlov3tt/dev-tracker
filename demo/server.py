#!/usr/bin/env python3
"""
FastAPI Server for Development Tracker Dashboard
Serves the dashboard and provides data API endpoints
"""

import json
import subprocess
from pathlib import Path
from fastapi import FastAPI, Query
from fastapi.responses import HTMLResponse, FileResponse
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


@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "demo_data_available": DEMO_DATA_PATH.exists(),
        "live_data_available": LIVE_DATA_PATH.exists()
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
