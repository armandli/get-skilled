# Scrutiny Checklist

Run through every item below before writing the plan file. For each issue found, state the problem, propose a fix, and apply it after user approval.

## Structural Integrity

- [ ] **No circular dependencies.** Trace every dependency chain to confirm it terminates at an entry point (a step with no dependencies). If A depends on B and B depends on A (directly or transitively), the plan cannot execute.
- [ ] **All dependency references are valid.** Every step ID listed in a `Depends on` field must match an existing step block's ID exactly.
- [ ] **All step IDs are unique.** No two step blocks share the same ID.
- [ ] **No self-dependencies.** No step lists itself in its own `Depends on` field.

## Completeness

- [ ] **Goal is achievable.** Walking through all steps from entry points to terminal steps (steps nothing depends on) should produce the stated goal.
- [ ] **No missing steps.** Are there implicit actions assumed but not captured? Common gaps: environment setup, configuration, testing, documentation, cleanup.
- [ ] **No orphaned steps.** Every step should either be an entry point or be reachable from an entry point through the dependency chain. A step that nothing depends on and that depends on nothing (unless it's the only step) may be orphaned.
- [ ] **Entry points exist.** At least one step must have `Depends on: none` so execution can begin.
- [ ] **Terminal steps exist.** At least one step should have no other steps depending on it, representing a natural end point.

## Concurrency Safety

- [ ] **No shared mutable state conflicts.** If two steps can run in parallel (no dependency between them), check that they don't modify the same files, database tables, or resources without coordination. If they do, either add a dependency between them or add a coordination note.
- [ ] **Inputs are available.** Every `Expected inputs` entry references a dependency that actually produces that output. The producing step's outcomes should mention generating what the consuming step expects.

## Quality

- [ ] **Procedures are concrete.** Each procedure step should be a specific action, not a vague directive. "Run `npm test`" is concrete. "Make sure everything works" is not.
- [ ] **Success criteria are verifiable.** Each success outcome should describe something an agent can objectively check — a file exists, a test passes, an endpoint returns 200.
- [ ] **Failure modes are addressed.** Steps with foreseeable failure points (network calls, user input, external dependencies) should include at least one failure outcome with recovery instructions.
- [ ] **Effort estimates are present.** Every step has an effort estimate (S/M/L/XL).
- [ ] **Granularity is reasonable.** No step should be so large that it takes multiple days (use XL sparingly). No step should be so trivial that it adds noise without value. If a step is XL, consider splitting it.
