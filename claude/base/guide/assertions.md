# Assertions

- **Assertions detect programmer errors; boundary validation detects operating errors.** Operating errors (external data, expected) are parsed at the boundary and handled as known outcomes; programmer errors (internal invariants, unexpected) must crash — the only correct way to handle corrupt code. Assertions downgrade catastrophic correctness bugs into liveness bugs.
- **Assert through the language's real assertion mechanism**, one that throws or aborts and, where the type system allows, narrows the checked value downstream. Never a mechanism that only logs. Where the repo has a shared assert helper, use it; where it lacks one, mint it in a shared module on first use, never as per-package inline copies.
- **Assert arguments, return values, pre/postconditions, and invariants** — at least two assertions per function on average; a function must not operate blindly on data it has not checked.
- **Pair assertions.** Enforce each property on at least two code paths: assert validity before writing, and again after reading back.
- **Assert the positive space and the negative space** — what you expect, and what you expect never to happen; bugs live where data crosses the boundary between them.
- **Split compound assertions** — two assert calls, not one conjunction, so a failure says precisely which half broke; a single-line `if (a) assert(b)` asserts an implication.
- **Exhaustiveness is asserted twice.** Compile time: an exhaustive `match`/`switch` over the closed set, so a new variant is a compile error. Runtime backstop: an unreachable assertion in the fallthrough arm, so a value that escapes the compiler crashes instead of passing silently.
- **A blatantly-true assertion beats a comment** where an invariant is critical and surprising.
