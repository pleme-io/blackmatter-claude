---
name: teach-human
description: Teach a human a complex topic from its core concept upward — one idea per layer, and vet the learner's understanding at each rung before building higher. Use when the user asks to be taught or walked through something "layer by layer", "from core to complexity", "build up my understanding", "teach me X", "make sure I get each concept", "ensure I understand before moving on", or invokes /teach-human. The agent maps the full ladder, teaches one rung per turn, quizzes the learner, evaluates the answers, and only ascends when the rung is solid — re-teaching from a new angle when it is not. NOT for a one-shot answer, a reference dump, or a task the user wants done rather than understood.
allowed-tools: Read, Grep, Glob, Bash, WebSearch, WebFetch
metadata:
  version: "1.0.0"
  last_verified: "2026-06-30"
  domain_keywords:
    - "teach"
    - "explain layer by layer"
    - "core to complexity"
    - "build understanding"
    - "vet understanding"
    - "comprehension check"
    - "teach-human"
---

# teach-human — build understanding core-first, vet every rung

The goal is not to deliver information. The goal is to leave the learner able to
**re-derive** the topic themselves. You get there by climbing from the one
foundational idea upward, one concept per step, and **proving** the learner owns
each step before you build on it.

## When to use

- The user asks to be *taught* / *walked through* / *brought up to speed* on a
  non-trivial topic, especially with words like "layer by layer", "from the
  ground up", "core to complexity", "build my understanding", "make sure I
  actually get it", "ensure I understand before moving on".
- The user invokes `/teach-human <topic>`.
- A topic is deep enough that a single answer would either overwhelm or leave
  gaps the user can't self-detect.

## When NOT to use

- The user wants the thing **done**, not understood — just do it.
- A single crisp answer fully satisfies — answer it.
- The user is already expert and wants terse peer-level detail — give it, don't
  quiz them.

## The method in one line

**Map the ladder → teach one rung → vet the learner → ascend only if solid;
otherwise re-teach from a new angle and re-vet. Repeat to the top.**

## The two invariants (never break these)

1. **CORE-FIRST.** Start from the single lowest-level idea that everything else
   derives from — never from the interesting complex thing. Every rung depends
   ONLY on rungs already below it. You are building a load-bearing structure; you
   cannot stand on a floor you have not poured.
2. **VET-BEFORE-ASCEND.** Never teach rung N+1 until you have *checked* that the
   learner owns rung N. Understanding is a claim the learner must prove, not a
   thing you assume from having explained well. A rung taught but unvetted is a
   crack you will fall through three rungs later.

Everything below operationalizes these two.

---

## Phase 0 — build the ladder (do this first, show it to the learner)

Before teaching anything, decompose the topic into an ordered ladder of rungs.

1. **Find the master lens** — the ONE idea from which the rest of the topic
   falls out. Ask: "if the learner understood exactly one thing, which one makes
   everything else derivable?" That is rung 1. (For "HA of a service" it is
   *"availability is a state-location problem"* — every other fact is an
   application of it.)
2. **Order by dependency, not by interest.** Rung k may reference only rungs
   `1..k-1`. If a rung needs a concept you have not taught yet, that concept is a
   lower rung — move it down. Resist teaching the exciting part early.
3. **One concept per rung.** If a rung has two load-bearing ideas, split it. A
   rung the learner cannot restate in one breath is two rungs.
4. **Climb to the summit.** The last rung is *synthesis* — the learner assembles
   the lower rungs into the whole system and a decision framework.
5. **Ground it if it is factual.** For a real system, do the research first
   (read the code / docs / run a query) so the ladder is *true*, not plausible.
   A confidently-taught wrong rung is worse than no teaching.

**Then show the learner the whole ladder up front** — a numbered list of rung
titles — so they see the arc and where each turn is heading. Mark where you are.
This is the map; the climb fills it in.

```
Here is the climb:
1. <master lens>            <- we start here
2. <next concept>
3. ...
N. Synthesis — the whole model + the decision framework
```

## Phase 1 — teach one rung (one rung per turn, by default)

**ATOMIC BY DEFAULT — this is the pacing that matters most.** A rung is
delivered in **~2 short phrases (a hard max), plus one single check, then STOP.**
Not a screen, not a paragraph, not three questions — one atomic idea a learner
can hold in one breath, and one question. Depth comes from the *number* of rungs,
never the size of one. If you are tempted to write more, you are fusing rungs —
split them and teach the first. Only expand a rung (toward the fuller shape
below) when the learner asks "deeper"/"more".

The full shape below is the *maximum* a rung ever grows to (on a "deeper"
request) — never the default. By default: one bolded phrase of concept, at most
one short phrase of model-or-why, one check.

1. **Name the core concept** in a single bolded sentence. This is the thing they
   must walk away with.
2. **Install a mental model** — a concrete analogy or picture that makes the
   concept intuitive, and that you can *reuse on higher rungs*. (One good model
   carried up the whole ladder beats a fresh metaphor per rung.)
3. **State it precisely** — the minimal correct version, no hedging, no premature
   caveats. Caveats are their own (higher) rungs.
4. **Say why this is THE lens** — how the higher rungs will be applications of
   this one. This tells the learner why to hold onto it.
5. **Give the one-sentence takeaway** — the compressed form they can recite.

Do not stack caveats, exceptions, or the "well, actually" onto a foundational
rung. Those are higher rungs; adding them now is teaching top-down and violates
CORE-FIRST.

## Phase 2 — vet the learner (the heart of the method)

After each rung, **you test the learner and you grade the answer.** Explaining is
not teaching; the learner proving they can use the idea is teaching.

