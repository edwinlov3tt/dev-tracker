---
description: Record an architectural or technical decision with context
allowed-tools: ["Read", "Write", "Edit"]
---

# Record Decision

Document a technical or architectural decision in DECISIONS.md.

**Decision to record:** $ARGUMENTS

## Gather Context

For this decision, determine:

1. **Title**: Brief name for the decision (e.g., "Use Cloudflare Workers over Vercel Edge")

2. **Context**: What situation required this decision? What problem were you solving?

3. **Decision**: What was chosen? (1-2 sentences)

4. **Alternatives Considered**: What other options existed and why were they rejected?

5. **Reasoning**: Why was this option selected? What factors mattered most?

6. **Tradeoffs**: 
   - What do we gain?
   - What do we give up?
   - What future implications does this have?

## Add to DECISIONS.md

Append to `.claude/docs/DECISIONS.md`:

```markdown
---

## [Title]
- **Date**: YYYY-MM-DD
- **Status**: Accepted

### Context
[What situation or problem required this decision. What constraints existed.]

### Decision
[What was chosen and the primary reason why.]

### Alternatives Considered
1. **[Option A]**: [Brief description] - Rejected because [reason]
2. **[Option B]**: [Brief description] - Rejected because [reason]

### Consequences
- **Positive**: [What we gain from this decision]
- **Negative**: [What we give up or must handle as a result]
- **Neutral**: [Other implications worth noting]
```

## Output

Confirm the decision was recorded:

```markdown
## Decision Recorded

**Title**: [Decision title]
**Date**: YYYY-MM-DD

### Summary
[1-2 sentence summary of the decision and primary reasoning]

Added to `.claude/docs/DECISIONS.md`
```
