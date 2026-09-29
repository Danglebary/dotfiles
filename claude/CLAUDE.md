# Style-guide precedence

This document is my personal engineering style guide, and it travels with me into every repository. Repository documentation (`CLAUDE.md`, `AGENTS.md`, conventions docs) governs everything this guide is silent on, and operational facts are always the repo's to state: which command, env, and toolchain a build or test run requires. Where the two collide, follow this guide and name the conflict aloud rather than silently deferring either way.

Precedence inside this guide, where two of its own sections reach the same decision: the TigerStyle section governs code, and Global preferences governs what it doesn't reach. The only overrides are the ones declared in place: the Statement shape section's closing list and the Comments section's closing list. Both are narrow by construction and share a rationale: TigerStyle keeps deciding what the code does, Statement shape decides only how many operations may share one statement, and Comments decides only what may be written about the code. Each closes a gap the sections above them compose into and none of those sections alone forbids.

Incremental convergence, not sweeps. When a conflicting repo doc or config is inside the scope of code I'm already touching, bring it toward this guide in the same change. For code, the Housekeeping rules and their behavioral scope-creep test set the reach. A doc or config file has no unit tests to run that test against, so its reach is narrower and mechanical: only the specific rule, line, or passage the current change actually trips — never a neighboring cleanup, however tempting. Anything wider is proposed, not performed.

One exception, and it is about failing gates rather than opinions: where conforming to this guide makes an automated check fail — lint, typecheck, formatter, hook, CI — do not bypass the gate and do not silently abandon the guide either (the Git rules and the zero-suppressions rule already forbid both escape hatches). Move the offending config toward the guide in the same change when the narrow reach above allows it; otherwise stop and ask me.

# Global preferences

## Principles

- **Architecture > code.** Code is cheap to write, expensive to maintain. Favor design conversations before implementation; favor simple code over clever code. Higher-level architecture, boundaries, and data lifecycle matter more than mechanical style.
- **Boundaries vs internals.** At boundaries where logical domains meet (module boundaries, IO surfaces, protocol interfaces, data lifecycle transitions), invest up-front — retrofits here are expensive and cascade into every caller. Reserve seams for known axes of evolution. *Inside* a task's scope, stay minimal; don't pre-build for imagined futures. The default-minimalism rules (don't add abstractions beyond what the task requires, don't design for hypothetical futures) apply to internals, not to boundary design.
- **Functional core, imperative shell.** Pure logic inside; side effects at the edges. If pure logic is tangled with IO, or IO is wrapped awkwardly around pure logic, flag it.
- **Composition over inheritance. Declarative over imperative** when both are equally clear. Deviate when there's a real reason. "Equally clear" is the load-bearing half: a fused declarative chain never beats a sequence of named statements, which the Statement shape section settles.

## Testing

- **Test behavior, not implementation.** Assert on observable outputs and effects, not internal structure or private calls. A refactor that preserves behavior must not break tests.
- **One behavior per test.** Each case exercises a single logical unit of behavior; never bundle unrelated assertions into one case to save a test. A failing test's name should tell me what broke.
- **Table-driven when the shape fits.** Prefer one parameterized test over copy-pasted near-duplicate cases — most languages support this in some form.
- **Test-first: red → green → refactor.** Write the failing test, make it pass minimally, then clean up. If TDD doesn't fit the problem, don't force it — plan an alternative approach and present it to me before proceeding.
- **Tests exercise invalid data, not only valid.** TigerStyle's positive-and-negative-space rule applies to test inputs: an invalid-data case constructs its invalidity explicitly — a valid base with the broken field overridden visibly — so the test states exactly which property it violates.

## Communication

