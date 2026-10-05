# Git

- **Git commands run sequentially, never in parallel.** Never place more than one git command across the parallel tool calls of a single batch — concurrent git processes race on `.git/index.lock`.
- **`index.lock` failures: retry, don't investigate.** The lock is almost always transient and self-clears. Wait briefly and retry once; only if it persists, verify no git process is running, then remove the stale lock. Don't re-derive this diagnosis or treat it as repo corruption.
- **Never use `--no-verify` to bypass git hooks.**
- **Never force push to main/master.**
- **Pushed history is immutable; unpushed history is mine to tidy.** A commit that has been pushed, or that anything else has been based on, is fixed: correct it with a new commit. Amending the latest unpushed commit to fix its message or fold in a file it was missing is fine. Squashing, rebasing, or reordering commits — including a squash-merge — happens only when I ask for it in so many words, never on your own initiative.
- **Merging is gated on my go-ahead, every time.** Offer a merge when the work is ready, and run it when I say so — never on your own judgment, and a go-ahead for one merge does not carry to the next. The `permissions.ask` rule for `gh pr merge` in `base/settings.json` is the mechanical backstop: the harness prompts before the command runs whatever the session's permission mode.
