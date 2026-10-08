---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: validating I/O

- **Validating I/O's boundary check is `assertSchema`.** Schemas stay zod, but the helper is the single invocation point: prefer it over bare schema calls at boundaries, so every failure is uniformly an `AssertionError` with the treeified zod error as `cause` (never a raw `ZodError`) and the validated variable narrows in place. External data arrives as `unknown` and is narrowed by an `assertSchema` call before anything consumes it. The one exception is transforming schemas (`.transform()`, `z.coerce`): an `asserts` signature returns `void` and can only narrow, never hand back a new value — a schema whose output differs from its input is invoked directly, `.safeParse` with an explicit failure branch.
- **`.safeParse` always; `.parse` never** — inside the `assert` helper included. `.parse` throws a raw `ZodError` at the call site, violating the treeify rule by construction and hiding the failure path; `.safeParse` returns the outcome as data, forcing the failure into an explicit `if` branch — the no-ternary and no-coalescing rules applied to validation.
- **A variable holding a zod schema is named in lower camel case ending in `Schema`** — `hookInputSchema`, never `HookInput`, `HookInputSchema`, or `HOOK_INPUT_SCHEMA`; the bare word `schema` qualifies. The suffix marks the value as a validator rather than the data it validates, so a parsed value and its schema share a stem without a reader confusing the two, and the lower camel case marks it a value, leaving PascalCase to the type inferred from it (`type HookInput = z.infer<typeof hookInputSchema>`). That type is PascalCase whether wrapped or indexed (`Readonly<z.output<…>>`, `z.infer<…>["id"]`) or not.
