---
name: carve
description: Take a single monolithic feature branch and split it into a stack of scope-aligned pull requests the team can actually review. Scopes are JIRA-optional — a scope may be a tracker ticket, a pure architectural layer (offline, no ticket), or a discrete change. Use when the operator has been developing freely in one branch and now needs to present that work back as a reviewable stack, when a PR is too large for review and needs decomposing along ticket or layer lines, or when restacking descendant PRs after a review-feedback fix landed on a parent. Skip for single-scope branches, doc-only branches, or branches with fewer than 3 commits.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.2.0"
  last_verified: "2026-06-08"
  domain_keywords:
    - "carve"
    - "stacked PRs"
    - "stacked pull requests"
    - "monolithic branch"
    - "scope-aligned"
    - "ticket-aligned"
    - "layer split"
    - "JIRA epic"
    - "sub-tickets"
    - "offline carve"
    - "split PR"
    - "carve into scopes"
    - "BLAKE3 backup"
    - "tree-hash gate"
    - "equivalence ledger"
    - "prove before mutate"
    - "net-diff"
    - "cross-cutting commit"
    - "restack"
    - "plan.yaml"
    - "stack diagram"
---

# carve — monolithic-branch → scope-aligned stacked-PR delivery

> **Canonical source.** The authoritative version of this skill lives in the
> private blackmatter skills repo and is synced (via home-manager) to
> `~/.claude/skills/carve/SKILL.md`. Edit it at the canonical source, not
> here — local edits at the deployed path are overwritten on the next sync.

This skill walks a development branch through the carve pattern:
analyse → operator-edit scopes → re-score → verify → **preflight → prove →
report** → execute → push + PR creation → tracker sync → restack on review
feedback.

- **Theory:** `pleme-io/theory/CARVE.md` (the WHY — the nine principles)
- **Operator how-to:** `pleme-io/carve/docs/operator-howto.md` (a generic
  offline + layer + net-diff worked example)
- **Tool repo:** `pleme-io/carve` (the binary + types)
- **Pre-merge sibling skill:** `vitrine` (post-carve evidence delivery)

This skill is the operator-side automation — it drives the `carve` binary,
captures the operator's commit-to-scope judgment in the plan, and produces
a stacked-PR set with attestable backup, disjointness preflight, and
proven tree-hash equivalence.

## The model: a scope is JIRA-optional

The unit of the stack is a **scope**, not a ticket. A scope is one of:

- a **Ticket** — backed by a tracker key (scope id = the bare key);
- a **Layer** — a horizontal architectural slice with no ticket at all
  (scope id = `layer:<slug>`, e.g. `layer:read-path`); or
- a **Change** — a discrete change unit.

This makes an **offline / no-tracker carve a first-class path**. You can
split a branch into reviewable layers with zero connectivity. A
**single-ticket branch** that still wants a layer split is exactly this:
author the layers inline, ignore the tracker.

## When to invoke

Invoke when the user says any of:
- "carve this branch into stacked PRs"
- "split this PR according to the tracker sub-tickets"
- "split this branch by layers" / "carve it into a read-path / wire-format stack"
- "this PR is too big — make it a stack"
- "we need to present this branch scope-by-scope to the team"
- "carve this offline, we have no tracker access"
- "restack the PRs after the fix lands"
- "regenerate the stack diagrams"

Or proactively when the operator has a feature branch with substantial
work (≥ 3 commits or ≥ 200 lines changed) that splits cleanly along
ticket OR layer boundaries.

## When to skip

- The branch already maps to a single clear scope — just open a normal PR.
- Doc-only / typo / one-line config changes.
- Branches where every commit touches the same path globs — there is
  nothing to carve.

## Step 1 — Inspect the situation

Before running anything, gather:

1. The source branch (often current). Confirm with
   `git symbolic-ref --short HEAD`.
2. **The scope axis** — does the work split along tracker tickets, along
   architectural layers, or both? If there is no tracker access (or the
   user asks to stay offline), go straight to the **layer** path.
3. The tracker epic key, *only if* using ticket-backed scopes (format like
   `EPIC-1`). Ask the user if not obvious.
4. The remote default branch — carve auto-detects via
   `git symbolic-ref refs/remotes/origin/HEAD`, so you rarely pass it.
