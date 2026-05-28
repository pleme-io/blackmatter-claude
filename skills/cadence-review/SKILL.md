---
name: cadence-review
description: Facilitate or compose a FinOps review packet (weekly team / monthly program / quarterly leadership / annual strategic). Use when running the scheduled review, when adding a new section to a recurring packet, when tuning the cadence of a team's review, or when migrating reviews from manual aggregation to automated forge-tool composition. Powered by the `cadence-forge` Rust binary.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "cadence-review"
    - "weekly-review"
    - "monthly-review"
    - "quarterly-review"
    - "cadence-forge"
    - "finops"
    - "review-packet"
---

# cadence-review — The recurring FinOps review

This skill wraps the `cadence-forge` Rust binary with workflow guidance
for **the recurring FinOps reviews** — weekly team, monthly program,
quarterly leadership, annual strategic.

The strategic philosophy lives in the FinOps Strategy doc on Confluence
(*FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
Part VI (The Continuous Cadence) is the directive: a mature program
operates on multiple loops at different cadences, each with a different
audience and a different question.

## When to invoke

- Running this week's / month's / quarter's review.
- Adding a new section to a recurring packet.
- Onboarding a new team and standing up their review rhythm.
- Migrating a manually-aggregated review to forge-composed packets.
- Quarterly packet-spec refresh — are the right sections still being
  surfaced?

## Tools used

- **`cadence-forge`** — the composer.
  - `cadence-forge render &lt;spec&gt;` — render a packet to Markdown.
  - `cadence-forge render &lt;spec&gt; --output &lt;path&gt;` — write to a file.
  - `cadence-forge spec sections &lt;spec&gt;` — list sections.
  - `cadence-forge spec print &lt;spec&gt;` — canonical YAML.
- **`showback-forge`** (skill: `chargeback-rollout`) — produces
  trend/render/top sections.
- **`anomaly-forge`** (skill: `cost-anomaly`) — produces anomaly section.
- **`rightsize-forge`** (skill: `rightsize-fleet`) — produces
  recommendation section.
- **`commitment-forge`** (skill: `commitment-review`) — produces
  portfolio status section (quarterly especially).
- **`unit-econ-forge`** (skill: `unit-economics`) — produces unit-economic
  metric section.

## Workflow

### A) Running a weekly team review

1. **Refresh the upstream outputs.** In CI or a `make weekly` recipe:
   ```bash
   attribution-forge ingest --sources sources.yaml --output /tmp/events.jsonl
   showback-forge trend /tmp/events.jsonl --dimension cost_center --period 1w --periods 8 \
     > sections/trend.txt
   anomaly-forge detect /tmp/events.jsonl --rules rules.yaml \
     > sections/anomalies.txt
   rightsize-forge analyze ... > sections/rightsize.txt
   ```
2. **Compose the packet:**
   ```bash
   cadence-forge render weekly-team-packet.yaml --output /tmp/weekly.md
   ```
3. **Post the Markdown** to the team channel / Confluence / email.
4. **15 minutes in the team meeting** — disposition the anomalies, decide
   on rightsize PRs, note the trend.

### B) Running a monthly program review

1. Same shape as weekly, but the packet spec includes more sections:
   - Org-wide cost trend (cost_center + product + tenant pivots)
   - Top-10 services by spend, top-10 by delta
   - Unit-economic series (cost-per-customer, cost-per-tenant)
   - Tag-coverage health
   - Anomaly disposition rate (how many fired, how many dispositioned)
2. Cadence is monthly, audience is the engineering org + finance.

### C) Running a quarterly leadership review

1. Cadence is once a quarter, audience is leadership + finance.
2. Includes:
   - Strategic narrative (one paragraph TL;DR)
   - Commitment portfolio status (`commitment-forge analyze`)
   - Gross margin by product (`unit-econ-forge margin` — v0.2)
   - Capacity-planning input from the Perf Hub
   - Architectural recommendations (rightsize + lifecycle posture
     summary)
3. Output is a single Markdown packet ≤ 5 pages; embed source data as
   appendix attachments.

### D) Adding a new section to a recurring packet

1. **Identify what's missing.** A common shape: an existing meeting
   surfaces information that's not in the packet. That information
   wants to be a section.
2. **Decide which forge tool produces it.** If none exists, the
   section is either `inline` (manually written) or a new forge tool
   you'll add later. Don't fight the absence — write inline for now,
   add the tool later.
3. **Add a section to the spec YAML.** Run `spec sections` to confirm
   the new entry parses.
4. **Wire the upstream tool into the recipe** if it's `forge_output`.
5. **Render and post.** First week's version may be rough — refine
   in subsequent weeks.

### E) Migrating from manual aggregation

When a team is already doing reviews but with hand-aggregated data:

1. Map what the team is currently writing manually to forge-tool
   outputs:
   - "Top 5 most expensive services this month" → `showback-forge top
     --dimension service`
   - "What anomalies fired" → `anomaly-forge detect`
   - "What's our cost trend" → `showback-forge trend`
2. **Run both in parallel for one cycle.** Manual + forge-composed.
   The forge version should match the manual one ±5%.
3. **Transition to forge-composed.** Keep the manual artifacts for one
   more cycle as backup; then retire them.

## Common patterns

- **TL;DR up top, drill-downs below.** Five rows of narrative + the
  detailed sections below. The TL;DR is what most readers consume.
- **Same packet structure week-over-week.** Consistency builds
  pattern-recognition; readers know where to look.
- **Source attribution on every section.** The `_Source: \`tool\`_` line
  cadence-forge adds is non-decorative — it tells the reviewer how
  to drill from packet back to raw data.
- **Embed JSON for the data-side reviewer.** A second packet
  (program-only, not team-facing) can use `json_file` sections to
  attach machine-readable copies of the data.

## Anti-patterns

- **Reviewing without dispositioning.** A meeting where anomalies are
  read out but never closed is wasted effort. Every meeting should
  close some open items.
- **Over-stuffing the packet.** A 30-section packet is unread. Aim
  for 5–7 sections per cadence; demote the rest to appendix or
  separate packets.
- **Different teams seeing different shapes.** Use the same shape
  across teams (cadence-forge's same-spec idea); team-specific data
  is in the inputs, not the spec.
- **Hand-aggregating "for this one quarter."** Manual aggregation
  always becomes permanent. Land the automation.
- **Skipping the cadence because "nothing changed."** A flat
  zero-change packet IS the story — and the discipline of producing
  it keeps the rhythm so an actual change next week doesn't go
  unreviewed.

## Related skills

- `chargeback-rollout` — provides the showback views the cadence
  packets embed.
- `cost-anomaly` — provides the alert section.
- `rightsize-fleet` — provides the recommendation section.
- `commitment-review` — provides the portfolio section.
- `unit-economics` — provides the cost-per-X section.
- `cost-attribution` — provides the upstream events the others read.
- `tag-architecture` — keeps dimension namespaces stable; broken tags
  break every packet.
