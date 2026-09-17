---
name: dream
description: >-
  Consolidate an agent memory corpus — measure reachability, migrate durable
  knowledge into CLAUDE.md/theory, merge duplicates, retire what is spent, and
  re-cue the rest so no memory is written-but-never-loaded. Use during ANY wait
  (a build, a workflow, a long agent run) as the standing answer to "what do I do
  while that runs", and whenever the operator says "dream", "consolidate memory",
  "refactor memory", "memory is full", "make memory efficient", "throw away the
  useless ones", or "get some of it out to CLAUDE.md". Also fires when MEMORY.md
  is near its byte ceiling, when a memory index link is dead, or when you catch
  yourself shortening index labels to make something fit.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-09-17"
  domain_keywords:
    - "memory consolidation"
    - "memory index"
    - "MEMORY.md ceiling"
    - "unreachable memories"
    - "migrate to CLAUDE.md"
---

# dream — memory consolidation

**A fast, capacity-limited store takes everything the day produced. Consolidation
replays it, promotes what *generalizes* into slow vast storage, and lets the rest
go.** Skip it and the fast store does not gently fill — it silently stops
admitting.

`MEMORY.md` is the capacity-limited store: one hard byte ceiling, loaded every
session, and its only job is to let a future agent decide **which file to open**.
CLAUDE.md and `theory/` are the slow vast storage. Dreaming moves things between
them.

## When

Any wait. A build, a workflow, a long agent run — this is the standing answer to
"what do I do while that runs", and it is a task class, not a mood. Also on the
explicit triggers in the description, and on one signal worth naming: **catching
yourself shortening an index label to make something fit.** That is the store
telling you it is full, and shaving is the wrong response (see Trap 1).

## Measure before you touch anything

Never consolidate from impression. Four numbers decide the whole pass:

```bash
M=~/.claude/projects/<project>/memory
python3 - <<'PY'
import os,re
M=os.path.expanduser("~/.claude/projects/<project>/memory")
PAT=r'\(([A-Za-z0-9_.-]+)\.md\)'          # hyphens and dots, NOT [a-z0-9_]+
have={f[:-3] for f in os.listdir(M) if f.endswith(".md")}
idx=set()
for f in ("MEMORY.md","INDEX-FULL.md"):
    p=os.path.join(M,f)
    if not os.path.exists(p): continue
    s=open(p).read(); links=set(re.findall(PAT,s)); idx|=links
    print(f"{f}: {len(s.encode())} bytes, {len(links)} links, {len(links-have)} DEAD")
mem={f[:-3] for f in os.listdir(M) if f.endswith(".md") and f not in ("MEMORY.md","INDEX-FULL.md")}
print(f"memories {len(mem)} | reachable {len(mem&idx)} | UNREACHABLE {len(mem-idx)}")
PY
```

