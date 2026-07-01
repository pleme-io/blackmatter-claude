# teach-human — directory context

This directory holds the `teach-human` skill: teach a human a complex topic from
its **core concept upward**, one idea per layer, and **vet the learner's
understanding at each rung before building higher**.

## Two invariants (never break)

1. **CORE-FIRST** — start from the single idea everything else derives from; each
   rung depends only on rungs already below it. Never teach top-down.
2. **VET-BEFORE-ASCEND** — never teach the next rung until a *using*-level check
   proves the learner owns the current one. Explaining is not teaching; the
   learner proving they can apply the idea is.

## Files

- `SKILL.md` — the operational skill: when to use, the ladder method, the
  per-rung template, the vetting rubric, the interaction contract, anti-patterns.
- `docs/LADDER-METHOD.md` — long-form: the pedagogy rationale (cognitive load,
  the testing effect, desirable difficulties), the ladder-construction algorithm,
  the vetting rubric with graded examples, and an expanded worked example.

## When editing

Keep the two invariants load-bearing in any change. Bump `metadata.version` +
`metadata.last_verified` in `SKILL.md`, update the `teach-human` entry in
`blackmatter-pleme/skill-map.d/meta.yaml`, and bump `skill-map.d/config.yaml`
(`version` + `lastModified`). Validate with `skill-lint check`.
