# The Ladder Method — teaching core-first, vetting every rung

Long-form companion to the `teach-human` skill. Read this once; the `SKILL.md` is
the operational quick-reference.

## The thesis

Most explanation optimizes for **transmission** — say the true thing clearly.
Teaching optimizes for **reconstruction** — leave the learner able to re-derive
the thing without you. Those are different targets, and the second needs a
different method: build a load-bearing structure from the ground up, and test
each floor before you stand on it.

Two invariants carry the whole method:

- **CORE-FIRST** — teach from the single foundational idea upward; each new idea
  rests only on ideas already taught.
- **VET-BEFORE-ASCEND** — advance only after the learner *proves* they own the
  current idea by using it, not by nodding at it.

## Why core-first works (the cognitive-load rationale)

Working memory is small. When you teach the complex, interesting result first,
the learner must hold a stack of undefined terms while you back-fill them — the
stack overflows and the ideas slide off. When you teach the base concept first,
each new idea has a *place to attach*: it is "just an application of the thing I
already hold." Load stays bounded because every rung compresses into the one
below it. This is why a good rung 1 (a **master lens**) is worth more than any
five higher facts — it is the schema the rest hangs on.

Corollary: the exciting part is almost never rung 1. Discipline is teaching the
boring foundation first anyway. The excitement is the *payoff* of the climb, not
its start.

## Why vetting works (the testing effect + desirable difficulty)

Two well-established results:

- **The testing effect** — retrieving/using a fact strengthens it far more than
  re-reading it. A comprehension check is not overhead; it is where the learning
  happens.
- **Desirable difficulty** — a learner who *struggles slightly* to apply an idea
  retains it; one who is handed a fluent restatement does not. So the vet
  questions should make the learner *do work* (apply to a novel case), not
  recognize the answer.

The deeper reason: **you cannot see inside the learner's head.** "I explained it
clearly" is evidence about *you*, not about *them*. The only signal that a rung
landed is the learner producing correct output on something you did not hand
them. Vetting converts an invisible internal state into an observable one.

## The ladder-construction algorithm

Given a topic, produce an ordered ladder:

