---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: database access

- **Pagination is an async generator.** An `async function*` yields rows page by page over Performance's keyset walk; consumers `for await` and break when done, so memory stays bounded regardless of result-set size. Underneath, the cursor is a row-value comparison against the last row seen (`WHERE (createdAt, id) > (:createdAt, :id) … LIMIT n`) ordered by a stable sort key plus a unique tiebreaker (`ORDER BY createdAt, id`), backed by a composite index matching that order. `LIMIT`/`OFFSET` is the fallback for when no stable cursor key exists or random page access is genuinely required.
- **Prefer raw SQL through the ORM over entities.** Write the query as SQL executed via the ORM's raw surface (`dataSource.query`, a QueryBuilder's raw execution) rather than through entity APIs — the SQL that runs is the SQL you read: no hydration, lazy-loading, or generated-join surprises, and the query's cost stays visible at the call site. Raw rows cross into the process as `unknown` and are narrowed by `assertSchema` — an asserted shape over an entity type's claim.
- **TypeORM rendering, where entity APIs are in play:** an id-ordered walk is `MoreThan(lastId)` with `order` + `take`; a composite cursor needs a QueryBuilder with a raw row-value `WHERE` (TypeORM has no tuple operator). With joined relations always paginate via `take`/`skip`, never `limit`/`offset` — the latter truncate raw joined rows and corrupt entity hydration.
- **A collection's shape is settled by the consumers that outlive the guard.** Once membership testing moves into a predicate, "array or `Set`?" stops being a question about every call site and becomes a narrow one about whatever still reads the data — and at a boundary that answer is forced rather than stylistic. An ORM operator or a driver bind is a wire format: TypeORM's `In<T>(value: readonly T[] | FindOperator<T>)` rejects a `Set` at compile time, and `pg`'s `prepareValue` dispatches on `Array.isArray`, so a `Set` reaching a bind parameter falls through to `JSON.stringify` and arrives as `{}` — an empty array that makes `= ANY($1)` silently always false. Reach for a `Set` where the collection is large, membership is hot, or set semantics are load-bearing; on a three-element constant that crosses into SQL the wire format decides, and it decides for the array. Valid keeps the three-element constant an array where it crosses into SQL:

  ```ts
  const activeStatuses = ["active", "pending"] as const satisfies readonly Status[];

  await dataSource.query("SELECT * FROM accounts WHERE status = ANY($1)", [
    activeStatuses,
  ]);
  ```

  Invalid reaches for a `Set` at the same boundary, and the bind silently degrades:

  ```ts
  const activeStatuses = new Set<Status>(["active", "pending"]);

  // pg's prepareValue dispatches on Array.isArray; a Set falls through to
  // JSON.stringify and arrives as "{}" — `= ANY($1)` is silently always false.
  await dataSource.query("SELECT * FROM accounts WHERE status = ANY($1)", [
    activeStatuses,
  ]);
  ```
