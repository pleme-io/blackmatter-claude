---
name: lifecycle-policy
description: Author, evaluate, and enforce declarative lifecycle policies (TTL, expiry, storage transitions) across cloud + Kubernetes resources. Use when adding a new lifecycle rule, when a cleanup task gets brought up as recurring work, when policy coverage drops, or when wiring a CI gate that blocks resources without retention coverage. Powered by the `lifecycle-forge` Rust binary.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "lifecycle"
    - "ttl"
    - "expiry"
    - "retention"
    - "storage-tier"
    - "lifecycle-forge"
    - "cleanup"
    - "garbage-collection"
---

# lifecycle-policy — Declarative lifecycle as architecture

This skill wraps the `lifecycle-forge` Rust binary with the workflow guidance
for four canonical situations: authoring a new policy, investigating
unhandled resources, wiring lifecycle into CI, and reviewing the audit
posture quarterly.

The strategic philosophy lives in the FinOps Strategy doc on Confluence
(*FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
Architectural Foundation **A8 — Lifecycle as architecture** — says it
explicitly: a FinOps program that has to run a "cleanup project" every
six months has an architectural failure, not a discipline failure.
Lifecycle is policy declared at creation time, enforced by automation —
not heroic cleanup events.

## When to invoke

- A new class of resource enters the org and needs a retention story (S3
  buckets for new audit streams, snapshot policies for new RDS clusters,
  ephemeral namespace shapes for new test patterns).
- A recurring cleanup task surfaces in incident retros or DevOps work
  weeks ("we keep having to delete X" → that's a missing policy, not a
  missing fix).
- `lifecycle-forge audit` reports coverage below threshold.
- Quarterly policy review — are existing policies still right? Are
  resource patterns drifting outside what we've encoded?
- Pre-publishing a new IaC module — the lifecycle rules should be
  declared and enforced alongside the resource itself.

## Tools used

- **`lifecycle-forge`** — the binary.
  - `lifecycle-forge eval --policies P.yaml --resources R.yaml` — produce
    action plan; exits non-zero if any action is planned.
  - `lifecycle-forge audit --policies P.yaml --resources R.yaml` — list
    resources matching NO policy; exits non-zero if coverage < 95%.
  - `lifecycle-forge policy list --policies P.yaml` — list policy IDs.
  - `lifecycle-forge policy print --policies P.yaml &lt;id&gt;` — describe a
    policy.

## Workflow

### A) Authoring a new policy

1. **Name the resource class precisely.** The `target.kind` field is a
   string; pick a stable name (`Namespace`, `Pod`, `s3_bucket`,
   `rds_snapshot`, `aws_eip`) and use it consistently across the
   policy bundle and the inventory pipeline.
2. **Choose the rule type:**
   - `ttl` — for ephemeral resources whose age is the *only* signal
     (test pods, scratch namespaces, ephemeral envs). Action defaults
     to `delete`; use `notify` if the resource needs human review first.
   - `expiry` — for snapshots, backups, log files where deletion at age
     is the expected outcome. Reads more naturally than `ttl: { action:
     delete }` for these cases.
   - `storage_lifecycle` — for storage with tiered hot/warm/cold/archive
     classes. Define transitions in age-ascending order plus an optional
     final `expire`.
3. **Choose the selector.** `label_selector` for K8s workloads
   (`lifecycle: ephemeral`). `tag_selector` for cloud resources
   (`cost_center: cc-observability`). Selectors are AND-combined within
   one policy; use multiple policies for OR.
4. **Validate the policy parses:**
   ```bash
   lifecycle-forge policy list --policies new-bundle.yaml
   ```
5. **Run a dry eval** against a representative resource sample to
   confirm the policy fires when expected and doesn't fire when not:
   ```bash
   lifecycle-forge eval --policies new-bundle.yaml --resources sample.yaml --no-fail
   ```
6. **Wire into the resource's IaC.** The policy is declared upstream
   of creation — the same PR that adds a new bucket should add the
   lifecycle rule, not "we'll add a lifecycle policy later".

### B) Investigating "we keep having to delete X"

When recurring cleanup work surfaces:

1. Add `X` to the resource inventory pipeline if it's not already
   there.
2. Run `lifecycle-forge audit` — confirm X is uncovered.
3. Author the policy (workflow A). The cleanup task disappears.
4. **Track the work as "architectural" not "operational"** — the value
   is the policy landing in IaC and the audit gate catching the next
   instance.

### C) Wiring lifecycle into CI

The `eval` and `audit` exit codes are CI-friendly out of the box:

```yaml
# .github/workflows/lifecycle.yml (sketch)
- name: lifecycle audit
  run: |
    lifecycle-forge audit \
      --policies infra/lifecycle/policies.yaml \
      --resources infra/inventory.yaml
- name: lifecycle eval (drift check)
  run: |
    lifecycle-forge eval \
      --policies infra/lifecycle/policies.yaml \
      --resources infra/inventory.yaml \
      --no-fail \
      --format json &gt; lifecycle-plan.json
```

`audit` is a hard gate (uncovered resources fail the build); `eval` is
a soft surface (emit the plan as an artifact for review). When the
`apply` mode lands in v0.2, `eval` becomes a hard gate too.

### D) Quarterly policy review

1. `policy list` → review the current bundle. Are all policies still
   relevant?
2. `audit` against the current inventory → uncovered count and
   uncovered-by-kind. Is the trend going up?
3. `eval --format json` and diff against the previous quarter's plan
   shape. Has any policy started firing constantly (signal: TTL too
   short for actual workload pattern)? Has any policy stopped firing
   entirely (signal: the resources moved or were renamed)?
4. Update the bundle. Land in the private overlay repo.

## Common patterns

- **Policy lives in the same PR as the resource.** Splitting policy
  authorship into "we'll do it later" produces drift permanently.
- **Audit before eval.** Coverage gaps are the real signal; once
  everything is covered, eval becomes the day-to-day operational
  surface.
- **TTL action `notify` for the first weeks** of a new policy. Watch
  what would have been deleted; flip to `delete` after confidence.
- **Storage tiers in age-ascending order.** STANDARD → IA → Glacier →
  Deep Archive → expire. The transitions evaluate left-to-right against
  current class.
- **Coverage is a moving target.** New resource types appear; the
  audit gate catches them before the cost lands.

## Anti-patterns

- **"We'll clean it up manually."** No. Author the policy. The point
  of this tool is that manual cleanup is the failure mode, not the
  feature.
- **One mega-policy with broad selectors.** Granularity matters —
  small, specific policies are easier to evolve and to silence
  individually if a workload shape changes.
- **TTL set to the shortest convenient unit.** Pick the age that
  reflects actual usage; tight TTLs that delete still-in-use
  resources erode trust in the program faster than anything else.
- **Ignoring uncovered resources.** Audit is the warning; uncovered
  resources become tomorrow's cleanup project.
- **Editing policies in the public reference bundle.** Real org-side
  policies live in a private overlay. The public `configs/default.yaml`
  is illustrative only.

## Related skills

- `tag-architecture` — many lifecycle policies key on tags / labels.
  Tag drift causes lifecycle drift.
- `cost-attribution` — the cost view of why lifecycle matters. When
  audit coverage drops, attribution's "Other" bucket grows.
- `cost-anomaly` (TBD) — surfaces cost spikes that often trace back
  to a missing lifecycle policy (snapshot pile-up, EIP orphan farm).
- `finops-onboarding` (TBD) — the umbrella that ensures every new
  service has its lifecycle declared at creation.
