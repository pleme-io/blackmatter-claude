---
name: carve
description: Take a single monolithic feature branch and split it into a stack of ticket-aligned pull requests the team can actually review. Use when the operator has been developing freely in one branch and now needs to present that work back to the team aligned with JIRA sub-tickets, when a PR is too large for review and needs decomposing along ticket lines, or when the operator is restacking descendant PRs after a review-feedback fix landed on a parent. Skip for single-ticket branches, doc-only branches, or branches with fewer than 3 commits.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  last_verified: "2026-05-20"
  domain_keywords:
    - "carve"
    - "stacked PRs"
    - "stacked pull requests"
    - "monolithic branch"
    - "ticket-aligned"
    - "JIRA epic"
    - "sub-tickets"
    - "split PR"
    - "carve into tickets"
    - "BLAKE3 backup"
    - "tree-hash gate"
    - "cross-cutting commit"
    - "restack"
    - "plan.yaml"
    - "stack diagram"
---

# carve — monolithic-branch → ticket-aligned stacked-PR delivery

This skill walks a development branch through the carve pattern:
analyse → operator-edit scopes → re-score → verify → execute → push +
PR creation → JIRA sync → restack on review feedback.

- **Theory:** `pleme-io/theory/CARVE.md` (the WHY)
- **Tool repo:** `pleme-io/carve` (the binary + types)
- **Pre-merge sibling skill:** `vitrine` (post-carve evidence delivery)

This skill is the operator-side automation — it drives the `carve` binary,
captures the operator's commit-to-ticket judgment in the plan, and produces
a stacked-PR set with attestable backup + tree-hash equivalence.

## When to invoke

Invoke when the user says any of:
- "carve this branch into stacked PRs"
- "split this PR according to the JIRA sub-tickets"
- "this PR is too big — make it a stack"
- "we need to present this branch ticket-by-ticket to the team"
- "restack the PRs after the fix lands"
- "regenerate the stack diagrams"

Or proactively when the operator has a feature branch with substantial
work (≥ 3 commits or ≥ 200 lines changed) and an open JIRA epic whose
sub-tickets correspond to scopes in the branch.

## When to skip

- The branch already has a single clear ticket — just open a normal PR.
- Doc-only / typo / one-line config changes.
- Branches that don't diverge from a JIRA epic with sub-tickets.
- Branches where every commit touches the same path globs — there's
  nothing to carve.

## Step 1 — Inspect the situation

Before running anything, gather:

1. The source branch (often the current branch). Confirm with
   `git symbolic-ref --short HEAD`.
2. The JIRA epic key (e.g. `ASM-18003`). Ask the user if not obvious.
3. The remote default branch — carve auto-detects via
   `git symbolic-ref refs/remotes/origin/HEAD` so you don't need to
   pass it explicitly.
4. Whether the operator has already done a carve on this branch (look
   for an existing `plan.yaml` or `carve-backup/*` tags).

If a `plan.yaml` already exists, the operator is in the middle of a
carve — go to step 3 (refresh) instead of starting fresh.

## Step 2 — Initial plan emission

```bash
carve plan --epic <EPIC-KEY> -o plan.yaml
```

This produces a skeleton with:
- Each JIRA sub-ticket as a `TicketScope` with empty `paths`.
- Every commit fingerprinted with full subject + path + author + date.
- Empty `assignments` and `cross_cutting` (operator hasn't declared
  scopes yet — every commit will be Unassigned).
- A `stack` with one node per ticket, in JIRA discovery order.

If the operator runs without `ATLASSIAN_*` env, carve warns and emits
empty tickets. Tell them to either configure those env vars or to
hand-author the tickets block in `plan.yaml`.

## Step 3 — Operator edits scopes

The plan is now operator-editable. Help the operator populate:

1. **`paths` globs** on each ticket — what files this ticket owns.
   Use `**` for recursive matches. Example:
   ```yaml
   - key: ASM-18006
     summary: Terraform regional resources
     paths:
       - "saas/terraform/environments/dbk/staging/GCP/saas/asia_southeast1/**"
       - "saas/terraform/modules/AWS/canary-test-direct/**"
   ```

2. **`exclude` globs** when needed — paths that match `paths` but
   belong to a more-specific ticket.

3. **`placeholder: true`** on tickets whose scope is non-repo (docs
   tracked on Confluence, CICD work in other repos). Carve will emit
   a draft PR with one `--allow-empty` commit.

4. **`stack_order`** — lower runs first; defaults are `0, 10, 20, ...`
   per JIRA discovery order.

5. **`story_points`** + **`target_status`** if you want
   `carve jira-sync` to update the ticket later.

After editing, re-score:

```bash
carve plan --refresh -o plan.yaml
```

Refresh runs glob intersection on every commit:
- **Single scope** → `HighSingleScope` assignment, no operator action
  needed.
