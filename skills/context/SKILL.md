---
name: context
description: "Create or trim CLAUDE.md and docs; audit skill budget"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "2.0.1"
  last_verified: "2026-07-27"
  domain_keywords:
    - "CLAUDE.md"
    - "docs"
    - "documentation"
    - "context"
    - "README"
---

# Context — CLAUDE.md and ./docs Documentation

This skill manages the documentation structure that gives Claude (and developers)
the right information at the right time. It enforces the index/library pattern:
CLAUDE.md as the lean always-loaded index, ./docs as the comprehensive on-demand library.

## Step 1: Assess Current State

Before creating or modifying anything, read the existing documentation:

```bash
# Check what exists
test -f CLAUDE.md && echo "CLAUDE.md: exists ($(wc -l < CLAUDE.md) lines)" || echo "CLAUDE.md: missing"
test -f README.md && echo "README.md: exists ($(wc -l < README.md) lines)" || echo "README.md: missing"
test -d docs && echo "docs/: exists ($(ls docs/ | wc -l) files)" || echo "docs/: missing"
```

Classify the situation:

| State | Action |
|-------|--------|
| No CLAUDE.md | Create one from the codebase |
| CLAUDE.md > 200 lines | Extract detail to ./docs, replace with pointers |
| CLAUDE.md exists but no ./docs | Add ./docs if there's deep knowledge worth capturing |
| ./docs exists but no pointers in CLAUDE.md | Add pointer section to CLAUDE.md |
| Everything exists and is lean | Audit for staleness and accuracy |

## Step 2: Create or Refine CLAUDE.md

CLAUDE.md is the index. It must be **lean** (under 200 lines) and cover:

1. **What this repo is** — one paragraph
2. **Build commands** — how to build, test, lint
3. **Key conventions** — naming, structure, patterns to follow
4. **Documentation pointers** — links to ./docs files with descriptions
5. **Anti-patterns** — what NOT to do (only the critical ones)

### Template

```markdown
# {repo-name}

{One paragraph: what this repo does, its role in the ecosystem}

## Build

{Minimal build/test/lint commands}

## Structure

{Key directories and what they contain — brief}

## Conventions

{Critical conventions that affect every task}

## Documentation

- `./docs/architecture.md` — {one-line description}
- `./docs/testing.md` — {one-line description}
- `./docs/adr/` — architecture decision records

## Anti-Patterns

- {thing to never do and why}
```

### What Does NOT Belong in CLAUDE.md

