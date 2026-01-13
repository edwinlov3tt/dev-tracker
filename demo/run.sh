#!/bin/bash
# Start the Development Tracker Dashboard
# Usage: ./run.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "  Development Tracker Dashboard"
echo "========================================"
echo ""

# Check for required environment variables
if [ -z "$ROADMAP_API_TOKEN" ]; then
    echo "⚠️  ROADMAP_API_TOKEN not set"
    echo "   Live Roadmap data will be unavailable."
    echo "   Set with: export ROADMAP_API_TOKEN='your_token'"
    echo ""
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  GITHUB_TOKEN not set"
    echo "   Live GitHub data will be unavailable."
    echo "   Set with: export GITHUB_TOKEN='ghp_...'"
    echo ""
fi

# Setup virtual environment if needed
VENV_DIR="$SCRIPT_DIR/.venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Check for required Python packages
echo "Checking dependencies..."
python3 -c "import fastapi, uvicorn, httpx" 2>/dev/null || {
    echo "Installing required packages..."
    pip install fastapi uvicorn httpx --quiet
}
echo "✓ Dependencies OK"
echo ""

# Generate fresh data if tokens are available
if [ -n "$ROADMAP_API_TOKEN" ] || [ -n "$GITHUB_TOKEN" ]; then
    echo "Collecting live data..."
    python3 data_collector.py 2>/dev/null && echo "✓ Live data collected" || echo "⚠️  Could not collect live data"
    echo ""
fi

# Start the server
echo "Starting server..."
echo ""
echo "Dashboard available at:"
echo "  → http://localhost:8080"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================"
echo ""

python3 -m uvicorn server:app --host 0.0.0.0 --port 8080 --reload
