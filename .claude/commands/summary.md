---
description: Generate an end-of-day summary of development work for time tracking and accounting
allowed-tools: ["Read", "Bash"]
---

# End-of-Day Summary

Generate a summary of development work for time tracking and accounting purposes.

## Arguments

- `$ARGUMENTS` - Optional: Date in YYYY-MM-DD format (defaults to today), or "week" for weekly summary

## Steps

### 1. Determine Date Range

```bash
# Parse arguments
DATE_ARG="$ARGUMENTS"

if [ "$DATE_ARG" = "week" ]; then
    echo "Generating weekly summary..."
    START_DATE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)
    END_DATE=$(date +%Y-%m-%d)
elif [ -n "$DATE_ARG" ]; then
    echo "Generating summary for $DATE_ARG..."
    START_DATE="$DATE_ARG"
    END_DATE="$DATE_ARG"
else
    echo "Generating today's summary..."
    START_DATE=$(date +%Y-%m-%d)
    END_DATE=$(date +%Y-%m-%d)
fi
```

### 2. Query Development Metrics

```bash
DB_PATH="${DEV_TRACKER_DB:-$HOME/dev-tracker/dev_tracker.db}"

if [ -f "$DB_PATH" ]; then
    echo "=== Development Time Summary ==="
    sqlite3 -header -column "$DB_PATH" "
        SELECT
            date,
            COALESCE(pm.project_name, 'Unlinked') as project,
            pm.phase,
            CASE WHEN pm.phase IN ('development', 'beta') THEN 'Yes' ELSE 'No' END as capitalizable,
            printf('%.2f', ds.total_dev_hours) as hours,
            ds.total_commits as commits,
            ds.total_insertions + ds.total_deletions as lines_changed
        FROM daily_summaries ds
        LEFT JOIN project_mappings pm ON ds.repo_path = pm.repo_path
        WHERE ds.date BETWEEN '$START_DATE' AND '$END_DATE'
        ORDER BY ds.date DESC, pm.project_name;
    "
else
    echo "Database not found at $DB_PATH"
fi
```

### 3. Calculate Totals

```bash
if [ -f "$DB_PATH" ]; then
    echo ""
    echo "=== Totals ==="
    sqlite3 -header -column "$DB_PATH" "
        SELECT
            printf('%.2f', SUM(ds.total_dev_hours)) as total_hours,
            SUM(ds.total_commits) as total_commits,
            SUM(ds.total_insertions + ds.total_deletions) as total_lines,
            printf('%.2f', SUM(CASE WHEN pm.phase IN ('development', 'beta') THEN ds.total_dev_hours ELSE 0 END)) as capitalizable_hours,
            printf('%.2f', SUM(CASE WHEN pm.phase NOT IN ('development', 'beta') OR pm.phase IS NULL THEN ds.total_dev_hours ELSE 0 END)) as expensed_hours
        FROM daily_summaries ds
        LEFT JOIN project_mappings pm ON ds.repo_path = pm.repo_path
        WHERE ds.date BETWEEN '$START_DATE' AND '$END_DATE';
    "
fi
```

### 4. Show Recent Commits

```bash
if [ -f "$DB_PATH" ]; then
    echo ""
    echo "=== Recent Commits ==="
    sqlite3 -header -column "$DB_PATH" "
        SELECT
            datetime(timestamp, 'unixepoch', 'localtime') as time,
            substr(commit_hash, 1, 7) as hash,
            COALESCE(pm.project_name, repo_path) as project,
            substr(message, 1, 50) as message
        FROM commits c
        LEFT JOIN project_mappings pm ON c.repo_path = pm.repo_path
        WHERE date(timestamp, 'unixepoch') BETWEEN '$START_DATE' AND '$END_DATE'
        ORDER BY timestamp DESC
        LIMIT 15;
    "
fi
```

### 5. Git Activity Summary

```bash
echo ""
echo "=== Git Activity (Current Repo) ==="
git log --since="$START_DATE" --until="$END_DATE 23:59:59" --pretty=format:"%h %ad %s" --date=short 2>/dev/null || echo "No git history in current directory"
```

---

## Output Format

Provide a formatted summary:

```markdown
## Development Summary

**Period**: [Date or Date Range]
**Generated**: [Current timestamp]

### Time Breakdown

| Project | Phase | Hours | Capitalizable |
|---------|-------|-------|---------------|
| [Name]  | [Phase] | [X.XX] | [Yes/No] |

**Total Hours**: X.XX
**Capitalizable**: X.XX (XX%)
**Expensed**: X.XX (XX%)

### Activity
- **Commits**: X
- **Lines Changed**: X (+additions / -deletions)
- **Active Projects**: X

### Notable Commits
- `abc1234` - Brief commit message
- `def5678` - Brief commit message

### Notes
[Optional: Add any session notes or context]
```

## Usage Examples

```
/summary              # Today's summary
/summary 2025-01-10   # Specific date
/summary week         # Last 7 days
```
