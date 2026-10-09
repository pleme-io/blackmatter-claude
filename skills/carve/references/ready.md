# carve: ready for a production window

`carve ready` reads only. It answers whether a change may be scheduled into
a production change window: the stack, deployed, soak, lane, freeze, notice
and approval gates, each pass, fail, blind or off, with a JSON receipt.
Exit 0 ready, 1 not ready, 2 blind.

```bash
# A stacked change: the stack is walked down from each top PR.
carve ready <ticket>... --pr <top PR>...

# One PR rolled out by pinning: lower tiers qualified in the rollout
# tool's ledger stand in for the merged lower PRs of a stack.
carve ready <ticket>... --rollout-ledger <ledger.json>
```

Units, lanes, freezes and fields are config (`carve ready --help`).
`carve windows sync` writes approved, scheduled change tickets as the
guardrail change-window file. A production pin waits for exit 0 here and
for the operator's go.

Read with `references/pitfalls.md`, "the units the branch never touched":
a pinned rollout still carries every consumer in its one PR, or names it
excluded with the reason.
