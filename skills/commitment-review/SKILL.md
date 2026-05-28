---
name: commitment-review
description: Run the quarterly commitment-portfolio review — what to commit, what to renew, what to let lapse, what to divest. Use when planning a commit purchase, when an existing commit is approaching expiry, when the workload's baseline has shifted, or when the discount catalog changes. Powered by the `commitment-forge` Rust binary.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "commitment"
    - "savings-plan"
    - "CUD"
    - "reserved-instance"
    - "commitment-forge"
    - "finops"
    - "rate-optimization"
---

# commitment-review — Quarterly commitment-portfolio review

This skill wraps the `commitment-forge` Rust binary with workflow guidance
for the canonical quarterly cadence and the discrete moments that demand
a commitment decision: new buy, renewal, expiry, baseline shift.

The strategic philosophy lives in the FinOps Strategy doc on Confluence
(*FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
**Architectural Foundation A6** is the directive: the commitment portfolio
is **architecture, not transactions** — bedrock / foundation / elastic /
experimental layers, each with a different commitment posture, and the
layers should be distinguishable in the cost data so commits cover the
right things.

## When to invoke

- The quarterly commitment review.
- A new commit is being proposed (e.g., "should we buy a 3-year savings
  plan on the new region?").
- An existing commit is within 90 days of expiry.
- The workload baseline has shifted materially (Karpenter went live,
  spot adoption changed the elastic top, a tenant migrated clouds).
- The discount catalog changes (cloud provider updated rates / new
  commit shapes available).

## Tools used

- **`commitment-forge`** — the binary.
  - `commitment-forge portfolio layers --portfolio p.yaml` — list layers
  - `commitment-forge analyze &lt;events&gt; --portfolio p.yaml --bucket 1d`
  - `commitment-forge analyze ... --format json`
- **`attribution-forge`** (separate skill: `cost-attribution`) — produces
  the events the analyzer consumes.
- **`showback-forge`** (separate skill: `chargeback-rollout`) — useful
  for "show the layer-by-layer view to leadership during the review."

## Workflow

### A) The quarterly review

1. **Refresh the attribution events.** A stale event stream produces a
   stale baseline.
2. **Refresh the portfolio config.** Real exits / new buys since last
   quarter should be reflected in `current_commits`.
3. **Run analyze with a window long enough to reflect the steady-state.**
   28 days (1mo) is typical. Use `--bucket 1d`:
   ```bash
   commitment-forge analyze events.jsonl --portfolio portfolio.yaml --bucket 1d
   ```
4. **Read the report:**
   - `baseline_hourly_usd` — the floor. This is what's commit-eligible.
   - Per-layer `gap_$/h` — positive means under-committed; negative
     means over-committed.
   - `recommended_purchase_hourly_usd` — what to buy this quarter.
   - `estimated_annual_savings_usd` — the dollar case for the
     leadership conversation.
5. **Cross-reference with `attribution-forge` and `showback-forge`** to
   confirm the baseline reflects the workload story the org tells
   itself.
6. **Take the recommendation to procurement**. The dollar case is
   embedded; finance can act on it.

### B) Proposed new commit (mid-cycle)

When someone proposes a buy outside the quarterly cadence:

1. Run analyze. If the recommended purchase for the relevant layer is
   already at or above the proposed buy, that's confirmation.
2. If the proposed buy exceeds the recommendation, ask: what does the
   buyer know that the analyzer doesn't?
   - **Future growth not yet observed** — fine, but document the
     hypothesis. Track outcomes.
   - **Discount window closing** — fine, but understand the
     marginal-vs-stranded-capacity tradeoff.
   - **Vendor pressure / quarterly target** — bad reason. Reject.

### C) Expiry handling

When a commit is 90 days from expiry:

1. Add expiry annotation to the current_commits entry so analyze can
   factor in (current_commits supports `expires_at` field).
2. Re-run analyze. The recommendation will treat the expiring commit
   as gone for layers where it would otherwise be retired.
3. Decision: renew at same shape, renew at new shape, let lapse, or
   migrate to a different layer (e.g., re-up at bedrock if the workload
   has matured into 3-year-stable territory).

### D) Baseline shift detection

When the workload baseline has materially moved (cloud migration,
Karpenter/spot adoption, big tenant change):

1. Run analyze before AND after the change against the same portfolio.
2. The delta in `baseline_hourly_usd` is the magnitude of the shift.
3. If shift &gt; 20%, plan a portfolio re-baseline at the next quarterly
   review:
   - Tighten target_coverage if elastic adoption grew (less commit-
     eligible).
   - Re-allocate between bedrock and foundation if the steady-state
     shape changed.

## Common patterns

- **Baseline = MIN, by design.** The analyzer's conservative baseline
  is the whole point. Mean / median baselines over-commit. If you
  want to commit on what you've ALWAYS had, MIN is the right floor.
- **Layer separation matters.** A flat "commit 30%" mandate is sloppy;
  bedrock (3y, all-upfront) buys different math than foundation (1y,
  partial-upfront). Keep them distinct.
- **The elastic layer should be growing as a percentage** if Karpenter
  + spot adoption are landing. The portfolio model surfaces this.
- **3-year horizon scares people; do the math.** A 3-year commit on
  what you've had unchanged for the last 18 months is reasonable. The
  fear lives in "what if we migrate clouds" — but cloud migrations
  don't happen on quarterly cycles, they happen on multi-year ones,
  and the savings on a 3-year commit usually outpace the risk by 2-3×.

## Anti-patterns

- **Committing on speculative peak.** "We might grow into it" + "we'll
  use it eventually" = stranded capacity. Commit on observed baseline
  only.
- **Over-committing to hit a discount tier.** Vendor reps love this;
  don't fall for it. The discount only matters if you'll use the
  commit fully.
- **One mega-commit per cloud.** Layered portfolio + multiple shapes
  per layer beats a single mega-buy. Diversifies expiry, allows
  evolution.
- **Letting commits lapse without renewal decision.** Auto-expiry is
  invisible until the next bill arrives 30% higher. Track expiries
  in the portfolio config (`expires_at`).
- **Treating layer_discounts as fixed.** Cloud providers renegotiate;
  contract overlays should be refreshed annually at minimum.

## Related skills

- `cost-attribution` — produces the JSONL the analyzer consumes;
  coverage health affects baseline accuracy.
- `chargeback-rollout` — showback views of the layered portfolio for
  visibility during the review.
- `rightsize-fleet` — rightsizing changes the baseline; coordinate
  the timing.
- `cadence-review` (TBD) — when `cadence-forge` ships, the quarterly
  commitment review becomes a section of the review packet.