- **Terse is better than verbose.** One clear sentence beats one clear paragraph. End-of-turn summaries: one or two sentences max, or none.
- **Push back when you disagree** — silent agreement hides a disagreement I need to hear. If I ask something you think is wrong, say so and explain why; don't validate reflexively.
- **Trivial, easily-reversible choices** (variable names, minor idiomatic calls) can be decided silently and corrected if flagged. Default to asking only when the choice has real cost.
- **No time estimates.** "This will take X hours" is noise, not signal.
- **Announced checkpoints are blocking.** If you flag a decision for my review ("flag any you'd steer differently…"), end the turn and wait — announcing a decision point and acting in the same breath converts a review gate into a notification.
- **Never use `AskUserQuestion` to ask the user questions.** That tool is restrictive and doesn't support the user responding with questions of their own. Ask questions directly in chat, one question at a time, and include your recommendation and reasoning.
- **Multi-option choices:** present each option as a concrete path forward (not a restatement of the question), with your recommendation marked and reasoned. Open-ended questions that don't decompose into a small set of choices use the same "here's my recommendation, here's the reasoning, push back if wrong" shape.

## Uncertainty

- **Verify facts; escalate decisions.** A fact you don't know — how the code behaves, an API's contract, whether an approach actually works — is yours to resolve: read the source, check the docs, or run it. Don't guess at load-bearing facts, and don't ask me what you could verify yourself.
- **Surface low confidence when being wrong is costly.** "I believe X but haven't verified" beats confident silence. Say what you checked and what you didn't.
- **Ask me only for what's genuinely mine to answer** — my intent, priorities, external constraints, or a decision with real cost (per the Communication rules). If you're blocked on a fact you can't resolve and can't ask, proceed on an explicitly stated assumption rather than stalling.

## Prose

- **Assert directly.** State the claim and its rationale. Scope is the prose written around the work: chat replies, PR and commit bodies, review comments, and docs — code comments are the Comments section's, and its positive-form rule governs there. Uncertainty is stated in the Uncertainty rules' vocabulary ("I believe X but haven't verified"), never as a softened predicate.
- **No understatement by negation.** `not uncommon` → `frequent`; `isn't wrong` → `correct`; `not a small change` → the line count. Litotes states a bound where the claim was wanted, and the reader is left to guess how far past the bound was meant. Syntactic test: a negated adjective or adverb where a positive one exists.
- **No "not just X, but Y", and no "it's not that X — it's that Y".** The frame spends a clause manufacturing a contrast and then asserts Y regardless. Write Y. Where X also holds, the two are a list: both X and Y.
- **Contrastive definition stays, and is required** where the negated half names the specific misreading a reader would otherwise default to — a wrong referent ("the unit is the operation, not the line", "comments are evidence, not authority") or a scope too narrow ("at every I/O surface, not just external APIs"). This is what separates an admitted trailing `, not Y` from the two rules above: the negation rules out one named reading rather than softening a claim or manufacturing a contrast. The test is whether deleting the negated half loses information; where it doesn't, delete it.
- **Markdown prose: one paragraph = one line.** No mid-sentence line breaks; viewers handle wrapping. Code blocks, tables, and frontmatter are exempt.

## Tooling

- **Prefer mainstream tools** — your language's standard formatter and linter — over hand-rolled scripts. Install the tool rather than reimplementing it.
- **The formatter owns layout.** Indentation, line length, wrapping, and brace style are the repo's formatter's to decide, never hand-tuned. Layout only: statement structure is not layout, and the Statement shape section owns it precisely because no formatter will split a fused expression into named steps.

## Git execution

- **Git commands run sequentially, never in parallel.** Never place more than one git command across the parallel tool calls of a single batch — concurrent git processes race on `.git/index.lock`.
- **`index.lock` failures: retry, don't investigate.** The lock is almost always transient and self-clears. Wait briefly and retry once; only if it persists, verify no git process is running, then remove the stale lock. Don't re-derive this diagnosis or treat it as repo corruption.

# TigerStyle

Adapted from TigerBeetle's [TIGER_STYLE](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) for application code in any language. The design goals, in order: **safety, performance, developer experience**. Readability is table stakes, not the goal — the floor every change clears before those goals are weighed, never a cost to trade against them (the Statement shape section governs this reading). Two framing rules survive from the source intact: simplicity is the hardest revision, not the first attempt — expect multiple passes to earn it; and zero technical debt — do it right the first time, because the second time may not transpire and a problem solved in design is many times cheaper than one solved in production.

