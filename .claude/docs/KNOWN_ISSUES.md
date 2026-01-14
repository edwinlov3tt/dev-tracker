# Known Issues

Track bugs, edge cases, and technical debt. This is the goldmine for developer handoffs.

## Active Issues

No active issues at this time.

---

## Resolved Issues

### [LOW] md5sum Not Available on macOS
- **Location**: `hooks/track.sh` - `get_session_id()`
- **Symptom**: Session ID generation failed on macOS which uses `md5` instead of `md5sum`
- **Root Cause**: Linux-specific command used
- **Resolution**: Added OS detection to use `md5sum` on Linux, `md5` on macOS, or `cksum` as fallback
- **Resolved**: 2025-01-14

### [LOW] Hardcoded Hourly Rate in ROI Calculations
- **Location**: `server.py`, `dashboard.py`
- **Symptom**: ROI report used fixed $75/hour rate
- **Root Cause**: Hardcoded value instead of configurable
- **Resolution**: Added `DEV_TRACKER_HOURLY_RATE` environment variable (default: 75). Both server.py and dashboard.py now read from this config.
- **Resolved**: 2025-01-14

### [LOW] No Git Repository Check Before Operations
- **Location**: `hooks/track.sh` - `log_commit()`
- **Symptom**: Script attempted git operations outside git repos, producing errors
- **Root Cause**: Limited error handling for non-git directories
- **Resolution**: Added `is_git_repo()` helper function. `log_commit()` now checks if in a git repo first and provides clear error messages to stderr.
- **Resolved**: 2025-01-14

### [MEDIUM] Shell Injection Risk in track.sh
- **Location**: `hooks/track.sh` - all SQL-interacting functions
- **Symptom**: Malicious git commit messages or branch names could break SQL or inject commands
- **Root Cause**: Variables were interpolated directly into SQL statements without escaping
- **Resolution**: Added `sanitize()` function that escapes single quotes for SQLite. Applied to all user-controlled inputs: session_id, repo_path, tool_name, commit_hash, message, author, branch, project_key, project_name. Numeric inputs (exit_code, days, auto_push) are validated to ensure they're numbers.
- **Resolved**: 2025-01-14

---

## Severity Guide

| Level | Description | Response Time |
|-------|-------------|---------------|
| CRITICAL | System unusable, data loss risk, security vulnerability | Fix immediately |
| HIGH | Major feature broken, no workaround available | Fix this sprint |
| MEDIUM | Feature impaired but workaround exists | Fix when possible |
| LOW | Minor inconvenience, cosmetic issues | Fix eventually |

## Issue Template

```markdown
### [SEVERITY] Brief Descriptive Title
- **Location**: `path/to/file.ts` - `functionName()`
- **Symptom**: What happens when this issue occurs
- **Root Cause**: Why it happens (or "Investigation needed")
- **Workaround**: Temporary fix (or "None")
- **Proper Fix**: What needs to be done to resolve permanently
- **Reproduction**: Steps to trigger (optional)
- **Added**: YYYY-MM-DD
```
