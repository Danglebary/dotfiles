# Errors

- **All errors are handled.** No floating futures, no empty `catch`, no swallowed rejection — handle it or rethrow with context. Most catastrophic production failures trace to mishandled non-fatal errors (OSDI '14: 92%).
- **Don't throw for known outcomes.** An outcome the caller is expected to handle — not-found, validation declined, limit reached — is a return value the type system forces callers to branch on, never an exception. Throwing is reserved for the unexpected: programmer errors (assertions) and operating failures no caller in the chain can meaningfully handle.
- **HTTP exceptions are thrown only in controllers and middleware.** Domain and service code throws domain errors; the HTTP layer alone maps them to status-carrying exceptions. An HTTP exception type imported below the controller layer is the smell — it couples business logic to one transport and breaks reuse from queues, jobs, and other entry points.