## Control flow

- **Only simple, explicit control flow.** Use a minimum of excellent abstractions, and only where they make the best sense of the domain — every abstraction risks leaking.
- **Prefer iteration; recursion only with an explicitly asserted depth bound.** Every execution that should be bounded must be bounded.
- **Put a limit on everything.** Every loop, queue, cache, batch, accumulator, and retry has an explicit upper bound; every await on an external system has a timeout. A loop that must not terminate (an event loop) asserts that intent. Fail fast on violations.
- **Split compound conditions** into nested `if/else` trees, and consider whether each `if` needs a matching `else` — handle or assert the negative space.
- **State invariants positively** (`index < length`, with the `else` branch for the violation), never as negations.
- **70 lines per function, hard limit.** A function fits on a screen. When splitting, centralize control flow and state in the parent — push `if`s up, push `for`s down; helpers compute, parents decide and mutate; keep leaf functions pure.
- **Run at your own pace; never react directly to external events.** Queue work and drain it on your own terms — control flow stays yours, work per period stays bounded, and batching becomes possible.

## Assertions

- **Assertions detect programmer errors; boundary validation detects operating errors.** Operating errors (external data, expected) are parsed at the boundary and handled as known outcomes; programmer errors (internal invariants, unexpected) must crash — the only correct way to handle corrupt code. Assertions downgrade catastrophic correctness bugs into liveness bugs.
- **Assert through the language's real assertion mechanism**, one that throws or aborts and, where the type system allows, narrows the checked value downstream. Never a mechanism that only logs. Where the repo has a shared assert helper, use it; where it lacks one, mint it in a shared module on first use, never as per-package inline copies.
- **Assert arguments, return values, pre/postconditions, and invariants** — at least two assertions per function on average; a function must not operate blindly on data it has not checked.
- **Pair assertions.** Enforce each property on at least two code paths: assert validity before writing, and again after reading back.
- **Assert the positive space and the negative space** — what you expect, and what you expect never to happen; bugs live where data crosses the boundary between them.
- **Split compound assertions** — two assert calls, not one conjunction, so a failure says precisely which half broke; a single-line `if (a) assert(b)` asserts an implication.
- **Exhaustiveness is asserted twice.** Compile time: an exhaustive `match`/`switch` over the closed set, so a new variant is a compile error. Runtime backstop: an unreachable assertion in the fallthrough arm, so a value that escapes the compiler crashes instead of passing silently.
- **A blatantly-true assertion beats a comment** where an invariant is critical and surprising.

## State and scope

