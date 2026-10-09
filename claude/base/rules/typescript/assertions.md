---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: assertions

- **Assert via the two shared assert functions** (pure TS + zod, so they work identically in Node and browser bundles), each an `asserts` signature so every assertion also narrows the static types downstream: **`assertCondition(cond, message)`** for relational and nullability invariants — a plain truthy check, hot-path cheap, message carrying the operand values; **`assertSchema(value, schema, message?)`** for structural invariants — a zod validation that narrows the ambient variable (which a bare schema call cannot), throwing an `AssertionError` whose `cause` is the treeified zod error, so the failure carries the full mismatch. Never `console.assert` — it logs and does not throw.
- **The helpers' contract** (verified to narrow in both forms under `--strict`). Every failure throws `AssertionError`; `assertSchema` sets its `cause` to the treeified zod error (`{ cause: z.treeifyError(result.error) }`):

  ```ts
  export class AssertionError extends Error {}
  export function assertCondition(condition: unknown, message: string): asserts condition;
  export function assertSchema<S extends z.ZodType>(value: unknown, schema: Readonly<S>, message?: string): asserts value is z.infer<S>;
  export function unreachable(value: never, message?: string): never;
  ```

- **The helpers keep their positional shape at three parameters.** Naming's language-forced exception, in TypeScript: a type predicate or `asserts` signature can only name a parameter, never a property path (`asserts options.value is T` is TS1228), so where a guard narrows its own argument, positional is the only expressible form.
- **Exhaustiveness, in TypeScript.** Compile time: `switch` with a `satisfies never` check in the default arm, and `satisfies` to assert relationships between constants and types before the program runs. Runtime backstop: `unreachable(value)` in that same arm.
