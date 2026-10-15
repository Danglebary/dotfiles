// The imperative shell: the hook that hands the model the auto-mode reminder
// with its steer rewritten, and the toast for a reminder left as it is.

import type { Register } from 'claude-code'

import { unreachable } from './assert'
import { SteerKind, steerRewrite } from './steer'

const TOAST_OPENING = 'dotfiles: the auto-mode reminder reached the model unchanged, because'

export const register: Register = on => {
  on('prompt.attachment', { type: 'auto_mode' }, async ($, e, next) => {
    const outcome = steerRewrite(e.text)
    switch (outcome.kind) {
      case SteerKind.rewritten:
        return await next({ ...e, text: outcome.text })
      case SteerKind.absent:
        return await next(e)
      case SteerKind.unrecognized:
        $.ui.toast(`${TOAST_OPENING} ${outcome.reason}.`)
        return await next(e)
      default:
        outcome satisfies never
        return unreachable(outcome)
    }
  })
}
