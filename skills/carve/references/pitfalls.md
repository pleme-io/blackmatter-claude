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

## The pitfall a carve cannot see: the units the branch never touched

A stack carved from what the branch happens to touch is complete about the
branch and silent about the fleet. It covers the unit someone started with and
leaves every other consumer on the old behaviour, and the gap is invisible
precisely because every PR in the stack looks finished and every gate is green.

So for a change that fans out, glob the consumers from the REPO before planning
scopes — every values file, every leaf, every caller — and account for each one:
a scope in the plan, or a line in the common PR naming it excluded and why.

Measured 2026-10-07 in a host GitOps repo: a chart repair shipped as a
four-PR stack covering one tenant's 3 clusters while 13 ran the chart, so 10
kept the fault the change existed to fix, and nothing in the stack said so.

Where the host ships that kind of fan-out as one PR rolled out by pinning, it
is not a carve at all: every consumer's values go in the one PR (or are named
excluded, with the reason), the rollout tool derives its units from the PR and
the live apps, and carve's part is `carve ready --rollout-ledger`
(`references/ready.md`).
