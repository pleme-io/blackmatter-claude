---
name: engenho
description: Operate and navigate engenho — pleme-io's typed, attested, Rust-native distributed Kubernetes runtime (Pillar 7). Use when reading live engenho/kikai cluster state via the engenho MCP, running the kikai cluster lifecycle (init/up/down/snapshot/destroy), locating a subsystem/state-machine/type across the 20-crate workspace, or reasoning about the distributed (revoada/teia/store), API-compatible (faces), and derivation-substrate layers. Pairs with the engenho-mcp tool catalog.
allowed-tools: Bash, Read, Glob, Grep, mcp__engenho__cluster_status, mcp__engenho__cluster_config, mcp__engenho__cluster_kubeconfig, mcp__engenho__cluster_snapshot_meta, mcp__engenho__cluster_pods, mcp__engenho__cluster_resource_list, mcp__engenho__cluster_resource_get
metadata:
  version: "0.1.0"
  last_verified: "2026-05-26"
  domain_keywords:
    - "engenho"
    - "kikai"
    - "kubernetes"
    - "runtime"
    - "revoada"
    - "teia"
    - "substrate"
    - "derivation"
    - "fonte"
    - "typescape"
    - "k3s"
    - "cluster"
---

# engenho — distributed Kubernetes runtime operator playbook

engenho is pleme-io's Pillar 7 **runtime** — *Pangea declares; magma realizes on
cloud; engenho runs the land (terreno)*. A typed, attested, Rust-native
Kubernetes (and Nomad, and PureRaft) distribution. One design, three axes:

- **Fully distributed** — `engenho-revoada` (gossip + raft + content + attest) over
  `engenho-teia` (NATS fabric) with `engenho-store` (dual raft groups).
- **API-compatible (many faces)** — a `Face` trait renders one `StoreMesh` truth
  into K8s / Nomad / PureRaft / REST / gRPC / GraphQL / MCP.
- **Shift bits to forms (nix/derivation)** — `engenho-substrate` content-addresses a
  `Drv`, renders it into a `WorkloadShape` (OCI image / Nix closure / qcow2 /
  wasm / static binary / helm chart), and distributes it after a K-of-N
  independent-rebuild quorum.

> **Status reality (important):** the `engenho` *binary* is an M0.0 placeholder.
> The **real cluster today is k3s, managed by `kikai`** (the wire-compat bridge),
> until engenho-native lands at M0.4. The engenho MCP reads kikai's on-disk state.

## Repos

| Repo | Role |
|---|---|
| `~/code/github/pleme-io/engenho` | the 20-crate runtime workspace |
| `~/code/github/pleme-io/kikai` | cluster lifecycle backend (k3s VMs via QEMU/kasou) |
| `~/code/github/pleme-io/engenho-promessa-controllers` | Viggy TargetControllers (SLA/CostBudget/Compliance/CustomerKpi/Security) + Akeyless image-validation platform |
| `~/code/github/pleme-io/theory/ENGENHO.md` | canonical destination doc (CSE) |

## Authoritative docs (read these first)

- `engenho/docs/STRATEGY.md` — invariants + action taxonomy + phase spine
- `engenho/docs/STATE-MACHINES.md` — the 12-machine catalog (states/events/transitions/source)
- `engenho/docs/TYPESCAPE.md` — the typed universe by domain + the sui bridge
- `engenho/docs/{DISTRIBUTED,FABRIC,CONSISTENCY-FABRIC,MANY-FACES,RESILIENCE,LEAN}.md`
- `theory/ENGENHO.md` — destination, wire-compat contract, phases (§I–§XII)

## Reading live cluster state (engenho MCP)

The MCP is a **read-only** typed reader over kikai's on-disk state (writer is P2,
gated on saguão authority). All tools take `{ "cluster": "<name>" }` from kikai's
`clusters.yaml`. Discover clusters first:

```bash
ls ~/.local/share/kikai        # registered clusters with on-disk state
cat ~/.config/kikai/clusters.yaml 2>/dev/null   # cluster config (cpus/mem/ports)
```

