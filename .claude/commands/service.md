---
description: Document a new or updated external service integration (API, SaaS, cloud service)
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep"]
---

# Document Service Integration

Create or update documentation for an external service integration.

**Service to document:** $ARGUMENTS

## 1. Analyze the Integration

Search the codebase for this service:

```bash
# Find imports and usage
grep -rn "[service name]" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" .

# Check env files
grep -i "[service name]" .env* 2>/dev/null

# Check package.json for SDK
grep "[service name]" package.json 2>/dev/null
```

## 2. Gather Information

Document:

### Service Overview
- **Name**: Official service name
- **Purpose**: Why we use this service in our project
- **Documentation**: Link to official docs
- **Dashboard**: Link to service console/dashboard

### Configuration
- **Environment Variables**: List ALL env vars (without actual values)
- **API Keys/Secrets**: Where they're stored (e.g., "Vercel env vars", "local .env")
- **Rate Limits**: Any known limits
- **Pricing Tier**: What plan we're on (if known)

### Implementation
- **SDK/Library**: What package we use and version
- **Files**: Where the integration code lives
- **Initialization**: How the client is set up

### Usage Patterns
- How the service is called in our code
- Common operations performed
- Error handling approach

### Known Issues/Gotchas
- Quirks discovered during implementation
- Edge cases to watch for
- Common errors and solutions

## 3. Create/Update Documentation

Save to `.claude/docs/services/{service-name}.md`:

```markdown
# [Service Name] Integration

## Overview

| | |
|---|---|
| **Service** | [Official Name] |
| **Purpose** | [Why we use it] |
| **Documentation** | [URL] |
| **Dashboard** | [URL] |

## Configuration

### Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `SERVICE_API_KEY` | API authentication | Yes |
| `SERVICE_URL` | API endpoint | No (has default) |

### Setup
[Any initial setup steps required]

## Implementation

### Files
- `src/lib/service.ts` - Client initialization
- `src/api/service/*.ts` - API routes using service

### SDK
- **Package**: `@service/sdk`
- **Version**: `^2.0.0`

### Initialization
```typescript
// Example initialization code from the codebase
```

## Usage Examples

### Common Operation 1
```typescript
// Example from codebase
```

### Common Operation 2
```typescript
// Example from codebase
```

## Rate Limits & Quotas

| Operation | Limit |
|-----------|-------|
| API calls | X per minute |
| Data transfer | X GB/month |

## Error Handling

Common errors and how to handle them:

| Error | Cause | Solution |
|-------|-------|----------|
| 429 | Rate limited | Implement exponential backoff |
| 401 | Invalid API key | Check env var configuration |

## Monitoring

- **Logs**: Where to find service-related logs
- **Metrics**: Dashboard locations for usage metrics
- **Alerts**: Any configured alerts

## Cost Considerations

- Current tier: [Free/Pro/Enterprise]
- Estimated monthly cost: [if known]
- Cost drivers: [what increases cost]

## Known Issues

[List any gotchas, bugs, or limitations discovered]

## Changelog

- YYYY-MM-DD: Initial integration
- YYYY-MM-DD: [Any major changes]
```

## Output

```markdown
## Service Documented

**Service**: [Name]
**File**: `.claude/docs/services/[name].md`

### Summary
- Environment variables: X required
- Files using service: [list]
- SDK version: [version]

[Created/Updated] service documentation.
```
