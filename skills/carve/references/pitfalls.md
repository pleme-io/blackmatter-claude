# carve: pitfalls to surface to the operator

## Pitfalls to surface to the operator

| Pitfall | What to say |
| --- | --- |
| `prove` says NOT equivalent | A by-commit node has an empty commit range. Run `carve plan --refresh` after editing globs. |
| `preflight` flags uncovered paths in net-diff mode | Glob-vs-concrete-path comparison; pass `--allow-overlap`. Real overlaps still refuse. |
| `--epic` required error | You are online. Pass `--offline`, `--scopes-from`, or `--layer` to author scopes inline. |
| Working tree dirty | Carve refuses to start (and recover refuses). Commit or stash first. |
| `master` ref stale in worktree | Carve auto-detects via `origin/HEAD`. Use `--fetch` to root the stack on the *current* remote tip. |
| Cross-cutting commit not flagged | Globs too broad/narrow. Tighten and `carve plan --refresh`. |
| Tree-hash gate FAILED at execute | The equivalence ledger didn't seal. Run `carve prove` and fix before executing. |
| Existing branch collision | Pass `--force` to recreate, or delete the stale branch. |
| Tracker/`gh` not authenticated | `gh auth status` must succeed before a pushing execute; tracker env only matters for ticket-backed scopes. |
