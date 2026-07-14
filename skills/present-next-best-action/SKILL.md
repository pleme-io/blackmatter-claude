---
name: present-next-best-action
description: Refresh state across every open thread (GitHub PRs, Jira sprint, Confluence, pending tasks, memory-flagged initiatives), rank them, and present exactly ONE next action with live recon so the user can decide fast. Use when the user says "what's next", "what can I do to move things forward", "give me my next best action", invokes /present-next-best-action, or asks to walk their backlog "one by one" / "don't dump everything at once". Built around the user's own stated constraints — thin working memory across sessions, low tolerance for bulk dumps, wants the final click on anything hard-to-reverse to stay theirs. NOT for open-ended backlog grooming, sprint planning, or presenting a menu of options (unless the user explicitly asks to compare choices).
allowed-tools: Read, Bash, Grep, Glob
metadata:
  version: "1.0.0"
  last_verified: "2026-07-14"
  domain_keywords:
    - "what's next"
    - "next best action"
    - "move things forward"
    - "one by one"
    - "present-next-best-action"
    - "my sprint"
    - "goldfish attention"
---

# present-next-best-action — one clear thing at a time, always freshly checked

The point of this skill is to be the user's external working memory and
triage function, not a status dashboard. It exists because the user has said
directly: his own memory and attention span are the limiting resource, not
his judgment — so the highest-leverage thing an agent can do is remove the
burden of *tracking* and *re-deriving priority*, and hand him one well-formed
decision at a time. Every invocation does the remembering and the ranking;
he only has to decide.

## The one-line contract

**Refresh everything live → rank by real leverage → present ONE action with
just-verified status → state one bounded ask → stop and wait.**

Never batch. Never assume state from earlier in the conversation is still
true. Never take the hard-to-reverse step yourself.

## When to use / not

- Use: "what's next", "what should I do now", "help me move my sprint
  forward", "give me the next best action", `/present-next-best-action`,
  or any request to walk a backlog "one by one" / "my attention span is
  goldfish" style pacing.
- Not for: sprint planning / backlog grooming (that's a bulk operation by
  nature), a request to compare N named options (present a comparison, not
  a single ranked pick), or a request that already names the exact task to
  work on (just do that task — this skill is for when the user hasn't
  named one).

## Step 1 — refresh, never recall

Before ranking anything, pull live state. Do not reuse a status you already
reported earlier in this conversation — a PR that was red five minutes ago
may be green now, a thread that was unresolved may be resolved. This is the
same discipline as [[reference_reality_over_inference]]: verify API state,
don't infer from what you last remember saying.

Cheap sources, check every invocation:
- **Open PRs the user authored**, across every repo they're active in right
  now (not just one) — `gh pr list --author <user> --repo <repo> --json
  number,title,isDraft,mergeStateStatus,reviewDecision,statusCheckRollup`
  per repo, or `gh search prs --author <user> --state open` for a
  cross-repo sweep. For each: is it draft, what's CI status, is it
  approved, is it blocked and by what (checks / conversations / behind
  base / review count) — the same kind of protection-rule dig used to
  explain why a PR was stuck despite green checks.
- **PRs open against the user for review** — lower priority for *his* next
  action (it's proof of nothing he needs to do), but worth one line if one
  has been sitting unreviewed a long time and he's the blocker for someone
  else.
- **The harness's own pending tasks** (TaskList/TaskGet if available this
  session) — treat `pending` items as candidates, `completed` as noise to
  filter out, and anything that looks done-in-reality-but-still-pending as
  a task-list hygiene fix to make silently, not present as an action.
- **Jira** — current sprint issues assigned to the user
  (`jira_get_sprint_issues` / `jira_search` with `assignee = currentUser()
  AND sprint in openSprints()`), read for status and any blocking
  transitions available right now.
- **Memory's active-initiatives index** (`MEMORY.md`) — cross-reference,
  but treat every line as a *claim to verify*, not a fact to present. A
  memory saying a PR is open must be re-checked against the real PR state
  before it's allowed to become "the next action" — per
  [[reference_reality_over_inference]] and the "before recommending from
  memory" rule: a memory is frozen at write time, reality may have moved.