| number | what it means |
|---|---|
| index bytes vs ceiling | how much room you have (the ceiling is stated in `MEMORY.md`'s own header) |
| **unreachable count** | memories written at full cost that no session can ever load — usually the real problem |
| dead links | index entries pointing at files that no longer exist |
| corpus size | the denominator for every other claim |

**Receipt, 2026-09-17:** 515 files / 2.77 MB, **253 unreachable (49%)** — and the
unreachable half was the *larger* one at 1.55 MB. Index headroom: 37 bytes. Zero
dead links, every file well-formed, each memory correct the day it was written.
Nothing was broken. It had simply never been consolidated.

## The four verdicts

Every memory gets exactly one. "Leave it" is not among them.

- **MIGRATE** — durable knowledge true for *anyone* in this codebase, not just
  this operator. The test: would it hold for a new contributor with no session
  history? Doctrine, an architectural law, a repo convention. **This is the step
  that actually creates room** — retiring alone rarely does. Route with
  `contextualizify`: org doctrine → the org CLAUDE.md, repo fact → that repo's,
  canonical spec → `theory/`. Hand the writing to `context`.
- **KEEP** — operator-specific, live-operational, or a trap that will bite again:
  the cross-session facts *not* derivable from code or git. Only these may hold
  hot-index bytes.
- **ARCHIVE** — true but rarely needed (a dated incident, a finished migration).
  Stays on disk, moves to the overflow index.
- **RETIRE** — superseded, duplicated, already in code/git/CLAUDE.md, or only
  ever mattered inside one finished conversation. **Name what supersedes it and
  confirm that thing exists on disk.** An unjustified delete is the only
  unrecoverable move in the pass, so an uncertain memory is KEEP, never RETIRE.

Back the corpus up first — `tar czf <scratch>/memory-backup.tgz -C <parent> memory`
— so the whole pass is reversible.

## Order of operations

1. **Measure** (above).
2. **Repair dead links and broken index pointers first.** Cheapest routing-power
   per byte by orders of magnitude.
3. **Classify** the corpus. At a few hundred files this is worth fanning out to
   subagents over slices; give them the descriptions, and require them to open
   any file they are inclined to RETIRE.
4. **Retire**, then strip those entries from *both* indexes in the same pass — a
   deletion that skips the overflow index just moves the dead links there.
5. **Migrate**, grouped by target so each doc is edited once.
6. **Re-cue everything still dark** into the overflow index. Unreachable is a
   routing failure, not a value judgement.
7. **Re-measure.** The pass is done when unreachable and dead links are both 0
   and the index has real headroom.

## Traps — every one of these was measured, not imagined

**1. Shaving labels destroys the thing the index is for.** Holding a ceiling by
compressing entries to `[Err names tl]`, `[pkill -f me]`, `[Trivy-=UNSCAN]` buys
bytes by making entries unroutable. A label nobody can decode routes nobody, so
it costs bytes and returns nothing. Measured: 120 of 262 labels were fully
redundant with their own filename (3,658 bytes) while the shaving campaign on the
cryptic ones recovered ~1,300. **Fix a ceiling by promoting and retiring.**

**2. Never read "unreachable" as "low value".** It almost always means the index
hit its ceiling. The 2026-09-17 pass found the **akeyless STEALTH trio**
unreachable from both indexes — an L1 disclosure rule governing whether AI
attribution leaks onto customer-facing artifacts, invisible to every session.

**3. One lost character can strand a hundred memories.** That same corpus had
`[INDEX-FULLmd](INDEX-FULLmd)` in the header — a dot lost to an earlier shave —
which cost routing to **101 memories**. A 2-byte repair. Check the index's own
links before anything else.

**4. Renaming files to shorten the index is a trap.** It looks like free bytes.
Measured: renaming 262 files would have broken **184 of the overflow index's 285
links** — destroying routing to 184 memories while repairing 101. Prefer dropping
labels that merely restate their filename; the filename is already a description.

**5. Your link regex needs hyphens and dots.** `[a-z0-9_]+` silently misses
`project_fleet_build_breakage_2026-05-27.md`, so a hyphenated memory reads as
unreachable *and* as not-a-link. A blind spot in the measurement reads exactly
like a finding.

**6. `mtime` IS a usable staleness signal — read it correctly.** A bucket like
`{<30d: 262}` cannot discriminate when every file is under 30 days; that is a
vacuous measurement, not a finding of uniformity. Measured properly: 211 files
sat at one bulk timestamp (an "untouched since" floor — exactly the retirement
candidate list) while 51 carried 44 distinct recent mtimes and were demonstrably
live.

**7. In zsh/frostmourne, `for f in $VAR` does not word-split.** A delete loop
over an unquoted space-separated variable iterates *one long string*, matches
nothing, and **exits 0 having done nothing** — indistinguishable from success.
Use an array, a `while read` loop, or do the file operations in Python.

## Ghost pointers — audit outward too

A memory corpus is cited *from* CLAUDE.md files. Grep the repos for memory
filenames and confirm each resolves. The same pass found `nix/CLAUDE.md` citing
`reference_rio_live_builder` (twice) and `reference_shepherd_loop` — neither had
ever existed. **A ghost pointer is worse than no citation**: a reader chasing a
named record assumes the detail exists somewhere and stops looking, so the
citation suppresses the search it was meant to start.

## Validation checklist

- [ ] Corpus backed up before any deletion.
- [ ] Measured first; every claim carries a number and a date.
- [ ] Unreachable = 0 and dead links = 0 in **both** indexes, re-measured at the end.
- [ ] Index under its ceiling with headroom bought by promoting/retiring, not shaving.
- [ ] Every RETIRE names a superseder that was confirmed to exist on disk.
- [ ] Migrated content landed via `context`/`contextualizify`, not pasted ad hoc.
- [ ] Outward citations (CLAUDE.md → memory filenames) all resolve.
- [ ] Link regex admitted hyphens and dots.
