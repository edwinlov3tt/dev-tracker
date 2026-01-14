---
description: Update project documentation after completing work. Run this after every coding session.
allowed-tools: ["Read", "Edit", "Write", "Bash"]
---

# Documentation Update Protocol

You are a documentation subagent. Review recent changes and update the project documentation.

## Steps

### 1. Analyze Recent Changes
```bash
# See what files changed
git diff HEAD~1 --name-only 2>/dev/null || git diff --name-only

# Get recent commit messages
git log -5 --pretty=format:"%h %s" 2>/dev/null || echo "No git history"

# Check for unstaged changes
git status --short 2>/dev/null
```

Understand what was built, fixed, or modified in this session.

### 2. Update CHANGELOG.md

Add entry under today's date in `.claude/docs/CHANGELOG.md`:

```markdown
## YYYY-MM-DD

### [Feature/Component Name]
- What was added, changed, or fixed
- Include relevant details
- Note any breaking changes
- Reference related issues if applicable
```

### 3. Check for New Issues

If you encountered or noticed any of these during the session, add to `.claude/docs/KNOWN_ISSUES.md`:
- Bugs or unexpected behavior
- Edge cases that aren't handled
- Performance concerns
- Technical debt created
- TODOs that were added to the code

Use this format:
```markdown
### [SEVERITY] Brief Title
- **Location**: `path/to/file.ts` - `functionName()`
- **Symptom**: What goes wrong
- **Workaround**: Temporary fix if any
- **Proper Fix**: What needs to be done
- **Added**: YYYY-MM-DD
```

### 4. Update Service/Component Docs

If any of these changed, update the relevant docs:

**Service changes** (`.claude/docs/services/*.md`):
- New API endpoints used
- Changed environment variables
- Updated SDK versions
- New rate limits discovered

**Component changes** (`.claude/docs/components/*.md`):
- New exports or functions
- Changed interfaces/types
- Updated dependencies
- New usage patterns

### 5. Record Decisions (if applicable)

If you made any non-obvious technical choices during this session, add to `.claude/docs/DECISIONS.md`:
- Why you chose one approach over another
- Tradeoffs you accepted
- Constraints that influenced the decision

### 6. Update ARCHITECTURE.md (if applicable)

Only update if:
- New environment variables were added
- Directory structure changed
- New external services integrated
- Deployment configuration changed

---

## Output

After updating, provide a brief summary:

```markdown
## Documentation Updated

**Session**: [Brief description of what was worked on]
**Date**: YYYY-MM-DD

### Changes Made
- [ ] CHANGELOG.md - [Added/Updated entry for X]
- [ ] KNOWN_ISSUES.md - [Added X new issues / No new issues]
- [ ] services/[name].md - [Updated/Created / No changes]
- [ ] components/[name].md - [Updated/Created / No changes]
- [ ] DECISIONS.md - [Added X decisions / No new decisions]
- [ ] ARCHITECTURE.md - [Updated / No changes needed]

### Summary
[1-2 sentences about what was documented]
```
