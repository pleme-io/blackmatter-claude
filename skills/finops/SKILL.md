---
name: finops
description: "Runs FinOps with the *-forge tools: tags, attribution, showback, cost anomalies, rightsizing, commitments, lifecycle, unit cost, reviews."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.2.0"
  domain_keywords:
    - "finops"
    - "tag"
    - "label"
    - "taxonomy"
    - "cost-center"
    - "allocation"
    - "tag-forge"
    - "cost-attribution"
    - "billing"
    - "cost-per"
    - "attribution-forge"
    - "showback"
    - "chargeback"
    - "team-cost"
    - "showback-forge"
    - "review"
    - "anomaly"
    - "cost-spike"
    - "drift"
    - "anomaly-forge"
    - "alert"
    - "regression"
    - "rightsize"
    - "rightsizing"
    - "downsize"
    - "sizing"
    - "utilization"
    - "rightsize-forge"
    - "commitment"
    - "savings-plan"
    - "CUD"
    - "reserved-instance"
    - "commitment-forge"
    - "rate-optimization"
    - "lifecycle"
    - "ttl"
    - "expiry"
    - "retention"
    - "storage-tier"
    - "lifecycle-forge"
    - "cleanup"
    - "garbage-collection"
    - "unit-economics"
    - "cost-per-customer"
    - "cost-per-request"
    - "gross-margin"
    - "pricing"
    - "unit-econ-forge"
    - "cadence-review"
    - "weekly-review"
    - "monthly-review"
    - "quarterly-review"
    - "cadence-forge"
    - "review-packet"
---

# finops — the FinOps practice, one skill per forge tool

Nine practices, each wrapping one `*-forge` Rust binary with workflow guidance.
Until 2026-10-01 each was its own skill; they shared one strategy source, one
section shape and one data plane, and every one of them listed the others as
related, so they are one skill now. Each practice's full procedure is kept
intact in `references/<practice>.md`. Pick the practice from the table, then
read its file before acting.

The strategic philosophy for all nine lives in the FinOps Strategy doc on
Confluence (*FinOps — Strategy, Architecture &amp; Continuous Practice
(2026+)*). Each practice implements one of its Architectural Foundations (A·),
Strategic Plays (P·) or Part VI.

## Dispatch

| Practice | Tool | Strategy anchor | Invoke when | Reference |
|---|---|---|---|---|
| `tag-architecture` | `tag-forge` | **100% of spend reaches a `cost_center`** | a service onboards; tag coverage drops below 98%; a new cost dimension; quarterly taxonomy review | [references/tag-architecture.md](references/tag-architecture.md) |
| `cost-attribution` | `attribution-forge` | A3 — cost-attribution data plane | wiring a billing source; "what did X cost"; an attribution gap (`(missing)` bucket); data-plane health check | [references/cost-attribution.md](references/cost-attribution.md) |
| `chargeback-rollout` | `showback-forge` | A7 — showback before chargeback | team cost views and trends; the multi-quarter showback→chargeback journey | [references/chargeback-rollout.md](references/chargeback-rollout.md) |
| `cost-anomaly` | `anomaly-forge` | P7 — alert on deltas, not absolutes | a cost alert fired; a billing surprise; authoring or tuning a detection rule; the monthly anomaly section | [references/cost-anomaly.md](references/cost-anomaly.md) |
| `rightsize-fleet` | `rightsize-forge` | P3 — continuous rightsizing | periodic rightsizing pass; "is X over-provisioned"; tuning the sizing policy; CI wiring | [references/rightsize-fleet.md](references/rightsize-fleet.md) |
| `commitment-review` | `commitment-forge` | A6 — commitment portfolio as architecture | quarterly commitment review; a proposed buy; a commit within 90 days of expiry; a baseline shift | [references/commitment-review.md](references/commitment-review.md) |
| `lifecycle-policy` | `lifecycle-forge` | A8 — lifecycle as architecture | "we keep having to delete X"; TTL, expiry or storage-tier retention; audit coverage below threshold | [references/lifecycle-policy.md](references/lifecycle-policy.md) |
| `unit-economics` | `unit-econ-forge` | A4 — instrumented unit economics | defining a cost-per-X metric; a metric that looks wrong; pre-pricing; gross margin | [references/unit-economics.md](references/unit-economics.md) |
| `cadence-review` | `cadence-forge` | Part VI — the continuous cadence | the weekly, monthly or quarterly review packet; adding a packet section | [references/cadence-review.md](references/cadence-review.md) |

## How the practices compose

```
tag-forge ──► attribution-forge ──► showback-forge   ┐
 (taxonomy)    (JSONL cost events)   anomaly-forge     │
                                     rightsize-forge   ├──► cadence-forge
                                     commitment-forge  │    (review packets)
                                     unit-econ-forge   ┘
lifecycle-forge keys on the same tags/labels and shrinks the cost the others see.
```

- `tag-architecture` is upstream of everything: broken tags break attribution,
  and broken attribution makes every downstream number suspect.
- `cost-attribution` is the data plane every other practice reads; check its
  cost-weighted coverage (`attribution-forge verify`) before trusting any
  downstream view.
- `cadence-review` is the composition layer; the other practices each produce
  one section of its packets.

Inside the reference files, "practice: `X`" and "Related practices" name the
sibling reference `references/X.md`.

## Reading a practice

Every reference file keeps the same sections: *When to invoke*, *Tools used*,
*Workflow* (four lettered situations, A–D or A–E), *Common patterns*,
*Anti-patterns*, *Related practices*. Follow the lettered workflow that matches
the situation; the anti-patterns are the review checklist.