5. Whether a carve is already in progress (look for an existing `plan.yaml`,
   `.carve/`, or `carve-backup/*` tags). If `plan.yaml` exists, the operator
   is mid-carve — go to the refresh step instead of starting fresh.

## Step 2 — Initial plan emission

`plan.yaml` is the single editable artifact. Choose the authoring path:

**A. Layer split (offline — no tracker):**

```bash
# Quick: glob-less layers, fill paths in afterwards.
carve plan --layer read-path --layer wire-format -o plan.yaml

# Cleaner (recommended, esp. for --net-diff): seed path globs up front.
cat > scopes.yaml <<'EOF'
- {id: "layer:read-path",  kind: layer, summary: "read path",  paths: ["read/**"],  stack_order: 0}
- {id: "layer:wire-format", kind: layer, summary: "wire format", paths: ["wire/**"], stack_order: 10}
EOF
carve plan --scopes-from scopes.yaml -o plan.yaml
```

`--layer` / `--scopes-from` is its own offline path: JIRA is never
consulted and `--epic` is not required. Each layer becomes a
`kind: Layer` scope with id `layer:<slug>`.

**B. Single ticket or epic (tracker-backed):**

```bash
# One epic fans its children out into ticket-backed scopes.
carve plan --epic EPIC-1 -o plan.yaml
```

If the `ATLASSIAN_*` env is not set, carve runs offline automatically and
emits a scope-less plan you hand-author (or use path A). The skeleton
gives you: scopes named, every commit fingerprinted, empty `assignments`,
and a `stack` with one node per scope.

**Net-diff vs by-commit.** Add `--net-diff` to materialise each node as a
single **squashed** commit holding the net diff of its paths (collapses
add-then-revert churn — the stack shows the *end state*, not the journey).
Without it, nodes cherry-pick their commit ranges, preserving per-commit
history. In `--net-diff` mode, seed path globs at emission (path A
"Cleaner") so the squashed nodes carry their path sets.

## Step 3 — Operator edits scopes, then re-score

Help the operator populate each scope:

1. **`paths` globs** — what files this scope owns (`**` for recursive).
2. **`exclude` globs** — paths that match `paths` but belong to a
   more-specific scope.
3. **`priority`** — when two scopes both match a path, the higher
   `priority` wins; equal priority falls to the cross-cutting split.
4. **`placeholder: true`** — scopes with no repo-side files (design docs,
   work in another repo). Carve emits a draft PR with one `--allow-empty`
   commit.
5. **`stack_order`** — lower runs first (closer to the root branch).
6. **`story_points` / `target_status`** — only meaningful on
   ticket-backed scopes; carve-jira-sync uses them later.

After editing, re-score:

```bash
carve plan --refresh -o plan.yaml
```

Refresh runs glob intersection on every commit (single-scope →
`HighSingleScope`; multi-scope → `CrossCuttingCommit` with a `ByPath`
split; no scope → uncovered). **In by-commit mode, refresh also fills each
node's commit range** — a fresh plan leaves ranges empty, which would make
`prove` fail. Always refresh after editing globs in by-commit mode.

## Step 4 — Verify (dry-run)

```bash
carve verify -p plan.yaml          # add --strict to fail on uncovered
```

Surfaces uncovered commits (no scope claims them — extend a scope's
`paths` or accept them), incomplete cross-cutting decisions, and
placeholder scopes that wrongly got assignments. Don't proceed until
verify is clean (or you have consciously accepted the uncovered set).

## Step 5 — Prove before you mutate: preflight → prove → report

This is the v0.2 heart of the skill. Establish correctness **before** any
branch is created or pushed.

```bash
# 5a. Disjointness: prove path claims don't overlap and nothing is lost.
carve preflight -p plan.yaml
#   Writes .carve/safety.yaml. Refuses on real overlaps.
#   In net-diff mode, node claims are globs and the source diff is concrete
#   files, so preflight may flag "uncovered" paths a glob actually covers —
#   pass --allow-overlap to proceed; the envelope is still written.

# 5b. Equivalence: reconstruct the stack's trees in a THROWAWAY worktree
#     (HEAD/working tree untouched) and seal the equivalence ledger.
carve prove -p plan.yaml
#   verdict: equivalent  ⟺  cumulative.last() == source top tree hash.
#   NOT equivalent usually means a by-commit node has an empty range —
#   run `carve plan --refresh`. Use --report-only to inspect without failing.

# 5c. Read the proof before mutating.
carve report -p plan.yaml          # or --json for CI
#   equivalence : proven   ← only execute once this says proven
```

