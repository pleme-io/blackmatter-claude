# kikai cluster lifecycle

kikai is a k3s VM orchestrator and is NOT engenho; this is its own lifecycle.

## kikai cluster lifecycle

`kikai` drives the 14-state cluster FSM (its `state.rs`, exhaustively
proptested). Subcommands (run from a cluster's nix dir; prefer the user runs
interactive ones via `! kikai …`):

| Command | Effect / FSM event |
|---|---|
| `kikai init --cluster <c>` | generate bootstrap secrets + TLS bag → `Initialized` |
| `kikai up` | build image, create disks, launch VM, wait health → `…→ Healthy` |
| `kikai status` | aggregate health (VM/API/node/Flux/pods) |
| `kikai down` | graceful shutdown → `Stopped` |
| `kikai destroy` | stop + remove disks (optionally secrets) → `Destroyed` |
| `kikai daemon` | continuous monitor + auto-restart (`Healthy ⇄ Degraded`) |
| `kikai pause` / `resume` | VZ freeze ↔ thaw |
| `kikai snapshot` | save VM state (from `Paused`) |
| `kikai dump-config` | print effective `ClusterConfig` as JSON |

Lifecycle FSM (the never-stuck spine): `Uninitialized → Initialized → DisksReady
→ WaitingForApi → WaitingForNode → WaitingForFlux → Healthy ⇄ Degraded`, plus
`Paused / ShuttingDown / Stopped / SavingSnapshot / RestoringSnapshot /
Destroyed` and the terminal `BlockedDeclarative` (broken declaration — needs
operator action, not retry).
