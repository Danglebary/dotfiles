# Tooling

- **Prefer mainstream tools** — your language's standard formatter and linter — over hand-rolled scripts. Install the tool rather than reimplementing it.
- **The formatter owns layout.** Indentation, line length, wrapping, and brace style are the repo's formatter's to decide, never hand-tuned. Layout only: statement structure is not layout, and the Statement shape section owns it precisely because no formatter will split a fused expression into named steps.
- **Every new dependency must be justified** against the standard library and the dependencies already in the repo — each one is supply-chain risk, safety and performance risk, and install time.
- **Pass options explicitly at call sites instead of relying on library defaults** — defaults change under you, and the call site should read complete.
- **Write scripts in the project's primary language**, not shell — type-safe, cross-platform, and one fewer dialect for the team. A script that must start in milliseconds on every render, such as a status line, is the exception, and shell is the right tool there.
- **Strictest settings, zero suppressions.** The compiler's and linter's strictest modes stay fully on; no ignore pragmas, no escape-hatch types, no lint-disable without a why-comment and no cleaner alternative.
