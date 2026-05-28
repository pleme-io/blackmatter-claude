---
name: unit-economics
description: Compute, instrument, and interrogate per-unit cost economics — cost-per-customer, cost-per-request, cost-per-tenant, cost-per-feature. Use when pricing a new product, when evaluating gross margin, when answering "what does X cost us per unit", or when wiring a new unit-event stream into the FinOps data plane. Powered by the `unit-econ-forge` Rust binary.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "unit-economics"
    - "cost-per-customer"
    - "cost-per-request"
    - "gross-margin"
    - "pricing"
    - "unit-econ-forge"
---

# unit-economics — Per-unit cost economics

This skill wraps the `unit-econ-forge` Rust binary with workflow guidance
for four canonical situations: defining a new metric, debugging a metric
that looks wrong, pre-pricing a new product, and refreshing the
unit-economics view for the monthly review.

The strategic philosophy lives in the FinOps Strategy doc on Confluence
(*FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
**Architectural Foundation A4** is the directive: instrumented unit
economics from the start, not reconstructed retrospectively. Healthy SaaS
gross margins run 70-80%; below 65% is a structural problem that can't
be optimized tactically — it requires architectural change. Without
this data, a company doesn't know which side of that line a product
sits on.

## When to invoke

- Defining a new cost-per-X metric (cost-per-feature, cost-per-API-call,
  cost-per-active-user).
- A metric's output looks wrong (numbers too high, too low, missing
  rows) — debugging the join.
- Pricing a new product or tier — what does it actually cost to serve?
- Monthly review prep — refresh the cost-per-customer / cost-per-tenant
  series.
- Pre-launching a high-volume customer or contract — does the unit
  cost support the pricing?

## Tools used

- **`unit-econ-forge`** — the binary.
  - `unit-econ-forge metrics list --metrics m.yaml` — list configured metrics
  - `unit-econ-forge metrics print --metrics m.yaml &lt;id&gt;` — show one definition
  - `unit-econ-forge compute --metrics m.yaml [--id &lt;single&gt;] [--format json]`
  - `unit-econ-forge schema` — canonical cost-event + unit-event shapes
- **`attribution-forge`** (separate skill: `cost-attribution`) — produces
  the cost events this tool consumes.
- **`tag-forge`** (separate skill: `tag-architecture`) — keeps the
  dimension namespace consistent so unit-event dimensions match cost-event
  dimensions.

## Workflow

### A) Defining a new metric

1. **Name the question precisely.** "Cost per customer" is ambiguous —
   monthly active, weekly active, paid-only, by tier? Pick one shape.
2. **Confirm the unit-event stream exists.** If the answer requires data
   that nobody's emitting yet, that's a separate engineering ask before
   the metric makes sense.
3. **Choose the unit strategy:**
   - `sum` — for countable events (requests, secret fetches, API calls).
     Each event represents one unit.
   - `max` — for gauge streams where each event is a snapshot of a
     current value (active customer count taken hourly).
   - `last` — for gauges where only the latest reading matters.
   - `avg` — for gauges where you want the average over the period.
4. **Choose the period.** Daily for high-volume operational metrics;
   monthly for business-shape metrics (customers, MRR-style).
5. **Decide on pivot dimensions.** Empty for a global series; one or two
   dimensions for per-tenant / per-product breakdowns.
6. **Test the metric against bundled samples first**:
   ```bash
   unit-econ-forge compute --metrics new-metric.yaml --id &lt;new-id&gt;
   ```
7. **Land in the private overlay** when it produces sensible numbers.

### B) Debugging a metric that looks wrong

Common shapes of "looks wrong" and how to triage:

| Symptom | Likely cause | How to confirm |
| --- | --- | --- |
| `cost_per_unit: None` in every row | Unit stream filter or dimension namespace mismatch | Print metric definition; check `unit_source.filter`; check dim keys in both streams |
| Unit count is way higher than reality | `strategy: sum` on a gauge stream (so each snapshot is being added) | Switch to `strategy: max` or `last` |
| Unit count is suspiciously low | Filter too tight, OR events arriving with wrong dimensions | Inspect a sample of raw unit events |
| Daily numbers vary by 10× | Stream is hour-granularity, period is daily, gauge being summed | Switch strategy OR change period |
| Cost is too low | `cost_source.filter` excludes too much | Check the `filter` block; try empty filter to see total |
| Cost is too high | No filter where one should be (capturing cost for products the unit stream doesn't measure) | Add or tighten `cost_source.filter` |

A useful debug trick: temporarily drop the pivot dimensions to see the
global series; if THAT looks right, the issue is in the pivot, not the
join.

### C) Pre-pricing a new product

1. Define an exploratory metric: cost-per-expected-unit at the
   anticipated demand profile.
2. Run against historical cost data and synthetic / projected unit
   data.
3. Cross-reference with the gross-margin target (70-80% healthy, 65%
   warning line).
4. If the model lands below threshold, the architecture has to change
   before pricing makes sense — pricing alone won't fix it.

### D) Monthly review refresh

1. Refresh the cost-event stream (`attribution-forge ingest`).
2. Run the metric bundle:
   ```bash
   unit-econ-forge compute --metrics monthly-metrics.yaml --format json &gt; monthly-econ.json
   ```
3. Compare the totals row vs last month's. Note any unit-cost trending
   up — that's the signal worth a paragraph in the review.
4. Note any new dimension values appearing — new tenants / new products
   that didn't exist last month. They need their own line.

## Common patterns

- **Dimension namespace alignment with tag-forge.** If your cost
  stream uses `tenant: tenant-a` but your unit stream uses
  `tenant_id: a-001`, the join fails silently (every cell becomes
  `(missing)`). Keep the dim names + values lockstep with the tag
  taxonomy.
- **Sparse buckets are honest.** A period with no units appears as
  `cost_per_unit: None`. Don't paper over with zero — the absence is
  the signal.
- **Cost-per-X compounds with attribution-forge's cost-weighted view.**
  If attribution coverage drops, every unit-econ metric becomes
  uncertain. The data plane has to be healthy first.
- **Watch the `(missing)` pivot bucket.** Resources that exist in the
  cost stream but lack the pivot dimension get bucketed under
  `(missing)`. Its size is a gauge of dimension-namespace drift.

## Anti-patterns

- **Reporting cost-per-X without context.** "$0.01 per request" is a
  number; "$0.01 per request, down 15% MoM, baseline 70% margin"
  is the metric.
- **Computing margin without sanity-checking the inputs.** Garbage
  in, polished-looking-garbage out. Always confirm the cost stream's
  coverage (`attribution-forge verify`) and the unit stream's
  shape before celebrating numbers.
- **Treating the global series as enough.** Per-tenant / per-product
  pivots almost always reveal an internally-cross-subsidized line of
  business hiding inside a healthy-looking global average.
- **Letting a metric drift unmaintained for months.** Unit definitions
  age — what was "an active customer" two years ago may not be the
  same definition today. Annual metric review.

## Related skills

- `cost-attribution` — produces the cost events this tool consumes.
- `tag-architecture` — keeps dimension namespaces aligned between
  cost and unit streams.
- `commitment-review` (TBD) — quarterly commitment decisions
  should use the unit-econ trajectory to size commits, not just
  raw cost trajectory.
- `cadence-review` (TBD) — the monthly review embeds the unit-econ
  series via `cadence-forge`.
