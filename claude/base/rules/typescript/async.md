---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: async

- **`Promise.allSettled` over `Promise.all`, always.** When awaiting multiple promises, collect every outcome as data: `Promise.all` short-circuits on the first rejection — in-flight siblings are abandoned, their rejections vanish unhandled, and all but one failure is hidden. `allSettled` hands back each result for an explicit fulfilled/rejected branch — the `safeParse` of concurrency.
- **`return await`, never a bare `return` of a promise.** An async function that hands a promise to its caller awaits it first, so the function's own frame is still live when that promise settles. The bare form drops the frame and takes two things with it. A rejection inside a `try` reaches no `catch` on the way out — `try { return failing(); } catch { return "recovered"; }` rejects where `return await failing()` resolves with `"recovered"` — and a `finally` runs at the `return` rather than at the settlement, so cleanup lands while the work it guards is still in flight. And a rejection arriving after a suspension point carries a stack naming the callee and the caller with the returning function missing between them, which is the frame an investigation needs. Each verified on Node v24.19.0; one microtask is the whole cost, and Principles rank safety above performance.
- **Prefer `node:timers/promises` when available** (server-side code): `setTimeout`/`setInterval`/`scheduler.wait` from it are awaitable and `AbortSignal`-aware — no hand-rolled `new Promise(resolve => setTimeout(resolve, ms))` wrappers, and cancellation composes instead of leaking timers. It is the cancelable sleep External APIs' backoff rule asks for.
