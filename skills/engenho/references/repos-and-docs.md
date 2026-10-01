# engenho repos and authoritative docs

## Repos

| Repo | Role |
|---|---|
| `pleme-io/engenho` | the 20-crate runtime workspace |
| cluster lifecycle backend (private) | k3s VMs via QEMU/kasou |
| Viggy target controllers (private) | SLA/CostBudget/Compliance/CustomerKpi/Security + the image-validation platform |
| the engenho doc in the operator's private theory repo | canonical destination doc (CSE) |

## Authoritative docs (read these first)

- `engenho/docs/FLEET-DESIGN.md` — the whole design: engenho on every node, every state class recoverable, one multi-raft engine, fenced role leases and a moving control plane, capability-inferred placement, movement, allocation, per-release API faces, the node as a release, and the build order (rungs R0–R8). Read it before any distributed, placement or GitOps work
- `engenho/docs/RECOVERABLE-STATE.md` — the consensus seals (durable votes, quorum-gated promotion, fencing) and their tiers
- `engenho/docs/STRATEGY.md` — invariants + action taxonomy + phase spine
- `engenho/docs/CONTROL-PLANE.md` — managing a running daemon: lifecycle, socket + remote trust, overrides, children, re-initialization, MCP
- `engenho/docs/STATE-MACHINES.md` — the 13-machine catalog (states/events/transitions/source); ⑬ is the daemon lifecycle
- `engenho/docs/TYPESCAPE.md` — the typed universe by domain + the sui bridge
- `engenho/docs/{DISTRIBUTED,FABRIC,CONSISTENCY-FABRIC,MANY-FACES,RESILIENCE,LEAN}.md`
- the engenho theory doc (private theory repo) — destination, wire-compat contract, phases (§I–§XII)
