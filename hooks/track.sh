#!/bin/bash
# Development Tracker - Claude Code Hook Script
# This script logs Claude Code events to SQLite for time tracking

set -e

# Configuration
DB_PATH="${DEV_TRACKER_DB:-$HOME/dev-tracker/dev_tracker.db}"
LOG_FILE="${DEV_TRACKER_LOG:-$HOME/dev-tracker/tracker.log}"

# Sanitize string for SQLite (escape single quotes)
sanitize() {
    printf '%s' "$1" | sed "s/'/''/g"
}

# Ensure database exists
init_db() {
    if [ ! -f "$DB_PATH" ]; then
        sqlite3 "$DB_PATH" < "$HOME/dev-tracker/schema.sql"
        log "Initialized database at $DB_PATH"
    fi
}

# Logging helper
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Get current timestamp
now() {
    date +%s
}

# Check if current directory is inside a git repository
is_git_repo() {
    git rev-parse --is-inside-work-tree &>/dev/null
}

# Get or create session ID (based on working directory + date)
get_session_id() {
    local repo_path=$(pwd)
    local date_part=$(date +%Y%m%d)
    # Use md5 on macOS, md5sum on Linux
    local hash
    if command -v md5sum &>/dev/null; then
        hash=$(echo "$repo_path" | md5sum | cut -c1-8)
    elif command -v md5 &>/dev/null; then
        hash=$(echo "$repo_path" | md5 | cut -c1-8)
    else
        hash=$(echo "$repo_path" | cksum | cut -d' ' -f1)
    fi
    echo "session_${date_part}_${hash}"
}

# Get repo path
get_repo_path() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Start a session
start_session() {
    local session_id=$(get_session_id)
    local repo_path=$(get_repo_path)
    local ts=$(now)

    # Sanitize for SQL
    local safe_session_id=$(sanitize "$session_id")
    local safe_repo_path=$(sanitize "$repo_path")

    # Get project mapping if exists
    local project_key=$(sqlite3 "$DB_PATH" "SELECT project_api_key FROM project_mappings WHERE repo_path='$safe_repo_path' LIMIT 1;" 2>/dev/null || echo "")
    local safe_project_key=$(sanitize "$project_key")

    sqlite3 "$DB_PATH" <<EOF
INSERT OR IGNORE INTO sessions (session_id, repo_path, project_api_key, started_at, status)
VALUES ('$safe_session_id', '$safe_repo_path', '$safe_project_key', $ts, 'active');
EOF

    log "Session started: $session_id for $repo_path"
    echo "$session_id"
}

# End a session
end_session() {
    local session_id=$(get_session_id)
    local ts=$(now)

    # Sanitize for SQL
    local safe_session_id=$(sanitize "$session_id")

    # Count tool calls
    local tool_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tool_events WHERE session_id='$safe_session_id';" 2>/dev/null || echo "0")

    sqlite3 "$DB_PATH" <<EOF
UPDATE sessions
SET ended_at = $ts,
    status = 'completed',
    total_tool_calls = $tool_count
WHERE session_id = '$safe_session_id' AND ended_at IS NULL;
EOF

    log "Session ended: $session_id with $tool_count tool calls"
}

# Log tool start
tool_start() {
    local tool_name="$1"
    local session_id=$(get_session_id)
    local ts=$(now)

    # Sanitize for SQL
    local safe_session_id=$(sanitize "$session_id")
    local safe_tool_name=$(sanitize "$tool_name")

    # Ensure session exists
    start_session > /dev/null

    sqlite3 "$DB_PATH" <<EOF
INSERT INTO tool_events (session_id, tool_name, event_type, timestamp)
VALUES ('$safe_session_id', '$safe_tool_name', 'start', $ts);
EOF

    log "Tool started: $tool_name in session $session_id"
}

# Log tool end
tool_end() {
    local tool_name="$1"
    local exit_code="${2:-0}"
    local session_id=$(get_session_id)
    local ts=$(now)

    # Sanitize for SQL
    local safe_session_id=$(sanitize "$session_id")
    local safe_tool_name=$(sanitize "$tool_name")
    # Ensure exit_code is numeric
    exit_code=$(echo "$exit_code" | grep -oE '^[0-9]+$' || echo "0")

    sqlite3 "$DB_PATH" <<EOF
INSERT INTO tool_events (session_id, tool_name, event_type, exit_code, timestamp)
VALUES ('$safe_session_id', '$safe_tool_name', 'end', $exit_code, $ts);
EOF

    log "Tool ended: $tool_name (exit: $exit_code) in session $session_id"
}

