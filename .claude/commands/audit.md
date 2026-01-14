---
description: Full project audit - analyze entire codebase and populate all documentation
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
---

# Full Project Audit

Perform a comprehensive analysis of the entire codebase and populate all documentation.

## Phase 1: Discovery

### 1.1 Project Metadata
- Read `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, or equivalent
- Identify project name, version, dependencies
- Run `!git remote -v` for repository info
- Check for monorepo structure

### 1.2 Directory Structure
- Map the full directory tree (excluding node_modules, .git, dist, build, __pycache__, .venv)
- Identify key directories: src, api, workers, components, utils, lib, etc.
- Note any unusual or project-specific organization

### 1.3 Tech Stack Detection
Scan for:
- **Frontend**: React, Vue, Svelte, Next.js, Nuxt, Astro (check for .jsx, .tsx, .vue, .svelte, .astro)
- **Backend**: Express, FastAPI, Hono, Django, Flask, Next.js API routes
- **Database**: Supabase, PostgreSQL, MongoDB, D1, Prisma, Drizzle (check env vars, imports, schema files)
- **Hosting**: Vercel (vercel.json), Cloudflare (wrangler.toml), Railway, Netlify, AWS
- **Build tools**: Vite, Webpack, esbuild, Turbopack, tsup
- **Testing**: Jest, Vitest, Playwright, Cypress, pytest

### 1.4 External Services
Search for:
- API keys and service URLs in env files (.env.example, .env.local, .env.sample)
- SDK imports (supabase, stripe, openai, anthropic, cloudflare, twilio, sendgrid, etc.)
- Configuration files (wrangler.toml, vercel.json, railway.json, netlify.toml)
- OAuth providers (auth0, clerk, supabase auth, next-auth)

---

## Phase 2: Code Analysis

### 2.1 Entry Points
- Find main entry files (index.ts, main.tsx, app.py, main.py, etc.)
- Trace the application startup flow
- Identify middleware, plugins, or initialization patterns

### 2.2 API Routes / Endpoints
- Find all API endpoints:
  - Next.js: `app/api/**/route.ts` or `pages/api/**`
  - Express: look for `app.get`, `app.post`, `router.*`
  - FastAPI: look for `@app.*` or `@router.*` decorators
  - Hono: look for `app.*` or `Hono()` usage
- Document: method, path, purpose, request/response shape
- Note any middleware or authentication requirements

### 2.3 Key Components/Modules
- Identify core business logic files
- Document major components and their responsibilities
- Note component dependencies and data flow

### 2.4 Database Schema
- Find schema definitions (Prisma schema, Drizzle schema, SQL migrations, Supabase types)
- Document main entities and relationships
- Note any indexes or special configurations

### 2.5 Environment Variables
- Compile ALL env vars used across the codebase
- Search patterns: `process.env.`, `import.meta.env.`, `os.environ`, `Env.`
- Categorize: required vs optional, by service
- Check .env.example for documentation

### 2.6 Potential Issues
Scan for:
- TODO/FIXME/HACK/XXX/BUG comments: `!grep -rn "TODO\|FIXME\|HACK\|XXX\|BUG" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" .`
- console.log/print statements (potential debug leftovers)
- Empty catch blocks
- Hardcoded URLs, API keys, or secrets
- Missing error handling
- Large functions (>100 lines)
- Deprecated package usage (check for warnings in package.json)
- Type `any` overuse in TypeScript
- Disabled ESLint rules

---

## Phase 3: Git History Analysis

### 3.1 Recent Changes
- Run `!git log --oneline -30` for recent commits
- Run `!git log --since="1 month ago" --oneline` for past month
- Summarize major features/fixes

### 3.2 Contributors
- Run `!git shortlog -sn --all | head -10` for top contributors

### 3.3 Active Areas
- Run `!git log --pretty=format: --name-only -30 | sort | uniq -c | sort -rn | head -20`
- Identify most frequently changed files (likely active development or problem areas)

### 3.4 Branch Status
- Run `!git branch -a` to see all branches
- Note any feature branches or release patterns

---

## Phase 4: Documentation Generation

### 4.1 Update ARCHITECTURE.md
Fill in with actual data:
- Real tech stack table (what's actually used)
- Actual directory structure
- Component descriptions based on code analysis
- Data flow based on traced code paths
- Complete environment variables list
- Deployment configuration

### 4.2 Update KNOWN_ISSUES.md
Add entries for:
- All TODO/FIXME comments found (with file locations and line numbers)
- Potential code smells identified
- Missing error handling patterns
- Hardcoded values that should be env vars
- Any security concerns
- Performance bottlenecks noticed

Severity guide:
- CRITICAL: Security issues, data loss risks
- HIGH: Major feature broken, blocking issues
- MEDIUM: Feature impaired, has workaround
- LOW: Minor issues, cosmetic, nice-to-have fixes

### 4.3 Update CHANGELOG.md
Based on git history:
- Group recent commits by feature/fix/chore
- Create entries for the past 2-4 weeks
- Use conventional commit style if project uses it

### 4.4 Create Service Documentation
For EACH external service detected, create `.claude/docs/services/{service}.md`:
- Service name and purpose in this project
- All environment variables required
- Files where the service is used
- Links to official documentation
- Any rate limits or pricing considerations
- Common issues or gotchas

### 4.5 Create Component Documentation
For major components/modules, create `.claude/docs/components/{component}.md`:
- Purpose and responsibility
- Key functions/exports
- Dependencies (internal and external)
- Usage examples from the codebase
- Testing approach

### 4.6 Update DECISIONS.md
Record any obvious architectural decisions visible in the code:
- Framework/library choices
- Database design patterns
- Authentication approach
- Deployment strategy
- State management approach
- API design patterns

---

## Phase 5: Summary Report

After completing all updates, provide this summary:

```markdown
# Project Audit Complete

**Generated**: [timestamp]
**Project**: [name from package.json or directory]
**Repository**: [git remote URL]

## Project Overview
- **Type**: [web app / API / CLI / extension / library / etc.]
- **Tech Stack**: [Frontend] + [Backend] + [Database] + [Hosting]
- **Size**: [X files, Y lines of code approximately]
- **Age**: [First commit date] - [Latest commit date]

## Documentation Created/Updated

| Document | Status | Details |
|----------|--------|---------|
| ARCHITECTURE.md | ✅ Updated | Tech stack, structure, env vars |
| KNOWN_ISSUES.md | ✅ Updated | X issues logged |
| CHANGELOG.md | ✅ Updated | Last N weeks of changes |
| DECISIONS.md | ✅ Updated | X decisions recorded |
| services/*.md | ✅ Created | [list of service docs] |
| components/*.md | ✅ Created | [list of component docs] |

## Key Findings

### Tech Stack Summary
| Layer | Technology |
|-------|------------|
| Frontend | [x] |
| Backend | [x] |
| Database | [x] |
| Auth | [x] |
| Hosting | [x] |

### External Services
[List all detected services]

### Issues by Severity
- 🔴 CRITICAL: X
- 🟠 HIGH: X  
- 🟡 MEDIUM: X
- 🟢 LOW: X

### Code Quality Notes
- [Notable patterns or concerns]
- [Testing coverage status]
- [Documentation quality]

## Immediate Attention Needed
1. [Critical issues requiring immediate fix]
2. [Security concerns]
3. [Missing critical documentation]

## Recommended Next Steps
1. [Priority action items]
2. [Technical debt to address]
3. [Documentation to expand]

---

**Documentation system installed. Use these commands going forward:**
- `/doc` - Update docs after each coding session
- `/issue [desc]` - Log bugs or issues
- `/decision [desc]` - Record architectural decisions
- `/service [name]` - Document new service integrations
- `/handoff` - Generate developer handoff document
```

---

## Execution Notes

- Be thorough - read actual code, don't guess based on file names
- If the project is large, acknowledge you're sampling representative files
- Flag areas that need manual review
- Ask clarifying questions if the project structure is unusual
- Prioritize accuracy over completeness - it's better to document less with certainty than more with guesses
