# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

---

## 2025-01-14

### Documentation System
- Added claude-docs-system for automated documentation
- Created `.claude/commands/` with 8 slash commands: audit, doc, doc-init, doc-status, decision, handoff, issue, service
- Created `.claude/docs/` with ARCHITECTURE.md, CHANGELOG.md, KNOWN_ISSUES.md, DECISIONS.md
- Added Documentation Protocol section to CLAUDE.md

---

## Initial Release (Pre-changelog)

### Core System
- MCP Server (`server.py`) with 12 tools for Claude Code integration
- Hook script (`hooks/track.sh`) for event capture
- SQLite database schema with 6 tables and 4 views
- CLI dashboard (`dashboard.py`) for quick stats

### MCP Tools
- **Project Management**: `list_roadmap_projects`, `get_project_details`, `link_repo_to_project`, `get_linked_projects`
- **Updates**: `push_project_update`, `push_commit_to_roadmap`
- **Analytics**: `get_dev_stats`, `get_recent_commits`, `generate_roi_report`
- **Sessions**: `log_session_start`, `log_session_end`

### Demo Dashboard
- FastAPI server for web-based dashboard
- Data collector for aggregating stats
- Demo data for testing

### Setup
- Automated setup script (`setup.sh`)
- Claude Code hooks configuration (`claude_hooks.json`)
- MCP server configuration template (`mcp_config.json`)

---

## Format Guide

Each entry should include:

- **Added**: New features or capabilities
- **Changed**: Changes to existing functionality
- **Fixed**: Bug fixes
- **Removed**: Removed features
- **Security**: Security-related fixes
- **Deprecated**: Features that will be removed in future