| Tool | Use |
|---|---|
| `mcp__engenho__cluster_status` | Agent/VM/API/Snapshot rows (sub-50ms, no kubectl) |
| `mcp__engenho__cluster_config` | typed config view (CPUs, memory, gitops, network) |
| `mcp__engenho__cluster_kubeconfig` | kubeconfig descriptor |
| `mcp__engenho__cluster_snapshot_meta` | auto-snapshot meta + store-path liveness |
| `mcp__engenho__cluster_pods` | typed Pod list (through the engenho-types catalog) |
| `mcp__engenho__cluster_resource_list` | generic typed list: `{cluster, kind, namespace, label_selector, field_selector}` — kind ∈ pod/service/config_map/secret(redacted)/service_account/endpoints/persistent_volume_claim/namespace/node/deployment/replica_set/role/role_binding |
| `mcp__engenho__cluster_resource_get` | generic typed get |

Secrets are **redacted at the MCP boundary** by type — never expect plaintext.

## kikai cluster lifecycle

`kikai` drives the 14-state cluster FSM (`kikai/src/state.rs`, exhaustively
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

## Navigating the codebase (where things live)

| Concern | Crate(s) |
|---|---|
| typed K8s catalog, GVK, faces translator, nomad_v1 | `engenho-types` |
| K8s REST apiserver, watch, openapi | `engenho-apiserver`, `engenho-kube-client`, `engenho-kube-codegen` |
| membership/raft/content/attest, topology strategies, `Face` | `engenho-revoada` |
| NATS fabric (5 channels), subjects | `engenho-teia` |
| dual raft store, ResourceCommand, watch | `engenho-store` |
| **derivation engine** (Drv, WorkloadShape, oci_renderer, ledger, quorum, maquina, mirante, selo, …) | `engenho-substrate` |
| reconcile controllers / scheduler / kubelet | `engenho-controllers`, `engenho-scheduler`, `engenho-kubelet` |
| source-of-truth reconciler `(defsistema)` + Viggy 7-beat | `engenho-fonte` |
| sui↔engenho bridge (`TypescapeValue`, `Typescape`) | `engenho-sui-typescape` |
| shikumi config surface | `engenho-config`; bootstrap render: `engenho-cluster-config(-render)` |
| **formalized state machines + typescape regs** | `engenho-machines` (`MaterializationMachine`, `TopologyNodeMachine`) |
| MCP reader/writer | `engenho-mcp` |

Fast code search: `mcp__zoekt__search` (repo is indexed as
`github.com/pleme-io/engenho`), or `cargo test -p <crate>` to verify a change.

## The non-negotiable rules (don't violate)

1. **No hand-authored K8s resource types** — every kind is generated from OpenAPI
   v3 by `kube-forge`; extend the generator, never sprintf YAML.
2. **Secrets through cofre** — k8s Secret objects carry references, not plaintext.
3. **One truth, many faces** — never let a face own state; translate to
   `ResourceCommand`/`StoreMesh`.
4. **Attest every transition** — role shifts + materializations write
   BLAKE3+ed25519 chain blocks; trust = K-of-N independent rebuilds (`QuorumOutcome`).
5. **Tatara/shigoto/shikumi, not bespoke** — daemon supervision, work graphs, and
   config go through the substrate primitives; shell beyond 3-line glue → tatara-script.

## Common tasks

- **"What's the state of cluster X?"** → `mcp__engenho__cluster_status` then
  `cluster_pods` / `cluster_resource_list`.
- **"Bring up / tear down the local cluster"** → kikai `up` / `destroy` (suggest the
  user run via `! kikai …` for interactive auth).
- **"Where is the <X> state machine?"** → `engenho/docs/STATE-MACHINES.md` index →
  the named source file; formalized FSMs in `engenho-machines`.
- **"Add a new typed primitive to the typescape"** → impl `Typescape` (round-trip
  law) per `engenho/docs/TYPESCAPE.md`; substrate types use the local-newtype
  pattern (`engenho-machines/src/shape_ts.rs`) to dodge the orphan rule.

This skill is deployed via blackmatter home-manager; changes land on `nix run
.#rebuild` from the nix repo.
