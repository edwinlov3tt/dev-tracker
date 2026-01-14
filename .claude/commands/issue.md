---
description: Quickly log an issue or bug discovered during development
allowed-tools: ["Read", "Write", "Edit"]
---

# Log Issue

Add a new issue to KNOWN_ISSUES.md.

**Issue to log:** $ARGUMENTS

## Gather Information

Based on the issue description, determine:

1. **Severity**:
   - CRITICAL: System unusable, data loss risk, security vulnerability
   - HIGH: Major feature broken, no workaround available
   - MEDIUM: Feature impaired but workaround exists
   - LOW: Minor inconvenience, cosmetic issue

2. **Location**: File path and function/component name where the issue occurs

3. **Symptom**: What happens when this issue occurs (user-visible behavior)

4. **Root Cause**: Why it happens (if known, otherwise "Investigation needed")

5. **Workaround**: Temporary fix users can apply (if any, otherwise "None")

6. **Proper Fix**: What needs to be done to resolve it permanently

7. **Reproduction** (if applicable): Steps to trigger the issue

## Add to KNOWN_ISSUES.md

Insert under "## Active Issues" in `.claude/docs/KNOWN_ISSUES.md`:

```markdown
### [SEVERITY] Brief Descriptive Title
- **Location**: `path/to/file.ts` - `functionName()`
- **Symptom**: Description of what goes wrong
- **Root Cause**: Why this happens
- **Workaround**: Temporary solution (or "None")
- **Proper Fix**: What needs to be built/changed
- **Added**: YYYY-MM-DD
```

## Output

Confirm the issue was logged:

```markdown
## Issue Logged

**Severity**: [SEVERITY]
**Title**: [Brief title]
**Location**: `[file path]`

Added to `.claude/docs/KNOWN_ISSUES.md`

[Optional: Suggest immediate actions if CRITICAL or HIGH severity]
```
