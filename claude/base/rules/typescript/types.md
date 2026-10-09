---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: types

- **Strictest settings, in TypeScript.** `tsconfig` strict stays fully on, and Tooling's zero-suppressions rule covers `@ts-ignore`, `@ts-expect-error`, and `any`.
- **`number` is a double.** Assert integer-ness where integers are meant (`z.int()`, `Number.isSafeInteger`), use `bigint` where 64-bit range matters, and never rely on implicit coercion.
- **Prefer `as const` over `interface`/`type` declarations** where a concrete value can carry the shape — define the value `as const` and derive the type from it, instead of declaring the type separately.
- **`type` exclusively; never `interface`.** Prefer union types when an `as const` derivation isn't appropriate; object shapes are `type` declarations too. The one exception is the language's rather than a preference: inside a module augmentation (`declare module "…"`) or `declare global`, declaration merging into an existing type is only expressible as an `interface`, and a `type` of the same name raises TS2300 against the declaration it means to extend. A `declare namespace` outside those two contexts declares a new namespace rather than merging into one, and gets no exception.
- **Never `enum`.** Use an `as const` object and derive the value union from it (`(typeof Level)[keyof typeof Level]`) — it erases cleanly and composes with the `as const` rule.
- **Discriminated unions are keyed by `kind`.** Every union's discriminant property is `kind` — never `type`, `status`, or `tag`, and never a per-module choice: `type` is the language's own word for the static type and the keyword that declares one, so a tag named `type` overloads the term (Naming's one-name-one-meaning rule), and a `status` here with a `tag` there spells one construct two ways. One name means a `switch` on the discriminant reads the same everywhere. Errors' known outcomes are returned as such a union, which the type system forces callers to branch on.
- **A union's kinds are declared once as an `as const` object, and every site reads its literals off that object.** Derive the kind union from it exactly as the never-`enum` rule derives one, then spell payload-map keys as `[LookupKind.found]`, constructions as `{ kind: LookupKind.found, account }`, and `switch` arms as `case LookupKind.found:`. The forcing constraint is widening, wherever no contextual type reaches the literal: a bare string in an object literal is a fresh literal type that TypeScript widens to `string` when it infers the enclosing type, so under the inferred-return rule `return { kind: "found", account }` hands back `{ kind: string; account: Account }` — the union never forms, the error lands at a distant caller with a message naming no cause, and the misspelling that caused it produces no error on its own line. A property of an `as const` object is a non-widening literal, so the same `return` infers `kind: "found"` with no annotation, and a misspelled kind is a property-does-not-exist error on the line that misspelled it.
- **The union is derived from the kinds, not written out.** A payload map keyed by the kinds and a mapped type stamping `kind: K` onto each payload make every member's tag match its key by construction, and a kind added to the object without a payload fails at the declaration — the pairing to the `satisfies never` arm, which catches a kind missing from a `switch` where this catches one missing from the union. A payloadless member's payload is `Record<never, never>`, the no-keys type; `Record<string, never>` collides with the stamped `kind`. Constructed values bind to an intermediate annotated with the union and return by name, never through a return annotation on the function: the literal is checked against the union on its own line, and TypeScript narrows a declared union to the member its initializer builds, so callers infer `LookupMember<"found"> | LookupMember<"missing">` — exactly the members the body constructs, so deleting a branch narrows every caller and a dead `case` arm stops compiling. Two bare returns infer `account?: undefined` onto the missing member instead, letting a caller narrowed to `missing` read `account`.

  ```ts
  const LookupKind = { found: "found", missing: "missing" } as const;
  type LookupKind = (typeof LookupKind)[keyof typeof LookupKind];

  type LookupPayloads = {
    [LookupKind.found]: { readonly account: Account };
    [LookupKind.missing]: Record<never, never>;
  };

  type LookupMember<K extends LookupKind> = { readonly kind: K } & LookupPayloads[K];
  type Lookup = { [K in LookupKind]: LookupMember<K> }[LookupKind];

  function lookupAccount(accounts: ReadonlyMap<string, Account>, accountId: string) {
    const account = accounts.get(accountId);
    if (account === undefined) {
      const missing: Lookup = { kind: LookupKind.missing };
      return missing;
    }
    const found: Lookup = { kind: LookupKind.found, account };
    return found;
  }
  ```

- **Absence is a union member, never a returned `null` or `undefined`.** A function whose result can be absent returns a `kind`-keyed member naming why — `{ kind: LookupKind.missing }` — so a reason added later fails every `satisfies never` arm that has not handled it, and absence has one spelling where the two literals give a module two to tell apart. A foreign `undefined` — `Map#get`, `Array#find`, `process.env` — is converted to a member where it is read, so it never travels through a return. A bare `return;` ends a `void` function and carries no value, and a React component returning `null` to render nothing is the framework's contract rather than an absent result.
- **Pure functions: strict inputs, inferred return.** Type a pure function's parameters as strictly as possible, and do not declare an explicit return type — instead make the returned values well-defined enough (narrow literals, `as const`, precise construction) that the correct return type is inferred. An explicit annotation masks implementation changes that still satisfy it, while inference propagates the true type so the language server breaks dependent call sites loudly. Do not "fix" a pure function by adding a return annotation. A type predicate (`(x): x is Narrowed`) is not the annotation this rule targets — it encodes a narrowing the compiler cannot infer rather than restating one it can; the same holds anywhere inference genuinely cannot express the type, such as a recursive function TypeScript would otherwise reject as implicitly `any`.
- **A value declared only to be returned carries its check as `satisfies` on the `return`.** `` const name: SecretName = `${namespace}/${environment}`; return name; `` binds a name that is dead at the return and that no caller sees; the annotation is the only work the two lines do, and it is a return annotation in disguise, because the declared type is what reaches the caller whatever the expression's own type was. `` return `${namespace}/${environment}` satisfies SecretName; `` keeps the assignability check on the expression and lets the expression's own type flow into the inferred return. Two initializers keep their binding. An object or array literal takes its type from the annotation, and `satisfies` hands back the literal's own type instead: two literal returns normalize into each other (`account?: undefined` on the member that never had one), an empty array is `never[]`, and a `readonly` on the annotation is dropped — so a literal binds to the annotated intermediate the union rule prescribes. An `await` keeps its binding because Statement shape makes `await` a statement, never an operand under `satisfies`.
- **Generics and function overloads wherever they sharpen static typing.** When an output type depends on an input's type or call shape, encode that relationship instead of widening: a type parameter (constrained as tightly as possible) when types flow through, function overloads when distinct call shapes deserve distinct signatures. Widened unions, `unknown`, or casts at call sites are the smell this rule targets. Inference stays the default; a generic still lets the return type infer, and overloads — whose signatures are necessarily explicit — are the sanctioned exception to the inferred-return rule when inference alone can't express the input→output relationship.
- **`readonly` is the default for parameters and constants.** State and scope's never-modify-inputs rule, made a compile error: parameters are typed immutable — `readonly T[]`, `ReadonlyMap`, `ReadonlySet`, `Readonly<T>` — and constants carry readonly shapes (`as const`). Mutability is the exception and must be visible in the type, so a signature that omits `readonly` is a claim that the function mutates. Everything whose type can carry it, does — including a class instance, where `Readonly<>` genuinely blocks field reassignment (verified: it also leaves generic inference intact, so `assertSchema`'s `Readonly<S>` still narrows through `z.infer<S>`). Only scalars and top types (`string`, `number`, `unknown`, `never`) are outside the rule, having nothing to mark. The `Array.from(input).sort(…)` copy is the case State and scope's copy-to-avoid-mutation comment exists for, since `.sort` mutates in place.
- **Never `delete`.** Build a new object without the key, or set an optional property to `undefined`. `delete` mutates an object's shape in place, which State and scope's never-modify-inputs rule forbids on an input and which is the same aliasing hazard on any object another binding can reach.
- **Class fields are `readonly` by default too.** A mutable field is a deliberate design decision, visible in the type and justified by the class genuinely owning that state's lifecycle. Where a class does own mutable state it is the single owner: mutation is confined to a few well-named methods that assert the invariants they preserve, never reached in from outside — Control flow's centralize-state-in-the-parent rule at class scope.
- **Test for arrays with `Array.isArray`**, never a simple nullish check — a nullish check accepts any non-null value, so non-array truthy values slip through.
- **Export the question, not the set.** A constant collection that exists to answer "is this value one of these?" is exported as a type guard, with the collection itself private or exported only for consumers that genuinely need the data. The forcing constraint is a variance collision: deriving the member union from the collection (`(typeof statuses)[number]`) wants the narrowest element type, while `Array.prototype.includes` types its argument as that same element type and so wants the widest — one binding cannot be both, and the attempt produces two. The tell is syntactic: a second binding whose only job is to widen the first (`const narrow = […] as const; export const wide: readonly Status[] = narrow;`) means the widening belongs inside a function, where the parameter can be as wide as the domain (`string | null | undefined`) while the return type stays as narrow as the set. `satisfies` does not resolve this — it validates without widening, so it earns its place pinning the literal (`[…] as const satisfies readonly Status[]`) and leaves the collision untouched. Exporting the collection instead pushes the same judgment into every call site — the nullish pre-check, the `as` cast forcing a provider string into the element type — where it drifts into as many spellings as there are callers. Valid exports the predicate and keeps the collection private:

  ```ts
  const statuses = ["active", "pending", "closed"] as const satisfies readonly string[];
  type Status = (typeof statuses)[number];

  export function isStatus(value: string | null | undefined): value is Status {
    if (value === null || value === undefined) {
      return false;
    }
    return (statuses as readonly string[]).includes(value);
  }
  ```

  Invalid exports the collection, so every caller repeats the nullish check and the cast `includes` forces:

  ```ts
  export const statuses = ["active", "pending", "closed"] as const;

  function handleStatus(value: string | null) {
    if (value !== null && statuses.includes(value as Status)) {
      // ...
    }
  }
  ```
