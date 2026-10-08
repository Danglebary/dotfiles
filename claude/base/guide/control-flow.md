# Control flow

- **Only simple, explicit control flow.** Use a minimum of excellent abstractions, and only where they make the best sense of the domain — every abstraction risks leaking.
- **Prefer iteration; recursion only with an explicitly asserted depth bound.** Every execution that should be bounded must be bounded.
- **Put a limit on everything.** Every loop, queue, cache, batch, accumulator, and retry has an explicit upper bound; every await on an external system has a timeout. A loop that must not terminate (an event loop) asserts that intent. Fail fast on violations.
- **Split compound conditions** into nested `if/else` trees, and consider whether each `if` needs a matching `else` — handle or assert the negative space.
- **Every branch and loop body is a braced block**, a one-line body included. A braceless body is one statement wide, and a second statement indented beneath it runs unconditionally — the `goto fail;` defect — so braces keep the indentation honest.
- **State invariants positively** (`index < length`, with the `else` branch for the violation), never as negations.
- **70 lines per function, hard limit.** A function fits on a screen. When splitting, centralize control flow and state in the parent — push `if`s up, push `for`s down; helpers compute, parents decide and mutate; keep leaf functions pure.
- **Run at your own pace; never react directly to external events.** Queue work and drain it on your own terms — control flow stays yours, work per period stays bounded, and batching becomes possible.