# Log a git commit
log_commit() {
    if ! is_git_repo; then
        echo "Error: Not in a git repository. Run this command from within a git repo." >&2
        log "Not in a git repository"
        return 1
    fi

    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [ -z "$commit_hash" ]; then
        echo "Error: Could not get commit hash. Is there at least one commit?" >&2
        log "Could not get commit hash"
        return 1
    fi

    local repo_path=$(get_repo_path)
    local session_id=$(get_session_id)
    local message=$(git log -1 --pretty=%s 2>/dev/null)
    local author=$(git log -1 --pretty=%an 2>/dev/null)
    local ts=$(git log -1 --pretty=%ct 2>/dev/null)
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    # Sanitize all string inputs for SQL
    local safe_commit_hash=$(sanitize "$commit_hash")
    local safe_repo_path=$(sanitize "$repo_path")
    local safe_session_id=$(sanitize "$session_id")
    local safe_message=$(sanitize "$message")
    local safe_author=$(sanitize "$author")
    local safe_branch=$(sanitize "$branch")

    # Get diff stats (ensure numeric)
    local stats=$(git diff --shortstat HEAD~1 HEAD 2>/dev/null || echo "0 0 0")
    local files_changed=$(echo "$stats" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
    local insertions=$(echo "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    local deletions=$(echo "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
    files_changed=${files_changed:-0}
    insertions=${insertions:-0}
    deletions=${deletions:-0}

    # Get project mapping
    local project_key=$(sqlite3 "$DB_PATH" "SELECT project_api_key FROM project_mappings WHERE repo_path='$safe_repo_path' LIMIT 1;" 2>/dev/null || echo "")
    local safe_project_key=$(sanitize "$project_key")

    sqlite3 "$DB_PATH" <<EOF
INSERT OR IGNORE INTO commits (
    commit_hash, repo_path, session_id, project_api_key,
    message, author, timestamp, files_changed, insertions, deletions, branch
) VALUES (
    '$safe_commit_hash', '$safe_repo_path', '$safe_session_id', '$safe_project_key',
    '$safe_message', '$safe_author', $ts, $files_changed, $insertions, $deletions, '$safe_branch'
);
EOF

    log "Commit logged: $commit_hash - $message"

    # Return commit info for potential roadmap push
    echo "$commit_hash|$message|$insertions|$deletions|$project_key"
}

# Generate daily summary
generate_summary() {
    local date="${1:-$(date +%Y-%m-%d)}"
    local repo_path="${2:-$(get_repo_path)}"

    # Sanitize inputs
    local safe_date=$(sanitize "$date")
    local safe_repo_path=$(sanitize "$repo_path")

    sqlite3 "$DB_PATH" <<EOF
INSERT OR REPLACE INTO daily_summaries (
    date, repo_path, project_api_key,
    total_sessions, total_dev_hours, active_coding_hours,
    total_commits, total_insertions, total_deletions,
    avg_commit_gap_minutes, commits_per_hour, lines_per_hour
)
SELECT
    '$safe_date' as date,
    '$safe_repo_path' as repo_path,
    pm.project_api_key,
    COUNT(DISTINCT s.session_id) as total_sessions,
    COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 0) as total_dev_hours,
    COALESCE((SELECT SUM(active_hours) FROM v_active_coding_time WHERE session_id IN
        (SELECT session_id FROM sessions WHERE repo_path = '$safe_repo_path'
         AND date(started_at, 'unixepoch') = '$safe_date')), 0) as active_coding_hours,
    (SELECT COUNT(*) FROM commits WHERE repo_path = '$safe_repo_path'
     AND date(timestamp, 'unixepoch') = '$safe_date') as total_commits,
    (SELECT COALESCE(SUM(insertions), 0) FROM commits WHERE repo_path = '$safe_repo_path'
     AND date(timestamp, 'unixepoch') = '$safe_date') as total_insertions,
    (SELECT COALESCE(SUM(deletions), 0) FROM commits WHERE repo_path = '$safe_repo_path'
     AND date(timestamp, 'unixepoch') = '$safe_date') as total_deletions,
    (SELECT AVG(gap_minutes) FROM v_commit_gaps WHERE repo_path = '$safe_repo_path'
     AND date(commit_time, 'unixepoch') = '$safe_date' AND gap_minutes IS NOT NULL) as avg_commit_gap_minutes,
    CASE
        WHEN COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 0) > 0
        THEN (SELECT COUNT(*) FROM commits WHERE repo_path = '$safe_repo_path' AND date(timestamp, 'unixepoch') = '$safe_date')
             / COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 1)
        ELSE 0
    END as commits_per_hour,
    CASE
        WHEN COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 0) > 0
        THEN (SELECT COALESCE(SUM(insertions + deletions), 0) FROM commits WHERE repo_path = '$safe_repo_path' AND date(timestamp, 'unixepoch') = '$safe_date')
             / COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 1)
        ELSE 0
    END as lines_per_hour
