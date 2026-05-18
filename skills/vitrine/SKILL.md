---
name: vitrine
description: Deliver a code change to a target environment with pre-merge evidence — Pattern A GitOps override for chart-driven work, structured three-layer evidence capture (TF state, cloud API, functional), PR-as-showcase delivery. Use when shipping infrastructure / chart / service changes that have a runtime in staging, when a reviewer-facing PR needs proof-of-life evidence inline, or when each step of a stacked PR set needs its own apply receipts. Skip for typo fixes, doc-only changes, or pre-bootstrap targets.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  last_verified: "2026-05-18"
  domain_keywords:
    - "vitrine"
    - "evidence"
    - "delivery"
    - "pre-merge"
    - "proof-of-life"
    - "Pattern A"
    - "ArgoCD"
    - "GitOps"
    - "annotation override"
    - "stacked PRs"
    - "terragrunt apply"
    - "showcase"
---

# vitrine — pre-merge evidence delivery

This skill walks a change through the vitrine pattern: implement → apply
to target via Pattern A (or direct terragrunt apply) → capture three-layer
evidence → embed in PR → review → merge → remove Pattern A override.

- **Theory:** `pleme-io/theory/VITRINE.md` (the WHY)
- **Operator reference:** `pleme-io/docs/vitrine.md` (the HOW)

This skill is the operator-side automation — it walks the user through
the steps, captures evidence, and produces the PR-description block
ready for `gh pr edit --body-file`.

## When to invoke

Invoke when the user says any of:
- "ship this with evidence"
- "apply this in staging before merge"
- "deliver this PR through vitrine"
- "do the Pattern A override"
- "make this PR carry evidence"
- "open the PR with proof-of-life"

Or proactively when the operator is opening a PR for an infra / chart /
service change that has a meaningful staging environment AND no existing
evidence section in the PR description.

## When to skip

- Pure documentation / comment / typo changes
- Library code that has no runtime
- Targets the operator can't reach (firewall-blocked, pre-bootstrap)
- Production-direct changes (production is the merged-and-promoted output
  of a staging vitrine — block direct Pattern A on production unless the
  operator explicitly authorizes)

## Step 1 — Confirm vitrine-applicability

Read the diff. Answer three questions:

1. Does the change have a runtime in a target environment? (No → skip.)
2. Does the target have a deployed predecessor of the change? (Yes →
   Pattern A override likely needed.)
3. Is this pure TF, Helm values, or mixed?

If unclear, ask the operator before proceeding.

## Step 2 — Pre-flight

Run the pre-flight checklist (canonical list in
`pleme-io/docs/vitrine.md#pre-flight-checklist-printable`).

Report failures up front. Don't proceed past pre-flight without clean
status. Common failure modes to surface explicitly:

- **AWS SSO expired** — `aws sts get-caller-identity` →
  `InvalidGrantException`. Surface a one-line fix: `! aws sso login`
- **kubectl wrong context** — operator has multiple clusters; the wrong
  one would receive the apply
- **gcloud active project mismatched** — apply runs against
  `gcloud config get-value project`, not the project in the terragrunt
  config; easy footgun
- **Pre-existing drift on target** — surface and propose either (a)
  sweep first in a separate apply pass, or (b) accept drift in evidence
  with clear annotation

## Step 3 — Plan

```bash
cd <target-terragrunt-dir>
terragrunt plan -out=/tmp/<branch>.tfplan -no-color
```

Trim output to the relevant resource(s); save the exact text. Don't
paraphrase.

If plan output is huge, try `terragrunt plan -target=<resource-address>`.
Note that `-target` can fail with "Moved resource instances excluded";
fall back to full plan + grep when this happens.

## Step 4 — Apply via the appropriate path

### Pure TF (no GitOps controller involved)

```bash
terragrunt apply /tmp/<branch>.tfplan
```

The planfile-pinned apply is atomic — no surprise diffs between plan
time and apply time. Skip `-auto-approve` on a fresh plan.

### GitOps chart (Helm + ArgoCD ApplicationSet) — Pattern A

**Preferred (binary):** invoke the `vitrine` CLI from `pleme-io/vitrine`:

```bash
vitrine isolate <chart-name> \
  --branch <feature-branch> \
  --cluster-terragrunt <path/to/argocd_cluster/>
```

This sets the annotation, runs `terragrunt apply`, and prints the
ArgoCD reconciliation watch command. Equivalent post-merge cleanup:

```bash
vitrine release <chart-name> \
  --cluster-terragrunt <path/to/argocd_cluster/>
```

Check that `vitrine` is installed (`vitrine --version`); if not,
suggest `programs.vitrine.enable = true;` in home-manager (the flake
auto-emits the module trio) or fall back to the manual path below.

