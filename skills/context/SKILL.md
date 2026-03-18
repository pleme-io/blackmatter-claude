---
name: context
description: "Create, audit, and maintain CLAUDE.md and ./docs documentation for any repo. Use when a repo lacks a CLAUDE.md, when CLAUDE.md is bloated, when ./docs is missing or disorganized, or when documentation needs restructuring for token efficiency."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-18"
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