1. **Find the master lens.** Ask: "what is the one idea that, once held, makes the
   rest of this topic *derivable* rather than *memorizable*?" Techniques:
   - Look for the invariant every fact is an instance of. ("Availability is a
     state-location problem" makes every HA fact an instance.)
   - Look for the question the expert asks reflexively. (An HA expert, on hearing
     "stateless", instantly asks "so where did the state go?")
   - If two candidates compete, pick the one the other can be derived *from*.
2. **Enumerate the concepts** the full understanding requires. Do not order yet.
3. **Topologically sort by dependency.** Concept B is above concept A iff
   understanding B *requires* A. A rung may reference only lower rungs. If your
   draft rung forward-references, the referenced thing is a lower rung — move it.
4. **Split fat rungs.** Any rung carrying two load-bearing ideas becomes two. Test:
   can the learner restate it in one breath? If not, split.
5. **Cap with synthesis.** The final rung assembles the lower rungs into the whole
   system and a decision framework — the learner does the assembling, prompted.
6. **Ground factual ladders in sources.** For a real system, research first (read
   code, docs, run a query) so each rung is *true*. A confidently-taught wrong
   rung is the worst outcome: the learner builds correctly on a false base.

Show the finished ladder (rung titles, numbered, "you are here" marked) to the
learner before teaching rung 1. The map lets them place each turn in the arc.

## The per-rung template

Keep a rung to ~one screen. Depth is the count of rungs, not the size of one.

1. **Core concept** — one bolded sentence; the takeaway.
2. **Mental model** — a concrete analogy/picture; reusable on higher rungs.
3. **Precise statement** — the minimal correct form; no premature caveats.
4. **Why this is THE lens** — how higher rungs will apply it.
5. **One-sentence takeaway** — the compressed, recitable form.

Carry **one** mental model up the ladder where you can. A model reused across
rungs (e.g. "state is water; components are pipes or buckets") compounds: each
rung deepens the same picture instead of resetting it.

## The vetting protocol and rubric

After each rung, pose 2–3 checks that require *using* the idea:

- **Restate** — in the learner's own words (catches parroting).
- **Apply** — to a novel case you supply (catches shallow grasp).
- **Derive** — what the next rung must resolve (catches load-bearing-ness).

Then grade:

| Learner produces | Verdict | Next move |
|---|---|---|
| Own-words restatement, correct | got-it | ascend |
| Correct application to a novel case | got-it | ascend |
| Derives the next rung's tension | got-it (strong) | ascend |
| Verbatim echo only | not-yet | pose an apply question |
| Wrong application | not-yet | re-teach, new angle |
| Hedged / uncertain | not-yet | shrink the step, give an example |
| "just continue" / silence | not-yet | offer a smaller sub-rung |

Grade **out loud and honestly**. A false "got-it" to be polite compounds into a
collapse several rungs up, where the true gap is hard to locate.

### Graded examples

Topic rung: *"HA is a state-location problem."*

- Learner: *"So a stateless service still has state, it just keeps it somewhere
  else, and any copy can grab it — the copies are the pipes, the somewhere-else
  is the reservoir."* → **got-it (strong)**: own words + extends the model.
  Ascend.
- Learner: *"HA means the correct answer survives a box dying."* → **got-it**:
  correct core, own words. Ascend (optionally probe with an apply case).
- Learner: *"HA means you run more than one replica."* → **not-yet**: that is a
  mechanism, not the concept; it misses *why* replicas help (state location).
  Re-teach by inverting: "here are two replicas that both lose the data on
  failover — are they HA? why not?"
- Learner: *"makes sense."* → **not-yet** (no signal). Pose an apply question;
  never accept agreement as evidence.

## Re-teaching moves (change representation, not volume)

A miss means the current representation did not attach. Switch it:

- **New analogy** for the same idea.
- **Smaller step** — split and teach the missing half.
- **Worked example** — one concrete instance end to end, then generalize.
- **Inversion** — show what breaks when the concept is violated.
- **Drop a rung** — a wrong answer often exposes a missing *lower* rung; shore it
  up and climb back.

Always re-vet after re-teaching. The rung is not done until a check passes.

## Interaction contract

- **One rung per turn** by default. The turn ends on the vet questions; the
  learner's reply begins the next. This physical structure is what enforces
  VET-BEFORE-ASCEND — you cannot ascend inside a single turn.
- **Pace controls:** faster (fuse thin rungs), slower/deeper (split), back
  (re-teach prior), skip (mark asserted-not-vetted + note the debt), example.
- **Opt-out:** if the learner says "just give me all of it," collapse to a normal
  explanation — they have left the method deliberately.

## Anti-patterns (expanded)

- **The wall of prose.** Delivering the whole ladder at once. It *looks* like
  teaching and *is* a reference dump; the learner cannot detect their own gaps.
- **Assumed understanding.** Ascending because you explained well. The most
  common and most damaging failure.
- **The agreeable check.** "Right?" / "make sense?" — measures politeness.
- **Top-down.** Leading with the impressive result. No foundation to stand on.
- **Caveat-first.** Exceptions on a base rung. Exceptions are higher rungs.
- **Metaphor churn.** A fresh analogy each rung; the learner rebuilds context
  every time instead of deepening one model.
- **Polite grading.** Passing a miss to avoid friction; guarantees a later
  collapse.

## Worked example — the Akeyless gateway HA ladder

Produced under this method (topic: "how HA is the Akeyless gateway, really?").

Ladder shown to the learner first:

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

- **Master lens (rung 1):** availability is decided by *where state lives*, not by
  keeping a box up. Model: **state is water; components are pipes or buckets; HA =
  no bucket is the only home of its water.** This model is then reused on every
  rung: the cache plane is a bucket whose water also lives in the SaaS reservoir
  (rung 5); a live bastion session is water that lives *only* in one bucket, so it
  cannot survive (rung 7); the customer fragment is the one drop of water that
  lives in *no* reservoir and so must be poured into every region by hand (rung
  8). Each higher rung is rung 1 applied.
- **Dependency ordering shows its value:** rung 2 (splitting state into durable
  records / live sessions / caches) is deliberately below rung 7 (the session
  taxonomy), because once the learner holds the three *kinds* of state, the
  session answers fall out for free instead of being memorized.
- **Vetting gated the climb:** rung 1's three checks (restate "stateless" in the
  water model; name the three fates of state on node death; say why "keep the box
  up" is wrong) had to pass before rung 2. A learner who answered "HA means more
  replicas" was re-taught by inversion (two replicas that both lose data on
  failover — HA or not?) before ascending.

The payoff of the method: by the summit the learner can answer a *new* question —
"what does a cross-region failover lose?" — by reasoning ("which of these buckets
has no reservoir in the other region?") instead of recalling a table. That is
reconstruction, which was the target.
