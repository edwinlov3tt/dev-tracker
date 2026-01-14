---
description: Generate a comprehensive handoff document for another developer
allowed-tools: ["Read", "Write", "Bash"]
---

# Generate Developer Handoff Document

Create a comprehensive handoff document by aggregating all project documentation.

## 1. Gather Project Info

```bash
# Project metadata
cat package.json 2>/dev/null | head -20

# Repository info
git remote -v 2>/dev/null

# Recent history
git log --oneline -10 2>/dev/null

# Current branch
git branch --show-current 2>/dev/null
```

## 2. Read All Documentation

Compile information from:
- `.claude/docs/ARCHITECTURE.md`
- `.claude/docs/KNOWN_ISSUES.md`
- `.claude/docs/DECISIONS.md`
- `.claude/docs/CHANGELOG.md`
- All files in `.claude/docs/services/`
- All files in `.claude/docs/components/`
- `CLAUDE.md` (if exists)
- `README.md` (if exists)

## 3. Generate HANDOFF.md

Create `HANDOFF.md` in project root:

```markdown
# Project Handoff Document

**Generated**: [DATE]
**Project**: [NAME]
**Repository**: [URL]

---

## Quick Start

### Prerequisites
- Node.js [version] (or Python [version], etc.)
- [Other required tools]
- Access to: [list services that need accounts/access]

### Setup

```bash
# 1. Clone the repository
git clone [repository-url]
cd [project-name]

# 2. Install dependencies
[npm install / pip install -r requirements.txt / etc.]

# 3. Set up environment
cp .env.example .env
# Fill in the following required variables:
# - [VAR1]: Get from [where]
# - [VAR2]: Get from [where]

# 4. Run the development server
[npm run dev / python main.py / etc.]
```

### Verify Setup
[How to confirm everything is working]

---

## Project Overview

### What This Project Does
[Brief description - 2-3 sentences]

### Key Features
- [Feature 1]
- [Feature 2]
- [Feature 3]

### Tech Stack

| Layer | Technology | Notes |
|-------|------------|-------|
| Frontend | [X] | |
| Backend | [X] | |
| Database | [X] | |
| Auth | [X] | |
| Hosting | [X] | |

---

## Architecture Summary

[Condensed version of ARCHITECTURE.md - key points only]

### Directory Structure
```
[Key directories and their purposes]
```

### Data Flow
[How data moves through the system]

---

## Current State

### Last Updated
- **Date**: [date of last commit]
- **By**: [author]
- **Change**: [brief description]

### Active Development
[What's currently being worked on, if anything]

### Recent Changes
[Summary from CHANGELOG.md - last 2 weeks]

---

## ⚠️ Known Issues

### Critical/High Priority
[List from KNOWN_ISSUES.md - most important first]

### Medium Priority
[List medium issues]

### Low Priority / Technical Debt
[Brief mention, full list in KNOWN_ISSUES.md]

---

## Key Decisions

[Most important decisions from DECISIONS.md that affect how you work on this project]

### [Decision 1 Title]
- **Choice**: [What was decided]
- **Why**: [Brief reason]
- **Impact**: [How this affects development]

### [Decision 2 Title]
...

---

## External Services

[For each service, brief overview with link to full docs]

### [Service 1]
- **Purpose**: [Why we use it]
- **Dashboard**: [URL]
- **Full docs**: `.claude/docs/services/[service].md`

### [Service 2]
...

---

## Environment Variables

| Variable | Purpose | Where to Get |
|----------|---------|--------------|
| `VAR1` | [purpose] | [source] |
| `VAR2` | [purpose] | [source] |

See `.env.example` for complete list.

---

## Development Workflow

### Running Locally
```bash
[commands]
```

### Running Tests
```bash
[commands]
```

### Building for Production
```bash
[commands]
```

### Deploying
[Deployment process - manual or CI/CD]

---

## Common Tasks

### Adding a New Feature
[Steps or patterns to follow]

### Debugging
[How to debug, where logs are, etc.]

### Database Changes
[Migration process if applicable]

---

## Code Conventions

[Any important patterns or conventions used in this project]

---

## Contacts & Resources

### Documentation
- Project docs: `.claude/docs/`
- [External docs if any]

### Access Needed
- [ ] Repository access
- [ ] [Service 1] account
- [ ] [Service 2] account
- [ ] Deployment platform access

---

## Next Steps / Roadmap

[Any planned features or known work remaining]

1. [Priority item]
2. [Priority item]
3. [Priority item]

---

## Questions?

[How to get help - who to contact, where to ask questions]

---

*This document was auto-generated. For the most current information, check the documentation in `.claude/docs/`*
```

## 4. Output

```markdown
## Handoff Document Generated

**File**: `HANDOFF.md` (project root)

### Contents
- Quick start guide
- Architecture summary
- X known issues documented
- X key decisions explained
- X external services documented
- Environment setup instructions

### Recommended Review
1. Verify the Quick Start steps work
2. Check that all env vars are listed
3. Update any sections that need current info

The new developer should be able to:
1. Read HANDOFF.md
2. Set up their environment
3. Understand the project structure
4. Know what issues to watch for
5. Start contributing
```
