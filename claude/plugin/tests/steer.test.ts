// Goal: pin what the model reads in place of each auto-mode reminder Claude Code
// renders. Methodology: each row hands `steerRewrite` a reminder's text and
// compares the outcome whole. The valid rows are the reminders as recorded in
// session transcripts, and each invalid row breaks one of them in the one way
// its name says.

import { expect, test } from 'claude-code/testing'

import { STEER_REPLACEMENT } from '../hooks/replacement'
import type { SteerOutcome } from '../hooks/steer'
import { SteerKind, steerRewrite } from '../hooks/steer'

const HEADING = 'While auto mode is active:'
const RELAXED_STEER =
  'You can do much of your work through the Bash tool when it is the simpler route: read files with cat, head, or sed -n, search with grep and find, and make small, mechanical file changes with sed, heredocs, or short scripts instead of the dedicated Read, Edit, or Write tools. The choice is yours: prefer Edit or Write when a shell edit would be fragile, such as exact or multi-line replacements, or sed/awk flags that differ between GNU and BSD/macOS.'
const STRICT_STEER =
  'Do your work through the Bash tool wherever it can accomplish the job: read files with cat, head, or sed -n, search with grep and find, and make file changes with sed, heredocs, or short scripts, rather than using the dedicated Read, Edit, or Write tools. Fall back to a dedicated tool only when Bash genuinely cannot do the job.'
const FULL_REMINDER =
  "## Auto Mode Active\n\nBias toward working without stopping for clarifying questions — when you'd normally pause to check, make the reasonable call and keep going; they'll redirect you if needed. If the user, a skill, or the shape of the task suggests they want you to ask (with AskUserQuestion or otherwise), do so. And even absent that signal, it's still fine to stop when you're genuinely blocked — unclear direction, missing input, a decision only they can make.\n\nBefore any command that could discard uncommitted work — `git checkout`/`restore`/`reset`/`clean`, `rm -rf` in the repo, restoring from a snapshot — run `git status` first and stash (with `-u` for untracked) or commit anything that's there. When staging or committing, review what's included (`git status` after a broad `git add`), and if you see anything suspicious that might reveal secrets — even if the filename looks innocuous — double-check the file's contents before pushing."

const RELAXED_REMINDER = `${HEADING}\n\n${RELAXED_STEER}`
const STRICT_REMINDER = `${HEADING}\n\n${STRICT_STEER}`
const REWRITTEN_REMINDER = `${HEADING}\n\n${STEER_REPLACEMENT}`

const ROWS: readonly { name: string; text: string; outcome: SteerOutcome }[] = [
  {
    name: 'the relaxed steer is replaced under its heading',
    text: RELAXED_REMINDER,
    outcome: { kind: SteerKind.rewritten, text: REWRITTEN_REMINDER },
  },
  {
    name: 'the strict steer is replaced under its heading',
    text: STRICT_REMINDER,
    outcome: { kind: SteerKind.rewritten, text: REWRITTEN_REMINDER },
  },
  {
    name: 'the full reminder carries no steer and passes as it is',
    text: FULL_REMINDER,
    outcome: { kind: SteerKind.absent },
  },
  {
    name: 'an empty reminder carries no steer',
    text: '',
    outcome: { kind: SteerKind.absent },
  },
  {
    name: 'a steer reworded around its anchor is not recognized',
    text: RELAXED_REMINDER.replace('read files with cat, head, or sed -n', 'read files with cat or head'),
    outcome: {
      kind: SteerKind.unrecognized,
      reason: 'it names the Bash tool but carries no steer this mod recognizes',
    },
  },
  {
    name: 'a reminder whose anchor stands in two paragraphs is not recognized',
    text: `${RELAXED_REMINDER}\n\n${STRICT_STEER}`,
    outcome: { kind: SteerKind.unrecognized, reason: "its steer's anchor phrase stands in 2 paragraphs" },
  },
  {
    name: 'a steer that carries the reminder wrapper is not recognized',
    text: `<system-reminder>\n${RELAXED_REMINDER}\n</system-reminder>`,
    outcome: { kind: SteerKind.unrecognized, reason: 'its steer paragraph carries the system-reminder wrapper' },
  },
]

for (const row of ROWS) {
  test(`when the reminder is read, ${row.name}`, () => {
    expect(steerRewrite(row.text)).toEqual(row.outcome)
  })
}
