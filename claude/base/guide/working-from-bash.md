# Working from Bash

The harness routes file changes to the shell, so the shell is where the instrument gets chosen. These rules choose it.

## Changing a file

- **A change to an existing file made from Bash goes through `splice`, and no other in-place editor is reached for.** `splice` applies literal, count-checked hunks across files, writes every file or none, and is silent on success. `sed -i`, `perl -i`, `awk -i inplace`, and a Python or Node script that reads a file and writes it back are the shapes it replaces. The splice plugin's guard blocks each of them from Bash and its refusal carries an example, so there is nothing to look up at the moment of use, and `splice --help` is the whole grammar.
- **A hunk matches exactly once unless its header says otherwise.** `@@` refuses zero matches and refuses two or more, reporting every line it found. A guard that only checks presence passes on an anchor occurring five times, and a blanket replacement then rewrites all five: an identifier rename done that way once hit two symbols belonging to another module, and the typechecker, the unit tests, and the linter all passed over the result. Where an anchor is genuinely ambiguous, extend it with surrounding context lines.
- **A deliberate multiple match declares itself.** `@@ all` changes every match, and `@@ count N` refuses any number of matches but N, which makes it the form to reach for whenever the number is known. Both count per file, so a hunk shared by several `===` paths is checked against each file on its own.
- **A pattern rewrite is `@@ regex`, with its count declared where it is known.** A Python substitution and `sed s///g` report nothing about how many sites they changed, and a regex rewrite over 17 sites once dropped a trailing comma and broke the file. A declared count refuses a batch that matched more or fewer sites than intended, before anything is written.
- **Nothing is written unless every hunk in every file matches.** A refusal exits 1 and a malformed script exits 2, both with the tree untouched, so there is no half-applied batch to unwind. One invocation carrying every hunk is the right size for a change that spans files, and a check chained after it with `&&` runs only on a batch that landed.
- **A line number constrains a content match and never addresses a line on its own.** `@@ line N` refuses unless the hunk's lines match starting at line N, so a line taken from a compiler error still names the content it points at. Every hunk matches the file as it stood before any hunk applied, so line numbers from one read stay valid across a batch.
- **Trust the exit status; do not `cat`, `sed -n`, or `grep` the region back.** A hunk that did not match as declared wrote nothing, so exit 0 means every hunk landed as written. `--diff` prints what was written, for the case where the rendered change is itself the question — an `all`, `inline`, or `regex` hunk across many lines — and `--dry-run` prints the same diff and writes nothing. A passing linter or test run answers a different question: that the file still compiles, not that the edit was the intended one.
- **A temporary edit is `splice try`, never an edit, a run, and a revert by hand.** `splice try -- COMMAND` applies the script, runs the command, and restores every file the script touched, whatever the command's status. A mutation test passes `--expect-fail`, which exits 0 when the command fails and 4 when it passes, so a test that does not catch the mutation fails the step.

## What stays in Bash

- **`cat > path <<'EOF'` creates a file and `cat >> path <<'EOF'` appends to one**, and the guard lets both through. `splice` carries the same two writes as `@@ create`, which refuses a path that already exists, and `@@ append`, whose `jsonl` form checks that each line is JSON. Reach for those where the write belongs to a batch that must land whole, or where overwriting an existing file would be the failure.
- **A value computed at run time reaches the script through the heredoc.** An unquoted `<<EOF` lets the shell substitute a variable into a `+` line. A script that carries any other `$` or a backtick is written to a file with the value substituted, and passed as `--script PATH`, so nothing else in it is expanded.

## Common operations

Every hunk line opens with its marker in column 0: a space for a context line, `-` for a removed one, `+` for an added one, and `~` for any run of lines.

```bash
# One hunk, with the check chained so it runs only on an edit that landed.
splice <<'EOF' && pnpm run test:unit src/services/planning/
=== src/services/planning/gather.ts
@@
-const settled = await Promise.all(pending);
+const settled = await Promise.allSettled(pending);
EOF

# A phrase changed mid-line in two files, every occurrence, with the written diff printed.
splice --diff <<'EOF'
=== README.md
=== AGENTS.md
@@ inline all
-docs/ops.md
+docs/operations.md
EOF

# A computed value substituted into an unquoted heredoc.
version=$(jq --raw-output .version package.json)
splice <<EOF
=== deploy/values.yaml
@@
-image_tag: latest
+image_tag: "$version"
EOF

# A mutation the suite must catch; the file is restored whatever the result.
splice try --expect-fail -- pnpm run test:unit src/auth/ <<'EOF'
=== src/auth/session.ts
@@
-  assertCondition(token.expiresAt > now, 'expired token reached the cache');
EOF
```
