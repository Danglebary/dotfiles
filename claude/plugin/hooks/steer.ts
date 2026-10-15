// Reads an auto-mode reminder and rewrites its steer, the paragraph that sends
// the model to Bash for reading and editing files. Everything here is pure, so
// each reminder Claude Code has rendered replays against it as a fixture.

import { assertCondition } from './assert'
import { STEER_REPLACEMENT } from './replacement'

/** What separates a reminder's paragraphs. */
const PARAGRAPH_SEPARATOR = '\n\n'
/** The phrase every recorded steer carries, the relaxed and the strict alike. */
const STEER_ANCHOR = 'read files with cat, head, or sed -n'
/** What a steer reworded past its anchor still names. */
const STEER_MARK = 'the Bash tool'
/** How each half of the wrapper Claude Code draws around a reminder ends. */
const WRAPPER_TAG_END = 'system-reminder>'

export const SteerKind = {
  rewritten: 'rewritten',
  absent: 'absent',
  unrecognized: 'unrecognized',
} as const
export type SteerKind = (typeof SteerKind)[keyof typeof SteerKind]

type SteerPayloads = {
  [SteerKind.rewritten]: { readonly text: string }
  [SteerKind.absent]: Record<never, never>
  [SteerKind.unrecognized]: { readonly reason: string }
}

type SteerMember<K extends SteerKind> = { readonly kind: K } & SteerPayloads[K]

/** What came of reading a reminder: its steer rewritten, no steer in it, or a steer this module cannot place, and why. */
export type SteerOutcome = { [K in SteerKind]: SteerMember<K> }[SteerKind]

/** The reminder the model reads with its one steer paragraph replaced, or why it is read as it is. */
export function steerRewrite(text: string) {
  const paragraphs = text.split(PARAGRAPH_SEPARATOR)
  const anchored = anchoredIndexes(paragraphs)
  if (anchored.length === 0) {
    return unanchoredOutcome(text)
  }
  if (anchored.length > 1) {
    const repeated: SteerOutcome = {
      kind: SteerKind.unrecognized,
      reason: `its steer's anchor phrase stands in ${anchored.length} paragraphs`,
    }
    return repeated
  }
  const steerIndex = anchored[0]
  assertCondition(steerIndex !== undefined, 'one anchored paragraph has an index')
  const steer = paragraphs[steerIndex]
  assertCondition(steer !== undefined, `anchored index ${steerIndex} names a paragraph`)
  if (steer.includes(WRAPPER_TAG_END)) {
    const wrapped: SteerOutcome = {
      kind: SteerKind.unrecognized,
      reason: 'its steer paragraph carries the system-reminder wrapper',
    }
    return wrapped
  }
  const replaced = paragraphsReplaced(paragraphs, steerIndex)
  const rewrittenText = replaced.join(PARAGRAPH_SEPARATOR)
  assertCondition(replaced.length === paragraphs.length, 'the rewrite keeps every paragraph but the steer')
  assertCondition(!rewrittenText.includes(STEER_ANCHOR), 'the rewrite leaves no anchor behind')
  const rewritten: SteerOutcome = { kind: SteerKind.rewritten, text: rewrittenText }
  return rewritten
}

function anchoredIndexes(paragraphs: readonly string[]) {
  const indexes: number[] = []
  for (const [index, paragraph] of paragraphs.entries()) {
    if (paragraph.includes(STEER_ANCHOR)) {
      indexes.push(index)
    }
  }
  return indexes
}

function unanchoredOutcome(text: string) {
  assertCondition(!text.includes(STEER_ANCHOR), 'an unanchored reminder carries no anchor')
  if (text.includes(STEER_MARK)) {
    const reworded: SteerOutcome = {
      kind: SteerKind.unrecognized,
      reason: 'it names the Bash tool but carries no steer this mod recognizes',
    }
    return reworded
  }
  const absent: SteerOutcome = { kind: SteerKind.absent }
  return absent
}

function paragraphsReplaced(paragraphs: readonly string[], steerIndex: number) {
  assertCondition(Number.isSafeInteger(steerIndex), `steer index ${steerIndex} is an integer`)
  assertCondition(steerIndex < paragraphs.length, `steer index ${steerIndex} is below ${paragraphs.length}`)
  const replaced: string[] = []
  for (const [index, paragraph] of paragraphs.entries()) {
    if (index === steerIndex) {
      replaced.push(STEER_REPLACEMENT)
    } else {
      replaced.push(paragraph)
    }
  }
  return replaced
}