FROM sessions s
LEFT JOIN project_mappings pm ON s.repo_path = pm.repo_path
WHERE s.repo_path = '$safe_repo_path' AND date(s.started_at, 'unixepoch') = '$safe_date'
GROUP BY pm.project_api_key;
EOF

    log "Generated summary for $date"
}

# Link a repo to a roadmap project
link_project() {
    local project_api_key="$1"
    local project_name="$2"
    local repo_path="${3:-$(get_repo_path)}"
    local auto_push="${4:-1}"

    # Sanitize inputs
    local safe_api_key=$(sanitize "$project_api_key")
    local safe_name=$(sanitize "$project_name")
    local safe_repo_path=$(sanitize "$repo_path")
    # Ensure auto_push is 0 or 1
    auto_push=$(echo "$auto_push" | grep -oE '^[01]$' || echo "1")

    sqlite3 "$DB_PATH" <<EOF
INSERT OR REPLACE INTO project_mappings (repo_path, project_api_key, project_name, auto_push_updates)
VALUES ('$safe_repo_path', '$safe_api_key', '$safe_name', $auto_push);
EOF

    log "Linked $repo_path to project $project_name ($project_api_key)"
}

# Get stats for display
get_stats() {
    local repo_path="${1:-$(get_repo_path)}"
    local days="${2:-7}"

    # Sanitize inputs
    local safe_repo_path=$(sanitize "$repo_path")
    # Ensure days is numeric
    days=$(echo "$days" | grep -oE '^[0-9]+$' || echo "7")

    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT
    date,
    printf("%.2f", total_dev_hours) as dev_hours,
    printf("%.2f", active_coding_hours) as active_hours,
    total_commits as commits,
    total_insertions as additions,
    total_deletions as deletions,
    printf("%.1f", avg_commit_gap_minutes) as avg_gap_min,
    printf("%.2f", commits_per_hour) as commits_hr,
    printf("%.0f", lines_per_hour) as lines_hr
FROM daily_summaries
WHERE repo_path = '$safe_repo_path'
  AND date >= date('now', '-$days days')
ORDER BY date DESC;
EOF
}

# Initialize database on first run
init_db

# Main command router
case "${1:-}" in
    start)
        start_session
        ;;
    end)
        end_session
        ;;
    tool_start)
        tool_start "$2"
        ;;
    tool_end)
        tool_end "$2" "$3"
        ;;
    commit)
        log_commit
        ;;
    summary)
        generate_summary "$2" "$3"
        ;;
    link)
        link_project "$2" "$3" "$4" "$5"
        ;;
    stats)
        get_stats "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {start|end|tool_start|tool_end|commit|summary|link|stats}"
        echo ""
        echo "Commands:"
        echo "  start                    - Start/resume a session"
        echo "  end                      - End the current session"
        echo "  tool_start <name>        - Log tool start"
        echo "  tool_end <name> [code]   - Log tool end with exit code"
        echo "  commit                   - Log current git commit"
        echo "  summary [date] [repo]    - Generate daily summary"
        echo "  link <api_key> <name>    - Link repo to roadmap project"
        echo "  stats [repo] [days]      - Show stats for last N days"
        exit 1
        ;;
esac