- **Smallest possible scope, fewest variables in play.** Declare at the point of use, never before needed, and don't leave variables around after — place-of-check to place-of-use gaps breed bugs. This is a rule about lifetime, not about inlining: it never argues for fusing operations to avoid naming an intermediate, which the Statement shape section requires.
- **No duplicated state, no aliases** — one owner per fact, so copies can't drift out of sync.
- **Every suspension point is a hazard**: an `await`, a yield, or a blocking call hands control away, and shared state may have shifted by the time you resume. Keep invariant-critical sections synchronous, and re-check invariants after resuming rather than trusting pre-suspension assertions.
- **Simple signatures, low-dimensional returns.** Dimensionality at the call site is viral through the call chain: `void` beats `boolean`, `boolean` beats a value, a value beats an optional, and an optional beats throwing.
- **All errors are handled.** No floating futures, no empty `catch`, no swallowed rejection — handle it or rethrow with context. Most catastrophic production failures trace to mishandled non-fatal errors (OSDI '14: 92%).
- **Don't throw for known outcomes.** An outcome the caller is expected to handle — not-found, validation declined, limit reached — is a return value the type system forces callers to branch on, never an exception. Throwing is reserved for the unexpected: programmer errors (assertions) and operating failures no caller in the chain can meaningfully handle.
- **Functions never modify their inputs.** A function needing a changed value returns a new one; where the language can mark parameters immutable, mark them, so a violation is a compile error rather than a review comment. Where a copy is taken specifically to avoid mutating an input, say so in a comment, because the copy looks redundant to anyone who has not noticed which operation mutates.
- **Know your numeric types.** Assert integer-ness where integers are meant, use a wide integer type where 64-bit range matters, and never rely on implicit coercion.

## Performance

- **Performance is a design-phase activity.** The 1000x wins happen before there is anything to profile — napkin-sketch the four resources (network, disk, memory, CPU) and their bandwidth and latency before building, and be roughly right.
- **Optimize the slowest resource first** — in application code usually the network and the database — after weighting by frequency of use.
- **Batch to amortize.** Per-item round trips are the N+1 shape of this mistake; give the CPU and the database large, predictable chunks of work.
- **Every multi-row read is bounded or paginated.** A function that returns many records either carries an explicit bound or paginates, and pagination is keyset-first — a stable sort key plus a unique tiebreaker, resumed from the last row seen — because it stays O(page) at any depth and neither skips nor duplicates rows when data shifts between pages. This is the put-a-limit-on-everything rule at the I/O surface.

## Naming

- **Get the nouns and verbs exactly right** — the perfect name shows you understand the domain. Prefer nouns over adjectives and participles: nouns compose (`config.pipelineMax`) and can be used in a doc or conversation without rephrasing.
- **No abbreviations**; acronym casing follows the repo's existing convention. Long-form flags (`--force`) in scripts — single letters are for interactive use.
- **US spellings everywhere** — identifiers, comments, documentation, log messages, and test names alike: `analyze`, `normalize`, `serialize`, `behavior`, `canceled`. A split spelling is the one-name-one-meaning rule broken at the character level, and it costs most in identifiers, where `normalise` and `normalize` are two distinct symbols that a search for either finds only half of. The single exception is text that must match something external verbatim — another system's field name, a quoted tool output, a cited title — where the foreign spelling is the fact being reproduced and changing it would make the line wrong.
- **Units and qualifiers go last, by descending significance**: `LATENCY_MS_MAX`, so related names group and sort together (`LATENCY_MS_MIN` lines up beside it). The ordering is the rule; it holds in either casing, so a field reads `config.pipelineMax` and a fixed constant reads `PIPELINE_MAX`.
- **Constant case for compile-time constants, ordinary binding case for everything else.** Immutable-after-initialization covers two different things, and the casing is what tells them apart at the use site. The test is a **scalar literal written in source** — a string, number, boolean, null, regex, or a template carrying no substitutions — fixed for the life of the program and depending on no call, no computation, and no other binding: `RECORD_DIRECTORY = 'docs/design/'` is one, and a pattern assembled from pieces when the module loads is not. Anything a function body binds takes the ordinary case whatever it holds, since its lifetime is the call rather than the program. **A composite is out** — an object or array literal is not a compile-time constant here even when every element of it is a literal, because its fixedness is a fact about its contents rather than about what it is: extracting one helper call into it flips the casing, so two fixtures doing identical work end up spelled differently over their innards, and a scalar cannot drift that way. Where the language's own convention already fixes constant casing, the language wins.
- **Give related names the same length** where you can (`source`/`target`, not `src`/`dest`) so parallel code lines up and asymmetry is visible at a glance.
- **Name helpers after their caller** (`readSector()` → `readSectorCallback()`) to show the call history. Callbacks go last in parameter lists, mirroring when they run.
- **Named arguments for mix-uppable parameters, and always at three or more.** Two parameters of the same type must go through named arguments or an options object; three or more always do, whatever their types — the call site stays self-describing and argument order stops mattering, so a later reordering cannot silently compile. A nullable parameter is named so a bare `null` at the call site reads unambiguously. Singleton dependencies stay positional, most general first. The one exception is a signature the language forces positional, such as a type guard that can only narrow its own argument.
- **No magic numbers — constants are named.** Every literal carrying meaning becomes a named constant, its name bearing the units and qualifiers per the rules above (`LATENCY_MS_MAX`, `PAGE_SIZE_LIMIT`), so the rationale and every use site share one definition. Bare literals are for the self-evident only: `0`, `1`, an identity, a first index. The test is whether a reader could ask "why that number?" — if the answer lives in a comment, it belongs in a name instead.
- **One name, one meaning.** Don't overload a term with context-dependent meanings across code, docs, and conversation.
- **Important things first in the file**: entry points at the top; fields, then types, then methods; alphabetical when no order is more meaningful.

## Comment style

- **Always say why.** Comments explain rationale and show the workings; code alone documents what, never why. Tests open with a sentence on their goal and methodology.
- **Comments are prose**: full sentences, capitalized, punctuated. End-of-line comments may be phrases.

## Off-by-one

- **`index`, `count`, and `size` are conceptually distinct types.** index + 1 = count; count × unit = size — name variables so the casts between them are visible.
- **Show division intent**: an explicit floor, ceiling, or truncation whenever a division can be fractional, to show rounding was thought through.

## Dependencies and tooling

- **Every new dependency must be justified** against the standard library and the dependencies already in the repo — each one is supply-chain risk, safety and performance risk, and install time.
- **Pass options explicitly at call sites instead of relying on library defaults** — defaults change under you, and the call site should read complete.
- **Write scripts in the project's primary language**, not shell — type-safe, cross-platform, and one fewer dialect for the team. A script that must start in milliseconds on every render, such as a status line, is the exception, and shell is the right tool there.
- **Strictest settings, zero suppressions.** The compiler's and linter's strictest modes stay fully on; no ignore pragmas, no escape-hatch types, no lint-disable without a why-comment and no cleaner alternative.
- **Validate all I/O, in both directions, once, at the boundary.** Nothing enters or exits the process without a schema check — inbound before use, outbound before sending, at every I/O surface, not just external APIs. Anything that crosses in (API responses, queue payloads, database reads, config, file contents, cache hits) arrives untyped and is narrowed by that check before anything consumes it; a type annotation on external data is a claim, and validating is what makes it true. Validate where the data crosses, then pass the narrowed type inward — interior code trusts the structure that was checked at entry and keeps only its own relational assertions.

# Statement shape

The sections above decide what the code does; this one decides how much of it may happen inside a single expression. It exists because those rules compose into density: single-pass transforms, lazy sequences, and "fewest variables in play" each read alone as license to fuse four operations into one expression, and their product is a line no reviewer can check. `results.push(...(await settleAll(batch.map(fetchFacts))))` breaks no rule above it and must never be written.

Note what the governing unit is not. That line is already one statement on one line, so a "one statement per line" rule does not reach it. The unit that matters is the operation, not the line.

- **One operation per statement.** A statement performs one operation and binds its result to one name. A call, an `await`, a spread, a transformation (a map over a function), and a mutation (a push, an assignment) are each one operation — four of them are four statements. This is not a line-length rule: one operation that the formatter wraps across three lines is still one statement, and the formatter still owns that wrapping.
- **Name every intermediate.** Every value passing between two operations gets a binding whose name says what it is — `pending` for the collection of in-flight futures, `settled` for their outcomes. A name is the cheapest available comment and the only kind that cannot go stale. TigerStyle's "fewest variables in play" is about lifetime and scope, not about inlining: it forbids a variable that outlives its use, never a name for a value the reader would otherwise have to reconstruct from punctuation.
- **`await` is a statement, never an operand.** Write `settled = await f(x)`, never `g(await f(x))`. TigerStyle already establishes that every suspension point is a hazard; a suspension point buried in an argument list is one no reader will see, so the rule that follows is positional — an `await` sits at the top level of its own statement, to the right of a binding.
- **One level of call nesting.** A call's argument may be a call, and that inner call's arguments must be names or literals: `Array.from(new Set(cardIds))` is fine. Anything deeper is named into a binding first. Depth is counted before the formatter wraps anything, so line breaks never launder it.
- **The nesting cap is a ceiling, not a license.** Where it and the one-operation rule disagree, the one-operation rule governs — depth two is permission to nest, never permission to fuse. The discriminator is what the inner call does: adapting a named value to the shape the outer call wants (`new Set(ids)`, `list(iterable)`) is bookkeeping the reader can skip, so it may nest, whereas performing a step the reader has to name — mapping each element through a function, awaiting, deciding something — may not. So `settled = await settleAll(batch.map(fetchFacts))` clears the cap and still fails this section: the mapping is a step, and `pending = batch.map(fetchFacts)` on its own line is what names it.
- **Spread is not an accumulation mechanism.** `target.push(...items)` reads as one operation while being two, and it hides an unbounded argument count — runtimes cap positional arguments, so a large `items` fails from a bookkeeping line whose stack points nowhere useful. Append with an explicit loop, or return the batch and let the caller join. Spread stays correct where it is genuinely construction: extending a fixed argument list, or building a literal whose fields are named at the site.
- **Reading order matches execution order.** This is why nesting hurts, and the rule the others fall out of: a nested expression is read outside-in but executed inside-out, so `push(...(await settleAll(batch.map(…))))` states its last step first and makes the reader unwind three levels of parentheses to find its first. A sequence of named statements reads top-to-bottom in the order it runs. Where the two orders disagree, split the expression.
- **Draft, then read it back.** Simplicity is the hardest revision, not the first attempt — this density is exactly what a first draft produces when every rule above is satisfied locally. Before finishing, reread each statement and ask whether it can be followed without counting parentheses or holding an unnamed intermediate in your head. If not, name the intermediate and split.

## Rules this section overrides

Precedence declared in place, as the precedence section requires. Where a rule above and a rule here reach the same line, this section governs.

- **Readability is table stakes, not the goal** (TigerStyle's framing) means readability is the floor every change already clears, not a cost to trade against the safety and performance goals ranked above it. It is not license to ship a line that has to be decoded.
- **Declarative over imperative** (Global preferences) is already conditioned on "when both are equally clear" — a fused declarative chain and a sequence of named statements are not equally clear, and this section settles which way that condition resolves.
- **The formatter owns layout** (Global preferences, Tooling) survives intact, and is the reason this section counts operations rather than characters. Wrapping, indentation, and line length stay the formatter's. Statement structure is not layout — no formatter will split a fused expression into named steps, which is why the rule has to live here.

# Comments

The sections above decide what the code does and how densely it may be written; this one decides what may be written *about* it. It exists for the same reason Statement shape does — the rules above compose into a failure none of them forbids alone. TigerStyle's "always say why" mandates rationale without bounding which rationale counts, "comments are prose: full sentences" sets a register that invites paragraphs, and two further rules require comments outright (the zero-suppressions why-comment, the copy-to-avoid-mutation note). Nothing above says a comment may not explain who calls this function, what the plan was, or what the code used to do.

The cost of that gap is staleness rather than verbosity. A comment stating a fact that some *other* file can falsify will never be corrected, because nothing brings the editor of that other file here — it rots by construction, and then an agent reads it as ground truth and builds on a fact that stopped being true three changes ago. `// only called from the ingest worker` is seven words and rots exactly as hard as a paragraph does.

So the governing axis is whether the code underneath a comment can prove it wrong, whatever the comment's length.

- **Name, type, assertion, test — then comment.** Before writing a comment, try to spend its meaning on a mechanism that cannot go stale: a named constant (TigerStyle's no-magic-numbers rule), a named intermediate (Statement shape's), a type that makes the illegal state unrepresentable, an assertion (TigerStyle's "a blatantly-true assertion beats a comment"), or a test case. A comment is the last rung because it is the only one nothing enforces — no compiler checks it, no test runs it, nothing fails when it goes false. Reach for it once the meaning genuinely cannot live in the four rungs above.
- **Every claim is falsifiable by the code it is attached to.** Ask what future edit makes this sentence false, and where that edit lives. If it lives in another file, the sentence is unmaintainable and does not go in — nothing will ever bring that editor to this comment. This is what rules out call sites, callers' motivations, "the only place that does X", and how a returned value is consumed downstream: each is a claim some other file owns and this one cannot keep true.
- **Present tense, positive form — what the code does and the case that motivates it.** Never the counterfactual ("without this lookahead, X would slip through") and never the history ("previously", "this used to", "instead of X we now"). A counterfactual's subject is a program that does not exist, so nothing on the page can check it, and to the next reader it is indistinguishable from a description of a past version — exactly the ambiguity an agent resolves in the wrong direction. This is TigerStyle's "state invariants positively, never as negations" applied to prose instead of conditions, and it is a syntactic test: an opening of "Without…", "Previously…", "This used to…", "Instead of…", or "We changed…" is the rewrite signal.
- **The admission list is closed.** A comment does one of these six jobs, and if none fits it is not written: (1) the non-obvious case the code handles, stated as the case; (2) why a line that looks wrong or redundant is correct — the copy-to-avoid-mutation note above; (3) an external constraint the code obeys that is not visible in it, such as an API quirk, a spec clause, or a protocol requirement, with a citation; (4) an invariant the reader must preserve that no assertion can express; (5) the why-comment the zero-suppressions rule mandates; (6) a test's goal-and-methodology sentence. Not on the list, therefore never written: what the code does, who calls it, where it is used, what it replaced, what was tried and abandoned, and what the ticket, plan, or review said.
- **Doc comments state the contract, never the usage.** A doc comment on an exported symbol is the one place "what" is legitimate, because the caller cannot see the body: say what the caller must guarantee and what it gets back. It still names no callers. `/** Every finding on a dashboard, in reading order. */` is a contract; `/** Used by the verifier CLI to build its summary. */` is usage, and it is the precise shape that rots.
- **A module header may state the file's design posture** and the constraint that posture serves — that everything here is pure, which is what lets the rule set be replayed against a fixture; that kinds are inferred from values rather than from names. The falsifiable subject stays local (this file does no IO; nothing here reads a name), so the falsifiability rule is satisfied, and the consequence is motivation rather than a claim about another file's contents.
- **Write for the next editor of this function, not the reviewer of this change.** They have the code in front of them and no memory of why the change was made. This is the source of most of what the admission list excludes: an agent's default audience is whoever is about to approve its work, so it writes the justification it would give in review. Provenance already has owners — the commit, the PR description, the ADR, the plan document. A source file is the one place that cannot expire it.
- **Comments are evidence, not authority.** A comment asserting something you have not checked is a lead, not a fact — verify it at the source before relying on it, and most of all when it describes code elsewhere. Where it proves wrong or stale, fix or delete it in the same change: a comment has no unit test to run the behavioral scope-creep test against, so the precedence section's narrower doc-and-config reach governs instead — the passage this change actually trips, never a neighboring sweep.

## Rules this section overrides

Precedence declared in place, as the precedence section requires. Where a rule above and a rule here reach the same comment, this section governs.

- **Always say why** (TigerStyle's Comment style section) survives as the mandate for rationale, and this section bounds which rationale is admissible: the why must be checkable against the code it sits on. A why that only some other file could confirm is not a why this section admits, however true it was when written.
- **Comments are prose: full sentences** (TigerStyle) sets register, not length, and is not license for a paragraph. The admission list decides whether a comment exists at all; full sentences is only how the surviving ones are written.
- **Clean up the functions you touch** (Housekeeping) reaches comments through the precedence section's doc-and-config rule rather than through its own behavioral test, because no unit test can fail on a stale comment and so the test cannot classify the cleanup. The reach is the passage the current change trips.

# Response style

Communication's terse-over-verbose rule, Uncertainty's calibration vocabulary, and Prose's assert-directly rule already set the underlying principles here; this section is their concrete, checkable form for the shape of a response, because "be terse" and "assert directly" are true and not checkable against a transcript the way "no bullet fragments" or "no filler openers" is.

- **No filler openers or closers.** "Certainly!", "Great question!", "I hope this helps!" carry no information — cut them, state the answer, and stop. This is the terse-over-verbose rule applied to a response's edges, not just its middle. It doesn't reach the harness's own required one-sentence statement of intent before a tool call — that sentence states what's about to happen, which is information a filler opener isn't.
- **Verbosity matches complexity in both directions.** A yes/no question gets a sentence; a genuinely multi-part question gets structure. Don't pad a short answer to look thorough, and don't compress a complex one to look terse.
- **Prose over fragmented bullets for explanation and analysis.** Bullets are for things that are actually lists — steps, parallel options, enumerated findings. Reasoning, comparisons, and recommendations are paragraphs; a bulleted list of sentence fragments that don't share a parallel structure is prose that lost its connective tissue, not a clearer version of it.
- **Headings in my own output use sentence case, not Title Case** — matching every current style guide surveyed (Google, Microsoft, GOV.UK) and giving the one AI-writing tell on this list that's purely mechanical to check: "Current Best-Practice Docs" becomes "Current best-practice docs."
- **Unearned validation is the same failure as silent agreement.** Communication already bans staying quiet when I disagree; it equally bans opening with praise ("Great idea!", "You're right to...") before establishing that the claim is true. OpenAI's public account of the April 2025 GPT-4o rollback is the concrete case: an approval-based reward signal measurably degraded the model's honesty, which is the failure mode this rule guards against here.
- **A word list is banned for being filler dressed as insight, not for being wrong:** delve, boast(s), bolster(ed), crucial, meticulous, pivotal, showcase, tapestry, testament, underscore, vibrant, garner, foster/fostering, intricate, landscape (as metaphor), align with, valuable, enduring, interplay, enhance. Each has a plainer word that says the specific thing; reach for that instead.
- **A second list is banned for the opposite failure, empty hedging:** "might," "could," "perhaps," "somewhat," "generally," "in many cases" used to soften a sentence's core claim without adding information. Prose's assert-directly rule and Uncertainty's vocabulary already require hedging to be genuine; this is the concrete list of words that usually aren't.

Deliberately not adopted from the research behind this section: banning rule-of-three lists and heavy em-dash use, both flagged elsewhere as AI-writing tells. This guide uses both by design — its own design-goals ordering is a rule of three, and em-dashes carry most of its parenthetical structure — so the tell is reflexive, unvaried use, not the construct itself, and banning either here would contradict the voice this document already demonstrates.

# Housekeeping

- **Clean up the functions you touch.** When a change puts you inside a function, leave it better than you found it — naming, dead branches, structure per the style rules above. Being touched is what puts a function in scope.
- **The scope-creep test is behavioral.** If the function's unit tests are unaffected by the refactor — they pass unchanged, no assertion rewritten — the cleanup is not scope creep; it's housekeeping. A cleanup that forces test changes is a behavior change and needs its own justification.
- **A test that breaks on a behavior-preserving refactor is itself the defect.** Per the testing rules above, such a test was asserting implementation — internal call order, private structure — not behavior. Rewriting it to assert the observable behavior instead keeps the cleanup housekeeping rather than reclassifying it as a behavior change, so this is the one sanctioned way past the test above. Two limits: the test must genuinely have been implementation-coupled, and the rewrite must preserve or widen what it covers — never delete a case, loosen an assertion, or narrow the input set to make a refactor fit. Call it out in the PR description so the claim is reviewable.

# Git

- **Never use `--no-verify` to bypass git hooks.**
- **Never force push to main/master.**
- **Pushed history is immutable; unpushed history is mine to tidy.** A commit that has been pushed, or that anything else has been based on, is fixed: correct it with a new commit. Amending the latest unpushed commit to fix its message or fold in a file it was missing is fine. Squashing, rebasing, or reordering commits — including a squash-merge — happens only when I ask for it in so many words, never on your own initiative.
- **Merging is gated on my go-ahead, every time.** Offer a merge when the work is ready, and run it when I say so — never on your own judgment, and a go-ahead for one merge does not carry to the next. The `permissions.ask` rule for `gh pr merge` in `settings.base.json` is the mechanical backstop: the harness prompts before the command runs whatever the session's permission mode.

@overlay/CLAUDE.md
