---
description: Check documentation status and health
allowed-tools: ["Read", "Bash"]
---

# Documentation Status Check

Analyze the current state of project documentation.

## Checks to Perform

### 1. Documentation Structure
Verify `.claude/docs/` exists and check for required files:
- CHANGELOG.md
- KNOWN_ISSUES.md
- DECISIONS.md
- ARCHITECTURE.md

### 2. Content Freshness

```bash
# When were docs last updated?
echo "=== Last doc updates ==="
for f in .claude/docs/*.md; do
  echo "$f: $(git log -1 --format='%ar' -- "$f" 2>/dev/null || echo 'not in git')"
done

# When was code last updated?
echo "=== Last code commit ==="
git log -1 --format="%ar - %s"
```

Flag if docs are significantly older than code (>1 week).

### 3. Issue Analysis

Read KNOWN_ISSUES.md and count:
- CRITICAL issues
- HIGH issues
- MEDIUM issues
- LOW issues
- Total active issues

### 4. Service Documentation Coverage

```bash
# List documented services
echo "=== Documented Services ==="
ls -1 .claude/docs/services/ 2>/dev/null || echo "No service docs"
```

Cross-reference with services detected in code:
- Check for common SDK imports (supabase, stripe, openai, cloudflare, etc.)
- Compare to documented services

### 5. Content Quality Checks

For each doc file, check:
- Is it mostly template/placeholder text?
- Does ARCHITECTURE.md have the tech stack filled in?
- Does CHANGELOG.md have recent entries?
- Are there decisions in DECISIONS.md?

### 6. Missing Documentation Scan

```bash
# Check for env vars in code that might not be documented
grep -rh "process\.env\." --include="*.ts" --include="*.tsx" --include="*.js" . 2>/dev/null | \
  grep -oP "process\.env\.\K\w+" | sort -u
```

Compare to env vars listed in ARCHITECTURE.md.

## Output

Provide status report:

```markdown
# Documentation Status Report

**Generated**: [timestamp]
**Project**: [name]

## Structure Health

| File | Status | Last Updated |
|------|--------|--------------|
| CHANGELOG.md | ✅ Present | [relative time] |
| KNOWN_ISSUES.md | ✅ Present | [relative time] |
| DECISIONS.md | ⚠️ Empty | [relative time] |
| ARCHITECTURE.md | ✅ Present | [relative time] |

## Documentation Freshness

- **Last doc update**: [relative time]
- **Last code commit**: [relative time]
- **Status**: [✅ Current / ⚠️ May need update / 🔴 Stale]

## Active Issues Summary

| Severity | Count |
|----------|-------|
| 🔴 CRITICAL | 0 |
| 🟠 HIGH | 1 |
| 🟡 MEDIUM | 3 |
| 🟢 LOW | 2 |
| **Total** | **6** |

## Service Documentation

| Service | Documented | Status |
|---------|------------|--------|
| Supabase | ✅ Yes | Current |
| Stripe | ❌ No | Needs doc |
| Cloudflare | ⚠️ Outdated | Needs update |

## Environment Variables

- **In code**: X variables
- **Documented**: Y variables
- **Missing docs**: [list any undocumented vars]

## Recommendations

1. [Highest priority action]
2. [Second priority]
3. [Third priority]

## Quick Actions

- Run `/doc` to update after recent changes
- Run `/service [name]` for undocumented services
- Run `/audit` for full refresh
```
