---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: logging

- **pino buffers its output**, so Observability's `fatal`-only-counts-if-it-flushes rule binds here: a `fatal` written on the way to `process.exit()` is lost unless the exit path flushes synchronously.
