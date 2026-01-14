-- Development Tracker D1 Database Schema
-- Cloudflare D1 (SQLite-compatible)

-- Sessions table: tracks Claude Code working sessions
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    repo_path TEXT,
    project_api_key TEXT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    total_tool_calls INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active',
    user_id TEXT,  -- For multi-user support
    created_at TEXT DEFAULT (datetime('now'))
);

-- Tool events: individual tool usage within sessions
CREATE TABLE IF NOT EXISTS tool_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    tool_name TEXT NOT NULL,
    event_type TEXT NOT NULL,
    exit_code INTEGER,
    timestamp INTEGER NOT NULL,
    metadata TEXT,
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Commits: git commit tracking
CREATE TABLE IF NOT EXISTS commits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commit_hash TEXT UNIQUE NOT NULL,
    repo_path TEXT NOT NULL,
    session_id TEXT,
    project_api_key TEXT,
    message TEXT,
    author TEXT,
    timestamp INTEGER NOT NULL,
    files_changed INTEGER,
    insertions INTEGER,
    deletions INTEGER,
    branch TEXT,
    pushed_to_roadmap INTEGER DEFAULT 0,
    user_id TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Project mappings: link git repos to roadmap projects
CREATE TABLE IF NOT EXISTS project_mappings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_path TEXT UNIQUE NOT NULL,
    project_api_key TEXT NOT NULL,
    project_name TEXT,
    phase TEXT DEFAULT 'development',
    auto_push_updates INTEGER DEFAULT 1,
    user_id TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- Daily summaries: aggregated metrics by day
CREATE TABLE IF NOT EXISTS daily_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
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
    user_id TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(date, repo_path, user_id)
);

-- API tokens for authentication
CREATE TABLE IF NOT EXISTS api_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token_hash TEXT UNIQUE NOT NULL,
    user_id TEXT NOT NULL,
    name TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    last_used_at TEXT,
    expires_at TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sessions_repo ON sessions(repo_path);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_tool_events_session ON tool_events(session_id);
CREATE INDEX IF NOT EXISTS idx_commits_repo ON commits(repo_path);
CREATE INDEX IF NOT EXISTS idx_commits_timestamp ON commits(timestamp);
CREATE INDEX IF NOT EXISTS idx_commits_user ON commits(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_date ON daily_summaries(date);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_user ON daily_summaries(user_id);
