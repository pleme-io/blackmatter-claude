# context: rejected approaches, with evidence

The table behind `★ REJECTED` in `SKILL.md`; the carve-out to MODULARIZE-DON'T-DELETE stays there.

## ★ REJECTED — measured negatives; do not re-litigate

Recorded so these are not rediscovered every sprint. Each has a source.

| Rejected | Evidence |
|---|---|
| **Cutting for file SIZE** | McMillan's factorial study — 1,650 Claude Code sessions, 3 frontier models — tested file size, instruction position, file architecture and adjacent-file contradictions and found **none produced a detectable contrast**. Cut for measured *irrelevance* (Shi: −22.6pp from merely-irrelevant sentences) and for hard budget caps, never for size alone. |
| **Reformatting to XML / reordering by priority** | Vendor-only recommendation, no independent validation; the widely-quoted "20–40% more consistent" traces to secondary blogs. Compact Constraint Encoding cut constraint tokens 71% with compliance unchanged (Cliff's δ<0.01), and Eliav found no universal format winner. |
| **Hierarchical disclosure (index → sub-index → leaf)** | Measured to FAIL: flat (one hop) beat raw 1.8× at half cost, while two routing levels **collapsed accuracy 0.9126 → 0.6398**. "Depth does not pay, and can hurt." Keep catalogs FLAT. |
| **Bigger context windows as the fix** | Extended-context variants show nearly identical curves; effective utilization is 10–20% of the window. |
| **`llms.txt`** | Negative evidence — ~300k domains, no significant correlation. |
| **Promising an adherence % from a cut** | **No published study measures instruction-file size against adherence.** Writing "reduces adherence by N%" would itself be the round-up the corpus forbids. |
