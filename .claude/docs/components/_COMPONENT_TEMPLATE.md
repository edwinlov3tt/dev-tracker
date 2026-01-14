# [Component Name]

## Overview

| | |
|---|---|
| **Purpose** | [What this component does] |
| **Location** | `src/[path]/` |
| **Type** | [API routes / UI components / utilities / hooks / etc.] |

## Responsibility

[2-3 sentences describing what this component is responsible for]

## Files

| File | Purpose |
|------|---------|
| `index.ts` | Main entry / exports |
| `types.ts` | Type definitions |
| `utils.ts` | Helper functions |

## Dependencies

### Internal
- `src/lib/database` - Database access
- `src/utils/validation` - Input validation

### External
- `zod` - Schema validation
- `date-fns` - Date utilities

## Key Exports

### Functions

#### `functionName(params)`
```typescript
/**
 * Brief description
 * @param params - Description
 * @returns Description
 */
export function functionName(params: ParamType): ReturnType
```

**Example:**
```typescript
const result = functionName({ key: 'value' });
```

### Types

#### `TypeName`
```typescript
interface TypeName {
  id: string;
  name: string;
  // ...
}
```

## Usage Patterns

### Basic Usage
```typescript
import { functionName } from '@/components/[component]';

// Example usage
```

### With Error Handling
```typescript
try {
  const result = await functionName(params);
} catch (error) {
  // Handle specific errors
}
```

## Testing

### Test Location
`__tests__/[component]/` or `[component].test.ts`

### Running Tests
```bash
npm test -- [component]
```

### Test Coverage
[Current coverage status if known]

## Known Limitations

- [Limitation 1]
- [Limitation 2]

## Related Components

- `[RelatedComponent1]` - [Relationship]
- `[RelatedComponent2]` - [Relationship]

## Changelog

- YYYY-MM-DD: Initial implementation
- YYYY-MM-DD: [Changes made]
