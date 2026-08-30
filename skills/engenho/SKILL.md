---
name: engenho
description: Operate and navigate engenho — pleme-io's typed, attested, Rust-native distributed Kubernetes runtime (Pillar 7). Use when reading live engenho/kikai cluster state via the engenho MCP, running the kikai cluster lifecycle (init/up/down/snapshot/destroy), locating a subsystem/state-machine/type across the 20-crate workspace, or reasoning about the distributed (revoada/teia/store), API-compatible (faces), and derivation-substrate layers. Pairs with the engenho-mcp tool catalog.
allowed-tools: Bash, Read, Glob, Grep, mcp__engenho__cluster_status, mcp__engenho__cluster_config, mcp__engenho__cluster_kubeconfig, mcp__engenho__cluster_snapshot_meta, mcp__engenho__cluster_pods, mcp__engenho__cluster_resource_list, mcp__engenho__cluster_resource_get
metadata:
  version: "0.1.0"
  last_verified: "2026-08-30"
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
    - "csi"
    - "cni"
    - "etcd"
    - "simulation"
    - "differential"
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

> **★ STATUS, RE-MEASURED 2026-08-30 — the previous note here was FALSE and had
> been for months.** It read: *"the `engenho` binary is an M0.0 placeholder; the
> real cluster today is k3s, managed by kikai."* Both halves are wrong now.
>
> engenho runs the local cluster **natively, on macOS baremetal** — no VM, no
> k3s, no kikai in the path. Measured today: a launchd daemon
> (`io.pleme.engenho.daemon`) serving `:6443` (`readyz` 200, reports `v1.34.0`,
> `compiler: rustc`) and `:10250`, enforcing RBAC, across **18 API groups plus
> core v1**. 27 crates, ~185k lines, **3,512 tests**.
>
> **kikai is a k3s VM orchestrator and is NOT engenho.** Pointing kikai's lens
> at engenho reports a healthy cluster as down. Use `banken` or `kubectl` with
> the right context — and note the context is named from inside the kubeconfig
> (`engenho-cid-<hash>`), not from a path.
>
> **The live binary routinely lags HEAD.** It is a nix store path installed by
> a rebuild, so a running daemon can be several releases behind the repo — check
> before drawing conclusions from live behaviour. This is the recurring trap.
>
> **Read [`docs/WHY-ENGENHO.md`](https://github.com/pleme-io/engenho/blob/main/docs/WHY-ENGENHO.md) before any
> strategic conversation about engenho.** It carries the researched case for
> what engenho is FOR — orchestrators are not architecturally special, the moat
> is accumulated convention, and the payoff is testing / simulation / embedding
> — with each claim measured or sourced.

## Repos

| Repo | Role |
|---|---|
| `~/code/github/pleme-io/engenho` | the 20-crate runtime workspace |
| `~/code/github/pleme-io/kikai` | cluster lifecycle backend (k3s VMs via QEMU/kasou) |
| `~/code/github/pleme-io/engenho-promessa-controllers` | Viggy TargetControllers (SLA/CostBudget/Compliance/CustomerKpi/Security) + the image-validation platform |
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

## ★ The contract ring — and the ONE rule for touching it

engenho's value is not its API; it is the ring of contracts AROUND the API
that lets existing software drive it. Each is independently composable — a
deployment can serve `:2379` and not `:10250`.

| contract | port / seam | state (2026-08-30) |
|---|---|---|
| **etcd v3** | `:2379`, `runtime.etcd_listen_addr` | read-only (`Range`/`Watch`/`Maintenance`); real `etcdctl` works |
| **kubelet API** | `:10250`, `runtime.kubelet_listen_addr` | logs / pods / exec over `v5.channel.k8s.io` |
| **CSI** | `<data_dir>/plugins_registry` | registration, node publish, dynamic provisioning — all wired |
| **CNI** | `/etc/cni/net.d` | config + planning + exec + node status. **Pod-attach NOT wired** (`pending-cni: pod-attach`, needs Linux) |

engenho also SHIPS its own implementations of both plugin contracts —
`engenho-ipam` (a real CNI IPAM plugin) and `engenho-csi-localpath` (a real
CSI driver). Naturalized, not vendored.

> ### ★★ THE RULE: a contract is not implemented until a foreign oracle says so.
>
> Our own reference driver and reference plugin are real processes on real
> sockets and they still **cannot falsify us** — same author, same reading of
> the same spec, so they prove our encoder agrees with our decoder. The
> differentials are what prove the contract. Measured on first contact:
>
> | oracle | verdict |
> |---|---|
> | real `etcdctl` | **found a bug** — `db_size: 0` → integer divide by zero in `endpoint status` |
> | `csi-driver-host-path` v1.15.0 | 3/3 clean |
> | `containernetworking/plugins` 1.8.0 | **found a bug** — missing `IgnoreUnknown=true` meant engenho could drive NO upstream plugin |
>
> Two of three. You cannot know which until you run it. Say "the contract is
> implemented", never "proven", until one has.
>
> ```bash
> # CSI (works on darwin)
> ENGENHO_CSI_ORACLE=/tmp/csi-state/csi.sock \
>   cargo test -p engenho-csi --test m2_3_foreign_driver_differential -- --ignored
> # CNI (needs Linux; cni-plugins does not build on darwin at all)
> ssh rio '… ENGENHO_CNI_PLUGIN_DIR=<store>/bin cargo test -p engenho-cni \
>   --test m3_1_foreign_plugin_differential -- --ignored'
> ```

## ★ "type + backend + no producer" — the recurring defect class

**Nine instances found in this codebase.** A trait, its backends and its tests
all exist; nothing constructs it. Every symbol resolves, every test passes, and
the capability is absent. `grep` cannot find it.

Detection: `grep -rn '<Trait>' --include=*.rs . | grep -v '<defining file>' |
grep -v '/tests/'` → zero non-test hits.

The worst instances were not missing features. `NetworkPolicyEnforcer` (#8)
meant a default-deny policy applied cleanly and restricted nothing.
`engenho-etcd` (#9) was a complete façade with 48 passing tests that nothing
could dial — and its whole purpose was to be an oracle.

**Rule: any new vocabulary ships its producer in the SAME commit.**

And a near-miss trait naming your use case in its own header is not evidence it
fits. `VolumeRuntime`'s header named `CsiVolumeBackend (R13b — gRPC to CSI
plugins)` as future work; measured, its INPUTS are provisioning-shaped and its
OUTPUT is mounting-shaped, while CSI splits those across two services on two
machines. Compare input shape AND output shape — one matching half is a trap.
It is now marked superseded, declaration retained (★★ MODULARIZE, DON'T DELETE).

## ★ Platform gaps are TYPED, never faked

darwin cannot host a network namespace or a Linux mount. Those are facts about
the world, so they get types rather than stubs — and nothing else in the
cluster distinguishes a computed result from a real one, because the pod gets
an address either way and `kubectl` shows it either way.

| type | meaning |
|---|---|
| `DatapathInstall::{Computed,Installed}` | kube-proxy rules computed vs. installed in a kernel |
| `PolicyDatapath::{Computed,Installed}` | NetworkPolicy tracked vs. actually filtering |
| `CniInstall::{Planned,Invoked}` | chain planned vs. plugins executed (published as `engenho.io/cni-install`) |

When adding a capability that cannot work on the host, copy this shape. A stub
that returns success is the failure mode these exist to prevent.

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

Fast code search: `mcp__codesearch__search_exact` / `semantic_search` (zoekt is
RETIRED since 2026-08-12), or `cargo test -p <crate>` to verify a change.

Newer crates not in the table above: `engenho-etcd` (etcd v3 façade + the
`/registry` keyspace), `engenho-csi` (CSI client, registration, the
`localpath` driver), `engenho-cni` (net.d config, chain exec, IPAM +
the `engenho-ipam` plugin).

## The non-negotiable rules (don't violate)

1. **No hand-authored K8s resource types** — every kind is generated from OpenAPI
   v3 by `kube-forge`; extend the generator, never sprintf YAML.
2. **Secrets through cofre** — k8s Secret objects carry references, not plaintext.
3. **One truth, many faces** — never let a face own state; translate to
   `ResourceCommand`/`StoreMesh`.
4. **Attest every transition** — role shifts + materializations write
   BLAKE3+ed25519 chain blocks; trust = K-of-N independent rebuilds (`QuorumOutcome`).
5. **Ship the producer with the vocabulary** — see the defect class above. A
   trait with backends and no caller is the most common way a capability is
   absent while every test is green.
6. **A detached task must NOT hold `Arc<StoreMesh>`** — it keeps the Raft log
   and fjall handles alive for the process lifetime, so shutdown can never
   reclaim the store. Hit twice (the :10250 and :2379 listeners); both now hold
   a `Weak` and there is a regression test.
7. **Tatara/shigoto/shikumi, not bespoke** — daemon supervision, work graphs, and
   config go through the substrate primitives; shell beyond 3-line glue → tatara-script.

## Common tasks

- **"What's the state of cluster X?"** → `mcp__engenho__cluster_status` then
  `cluster_pods` / `cluster_resource_list`.
- **"Bring up / tear down the local cluster"** → kikai `up` / `destroy` (suggest the
  user run via `! kikai …` for interactive auth).
- **"Where is the <X> state machine?"** → `engenho/docs/STATE-MACHINES.md` index →
  the named source file; formalized FSMs in `engenho-machines`.
- **"Why engenho / is this worth it / what is it for?"** → read
  [`docs/WHY-ENGENHO.md`](https://github.com/pleme-io/engenho/blob/main/docs/WHY-ENGENHO.md). Short version:
  Kubernetes and Nomad are the same shape in different packaging (server/client
  + Raft + reconciliation), engenho is Nomad's packaging speaking Kubernetes'
  contract, and the payoff is **testing / simulation / embedding** — because
  Raft determinism and deterministic-simulation determinism are the SAME
  requirement, and engenho already paid for it (`mint_uid` is BLAKE3-derived,
  `relogio` is a typed clock seam, every side effect is behind an Environment
  trait). The named next step is auditing away stray `SystemTime::now()` calls.
- **"Add a new typed primitive to the typescape"** → impl `Typescape` (round-trip
  law) per `engenho/docs/TYPESCAPE.md`; substrate types use the local-newtype
  pattern (`engenho-machines/src/shape_ts.rs`) to dodge the orphan rule.

This skill is deployed via blackmatter home-manager; changes land on `nix run
.#rebuild` from the nix repo.
