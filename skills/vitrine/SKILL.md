---
name: vitrine
description: "Ship an infra change with pre-merge staging evidence"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.2.0"
  last_verified: "2026-10-09"
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
    - "pinned rollout"
    - "cluster Secret pin"
    - "stacked PRs"
    - "terragrunt apply"
    - "showcase"
---

# vitrine — pre-merge evidence delivery

This skill walks a change through the vitrine pattern: implement → put it
on the target (a GitOps pin, or a direct terragrunt apply) → capture
three-layer evidence → embed in PR → review → merge → hand the pin back.

- **Theory:** the vitrine doc in the operator's private theory repo (the WHY)
- **Operator reference:** the vitrine operator reference in the operator's
  private docs (the HOW)

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
- Production outside its gate. A production pin is gated, not forbidden:
  it goes only through the host's pin tool, inside an open change window,
  after `carve ready` passes for the PR and the operator says go. Pattern A
  by Terraform apply never reaches production.

## Step 1 — Confirm vitrine-applicability

Read the diff. Answer three questions:

1. Does the change have a runtime in a target environment? (No → skip.)
2. Does the target have a deployed predecessor of the change? (Yes →
   a pin likely needed.)
3. Is this pure TF, Helm values, or mixed?

If unclear, ask the operator before proceeding.

## Step 2 — Pre-flight

Run the pre-flight checklist (canonical list: the printable pre-flight
checklist in the operator reference).

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

### GitOps chart (Helm + ArgoCD ApplicationSet) — a pin

The appset reads its revision from the destination cluster Secret,
`coalesce(annotation <key>, label <key>)`, so pointing that key at a branch
puts the branch on the cluster.

**Where the host has a pinned-rollout tool, every pin goes through it.**
Such a tool writes the key by compare-and-swap, absorbs anyone else's pin
on the key into a tool-made alias branch instead of reverting it, records
every write in a ledger, and hands each pin back after the merge. The host
org's ArgoCD skill names the tool and its verbs. A hand `kubectl label` or
`kubectl annotate` of a cluster Secret skips all of that; don't.

**Pattern A by Terraform apply fits only a cluster nobody else pins.**
Terraform owns the cluster Secret's labels: a `terragrunt apply` of the
`argocd_cluster` leaf resets every label to its declared value (`master`),
so it silently reverts other people's label pins on that cluster. A pin
tool reports such a unit as displaced. Where nobody else pins the cluster,
Pattern A still works as below.

**Pattern A, preferred (binary):** invoke the `vitrine` CLI:

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

**Pattern A, manual fallback (when `vitrine` isn't installed):**

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
4. Pin the chart's key to the feature branch (the pin tool; Pattern A
   only where nobody else pins the cluster)
5. ArgoCD reconciles; chart deploys

Where the host's rules apply Terraform leaves only from the default
branch after the merge, the PR carries each leaf's plan as its evidence
and the apply receipt follows the merge; a chart that reads a new leaf's
outputs cannot be pinned before that apply.

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

Compose the evidence into the PR body using the operator reference's
"rollback noted, evidence committed" layout. Sections:

1. **Summary**
2. **Pre-flight** — auth, drift, working tree, context
3. **Plan** — fenced code block, trimmed
4. **Apply** — apply output, "Apply complete!" line, ISO timestamp,
   operator identity
5. **Verification** — three-layer table with literal commands + outputs
6. **Rollback** — inverse for each apply step + the pin's restore (the pin
   tool's restore, or Pattern A cleanup)
7. **Tickets**

Push via:

```bash
gh pr edit <PR-num> --body-file <evidence-file>
```

## Step 7 — Post-merge cleanup

After the PR merges to master:

1. If the pin tool was used: run its finalize. It hands every pin back
   (the default branch, the prior holder's branch, or a custody branch
   until that branch contains the merge) and diffs each app against what
   was staged. A pin left in place stops the cluster following the
   default branch.
2. If Pattern A was used: remove the annotation from argocd_cluster TF
   and apply. ArgoCD's targetRevision now resolves from the label to
   `master`, which has the merged content. No Service recreate, no
   traffic blip.
3. If a temporary feature-branch ref persists anywhere in state: confirm
   it has been replaced by `master`.

## Anti-patterns this skill blocks

- "Let me just merge and apply" — block; put every pinnable unit on its
  target before the merge. Terraform leaves the host applies from the
  default branch after the merge carry their plan in the PR instead.
- "Screenshot of the Service health" — block; require the exact command
  + output
- "I'll fix the drift after" — block; sweep drift first, then apply,
  then evidence
- "Pin production now" — block outside the gate; a production pin goes
  only through the pin tool, inside an open change window, after
  `carve ready` passes and the operator says go
- "Pattern A on production", or a `terragrunt apply` of a cluster
  registration while others hold pins on it — block; it reverts their pins
- "I'll just `kubectl annotate` the cluster Secret" — block; the pin tool,
  or a cluster nobody else pins
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

v0.1 (2026-05-18) — the `vitrine` Rust CLI exists. Implemented:

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
