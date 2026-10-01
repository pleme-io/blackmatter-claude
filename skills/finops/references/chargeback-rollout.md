> Practice reference of the `finops` skill. Until 2026-10-01 this was the standalone skill `chargeback-rollout` (version 0.1.1). Former description: Renders team cost views with showback-forge and plans the move to chargeback. Use for team cost trends. Former domain keywords: `showback`, `chargeback`, `team-cost`, `showback-forge`, `finops`, `review`.

# chargeback-rollout — Showback views and the journey to chargeback

This practice wraps the `showback-forge` Rust binary plus the **showback→chargeback
journey** — the multi-quarter rollout from "every team can see their cost"
(showback) to "every team's budget is debited by their cost" (chargeback).

The strategic philosophy lives in the FinOps Strategy doc on Confluence
(*FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
**Architectural Foundation A7** is the directive: **showback before
chargeback.** Skipping showback and jumping straight to chargeback produces
resentment, gaming, and political fights because teams don't trust the data
yet and don't have the control levers to act on it. The journey is the
discipline.

## When to invoke

- Standing up the weekly / monthly team cost-review rhythm.
- Authoring views for a newly-onboarded team or product.
- A team asks "what's our cost trending like" — produce the view.
- Planning the multi-quarter showback→chargeback rollout.
- Quarterly view-bundle review — are the standard views still right?

## Tools used

- **`showback-forge`** — the binary.
  - `showback-forge render &lt;events&gt; --dimension X --period P --periods N` — wide table
  - `showback-forge trend &lt;events&gt; --dimension X --period P --periods N` — delta + sparkline
  - `showback-forge top &lt;events&gt; --dimension X --period P --limit N` — top-N for latest period
- **`attribution-forge`** (practice: `cost-attribution`) — produces
  the JSONL events these views render.
- **`tag-forge`** (practice: `tag-architecture`) — keeps dimension
  values stable so trend lines aren't broken by taxonomy churn.

## Workflow

### A) Authoring views for a new team

1. **Confirm the team's dimension lives in the taxonomy** (typically
   `cost_center` or `team`). If it doesn't, `tag-architecture` practice first.
2. **Pick the team's review cadence** — weekly is typical for
   engineering, monthly for product / leadership.
3. **Pick the period count** — show enough history for a team to see
   their trend. 8 periods is a good default (8 weeks ≈ 2 months;
   6 months ≈ 6 periods).
4. **Run the three canonical views:**
   ```bash
   showback-forge render --dimension cost_center --period 1w --periods 8 events.jsonl
   showback-forge trend  --dimension cost_center --period 1w --periods 8 events.jsonl
   showback-forge top    --dimension service    --period 1w --limit 10  events.jsonl
   ```
5. **Wrap into a recurring delivery** — typically pasted into the team
   channel weekly. Future `cadence-forge` will automate this.

### B) Operational use — answering a team's cost question

When someone asks "what's our cost doing?":

1. **Trend view first.** It surfaces the period-over-period delta and
   shows the sparkline shape — that's the answer to "trending up or
   down?".
2. **Top view second.** Tells you which services / dimensions are
   driving the dominant slice.
3. **Render view if more context needed.** The wide table shows the
   raw values for the trend computation.

For programmatic answers, use `--format json` and pipe through `jq`.

### C) Investigating a worrying trend

The trend output sorts biggest-first by current cost, so the top rows
matter most. For each concerning row:

1. Cross-reference with the anomaly-forge output for the same period.
   If anomaly-forge fired, that's the smoking gun.
2. Drill from `cost_center` to `service` — what service inside the
   center accounts for the change?
3. Cross-reference with deploy events for the period.
4. Disposition: planned launch / unplanned regression / tagging drift.
5. If unplanned and undispositioned, file a ticket with the team that
   owns the cost_center.

### D) The showback→chargeback journey

A multi-quarter rollout. Don't skip steps:

| Phase | Duration | What's true at the end |
| --- | --- | --- |
| **0 — Tag foundation** | already done (Wave 1) | Every resource carries `cost_center`; coverage ≥ 90%. |
| **1 — Attribution data plane** | already done (Wave 1) | Every cost dollar reaches a `cost_center` via tag or virtual rule. |
| **2 — Showback dashboards** | 1 quarter | Every team has a recurring views packet; teams have *seen* their numbers for ≥ 6 weeks. |
| **3 — Showback meetings** | 1 quarter | Each engineering team has a 15-min weekly cost review on their calendar; reviews surface ≥ 1 actionable item per month. |
| **4 — Pre-chargeback drill** | 1 quarter | A mock-chargeback line item appears in each team's showback for 3 months — same number that *would* be debited if chargeback were on. Teams react to the data without consequence. |
| **5 — Chargeback enabled** | go-live | Actual budget debits begin. Finance integration live. |
| **6 — Annual normalization** | continuous | Yearly review of chargeback rules; new teams onboard via phases 2-5 abridged. |

Phase 0-3 use `showback-forge` as-is. Phase 4-5 require **chargeback
mode** on showback-forge — currently planned for v0.2. Don't promise
phase 4-5 timelines until v0.2 lands.

**The temptation to skip to phase 5 is the single biggest failure mode**
of cost programs. Resist it. Each phase builds trust + capability that
the next phase needs.

## Common patterns

- **The sparkline is glance-readable.** It's what a team member should
  notice first in a weekly digest. Big spike vs flat is visible in a
  half-second.
- **Period-over-period delta + percentage tells the right story.**
  Absolute dollar change matters for budget; percentage matters for
  signal strength. Both columns make sense.
- **Top-N is for "where to look" decisions.** Don't try to explain
  every row — explain the top three.
- **Render the same views every week.** Consistency builds
  pattern-recognition; novelty hides drift.
- **Use top dimensions, not just cost_center.** Per-service top-N
  reveals which workload is doing the moving inside a steady-total
  cost_center.

## Anti-patterns

- **Showback once, never again.** A one-off "here's your cost" email
  doesn't build the discipline. Recurring delivery is the practice.
- **Chargeback without trust.** Teams who haven't seen their data for
  three months will treat the first chargeback bill as an ambush.
  Phase 4 (pre-chargeback drill) is non-negotiable.
- **Per-team views with too many rows.** Five rows is rich; 50 rows is
  noise. If your team has more than ~8 cost-centers / services
  worth surfacing, group them in a tier higher.
- **Comparing teams against each other.** Showback is **per-team's
  own trend over time**, not "team A vs team B." Inter-team comparison
  invites unproductive politics.
- **Skipping the audit before showback.** If attribution-forge's
  coverage is &lt;90%, every showback view is suspect. Fix tagging
  first; render second.

## Related practices

- `cost-attribution` — produces the JSONL these views consume; check
  coverage health before publishing showback to teams.
- `tag-architecture` — keeps dimension values stable so trend lines
  aren't broken by taxonomy churn.
- `cost-anomaly` — supplements showback for "why" questions when a
  trend turns; anomalies fire faster than the weekly cadence.
- `cadence-review` (TBD) — when `cadence-forge` ships, it'll embed
  these views into a full review packet. This skill becomes the
  per-team operational layer; cadence-review becomes the program
  composition layer.
