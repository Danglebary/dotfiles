/** Thrown when an invariant of this plugin's own code fails. */
export class AssertionError extends Error {
  override name = 'AssertionError'
}

/** Throws an `AssertionError` carrying `message` unless `condition` holds, and narrows it where it does. */
export function assertCondition(condition: unknown, message: string): asserts condition {
  if (condition) {
    return
  }
  throw new AssertionError(message)
}

/** Throws for a value the compiler has proven cannot exist, naming it unless `message` says otherwise. */
export function unreachable(value: never, message?: string): never {
  if (message === undefined) {
    throw new AssertionError(`unreachable value: ${JSON.stringify(value)}`)
  }
  throw new AssertionError(message)
}
