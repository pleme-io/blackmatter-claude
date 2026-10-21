# Reconciler state: one typed Phase

## The rules

1. **Status is a pure function of one typed Phase.** Every condition, printer column and summary is projected from it. No code path writes a condition by hand.
2. **Ready or Settled while `generation > observedGeneration` is unconstructible.** The projection takes the live generation. `observedGeneration` advances only when a pass settles, or fails with a reason.
3. **A progress heartbeat with a rate.** A running pass writes a heartbeat time and a progress count (resources done, cursor length, upstream calls). A reader gets a rate from two reads. CPU and open sockets are never the signal.
4. **Named stuck states.** Each known stuck state is its own variant, for example `QueuedBehind{pass}`, `ProviderSilent`, `ImportAbsent`. Each has its own reason, event, metric and remedy.
5. **A generic deadline is a backstop only.** When it fires it reports which unnamed state it caught, so the next fix can name it.
6. **Detect the previous incarnation's phase on startup.** A phase left by a dead process (Planning with no live worker) is marked at startup. It never waits for a timeout.

## Receipt

pangea-operator, 2026-10-21. A 2,049-resource drift pass held the reconcile and wrote no status. A new generation showed Ready=True for about 24 minutes. A provider at 0% CPU was killed as wedged while it was only slow. Fix: commit 1b527a6 (`PassPhase`, `ConditionSet`, `PassGuard` heartbeat, watchdog to `Stalled`).

## Reading it from outside

`shinchoku reconcile-liveness` (a blue command) reads two snapshots. It answers moving, stalled, queued-behind, blind or settled. It is blind, never stalled, when no progress field exists.