- Full architecture descriptions (move to `./docs/architecture.md`)
- API reference (move to `./docs/api.md`)
- Migration guides (move to `./docs/migration.md`)
- Troubleshooting (move to `./docs/troubleshooting.md`)
- History or changelog (that's git)

If you're writing more than 20 lines about a single topic, it belongs in ./docs.

## Step 3: Create or Refine ./docs

./docs is the library. Create files for any topic that needs more than a section:

```bash
mkdir -p docs
```

### Common docs to create

| File | When to create | Content |
|------|----------------|---------|
| `architecture.md` | System has multiple components or non-obvious design | Component relationships, data flow, key abstractions |
| `testing.md` | Test strategy isn't obvious from code | Fixtures, test categories, how to run integration tests |
| `api-conventions.md` | Repo exposes APIs | Endpoint patterns, error codes, auth |
| `deployment.md` | Deployment is non-trivial | Release process, environment config, rollback |
| `troubleshooting.md` | Common issues exist | Problem → diagnosis → solution |
| `adr/NNN-title.md` | Non-obvious design decision made | Context, decision, consequences |

### ADR Template

```markdown
# ADR-{NNN}: {Title}

## Status: {Proposed | Accepted | Superseded by ADR-XXX}

## Context
{What problem or question prompted this decision}

## Decision
{What was decided and why}

## Consequences
{What follows from this decision — both positive and negative}
```

### Writing docs for the agent

Write docs that are useful to both humans and agents:

- **Lead with the answer**, not the reasoning. An agent reading `architecture.md` wants
  to know the component layout before the history of how it evolved.
- **Use concrete examples** over abstract descriptions. Show a real API call, not a
  description of what API calls look like.
- **State constraints explicitly.** "Never modify the auth middleware without updating
  the integration tests" is more useful than "the auth middleware has tests."

## Step 4: Add Pointers to CLAUDE.md

After creating ./docs files, add a Documentation section to CLAUDE.md:

```markdown
## Documentation

- `./docs/architecture.md` — system design, component relationships, data flow
- `./docs/testing.md` — test strategy, fixtures, integration test setup
- `./docs/adr/` — architecture decision records (one per decision)
```

Every pointer needs a description. The description is what the agent uses to decide
whether to read the file — without it, the agent has to guess from the filename.

## Step 5: Validate

After creating or modifying documentation:

1. **CLAUDE.md is under 200 lines** — if not, extract more to ./docs
2. **Every ./docs file has a pointer in CLAUDE.md** — orphan docs are invisible
3. **Every pointer has a description** — filenames alone aren't enough
4. **Build commands are accurate** — test them
5. **No duplication between CLAUDE.md and ./docs** — CLAUDE.md points, ./docs explains

## The Closed Evolution Loop

When working in a repo and you notice:

- CLAUDE.md is missing → create it from the codebase
- CLAUDE.md is bloated → extract to ./docs
- A topic has no doc → create it in ./docs, add pointer
- An ADR should exist → create it in ./docs/adr/
- Documentation is stale → update it

**Do this as a side effect of the current task, not as a separate documentation sprint.**
The context skill follows the same self-extending pattern as the build and service skills:
gaps are filled as work is done, not as a separate effort.

## Anti-Patterns

- **Never put full architecture docs in CLAUDE.md** — wastes tokens on every conversation
- **Never create ./docs files without CLAUDE.md pointers** — orphan docs are invisible to the agent
- **Never duplicate content between CLAUDE.md and ./docs** — one points, the other explains
- **Never omit pointer descriptions** — the agent needs descriptions to select the right doc
- **Never skip ADRs for non-obvious decisions** — the agent will propose reversing them

---

# Part II — Auditing a fleet-scale context budget

Part I authors one repo's docs. This part governs the **whole loaded surface** when
it has grown past the point where reading it is affordable. Written from a measured
sweep of a 935-repo fleet (2026-07-27); every number below was produced by a command,
not an estimate.

## The mechanical facts (verify with `/context`, do not trust from memory)

These come from `code.claude.com/docs`, quoted, and they are the constraints any
context work is actually optimizing against:

- **Per-entry skill cap: 1,536 characters.** "The combined `description` and
  `when_to_use` text is truncated at 1,536 characters in the skill listing."
  Text past the cut is *silently discarded* — a trigger phrase there can never match.
  Configurable via `skillListingMaxDescChars`.
- **Aggregate listing budget: 1% of the context window.** "When the listing
  overflows, Claude Code drops descriptions starting with the skills you invoke
  least." Raise with `skillListingBudgetFraction` or `SLASH_COMMAND_TOOL_CHAR_BUDGET`.
  The doc's "1%" is not the number you get: read the real one from
  `claude -p --debug-file <f> --model <m> "reply ok"`, which logs
  `Skill listing over budget: N skills, X chars > B budget` on overflow. Measured
  2026-10-01 (2.1.286): **B = 30,000 on a 1M-context model, 8,000 on a 200k one**,
  and bundled skills take ~13,000 of it before any of yours.
- **CLAUDE.md is re-injected into every subagent.** "Every level of the CLAUDE.md
  hierarchy the main conversation loads… The built-in Explore and Plan agents skip
  this," and "there is no frontmatter field or per-agent setting to change which
  agents skip them." So an N-agent fan-out pays the org file N times. **The agent
  *type* is the only lever.**
- **Compaction budget:** re-attached skills keep the first 5,000 tokens each, sharing
  25,000 total; older invocations are dropped.
- CLAUDE.md is **context, not enforced configuration**. "To block an action
  regardless of what Claude decides, use a PreToolUse hook."

## The order of operations

1. **Measure first, with `/context` and `/doctor`.** `/context`'s Skills row reports
   the listing size *after* the budget is applied — i.e. what the model actually
   receives. Cutting before measuring makes the result unmeasurable.
2. **Fix the tooling layer before the prose.** It is cheaper, contained, and makes
   every later step cheaper. Sweep MCP servers for reachability — a dead registration
   still pays full tool-schema and instruction-block cost forever. Then price them by
   use: `skill-lint usage report` counts skill invocations, and
   `skill-lint usage mcp-report --since 30d --tools <names>` counts calls per MCP
   server and ranks the configured-but-unused ones by tool count.
3. **Correct facts before relocating them.** A collapse that moves a wrong claim is
   worse than the bloat.
4. **Cut, then seal.** An unsealed cut regrows. Land a baseline-debt lint in the
   same arc.

## The measurement traps (each of these produced a real wrong number here)

- **Grepping for a banned token matches the documentation OF the ban.** Counting
  `format!` in a crate returned 5; four were doc-comments *stating there is no
  `format!()`*. The true count was 1. **Exclude comments and test modules.**
- **A harness that reports the fix broken is usually the broken thing.** A coverage
  check said a workflow mis-routed; the regex was capturing only the first line of a
  multi-line `if: >-`. Validate the harness against a known-good input first.
- **Count what the consumer counts.** YAML block scalars reach the listing *folded*;
  raw source bytes over-count. Fold before measuring.
- **A gate that has never failed may be checking nothing.** Before trusting one,
  break its input deliberately and watch it go red.
- **Coverage is part of the gate.** A linter wired into 1 of 7 repos is green because
  it never looks at the other 6 — indistinguishable from passing.

## ★ REJECTED — measured negatives; do not re-litigate

Recorded so these are not rediscovered every sprint. Each has a source.

Rejected, in one line each: cutting for file SIZE alone, reformatting to XML or reordering by priority, hierarchical (multi-level) disclosure, bigger context windows, `llms.txt`, and promising an adherence % from a cut. The evidence table: `references/rejected.md`.

**The one carve-out to MODULARIZE-DON'T-DELETE.** That rule is right for code, where a
dormant declaration costs zero tokens. It **inverts in always-loaded context**:
repeating a claim closes the source-authority gap by **~30 percentage points**
("Whose Facts Win?", 13 models, 7,440 conflict pairs). So leaving a stale claim beside
its correction makes the *wrong* claim more authoritative, and a DESIGN-tier claim
restated in four places outranks a SHIPPED one stated once — inverting the tier ledger
the corpus exists to maintain. **In always-loaded context: delete-and-restate. Git holds
the history.**

## Sequencing that is known to work

Tooling sweep → tier corrections → per-entry caps → aggregate budget → prose collapse
→ seal with a lint. Diagnosis parallelizes (use **Explore** agents — they skip the
CLAUDE.md injection); edits to shared files serialize.

## References

- `references/rejected.md`: the evidence behind each rejected approach, before proposing one of them
