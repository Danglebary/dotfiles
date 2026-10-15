// Goal: pin what the model reads of an auto-mode reminder once the mod is
// loaded, and what the person is told when the mod leaves one unchanged.
// Methodology: each test raises `prompt.attachment` through the engine with a
// hook beneath the mod standing in for Claude Code's core, which answers the
// text that reaches it; the toasts are read from a fake that keeps their text.

import type { EngineInterface, PromptAttachmentInput } from 'claude-code'
import { expect, test } from 'claude-code/testing'

import { STEER_REPLACEMENT } from '../hooks/replacement'

const HEADING = 'While auto mode is active:'
const STRICT_STEER =
  'Do your work through the Bash tool wherever it can accomplish the job: read files with cat, head, or sed -n, search with grep and find, and make file changes with sed, heredocs, or short scripts, rather than using the dedicated Read, Edit, or Write tools. Fall back to a dedicated tool only when Bash genuinely cannot do the job.'
const REWORDED_STEER = 'Do your work through the Bash tool wherever it can accomplish the job.'

/** Stands in for Claude Code's core, which answers the text that reaches it. */
async function coreAnswer(_engine: EngineInterface, e: PromptAttachmentInput) {
  return { text: e.text }
}

test('the model reads the replacement in place of the steer', async ($, on) => {
  on('prompt.attachment', coreAnswer)

  const read = await $.prompt.attachment({
    type: 'auto_mode',
    text: `${HEADING}\n\n${STRICT_STEER}`,
    origin: { kind: 'engine' },
  })

  expect(read.text).toBe(`${HEADING}\n\n${STEER_REPLACEMENT}`)
})

test('a reminder of another type reaches the model as it is', async ($, on) => {
  on('prompt.attachment', coreAnswer)

  const read = await $.prompt.attachment({
    type: 'todo_reminder',
    text: `${HEADING}\n\n${STRICT_STEER}`,
    origin: { kind: 'engine' },
  })

  expect(read.text).toBe(`${HEADING}\n\n${STRICT_STEER}`)
})

test('a steer the mod does not recognize reaches the model as it is, and a toast says so', async ($, on) => {
  const toasts: string[] = []
  on('prompt.attachment', coreAnswer)
  on('ui.toast', async (_$, e) => {
    toasts.push(e.text)
    return { value: undefined }
  })

  const read = await $.prompt.attachment({
    type: 'auto_mode',
    text: `${HEADING}\n\n${REWORDED_STEER}`,
    origin: { kind: 'engine' },
  })

  expect(read.text).toBe(`${HEADING}\n\n${REWORDED_STEER}`)
  expect(toasts).toEqual([
    'dotfiles: the auto-mode reminder reached the model unchanged, because it names the Bash tool but carries no steer this mod recognizes.',
  ])
})
