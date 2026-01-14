#!/bin/bash
# Cloud-based Development Tracker Hook Script
# POSTs events to Cloudflare Workers API instead of local SQLite

set -e

# Configuration - set these in your environment or .env file
API_URL="${DEV_TRACKER_API_URL:-https://dev-tracker.YOUR_SUBDOMAIN.workers.dev}"
API_TOKEN="${DEV_TRACKER_API_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check required config
check_config() {
    if [ -z "$API_TOKEN" ]; then
        echo -e "${RED}Error: DEV_TRACKER_API_TOKEN not set${NC}" >&2
        echo "Set it in your environment or .env file" >&2
        exit 1
    fi
}

# Get current repo path
get_repo_path() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Generate session ID based on repo + date
get_session_id() {
    local repo_path=$(get_repo_path)
    local date=$(date +%Y%m%d)

    if command -v md5sum &>/dev/null; then
        hash=$(echo "$repo_path" | md5sum | cut -c1-8)
    elif command -v md5 &>/dev/null; then
        hash=$(echo "$repo_path" | md5 | cut -c1-8)
    else
        hash=$(echo "$repo_path" | cksum | cut -d' ' -f1)
    fi

    echo "session-${date}-${hash}"
}

# POST to API with auth
api_post() {
    local endpoint="$1"
    local data="$2"

    curl -s -X POST "${API_URL}${endpoint}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -d "$data"
}

# API GET request
api_get() {
    local endpoint="$1"

    curl -s -X GET "${API_URL}${endpoint}" \
        -H "Authorization: Bearer ${API_TOKEN}"
}

# Start a new session
cmd_start() {
    check_config

    local session_id=$(get_session_id)
    local repo_path=$(get_repo_path)
    local timestamp=$(date +%s)

    local data=$(cat <<EOF
{
    "session_id": "$session_id",
    "repo_path": "$repo_path",
    "started_at": $timestamp
}
EOF
)

    response=$(api_post "/api/sessions/start" "$data")

    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}Session started: $session_id${NC}"
    else
        echo -e "${RED}Failed to start session: $response${NC}" >&2
    fi
}

# End current session
cmd_end() {
    check_config

    local session_id=$(get_session_id)
    local timestamp=$(date +%s)

    local data=$(cat <<EOF
{
    "session_id": "$session_id",
    "ended_at": $timestamp
}
EOF
)

    response=$(api_post "/api/sessions/end" "$data")

    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}Session ended: $session_id${NC}"
    else
        echo -e "${RED}Failed to end session: $response${NC}" >&2
    fi
}

# Log a tool event
cmd_event() {
    check_config

    local tool_name="${1:-unknown}"
    local event_type="${2:-start}"
    local exit_code="${3:-0}"

    local session_id=$(get_session_id)
    local timestamp=$(date +%s)

    local data=$(cat <<EOF
{
    "session_id": "$session_id",
    "tool_name": "$tool_name",
    "event_type": "$event_type",
    "exit_code": $exit_code,
    "timestamp": $timestamp
}
EOF
)

    # Fire and forget - don't block on response
    api_post "/api/events" "$data" > /dev/null 2>&1 &
}

# Log a git commit
cmd_commit() {
    check_config

    local repo_path=$(get_repo_path)
    local session_id=$(get_session_id)

    # Get commit info
    local commit_hash=$(git rev-parse HEAD 2>/dev/null)
    local message=$(git log -1 --pretty=%s 2>/dev/null)
    local author=$(git log -1 --pretty=%an 2>/dev/null)
    local timestamp=$(git log -1 --pretty=%ct 2>/dev/null)
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    # Get diff stats
    local stats=$(git diff --shortstat HEAD~1 HEAD 2>/dev/null || echo "")
    local files_changed=$(echo "$stats" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
    local insertions=$(echo "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    local deletions=$(echo "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

    # Escape message for JSON
    message=$(echo "$message" | sed 's/"/\\"/g' | tr '\n' ' ')

    local data=$(cat <<EOF
{
    "commit_hash": "$commit_hash",
    "repo_path": "$repo_path",
    "session_id": "$session_id",
    "message": "$message",
    "author": "$author",
    "timestamp": $timestamp,
    "files_changed": $files_changed,
    "insertions": $insertions,
    "deletions": $deletions,
    "branch": "$branch"
}
EOF
)

    response=$(api_post "/api/commits" "$data")

    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}Commit logged: ${commit_hash:0:7}${NC}"
    else
        echo -e "${YELLOW}Failed to log commit (continuing): $response${NC}" >&2
    fi
}

# Link repo to project
cmd_link() {
    check_config

    local project_api_key="$1"
    local project_name="$2"
    local phase="${3:-development}"

    if [ -z "$project_api_key" ] || [ -z "$project_name" ]; then
        echo "Usage: track-cloud.sh link <api_key> <project_name> [phase]"
        echo "Phases: ideation, development, beta, live, maintenance"
        exit 1
    fi

    local repo_path=$(get_repo_path)

    local data=$(cat <<EOF
{
    "repo_path": "$repo_path",
    "project_api_key": "$project_api_key",
    "project_name": "$project_name",
    "phase": "$phase"
}
EOF
)

    response=$(api_post "/api/mappings" "$data")

    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}Linked $repo_path to $project_name ($phase)${NC}"
    else
        echo -e "${RED}Failed to link: $response${NC}" >&2
    fi
}

# Show stats
cmd_stats() {
    check_config

    local days="${1:-7}"
    local repo="${2:-}"

    local endpoint="/api/stats?days=$days"
    if [ -n "$repo" ]; then
        endpoint="${endpoint}&repo=$repo"
    fi

    response=$(api_get "$endpoint")

    echo "Development Stats (last $days days)"
    echo "===================================="
    echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
stats = data.get('stats', {})
print(f\"Hours:         {stats.get('hours', 0)}\")
print(f\"Commits:       {stats.get('commits', 0)}\")
print(f\"Lines Changed: {stats.get('lines_changed', 0)}\")
print(f\"Active Days:   {stats.get('active_days', 0)}\")
" 2>/dev/null || echo "$response"
}

# Health check
cmd_health() {
    response=$(curl -s "${API_URL}/api/health")
    echo "API Health Check"
    echo "================"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
}

# Show help
cmd_help() {
    echo "Dev Tracker Cloud - Hook Script"
    echo ""
    echo "Usage: track-cloud.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start              Start a development session"
    echo "  end                End current session"
    echo "  event <tool> <type> Log a tool event (start/end)"
    echo "  commit             Log the latest git commit"
    echo "  link <key> <name>  Link repo to a project"
    echo "  stats [days] [repo] Show development stats"
    echo "  health             Check API health"
    echo ""
    echo "Environment Variables:"
    echo "  DEV_TRACKER_API_URL   API endpoint (default: https://dev-tracker.YOUR_SUBDOMAIN.workers.dev)"
    echo "  DEV_TRACKER_API_TOKEN API authentication token (required)"
}

# Main command router
case "${1:-help}" in
    start)
        cmd_start
        ;;
    end)
        cmd_end
        ;;
    event)
        cmd_event "$2" "$3" "$4"
        ;;
    commit)
        cmd_commit
        ;;
    link)
        cmd_link "$2" "$3" "$4"
        ;;
    stats)
        cmd_stats "$2" "$3"
        ;;
    health)
        cmd_health
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        echo "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac
