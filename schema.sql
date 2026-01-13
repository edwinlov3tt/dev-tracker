-- Development Tracker Database Schema
-- SQLite database for tracking Claude Code sessions, commits, and project metrics

-- Sessions table: tracks Claude Code working sessions
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    repo_path TEXT,
    project_api_key TEXT,  -- Links to roadmap project
    started_at INTEGER NOT NULL,  -- Unix timestamp
    ended_at INTEGER,
    total_tool_calls INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active',  -- active, completed, abandoned
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tool events: individual tool usage within sessions
CREATE TABLE IF NOT EXISTS tool_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    tool_name TEXT NOT NULL,
    event_type TEXT NOT NULL,  -- start, end
    exit_code INTEGER,
    timestamp INTEGER NOT NULL,
    metadata TEXT,  -- JSON for extra context
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Commits: git commit tracking
CREATE TABLE IF NOT EXISTS commits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commit_hash TEXT UNIQUE NOT NULL,
    repo_path TEXT NOT NULL,
    session_id TEXT,  -- Links commit to Claude session if applicable
    project_api_key TEXT,
    message TEXT,
    author TEXT,
    timestamp INTEGER NOT NULL,
    files_changed INTEGER,
    insertions INTEGER,
    deletions INTEGER,
    branch TEXT,
    pushed_to_roadmap INTEGER DEFAULT 0,  -- 1 if update was sent
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Project mappings: link git repos to roadmap projects
CREATE TABLE IF NOT EXISTS project_mappings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_path TEXT UNIQUE NOT NULL,
    project_api_key TEXT NOT NULL,
    project_name TEXT,
    auto_push_updates INTEGER DEFAULT 1,  -- Auto-send updates on commit
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Daily summaries: aggregated metrics by day
CREATE TABLE IF NOT EXISTS daily_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,  -- YYYY-MM-DD
    repo_path TEXT,
    project_api_key TEXT,
    total_sessions INTEGER DEFAULT 0,
    total_dev_hours REAL DEFAULT 0,
    active_coding_hours REAL DEFAULT 0,
    total_commits INTEGER DEFAULT 0,
    total_insertions INTEGER DEFAULT 0,
    total_deletions INTEGER DEFAULT 0,
    avg_commit_gap_minutes REAL,
    commits_per_hour REAL,
    lines_per_hour REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(date, repo_path)
);

-- Roadmap sync log: track what's been pushed to the API
CREATE TABLE IF NOT EXISTS roadmap_sync_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_api_key TEXT NOT NULL,
    sync_type TEXT NOT NULL,  -- update, metrics, commit
    payload TEXT,  -- JSON of what was sent
    response_status INTEGER,
    response_body TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_sessions_repo ON sessions(repo_path);
CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_api_key);
CREATE INDEX IF NOT EXISTS idx_tool_events_session ON tool_events(session_id);
CREATE INDEX IF NOT EXISTS idx_commits_repo ON commits(repo_path);
CREATE INDEX IF NOT EXISTS idx_commits_session ON commits(session_id);
CREATE INDEX IF NOT EXISTS idx_commits_timestamp ON commits(timestamp);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_date ON daily_summaries(date);

-- Views for common queries

-- Session duration view
CREATE VIEW IF NOT EXISTS v_session_durations AS
SELECT 
    s.session_id,
    s.repo_path,
    s.project_api_key,
    pm.project_name,
    s.started_at,
    s.ended_at,
    CASE 
        WHEN s.ended_at IS NOT NULL 
        THEN (s.ended_at - s.started_at) / 3600.0 
        ELSE NULL 
    END as duration_hours,
    s.total_tool_calls,
    (SELECT COUNT(*) FROM commits c WHERE c.session_id = s.session_id) as commits_in_session
FROM sessions s
LEFT JOIN project_mappings pm ON s.repo_path = pm.repo_path;

-- Active coding time per session
CREATE VIEW IF NOT EXISTS v_active_coding_time AS
SELECT 
    session_id,
    SUM(
        CASE 
            WHEN te_end.timestamp IS NOT NULL 
            THEN (te_end.timestamp - te_start.timestamp) / 3600.0 
            ELSE 0 
        END
    ) as active_hours
FROM tool_events te_start
LEFT JOIN tool_events te_end ON 
    te_start.session_id = te_end.session_id 
    AND te_start.tool_name = te_end.tool_name
    AND te_start.event_type = 'start' 
    AND te_end.event_type = 'end'
    AND te_end.timestamp > te_start.timestamp
WHERE te_start.event_type = 'start'
GROUP BY session_id;

-- Commit velocity view
CREATE VIEW IF NOT EXISTS v_commit_velocity AS
SELECT 
    date(timestamp, 'unixepoch') as commit_date,
    repo_path,
    project_api_key,
    COUNT(*) as commits,
    SUM(insertions) as total_insertions,
    SUM(deletions) as total_deletions,
    SUM(insertions + deletions) as total_changes
FROM commits
GROUP BY commit_date, repo_path;

-- Time between commits view
CREATE VIEW IF NOT EXISTS v_commit_gaps AS
SELECT 
    c1.repo_path,
    c1.commit_hash,
    c1.timestamp as commit_time,
    c1.message,
    LAG(c1.timestamp) OVER (PARTITION BY c1.repo_path ORDER BY c1.timestamp) as prev_commit_time,
    (c1.timestamp - LAG(c1.timestamp) OVER (PARTITION BY c1.repo_path ORDER BY c1.timestamp)) / 60.0 as gap_minutes
FROM commits c1
ORDER BY c1.repo_path, c1.timestamp;