**Manual fallback (when `vitrine` isn't installed):**

Apply uses a temporary annotation on the cluster's `argocd_cluster`
terragrunt that overrides the default `master` git ref:

```hcl
metadata = {
  labels = {
    <chart-name> = "master"
  }
  annotations = {
    <chart-name> = "<feature-branch>"
  }
}
```

Then `terragrunt apply` on the argocd_cluster directory. ArgoCD's
ApplicationSet picks up the annotation, generates an Application pulling
from the feature branch. Watch reconciliation:

```bash
kubectl --context <target-cluster> get application -n argocd <app-name> \
  -o jsonpath='{.status.sync.status}:{.status.health.status}'
```

Expect `Synced:Healthy` within 1–2 min.

### Mixed (TF + Helm values referencing TF outputs)

Order matters:
1. TF apply first (creates resources the chart needs — reserved IPs, etc.)
2. Read TF outputs for any values the helm chart needs
3. Push a fixup commit replacing placeholder values with actual TF outputs
4. argocd_cluster TF apply with Pattern A annotation pointing at the
   feature branch
5. ArgoCD reconciles; chart deploys

## Step 5 — Verify (three layers, all required)

Capture all three. Cite each in the PR with the literal command + output.

| Layer | Sample commands |
|---|---|
| TF state | `terragrunt output -json` |
| Cloud API | `gcloud compute addresses describe …` / `aws … describe-…` / `az resource show …` |
| Functional | `curl -v https://<endpoint>:443/` / `kubectl get svc -n <ns> <name>` / health probe |

A passing functional probe without the literal command behind it is not
evidence — reviewers must be able to re-run.

## Step 6 — Embed evidence + rollback in PR description

Compose the evidence into the PR body using the layout in
`pleme-io/docs/vitrine.md#5-rollback-noted-evidence-committed`. Sections:

1. **Summary**
2. **Pre-flight** — auth, drift, working tree, context
3. **Plan** — fenced code block, trimmed
4. **Apply** — apply output, "Apply complete!" line, ISO timestamp,
   operator identity
5. **Verification** — three-layer table with literal commands + outputs
6. **Rollback** — inverse for each apply step + Pattern A cleanup if used
7. **Tickets**

Push via:

```bash
gh pr edit <PR-num> --body-file <evidence-file>
```

## Step 7 — Post-merge cleanup

After the PR merges to master:

1. If Pattern A was used: remove the annotation from argocd_cluster TF
   and apply. ArgoCD's targetRevision now resolves from the label to
   `master`, which has the merged content. No Service recreate, no
   traffic blip.
2. If a temporary feature-branch ref persists anywhere in state: confirm
   it has been replaced by `master`.

## Anti-patterns this skill blocks

- "Let me just merge and apply" — block; insist on apply-before-merge
- "Screenshot of the Service health" — block; require the exact command
  + output
- "I'll fix the drift after" — block; sweep drift first, then apply,
  then evidence
- "Pattern A on production" — block by default; production deployments
  follow staging via reviewed merge, not pre-merge annotation override
- "Just trust me, it's running" — block; cite or skip the PR

## Output format

When the operator says "ship this with vitrine", produce:

1. A pre-flight report (auth confirmations, drift status, working tree)
2. The plan output (fenced code block, trimmed)
3. The apply output (fenced code block, with timestamp)
4. The three-layer verification table with actual outputs
5. The rollback block
6. A `gh pr edit … --body-file …` command the operator runs to embed
   all of the above into the PR

Use a TaskCreate task list when the steps span more than four operator
commands. Keep each cited command short enough to fit in a PR table cell
or a 5-line code block.

## Substrate status

v0.1 (2026-05-18) — `pleme-io/vitrine` Rust CLI exists. Implemented:

- ✅ `vitrine isolate <chart> --branch <feature> --cluster-terragrunt <path>`
- ✅ `vitrine release <chart> --cluster-terragrunt <path>`

Stubbed (this skill still walks the operator through these manually
until they're implemented):

- 🚧 `vitrine plan <module>` — capture `terragrunt plan` for evidence
- 🚧 `vitrine apply <module> --planfile <file>` — planfile-pinned apply with capture
- 🚧 `vitrine verify --config <path>` — three-layer evidence capture
- 🚧 `vitrine embed <pr> --evidence <path>` — `gh pr edit --body-file`
- 🚧 `vitrine ship --config <path> --pr <num>` — full workflow

Other deferred substrate (no work started):

- A `pleme-io/actions-vitrine` reusable workflow that auto-comments on PR
- A PR template (`.github/PULL_REQUEST_TEMPLATE.md`) lintable by CI

When `vitrine` is installed (`programs.vitrine.enable = true;` in
home-manager imports `vitrine.homeManagerModules.default` auto-emitted by
the substrate flake), prefer the binary path for any operation it
covers. Walk the operator manually for stubbed operations.
