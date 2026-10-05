---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: test data

- **Tests always use strongly typed data.** Fixtures, builders, and expected values are typed as the real domain types (or derived from the zod schemas) — never `any`, untyped JSON blobs, or `as` casts that dodge the compiler. A refactor that changes a type must break the fixtures at compile time, not at assertion time. Testing's invalid-data cases build on a typed valid base.