Only reach for a slower source (Confluence sweep, a fresh recon subagent)
when the cheap sources come up empty, or the user explicitly asks "check
everywhere."

## Step 2 — rank by real leverage, not by list order

Score every live candidate this way, highest tier wins:

1. **Already at a decision point.** Green CI, approved, nothing left but a
   human's final click, OR blocked on a small named fact only the user can
   supply (a yes/no, a value, a judgment call). Zero new work for him,
   maximum leverage from thirty seconds of attention. Always the top tier.
2. **Blocked on something narrow and nameable.** One missing piece — a
   review request, a merge conflict only he can resolve the intent of, a
   design question with a clean two-option shape. Still cheap, still high
   leverage.
3. **Unblocks other things.** Progressing it clears a dependency for
   something else on the list (a fan-in point) — worth surfacing even if
   it takes more than a glance.
4. **Plain new work, no urgency signal.** Present only when nothing above
   exists. If several are tied, use the memory index to see which one has
   an external commitment or timeline attached ("Why:" lines exist for
   exactly this).

Within a tier, prefer **the freshest signal** — something whose status
*just changed* (CI just went green, a reviewer just replied, a conflict
just got resolvable) over something merely old. Recency of actionable
state beats recency of creation; a three-week-old ticket with nothing new
to react to is not more urgent than a PR that turned green ten minutes
ago.

Anything requiring an irreversible action from the agent (merging,
force-pushing, deleting, applying to a shared environment) is never itself
"the action" — it always surfaces one step earlier, as "ready, needs your
click," never as something already done or about to be done without him.

## Step 3 — present exactly one

Template (adapt tone, keep the shape):

```
<one line: what this is, plain language, no doctrine jargon>
<one line: why this is the one right now — the tier + the fresh signal>

<3-6 bullet freshly-checked facts: CI, review, blockers, exact numbers/links>

<one bounded ask: a decision, a click, an answer — specific enough to act on in one reply>
```

Keep it short enough to read in one breath. If there is genuinely a
second-tier item close behind, do not show it unless asked — mention only
that there is a next one in line ("and there's one more ready after this,
say the word").

## Standing constraints (do not relearn these mid-skill)

- **Never execute the hard-to-reverse step for him.** No merges, no
  force-pushes, no destructive applies — prepare, verify, get to green,
  hand off the click. This is a fixed line, not a per-PR judgment call.
- **Never reveal AI involvement in any akeyless-facing artifact** (PR
  comments, Jira comments, Confluence in shared/akeyless spaces) — act and
  write as the operator, first person, no attribution.
- **One thing at a time, always.** Presenting three ranked options when he
  asked "what's next" is the failure mode this skill exists to prevent.
- **State the fresh check, don't just assert the conclusion** — "CI is
  green as of just now (link)" beats "this is ready," because the former
  is falsifiable and the latter asks for trust in stale memory.

## After he responds

- If he acts (answers the question, tells you to proceed, hits merge
  himself) — do the next bounded piece of work that follows from that
  answer, then either keep going within the same thread or re-enter Step 1
  fresh before naming the *next* next action. Do not carry forward a
  ranking computed before his answer — his answer may have changed what's
  now unblocked.
- If he doesn't respond or moves on to something else entirely, drop the
  thread; do not chase.

## Anti-patterns this skill exists to prevent

- Dumping the full backlog "so you have everything" — the opposite of the
  point.
- Presenting a status from earlier in the conversation as still current.
- Ranking by list/creation order instead of real leverage.
- Treating a memory file's claim as ground truth without re-checking it.
- Executing the final irreversible step because it was "obviously" what
  he'd want.
- A generic multi-option menu when he asked for the single next thing —
  save menus for when he explicitly asks to compare.

## Related

[[reference_reality_over_inference]] · [[feedback_recon_is_not_decision]] ·
[[reference_development_rhythm]] — this skill is the *presentation* layer
that sits on top of those existing verification/pacing disciplines; it adds
nothing to what "verify before claiming" already means, it just applies it
on a fixed one-item-at-a-time cadence tuned to how this user wants to
receive it.
