---
name: tag-architecture
description: Design, audit, and enforce the cost-allocation tag taxonomy across clouds and Kubernetes. Use when onboarding a new service, when tag coverage drops, when adding a new cost dimension, or when investigating an attribution gap. Powered by the `tag-forge` Rust binary.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "tag"
    - "label"
    - "taxonomy"
    - "cost-center"
    - "allocation"
    - "finops"
    - "tag-forge"
---

# tag-architecture — Cost-allocation tag taxonomy design + enforcement

This skill wraps the `tag-forge` Rust binary with the workflow guidance for the
four canonical situations: new-service onboarding, coverage drop, dimension
addition, and attribution-gap investigation.

The strategic philosophy this implements lives in the FinOps Strategy doc
(Confluence: *FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
The single non-negotiable: **100% of spend reaches a cost_center**, even if
some of it gets there through virtual-allocation rules.

## When to invoke

- A new service / product / repo is being created — its tags must be designed
  before first commit.
- Tag coverage on a cloud account drops below 98% (anomaly-forge alert).
- A new cost dimension is being added (e.g., new compliance regime, new
  tenant class).
- An attribution gap is found — "$50K/mo lands in the `Other` bucket; why?"
- Quarterly taxonomy review.

## Tools used

- **`tag-forge`** — the Rust binary that validates plans, scans directories,
  renders the taxonomy.
  - `tag-forge taxonomy print` — render current taxonomy
  - `tag-forge taxonomy describe <dim>` — describe one dimension
  - `tag-forge validate <plan>` — exit non-zero on violations
  - `tag-forge scan <dir>` — coverage report across a manifest tree
- **`attribution-forge`** (separate skill: `cost-attribution`) — to verify
  post-change that the tags reach the attribution layer cleanly.

## Workflow

### A) Onboarding a new service

1. Read the canonical taxonomy:
   ```bash
   tag-forge --config $TAG_FORGE_CONFIG taxonomy print
   ```
2. Determine which `cost_center`, `product`, `tenant`, `environment`, `owner`
   the service belongs to. **If any required dimension does not have an obvious
   value, that's a design conversation, not a tagging shortcut.**
3. Add the tags to the resource specs (Terraform / Helm / Kustomize) at the
   creation site, not as a separate `tags.tf` afterthought.
4. Validate the plan locally before merge:
   ```bash
   tag-forge --config $TAG_FORGE_CONFIG validate path/to/plan.yaml
   ```
5. Post-deploy, scan the live manifest tree to confirm coverage:
   ```bash
   tag-forge --config $TAG_FORGE_CONFIG scan path/to/manifests/
   ```

### B) Tag coverage drop — anomaly-driven

1. Identify which dimension(s) dropped from anomaly-forge output / cost-anomaly
   skill investigation.
2. Scan to localize:
   ```bash
   tag-forge --config $TAG_FORGE_CONFIG scan path/to/manifests/ --format json | jq '.per_dimension'
   ```
3. For each impacted dimension, find the new resources that lack it. Common
   causes: a new module skipped the convention, a new chart was written
   without the tag block, a vendor-provided manifest was used as-is.
4. Open PRs that add the missing tags at the creation site.
5. After fix, re-scan to confirm coverage restored.

### C) Adding a new dimension

1. Have the FinOps conversation: does this dimension justify its propagation
   cost? Every dimension adds taxonomy mass — only add when the use case is
   actionable.
2. Update the canonical taxonomy config (the Akeyless overlay, not the generic
   `pleme-io/tag-forge` config):
   - Add to `required` or `optional` list.
   - Add validator definition (`type: string`/`type: enum`).
3. Validate the config parses:
   ```bash
   tag-forge --config new-overlay.yaml taxonomy print
   ```
4. Plan the rollout:
   - Enforce on **new resources first** (CI gate flips required-mode).
   - **Backfill existing on a campaign** — typically a quarter, tracked in a
     Confluence rollout doc.
5. Update the attribution data plane's join keys downstream
   (see `cost-attribution` skill).

### D) Investigating an attribution gap

1. Pull the untagged-spend leaderboard:
   ```bash
   tag-forge --config $TAG_FORGE_CONFIG scan path/to/manifests/ \
     --format json | jq '.per_dimension'
   ```
2. For each gap, distinguish:
   - **Tagging miss** — fix the tags at source.
   - **Untaggable resource** (NAT pool, support tier, shared control plane) —
     write a virtual-allocation rule under `virtual_allocation:` in the
     taxonomy config.
3. Confirm 100% of spend now resolves to a `cost_center`. If not, the gap is
   structural (probably a new resource type), and the taxonomy needs an
   architectural review.

## Common patterns

- **Creation-time enforcement is non-negotiable.** A retroactive-tagging
  campaign is a sign that creation-time enforcement is missing — fix the
  enforcement, the campaign goes away.
- **Virtual tagging for shared infra.** NAT pools, control-plane fees, support
  tier costs, shared CICD clusters — all get virtual-allocation rules. Don't
  leave them in `Other`.
- **K8s labels over node tags for pod workloads.** `tag-forge` already
  resolves label-over-tag where both are present.
- **Tag drift is a signal, not a bug.** Drift usually means a new pattern
  emerged that the taxonomy didn't anticipate. Update the taxonomy.

## Anti-patterns

- **Mandating required tags without enforcement.** Required without a gate is
  optional in practice. Add the validate-on-PR step.
- **Adding dimensions for completeness.** Each dimension has a propagation
  cost. Don't add one without an actionable use.
- **Ignoring untaggable spend.** Letting it accumulate in `Other` until it's
  too big to allocate is a slow-motion failure of the program.
- **Hardcoding tag rules in code.** All policy lives in the taxonomy config,
  not the binary. If you're tempted to hard-code, you're modeling something
  that should be a validator.

## Related skills

- `cost-attribution` — wires the tags into the cost-attribution data plane.
- `lifecycle-policy` — uses the `lifecycle` dimension to drive TTL / retention.
- `cost-anomaly` — surfaces tag-coverage anomalies that trigger this skill.
- `finops-onboarding` — the umbrella onboarding flow that includes this skill.