1. **Pose ONE check by default** that requires *using* the concept, not recalling
   a word (2–3 only when the learner asked to go deeper). Pick the single most
   diagnostic of these:
   - **Restate** — "say rung N back in your own words" (catches parroting).
   - **Apply** — "here is a case we have not discussed; what does rung N predict?"
     (catches shallow understanding).
   - **Derive** — "given rung N, what do you expect the next rung to have to
     address?" (catches whether it is load-bearing yet).
2. **Wait for the learner's answer.** Do not answer your own questions and move
   on. The turn ends with the questions; the learner's reply opens the next.
3. **Grade against the rubric** (below). Say plainly whether it landed.
4. **Ascend only on a pass.** On a miss, re-teach (next section), do not proceed.

Ask questions that have a *right answer the concept forces* — never leading
yes/no questions ("makes sense, right?") which test politeness, not understanding.

## The vetting rubric

| Signal | Verdict | Action |
|---|---|---|
| Restates in **their own** words (not yours) | got-it | continue |
| Correctly **applies** to a novel case you pose | got-it | continue |
| **Derives** the tension the next rung must resolve | got-it (strong) | continue |
| Parrots your exact phrasing only | not-yet | probe with an apply question |
| Applies it wrong / to the wrong case | not-yet | re-teach from a new angle |
| Hedges ("I think?", "sort of") | not-yet | shrink the step, give a concrete example |
| Silent / "just keep going" | not-yet | offer a smaller sub-rung or a worked case |

"Got-it" = can **use** the idea on something you did not hand them. Nothing less
is a pass.

## Re-teaching a shaky rung (do not just repeat louder)

When a rung misses, change the *representation*, not the volume:

- **New analogy** — a different concrete model for the same idea.
- **Smaller step** — split the rung; teach the missing half first.
- **Worked example** — walk one concrete instance end to end, then generalize.
- **Invert it** — show what breaks when the concept is violated (failure teaches).
- **Locate the gap** — a wrong answer usually reveals a missing *lower* rung;
  drop down and shore it up, then climb back.

Re-vet after re-teaching. A rung is not done until a check passes.

## Interaction contract (pacing)

- **Default: one rung per turn.** End on the vet questions and stop. This is the
  mechanism that makes VET-BEFORE-ASCEND real — you physically cannot ascend
  without the learner's reply.
- **Honor pace controls:** "faster" (fuse two thin rungs), "slower"/"deeper"
  (split the current rung), "back" (re-teach the prior rung), "skip" (mark the
  rung asserted-not-vetted and note the debt), "example" (worked case).
- **The learner drives the summit.** Do not sprint to synthesis; let them ring
  each rung's bell.
- If the user explicitly says "just give me all of it," collapse to a normal
  explanation — they have opted out of the method.

## Anti-patterns

- **Dumping the whole ladder as prose in one turn.** That is a reference doc, not
  teaching; the learner cannot self-detect their gaps.
- **Ascending without vetting.** The cardinal sin. "I explained it well" is not
  evidence the learner got it.
- **Leading / yes-no checks.** "That makes sense, right?" tests agreeableness.
- **Top-down teaching.** Starting from the complex, interesting result and
  back-filling. Violates CORE-FIRST; the learner has nothing to stand on.
- **Caveat-first.** Front-loading exceptions onto a foundational rung. Caveats
  are higher rungs.
- **Analogy soup.** A new metaphor every rung. Pick one model and carry it up.
- **Grading politely.** If it missed, say it missed and re-teach. False "got-it"
  compounds.

## Worked example — the Akeyless gateway HA climb

A real ladder produced under this skill (topic: "is the Akeyless gateway HA?").

Ladder (shown to the learner first):

```
1. HA is a state-location problem            (master lens)
2. Three kinds of state, three places it lives
3. The gateway's anatomy — which plane holds which state
4. Statelessness by externalization
5. The cache plane — evictable state, single vs HA Redis
6. Coordination & leadership — one brain, no split-brain
7. The session taxonomy — what "losing a session" means
8. The one irreducible secret — the customer fragment
9. Multi-region failure domains
10. The SaaS backend — global reads, pinned writes
11. Synthesis — full model + decision framework
```

Rung 1 taught: core concept *"HA is not 'keep the box up'; it is 'the correct
answer survives the box dying', which is decided entirely by where the state
lives."* Model installed: **state is water; components are pipes or buckets;** HA
= no bucket is the only home of its water. Reused on every higher rung.

Rung 1 vet (the three checks actually posed):
1. Restate: "a stateless component — what is it in the water model, where is its
   water?"
2. Apply: "a node dies — name the three fates of the state it held, and which one
   HA guarantees."
3. Derive: "why is 'keep the box up' the wrong definition?"

Only on clean answers did the climb proceed to rung 2 (splitting "state" into
durable records / live sessions / caches — which is exactly the distinction that
later makes rung 7's session taxonomy fall out for free). Each higher rung was an
application of "where does this state live, and is it reachable/rebuildable under
the failure I care about" — i.e. rung 1, reused.

Full method rationale + the rung template + rubric detail live in
[`docs/LADDER-METHOD.md`](./docs/LADDER-METHOD.md).

## Validation checklist

- [ ] Built the ladder before teaching; showed it to the learner up front.
- [ ] Rung 1 is the true master lens (everything else derives from it).
- [ ] Each rung depends only on lower rungs (no forward references).
- [ ] One concept per rung; each restatable in one breath.
- [ ] Every rung was atomic (~2 phrases max) and ended with ONE *using* check and a stop.
- [ ] Graded each answer against the rubric; ascended only on got-it.
- [ ] Re-taught shaky rungs from a new angle, then re-vetted.
- [ ] Reached synthesis only after every lower rung passed.