- **Multiple scopes** → `CrossCuttingCommit` with `ByPath` split
  proposal. Operator reviews the halves.
- **No scope** → `Unassigned`. Operator must extend a ticket's `paths`
  or hand-pin the assignment by setting `confidence: operator-pinned`.

## Step 4 — Verify

```bash
carve verify -p plan.yaml
```

Surfaces:
- Unassigned commits (operator must resolve).
- Cross-cutting commits whose `Drop` decision has no rationale (error).
- Placeholder tickets that somehow got assignments (error).

Don't proceed to execute until verify is clean.

## Step 5 — Execute

```bash
carve execute -p plan.yaml
```

This is the mechanical phase. Carve will:
1. Create the BLAKE3-attested backup tag `carve-backup/<epic>-<timestamp>`.
2. Build each stack node's branch off its base.
3. Cherry-pick or apply path-restricted splits.
4. Verify tree-hash equivalence (refuse to push on mismatch).
5. Push branches via `--force-with-lease`.
6. Open stacked PRs via `gh pr create --base <parent>`.

If something goes wrong, recover via:

```bash
git checkout carve-backup/<epic>-<timestamp>
git branch -f <source-branch>
```

The backup tag is the canonical recovery anchor.

Add `--no-push` to test execute locally without touching origin or
opening PRs — useful for the first carve on a tricky branch.

## Step 6 — JIRA sync

```bash
carve jira-sync -p plan.yaml
```

For each ticket with `story_points` set, carve writes the value into
the configured custom field. For each ticket with `target_status` set,
carve transitions the issue — capped by `JiraConfig.max_auto_transition`
in `.carve.toml` (or the user-global config).

If the operator's team uses a stricter workflow ("automation can't
move tickets past Ready To Work"), set:

```toml
[jira]
max_auto_transition = "Ready To Work"
```

Carve will emit a warning when a target exceeds the cap and leave the
advance to a human.

## Step 7 — Restack on review feedback

When a reviewer asks for a change on PR #N in the stack:

1. Operator pushes the fix to that branch (normal git workflow).
2. Run:
   ```bash
   carve restack --from <branch-of-PR-N>
   ```
   This `git rebase --onto`s every descendant onto the new parent tip.
3. Regenerate the embedded stack diagrams so PRs reflect new tips:
   ```bash
   carve diagram -p plan.yaml
   ```
4. Push the rebased descendants:
   ```bash
   git push --force-with-lease origin <branch-A> <branch-B> ...
   ```

## Step 8 — Gate (CI hook)

For repos where merge queue isn't available (admin-gated), add the
carve gate as a `pull_request` workflow check:

```yaml
- name: Refuse out-of-order stack merge
  run: carve gate --pr ${{ github.event.pull_request.number }} -p plan.yaml
```

The check fails if any parent PR in the stack is still open.

## Pitfalls to surface to the operator

| Pitfall | What to say |
| --- | --- |
| `master` ref stale in worktree | Carve auto-detects via `origin/HEAD`. Don't pass `--master master` if the local branch is behind origin. |
| Cross-cutting commit not flagged | Operator's `paths` globs are too broad/narrow. Tighten the globs and `carve plan --refresh`. |
| Tree-hash gate FAILED | A commit was Drop'd without compensating path coverage elsewhere. Run `carve verify` for details; usually fix is to convert the `Drop` into a `ByPath` split. |
| Auto-detect picks wrong default branch | Pass `--master origin/<branch>` explicitly. |
| Story points field id wrong | Set `[jira] story_points_field = "customfield_XXXXX"` in `.carve.toml`. |
| ATLASSIAN_* env not set | Tell the operator to export `ATLASSIAN_BASE_URL`, `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`. JIRA-touching commands fail without these. |
| `gh` not authenticated | `gh auth status` must succeed before execute. |
| Working tree dirty | Carve refuses to start; commit/stash first. |
| Existing branch collision | Carve refuses to clobber a local branch. Pass `--force` to recreate. |

## Anti-patterns to refuse

- **Don't run execute without verify first.** Verify catches most
  preflight failures.
- **Don't mutate the source branch** between plan and execute. The
  plan's `commits` list is captured at plan time; a re-pushed source
  branch invalidates the plan.
- **Don't manually mark cross-cutting as `WholeTo`** without
  understanding the scope blur it introduces. `ByPath` is the
  default for good reason.
- **Don't push without `--force-with-lease`.** Carve never uses bare
  `--force`; if you're running git push by hand during recovery, mirror
  that discipline.

## Family

- **vitrine** — what each carved PR uses to embed pre-merge evidence
  into its description before review.
- **cordel** — provides the BLAKE3-attestation pattern carve borrows
  for backup tags.
- **shikumi** — provides the typed-config pattern carve borrows for
  per-org JIRA policy.
