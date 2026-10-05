# Testing

- **Test behavior, not implementation.** Assert on observable outputs and effects, not internal structure or private calls. A refactor that preserves behavior must not break tests.
- **One behavior per test.** Each case exercises a single logical unit of behavior; never bundle unrelated assertions into one case to save a test. A failing test's name should tell me what broke.
- **Table-driven when the shape fits.** Prefer one parameterized test over copy-pasted near-duplicate cases — most languages support this in some form.
- **Test-first: red → green → refactor.** Write the failing test, make it pass minimally, then clean up. If TDD doesn't fit the problem, don't force it — plan an alternative approach and present it to me before proceeding.
- **Tests exercise invalid data, not only valid.** Assertions' positive-and-negative-space rule applies to test inputs: an invalid-data case constructs its invalidity explicitly — a valid base with the broken field overridden visibly — so the test states exactly which property it violates.
