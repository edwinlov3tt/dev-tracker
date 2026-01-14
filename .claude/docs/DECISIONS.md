# Architectural Decisions

Record of significant technical decisions and their context. This helps future developers understand *why* things were built a certain way.

---

## Decisions

## Use SQLite for Local Data Storage
- **Date**: 2025-01-14 (documented)
- **Status**: Accepted

### Context
Need to store session data, tool events, commits, and metrics locally for each developer. Data needs to be queryable for analytics and persist across sessions.

### Decision
Use SQLite as the local database. It's file-based, requires no server, and is pre-installed on most systems.

### Alternatives Considered
1. **JSON files**
   - Pros: Simple, no dependencies
   - Cons: No query capability, poor for relational data, concurrent write issues
   - Rejected because: Complex queries needed for analytics views

2. **PostgreSQL/MySQL**
   - Pros: Full SQL, network-accessible
   - Cons: Requires server installation and management
   - Rejected because: Overkill for local single-user data

### Consequences
- **Positive**: Zero setup, portable database file, full SQL support, pre-computed views
- **Negative**: Single-writer limitation, not suitable for shared access
- **Neutral**: Database lives at `~/dev-tracker/dev_tracker.db`

---

## Use MCP Protocol for Claude Code Integration
- **Date**: 2025-01-14 (documented)
- **Status**: Accepted

### Context
Need to expose development tracking tools to Claude Code so the AI can access stats, push updates to Roadmap API, and manage projects.

### Decision
Implement as an MCP (Model Context Protocol) server using the official `mcp` Python SDK.

### Alternatives Considered
1. **HTTP REST API**
   - Pros: Language-agnostic, standard tooling
   - Cons: Requires separate server process, more complex integration
   - Rejected because: MCP is the native Claude Code extension protocol

2. **Direct CLI commands**
   - Pros: Simple, shell-native
   - Cons: Not accessible as Claude Code tools, no structured data
   - Rejected because: Would require manual execution, loses automation benefits

### Consequences
- **Positive**: Native integration with Claude Code, structured tool definitions, async support
- **Negative**: Tied to MCP protocol, requires Python
- **Neutral**: Server runs via stdio when invoked by Claude Code

---

## Use Bash for Hook Script
- **Date**: 2025-01-14 (documented)
- **Status**: Accepted

### Context
Claude Code hooks execute shell commands. Need to log events to SQLite quickly and reliably.

### Decision
Implement hook script in Bash with direct sqlite3 CLI calls.

### Alternatives Considered
1. **Python script**
   - Pros: Better error handling, parameterized queries
   - Cons: Slower startup, requires Python available
   - Rejected because: Hook latency matters, Bash is faster to invoke

2. **Node.js script**
   - Pros: Good SQLite libraries
   - Cons: Slower startup than Bash
   - Rejected because: Adds unnecessary dependency

### Consequences
- **Positive**: Fast execution, minimal dependencies, works on any Unix system
- **Negative**: Shell escaping complexity, potential injection risks
- **Neutral**: Script located at `~/dev-tracker/hooks/track.sh`

---

## Use 2.5x Manual Multiplier for ROI Calculations
- **Date**: 2025-01-14 (documented)
- **Status**: Accepted

### Context
Need to estimate time saved by AI-assisted development for ROI reports to leadership.

### Decision
Use a conservative 2.5x multiplier based on industry studies showing AI coding assistants improve productivity by 30-60%.

### Alternatives Considered
1. **3x-5x multiplier**
   - Pros: More impressive numbers
   - Cons: May be seen as inflated, harder to defend
   - Rejected because: Conservative estimates build more trust

2. **User-configurable multiplier**
   - Pros: Flexibility
   - Cons: Complexity, potential for abuse
   - Rejected because: Standard baseline more defensible

### Consequences
- **Positive**: Believable ROI numbers, aligned with published research
- **Negative**: May underestimate actual savings in some cases
- **Neutral**: Formula: `Time Saved = Dev Hours × (2.5 - 1) = Dev Hours × 1.5`

---

## When to Record

Record when:
- Choosing between technologies or frameworks
- Designing data models or API structures
- Setting up deployment or infrastructure
- Establishing patterns that will be repeated
- Making tradeoffs that won't be obvious later

Don't record:
- Obvious industry-standard choices
- Temporary implementations
- Personal style preferences
