#!/bin/bash
# Development Tracker - Claude Code Hook Script
# This script logs Claude Code events to SQLite for time tracking

set -e

# Configuration
DB_PATH="${DEV_TRACKER_DB:-$HOME/dev-tracker/dev_tracker.db}"
LOG_FILE="${DEV_TRACKER_LOG:-$HOME/dev-tracker/tracker.log}"

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

# Get or create session ID (based on working directory + date)
get_session_id() {
    local repo_path=$(pwd)
    local date_part=$(date +%Y%m%d)
    echo "session_${date_part}_$(echo "$repo_path" | md5sum | cut -c1-8)"
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
    
    # Get project mapping if exists
    local project_key=$(sqlite3 "$DB_PATH" "SELECT project_api_key FROM project_mappings WHERE repo_path='$repo_path' LIMIT 1;" 2>/dev/null || echo "")
    
    sqlite3 "$DB_PATH" <<EOF
INSERT OR IGNORE INTO sessions (session_id, repo_path, project_api_key, started_at, status)
VALUES ('$session_id', '$repo_path', '$project_key', $ts, 'active');
EOF
    
    log "Session started: $session_id for $repo_path"
    echo "$session_id"
}

# End a session
end_session() {
    local session_id=$(get_session_id)
    local ts=$(now)
    
    # Count tool calls
    local tool_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tool_events WHERE session_id='$session_id';" 2>/dev/null || echo "0")
    
    sqlite3 "$DB_PATH" <<EOF
UPDATE sessions 
SET ended_at = $ts, 
    status = 'completed',
    total_tool_calls = $tool_count
WHERE session_id = '$session_id' AND ended_at IS NULL;
EOF
    
    log "Session ended: $session_id with $tool_count tool calls"
}

# Log tool start
tool_start() {
    local tool_name="$1"
    local session_id=$(get_session_id)
    local ts=$(now)
    
    # Ensure session exists
    start_session > /dev/null
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO tool_events (session_id, tool_name, event_type, timestamp)
VALUES ('$session_id', '$tool_name', 'start', $ts);
EOF
    
    log "Tool started: $tool_name in session $session_id"
}

# Log tool end
tool_end() {
    local tool_name="$1"
    local exit_code="${2:-0}"
    local session_id=$(get_session_id)
    local ts=$(now)
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO tool_events (session_id, tool_name, event_type, exit_code, timestamp)
VALUES ('$session_id', '$tool_name', 'end', $exit_code, $ts);
EOF
    
    log "Tool ended: $tool_name (exit: $exit_code) in session $session_id"
}

# Log a git commit
log_commit() {
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [ -z "$commit_hash" ]; then
        log "Not in a git repository"
        return 1
    fi
    
    local repo_path=$(get_repo_path)
    local session_id=$(get_session_id)
    local message=$(git log -1 --pretty=%s 2>/dev/null | sed "s/'/''/g")
    local author=$(git log -1 --pretty=%an 2>/dev/null | sed "s/'/''/g")
    local ts=$(git log -1 --pretty=%ct 2>/dev/null)
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    
    # Get diff stats
    local stats=$(git diff --shortstat HEAD~1 HEAD 2>/dev/null || echo "0 0 0")
    local files_changed=$(echo "$stats" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
    local insertions=$(echo "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    local deletions=$(echo "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
    
    # Get project mapping
    local project_key=$(sqlite3 "$DB_PATH" "SELECT project_api_key FROM project_mappings WHERE repo_path='$repo_path' LIMIT 1;" 2>/dev/null || echo "")
    
    sqlite3 "$DB_PATH" <<EOF
INSERT OR IGNORE INTO commits (
    commit_hash, repo_path, session_id, project_api_key, 
    message, author, timestamp, files_changed, insertions, deletions, branch
) VALUES (
    '$commit_hash', '$repo_path', '$session_id', '$project_key',
    '$message', '$author', $ts, $files_changed, $insertions, $deletions, '$branch'
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
    
    sqlite3 "$DB_PATH" <<EOF
INSERT OR REPLACE INTO daily_summaries (
    date, repo_path, project_api_key,
    total_sessions, total_dev_hours, active_coding_hours,
    total_commits, total_insertions, total_deletions,
    avg_commit_gap_minutes, commits_per_hour, lines_per_hour
)
SELECT 
    '$date' as date,
    '$repo_path' as repo_path,
    pm.project_api_key,
    COUNT(DISTINCT s.session_id) as total_sessions,
    COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 0) as total_dev_hours,
    COALESCE((SELECT SUM(active_hours) FROM v_active_coding_time WHERE session_id IN 
        (SELECT session_id FROM sessions WHERE repo_path = '$repo_path' 
         AND date(started_at, 'unixepoch') = '$date')), 0) as active_coding_hours,
    (SELECT COUNT(*) FROM commits WHERE repo_path = '$repo_path' 
     AND date(timestamp, 'unixepoch') = '$date') as total_commits,
    (SELECT COALESCE(SUM(insertions), 0) FROM commits WHERE repo_path = '$repo_path' 
     AND date(timestamp, 'unixepoch') = '$date') as total_insertions,
    (SELECT COALESCE(SUM(deletions), 0) FROM commits WHERE repo_path = '$repo_path' 
     AND date(timestamp, 'unixepoch') = '$date') as total_deletions,
    (SELECT AVG(gap_minutes) FROM v_commit_gaps WHERE repo_path = '$repo_path' 
     AND date(commit_time, 'unixepoch') = '$date' AND gap_minutes IS NOT NULL) as avg_commit_gap_minutes,
    CASE 
        WHEN COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 0) > 0
        THEN (SELECT COUNT(*) FROM commits WHERE repo_path = '$repo_path' AND date(timestamp, 'unixepoch') = '$date') 
             / COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 1)
        ELSE 0
    END as commits_per_hour,
    CASE 
        WHEN COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 0) > 0
        THEN (SELECT COALESCE(SUM(insertions + deletions), 0) FROM commits WHERE repo_path = '$repo_path' AND date(timestamp, 'unixepoch') = '$date')
             / COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL THEN (s.ended_at - s.started_at) / 3600.0 ELSE 0 END), 1)
        ELSE 0
    END as lines_per_hour
FROM sessions s
LEFT JOIN project_mappings pm ON s.repo_path = pm.repo_path
WHERE s.repo_path = '$repo_path' AND date(s.started_at, 'unixepoch') = '$date'
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
    
    sqlite3 "$DB_PATH" <<EOF
INSERT OR REPLACE INTO project_mappings (repo_path, project_api_key, project_name, auto_push_updates)
VALUES ('$repo_path', '$project_api_key', '$project_name', $auto_push);
EOF
    
    log "Linked $repo_path to project $project_name ($project_api_key)"
}

# Get stats for display
get_stats() {
    local repo_path="${1:-$(get_repo_path)}"
    local days="${2:-7}"
    
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
WHERE repo_path = '$repo_path'
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
