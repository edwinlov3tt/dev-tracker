"""
Configuration for Development Tracker Dashboard
Loads settings from environment variables
"""

import os
from pathlib import Path

# API Tokens (load from environment)
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
ROADMAP_API_TOKEN = os.environ.get("ROADMAP_API_TOKEN", "")

# API Base URLs
ROADMAP_API_BASE = "https://feedback.edwinlovett.com/roadmap/api/v1"
GITHUB_API_BASE = "https://api.github.com"

# GitHub username for repo discovery
GITHUB_USERNAME = "edwinlovettiii"

# Database path
DB_PATH = os.environ.get(
    "DEV_TRACKER_DB",
    Path.home() / "dev-tracker" / "dev_tracker.db"
)

# ROI Calculation defaults
DEFAULT_HOURLY_RATE = 75
DEFAULT_MULTIPLIER = 2.5

# Data collection settings
DEFAULT_DAYS = 30
REPO_ACTIVITY_DAYS = 90  # Only include repos active in last N days