Only a sealed, `equivalent` verdict licenses execution. If `prove` left
scratch refs (`refs/carve/*`) or `carve-prove/*` branches in a sandbox,
`git switch <source>` and delete them before the next step.

## Step 6 — Execute (the only mutating step, journaled)

```bash
carve execute -p plan.yaml --no-push -y
```

- `--no-push` builds branches locally without touching origin or opening
  PRs — always do this for the first carve on a tricky branch.
- `-y` skips the interactive confirmation (auto-skipped on CI / non-tty).
- Execute re-runs the disjoint preflight first; pass `--no-preflight` to
  skip it when you already ran preflight with `--allow-overlap`.

Execute, in order: re-check disjointness → write the recovery manifest +
BLAKE3-attested backup tag → build each node (squashed net-diff commit, or
cherry-picked range) → gate on the sealed equivalence ledger → push each
branch with a strict per-branch `--force-with-lease` → open stacked PRs
with `gh pr create --base <parent>`.

Every step is journaled (`Started` before, `Done` after), so a crash is
resumable:

```bash
carve execute -p plan.yaml --resume     # skip steps already Done
```

## Step 7 — Recover (clean undo)

```bash
carve recover -p plan.yaml
```

Reads `.carve/recovery-<hash>.yaml`, deletes exactly the branches carve
created (never the source), restores HEAD to the original branch, and
re-hashes the backup tag to confirm no drift. Refuses on a dirty tree
(commit/stash first) and on a plan-hash mismatch (override with `--force`).
Use `--latest` or `--manifest <path>` to target a specific run, and
`--prune-journal` to also clear the journal + carve refs.

(The legacy manual recovery still works too:
`git checkout carve-backup/<...>` then `git branch -f <source-branch>`.)

## Step 8 — Tracker sync (ticket-backed scopes only)

```bash
carve jira-sync -p plan.yaml
```

For each ticket-backed scope with `story_points` / `target_status`, carve
writes the field and transitions the issue — capped by
`max_auto_transition` in `.carve.toml`. **Layer-only scopes carry no
ticket, so jira-sync skips them entirely.** If the team's workflow forbids
automation past an early state, set:

```toml
[jira]
max_auto_transition = "Ready To Work"
```

## Step 9 — Restack on review feedback

```bash
carve restack --from <branch-of-the-parent>   # rebase --onto every descendant
carve diagram -p plan.yaml                     # refresh embedded PR diagrams
git push --force-with-lease origin <descendant-branches...>
```

The tree-hash gate applies to restack too — a restack that would drop
content refuses.

## Step 10 — Gate (CI hook)

```yaml
- name: Refuse out-of-order stack merge
  run: carve gate --pr ${{ github.event.pull_request.number }} -p plan.yaml
```

Fails if any parent PR in the stack is still open.

## Sidecar state

Carve writes `.carve/safety.yaml`, `.carve/journal.yaml`, and
`.carve/recovery-<hash>.yaml`. Ensure the repo `.gitignore` carries
`plan.yaml` and `.carve/` (these are per-run operator state, not
artifacts to commit).

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

## Anti-patterns to refuse

- **Don't execute without prove first.** preflight + prove establish
  correctness before any mutation; that is the whole point of v0.2.
- **Don't run execute without verify.** Verify catches uncovered commits.
- **Don't mutate the source branch** between plan and execute. The plan's
  `commits` list is captured at plan time; a re-pushed source invalidates it.
- **Don't manually mark cross-cutting as `WholeTo`** without understanding
  the scope blur. `ByPath` is the default for good reason.
- **Don't push with bare `--force`.** Carve always uses
  `--force-with-lease`; mirror that during manual recovery.

## Family

- **vitrine** — what each carved PR uses to embed pre-merge evidence into
  its description before review.
- **cordel** — the BLAKE3-attestation pattern carve borrows for backup tags.
- **shikumi** — the typed-config pattern carve borrows for per-org policy.
