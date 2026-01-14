---
description: Initialize the documentation structure for a new project
allowed-tools: ["Read", "Write", "Bash"]
---

# Initialize Documentation Structure

Set up the `.claude/docs/` folder structure for this project.

## 1. Create Directory Structure

```bash
mkdir -p .claude/docs/services
mkdir -p .claude/docs/components
```

## 2. Create CHANGELOG.md

Create `.claude/docs/CHANGELOG.md`:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Initial project setup
- Documentation system initialized

### Changed

### Fixed

### Removed

---

## Format Guide

- **Added**: New features or capabilities
- **Changed**: Changes to existing functionality
- **Fixed**: Bug fixes
- **Removed**: Removed features
- **Security**: Security-related fixes
- **Deprecated**: Features that will be removed
```

## 3. Create KNOWN_ISSUES.md

Create `.claude/docs/KNOWN_ISSUES.md`:

```markdown
# Known Issues

Track bugs, edge cases, and technical debt.

## Active Issues

_No active issues yet._

---

## Resolved Issues

_Resolved issues are moved here for reference._

---

## Severity Guide

| Level | Description | Response |
|-------|-------------|----------|
| **CRITICAL** | System unusable, data loss, security risk | Fix immediately |
| **HIGH** | Major feature broken, no workaround | Fix this sprint |
| **MEDIUM** | Feature impaired, workaround exists | Fix when possible |
| **LOW** | Minor inconvenience, cosmetic | Fix eventually |

## Issue Template

```
### [SEVERITY] Brief Title
- **Location**: `path/to/file.ts` - `functionName()`
- **Symptom**: What goes wrong
- **Root Cause**: Why it happens
- **Workaround**: Temporary fix (or "None")
- **Proper Fix**: What needs to be done
- **Added**: YYYY-MM-DD
```
```

## 4. Create DECISIONS.md

Create `.claude/docs/DECISIONS.md`:

```markdown
# Architectural Decisions

Record of significant technical decisions and their context.

---

## Decisions

_No decisions recorded yet._

---

## When to Record

Record decisions when:
- Choosing between technologies or frameworks
- Designing data models or API structures
- Setting up deployment or infrastructure
- Establishing patterns that will be repeated
- Making tradeoffs that might not be obvious later

## Decision Template

```
## [Title]
- **Date**: YYYY-MM-DD
- **Status**: Accepted

### Context
What problem needed solving. What constraints existed.

### Decision
What was chosen and why.

### Alternatives Considered
1. **Option A**: Why rejected
2. **Option B**: Why rejected

### Consequences
- **Positive**: What we gain
- **Negative**: What we give up
- **Neutral**: Other implications
```
```

## 5. Create ARCHITECTURE.md

Create `.claude/docs/ARCHITECTURE.md`:

```markdown
# Architecture Overview

High-level system architecture and design.

## Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Frontend | | |
| Backend | | |
| Database | | |
| Auth | | |
| Hosting | | |

## Directory Structure

```
[To be filled by /audit]
```

## Key Components

[To be filled by /audit]

## Data Flow

[To be filled by /audit]

## Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| | | |

## External Services

See individual docs in `services/` folder.

## Deployment

### Production
- Platform: 
- URL: 
- Deploy command: 

### Preview/Staging
- Platform:
- URL pattern:
```

## 6. Confirm Setup

List all created files and confirm structure is ready.

## Output

```markdown
## Documentation Initialized

Created `.claude/docs/` structure:

```
.claude/docs/
├── ARCHITECTURE.md
├── CHANGELOG.md
├── DECISIONS.md
├── KNOWN_ISSUES.md
├── components/
└── services/
```

### Next Steps
1. Run `/audit` to populate documentation with project analysis
2. Or manually fill in the templates

### Commands Available
- `/doc` - Update docs after coding sessions
- `/issue [desc]` - Log bugs and issues
- `/decision [desc]` - Record technical decisions
- `/service [name]` - Document external services
- `/audit` - Full project analysis
- `/handoff` - Generate handoff document
```
