# [Service Name] Integration

## Overview

| | |
|---|---|
| **Service** | [Official Name] |
| **Purpose** | [Why we use this service] |
| **Documentation** | [Official docs URL] |
| **Dashboard** | [Service console URL] |

## Configuration

### Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `SERVICE_API_KEY` | API authentication | Yes |
| `SERVICE_URL` | API endpoint (if custom) | No |

### Initial Setup
[Any one-time setup steps required]

## Implementation

### Files
- `src/lib/[service].ts` - Client initialization
- `src/api/[service]/*.ts` - API routes

### SDK/Library
- **Package**: `@[service]/sdk`
- **Version**: `^X.X.X`

### Client Initialization
```typescript
// Example from codebase
import { ServiceClient } from '@service/sdk';

export const client = new ServiceClient({
  apiKey: process.env.SERVICE_API_KEY,
});
```

## Usage Examples

### Common Operation
```typescript
// Example usage
const result = await client.doSomething({ param: 'value' });
```

## Rate Limits & Quotas

| Operation | Limit | Notes |
|-----------|-------|-------|
| API calls | X/min | |
| Data | X GB/mo | |

## Error Handling

| Error Code | Cause | Solution |
|------------|-------|----------|
| 429 | Rate limited | Implement backoff |
| 401 | Auth failed | Check API key |

## Monitoring

- **Logs**: [Where to find logs]
- **Metrics**: [Dashboard location]
- **Alerts**: [Any configured alerts]

## Cost

- **Tier**: [Free/Pro/etc]
- **Cost Drivers**: [What increases cost]

## Known Issues

[Any gotchas or limitations discovered]

## Changelog

- YYYY-MM-DD: Initial integration
