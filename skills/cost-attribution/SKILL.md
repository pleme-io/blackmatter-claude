---
name: cost-attribution
description: Set up, query, and audit the cost-attribution data plane. Use when wiring a new source into the cost stream, when investigating an attribution gap, when answering "what did X cost last month", or when verifying that the data plane is healthy. Powered by the `attribution-forge` Rust binary.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "cost-attribution"
    - "billing"
    - "cost-per"
    - "showback"
    - "unit-economics"
    - "attribution-forge"
    - "finops"
---

# cost-attribution — The cost-attribution data plane

This skill wraps the `attribution-forge` Rust binary with workflow guidance
for the four canonical situations: source wiring, gap investigation,
ad-hoc cost queries, and data-plane health checks.

The strategic philosophy lives in the FinOps Strategy doc on Confluence
(*FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
The architectural foundation this implements is **A3 — Cost-attribution
data plane**: cost data lands in the same queryable surface as the rest of
observability, joinable on `cost_center × tenant × product × time`, so cost
questions become SQL queries instead of tickets.

## When to invoke

- A new source (cloud account, new cluster, new business-event stream) needs
  to feed the cost data plane.
- An attribution gap is found — "$X of monthly spend resolves to no
  `cost_center`; why?"
- Someone asks "what did service / tenant / product / region X cost
  yesterday / last week / last month?"
- Quarterly data-plane health check — what's coverage today vs last quarter?
- Pre-launching unit-economics work — `unit-econ-forge` requires the
  attribution layer to be healthy first.

## Tools used

- **`attribution-forge`** — the binary.
  - `attribution-forge schema print` — canonical Event schema
  - `attribution-forge ingest --sources &lt;cfg&gt; --output &lt;events.jsonl&gt;`
  - `attribution-forge query &lt;events&gt; --by &lt;dims&gt; [--format json]`
  - `attribution-forge verify &lt;events&gt; --required &lt;dims&gt; [--format json]`
- **`tag-forge`** (separate skill: `tag-architecture`) — pre-step. If
  attribution is broken, tagging is often the root cause.

## Workflow

### A) Wiring a new source

1. **Identify the source format.** Most cloud billing exports are CSV. AWS
   CUR, GCP Billing Export, Azure Cost Management — all support CSV.
   Kubernetes utilization scrapes can be exported to CSV by most tooling.
2. **Sample the file.** Look at column headers. Identify:
   - the timestamp column
   - the cost column (USD; if not USD, conversion is required upstream)
   - the service / SKU column
   - region / resource id (optional but useful)
   - which tag columns exist (`resource_tags_user_*`, `labels_*`,
     `tag_*`, etc.)
3. **Author the source entry** in the org's `sources.yaml` overlay:
   ```yaml
   sources:
     - type: csv
       id: <stable-id>
       path: /path/to/export.csv
       cloud: aws | gcp | azure | k8s
       column_map:
         ts: <column>
         cost_usd: <column>
         service: <column>
         region: <column>  # optional
         resource_id: <column>  # optional
       tag_columns:
         cost_center: <column>
         tenant: <column>
         product: <column>
         environment: <column>
         owner: <column>
   ```
4. **Test ingest locally** before adding to the org sources config:
   ```bash
   attribution-forge ingest --sources test-source.yaml --output /tmp/t.jsonl
   ```
   - Read the stderr stats — `ok` count vs `skipped` count.
   - Sample a few JSONL lines with `head /tmp/t.jsonl | jq` to confirm
     fields landed correctly.
5. **Add to the org sources config**. The real config lives in a private
   repo (e.g. `akeyless-finops-config`), not in pleme-io.

### B) Investigating an attribution gap

1. Run a fresh ingest to ensure data is current.
2. Query by the dimension that's reportedly missing:
   ```bash
   attribution-forge query events.jsonl --by cost_center
   ```
3. The `(missing)` bucket is the gap. Note its $ amount — that's the bill
   you're hunting.
4. Drill into the missing bucket — query by the resource_id column to find
   specific untagged resources:
   ```bash
   attribution-forge query events.jsonl --by cost_center,service --format json \
     | jq '.rows[] | select(.key[0] == "(missing)")'
   ```
5. Cross-reference with `tag-forge scan` to find whether the resources
   themselves are untagged (fix at the source) or whether they ARE tagged
   but the column map is wrong (fix the sources config).
6. For inherently untaggable spend (shared NAT, control plane, support
   tier), use a virtual-allocation rule in `tag-forge` rather than
   shoehorning a real tag.

### C) Answering an ad-hoc cost question

1. Confirm the events file is recent. If not, re-ingest.
2. Choose the right grouping dimension(s):
   - "Cost by service": `--by service`
   - "Cost by product": `--by product`
   - "Cost by tenant per product": `--by tenant,product`
   - "Cost by cloud per region": `--by cloud,region`
3. Run the query. For programmatic use, prefer `--format json`.
4. Note time-window filtering is **not yet** in v0.1 — pre-filter the
   events file with `jq` if you need a specific window.

### D) Data-plane health check

1. Run `verify` against the org's required dimensions:
   ```bash
   attribution-forge verify events.jsonl --required cost_center,tenant,product
   ```
2. **Read the cost-weighted column, not the row-count column.** Row
   coverage of 99% can hide 50% of dollars in 1% of untagged-but-huge
   resources.
3. Exit code is 1 if any required dimension drops below 95% cost coverage.
   This is intentional — the verify command is CI-friendly.
4. If coverage is below threshold, the disposition is one of:
   - Tag the under-tagged resources at the source (via `tag-architecture`
     skill).
   - Add a virtual-allocation rule for inherently untaggable spend.
   - Adjust the column map if the data is present but the mapping is
     wrong.

## Common patterns

- **The data plane is the substrate.** Every downstream forge tool
  (`unit-econ-forge`, `anomaly-forge`, etc.) consumes this output. If
  attribution coverage drops, downstream confidence drops.
- **Cost-weighted &gt; row-weighted.** Always the more honest metric.
- **Per-row errors don't fail the ingest.** Malformed rows get skipped
  with a logged reason; structural errors (missing required column)
  fail the run. This shape matches the "data quality is the
  foundation" principle — surface gaps without blocking the pipeline.
- **JSONL output is composable.** Stream into `jq`, into Shinryū, into
  any downstream tool that reads line-delimited JSON.
- **`(missing)` is a legitimate bucket.** Don't filter it out — its size
  is the metric.

## Anti-patterns

- **Treating row coverage as the only signal.** A handful of huge
  untagged resources can hide behind 99% row coverage. The verify
  command shows both; read both.
- **Ignoring skipped rows during ingest.** Each skip is a data-quality
  signal. Track the trend; investigate increases.
- **Burying the column map in a script.** The sources YAML is the
  contract. Keep it declarative.
- **Adding a new source without verify follow-up.** Every wired source
  should produce a verify report before the data plane is considered
  healthy with it included.

## Related skills

- `tag-architecture` — the upstream skill. If tags are bad, attribution
  is bad.
- `unit-economics` (TBD) — the next downstream consumer; will reference
  this skill when computing cost-per-X.
- `cost-anomaly` (TBD) — uses the attribution events as the baseline
  it detects deltas against.
- `finops-onboarding` (TBD) — the umbrella onboarding flow that
  includes wiring a new service into the attribution layer.
