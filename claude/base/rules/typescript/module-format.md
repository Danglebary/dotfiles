---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: module format

- **A file Node loads as ESM names nothing the CommonJS wrapper binds.** `__dirname`, `__filename`, `require`, `module`, and `exports` exist only inside the wrapper Node puts around a CommonJS file, so in an ESM file each throws a `ReferenceError` at the first line that reaches it. Write `import.meta.dirname` and `import.meta.filename`; a static `import` or `await import()` for `require`, `import.meta.resolve` for `require.resolve`, and `createRequire(import.meta.url)` from `node:module` only for a load that only CommonJS can make; `export` for `module.exports` and `exports`; and `import.meta.main` for `require.main === module`.
- **The format is Node's decision, read from the extension and then the manifest.** `.mts` is ESM and `.cts` is CommonJS whatever the manifest says; any other file takes the `"type"` of the nearest `package.json` above it, and a manifest stating no type, or no manifest, means CommonJS. So in a CommonJS package those five names are correct and `import.meta` does not compile.
