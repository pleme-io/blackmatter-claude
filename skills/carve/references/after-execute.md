# carve: steps 7–10, after execute

The full form of the steps summarised in `SKILL.md`.

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
ticket, so jira-sync skips them entirely.**

A ticket carve creates or syncs is still a ticket, so it carries the full
field set — assignee, sprint, labels, points, parent — not just the two
fields jira-sync writes. The ticket-flow skill owns that standard; check the
synced issues against it rather than leaving a half-populated ticket on the
board. If the team's workflow forbids
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
