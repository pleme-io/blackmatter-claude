---
name: engenho
description: "Operate engenho, the Rust Kubernetes runtime (ctl, MCP)"
allowed-tools: Bash, Read, Glob, Grep, mcp__engenho__cluster_status, mcp__engenho__cluster_config, mcp__engenho__cluster_kubeconfig, mcp__engenho__cluster_snapshot_meta, mcp__engenho__cluster_pods, mcp__engenho__cluster_resource_list, mcp__engenho__cluster_resource_get, mcp__engenho__control_hello_show, mcp__engenho__control_runtime_show, mcp__engenho__control_boot_show, mcp__engenho__control_boot_attempts, mcp__engenho__control_init_show, mcp__engenho__control_config_show, mcp__engenho__control_config_leaves, mcp__engenho__control_config_get, mcp__engenho__control_config_overrides, mcp__engenho__control_config_drift, mcp__engenho__control_children_list, mcp__engenho__control_children_get, mcp__engenho__control_pki_show, mcp__engenho__control_store_show, mcp__engenho__control_kubeconfigs_list, mcp__engenho__control_events_list, mcp__engenho__control_logs_list, mcp__engenho__control_audit_list, mcp__engenho__control_control_show
metadata:
  version: "0.2.1"
  last_verified: "2026-09-22"
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

> **★ STATUS, RE-MEASURED 2026-08-30:** engenho runs the local cluster natively on macOS, with no VM, k3s or kikai in the path. The measurement, and the false note it replaced: `references/status-2026-08-30.md`.
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

## Authoritative docs (read these first)

`pleme-io/engenho` is the runtime workspace; the private repos around it, and the full doc list with what each covers: `references/repos-and-docs.md`. Start with `engenho/docs/FLEET-DESIGN.md` (before any distributed, placement or GitOps work), `CONTROL-PLANE.md` (a running daemon) and `STATE-MACHINES.md` (a state machine).

## Managing the running daemon (control plane — NOT the Kubernetes API)

A running engenho has its own control plane, separate from `:6443`: a local Unix
socket (always on — the recovery path, serving even when a boot has failed) and
an optional SPKI-pinned mTLS listener for other machines. It manages the daemon
itself — nothing about it is a Kubernetes object. Spec:
`engenho/spec/engenho-control.openapi.yaml`; every operation is one
`engenho ctl <resource> <verb>`:

Every resource and verb (`runtime`, `boot`, `init`/`pki`/`store`, `config` and its leaf classes, `children`, `events`/`logs`/`audit`, the destructive `reinit`, `--remote`): `references/control-plane.md`.

Authority is the kernel's (socket peer uid; group members get `groupTier`) or
the pin's tier, capped by `--ceiling`. Exit codes: 0 answered, 2 usage, 3
refused (the reason and what would be accepted are printed), 4 blind — conclude
nothing — 5 confirmation aborted. Store-touching re-inits need the runtime
stopped (`runtime stop`) in the epoch the confirmation was prepared in.

**Agents:** the engenho MCP generates one `control_<resource>_<verb>` tool per
operation from the same catalog. Observe tier only unless the server was
launched with `--allow-mutate`; destructive operations are never tools. The
daemon caps every call at that tier and audits it as `agent`.

## Reading live cluster state, and the kikai lifecycle

The `cluster_*` MCP tools are a read-only typed reader over kikai's on-disk state and the live Kubernetes API; secrets are redacted at the MCP boundary. The tool table: `references/cluster-reader.md`. kikai's subcommands and its 14-state FSM: `references/kikai.md`.

## ★ The contract ring — and the ONE rule for touching it

engenho's value is not its API; it is the ring of contracts AROUND the API
that lets existing software drive it. Each is independently composable — a
deployment can serve `:2379` and not `:10250`.

> ### ★★ THE RULE: a contract is not implemented until a foreign oracle says so.
>
> Our own reference driver and plugin cannot falsify us. Say "the contract is implemented", never "proven", until a foreign oracle has run. The per-contract state, the oracle verdicts (two of three found a bug) and the differential commands: `references/contract-ring.md`.

## ★ "type + backend + no producer" — the recurring defect class

**Nine instances found in this codebase.** A trait, its backends and its tests
all exist; nothing constructs it. Every symbol resolves, every test passes, and
the capability is absent. `grep` cannot find it.

Detection: `grep -rn '<Trait>' --include=*.rs . | grep -v '<defining file>' |
grep -v '/tests/'` → zero non-test hits.

**Rule: any new vocabulary ships its producer in the SAME commit.**

A near-miss trait naming your use case in its own header is not evidence it fits: compare input shape AND output shape. The receipts (`NetworkPolicyEnforcer`, `engenho-etcd`, `VolumeRuntime`): `references/no-producer-defect.md`.

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

Where Linux hosts are going (the host only boots and runs engenho; the node itself as a release): `references/service-layer.md`.

A local engenho cluster qualifies manifests bound for upstream Kubernetes. A gap it shows is engenho's backlog, never worked around in the consumer, and a pass is a floor, not proof of upstream behaviour: `references/qualification.md`.

## Navigating the codebase

Which crate owns which concern (types, apiserver, revoada, teia, store, substrate, controllers, fonte, runtime, control plane, MCP, etcd/CSI/CNI): `references/crate-map.md`. Fast code search: `mcp__codesearch__search_exact` / `semantic_search`, or `cargo test -p <crate>` to verify a change.

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

- **"Is this machine's engenho healthy / why won't it boot?"** → `engenho ctl
  runtime show`, then `boot show` (the failed phase and its error), `config
  drift`, `logs list --level warn`. A held failure is fixed by `config set …`
  (an override) or a declared-file change, then `runtime retry` — no restart of
  the process.
- **"What's the state of cluster X?"** → `mcp__engenho__cluster_status` then
  `cluster_pods` / `cluster_resource_list`.
- **"Bring up / tear down the local cluster"** → kikai `up` / `destroy` (suggest the
  user run via `! kikai …` for interactive auth).
- **"Where is the <X> state machine?"** → `engenho/docs/STATE-MACHINES.md` index →
  the named source file (the doc names code, never a model; `ci/doc-sources.tlisp`
  fails CI on a pointer that stops resolving).
- **"Why engenho / is this worth it / what is it for?"** → read
  [`docs/WHY-ENGENHO.md`](https://github.com/pleme-io/engenho/blob/main/docs/WHY-ENGENHO.md). The short version: `references/why-engenho.md`.
- **"Add a new typed primitive to the typescape"** → impl `Typescape` (round-trip
  law) per `engenho/docs/TYPESCAPE.md`, through the sui bridge
  (`engenho-sui-typescape`); a foreign type takes a local newtype to dodge the
  orphan rule.

This skill is deployed via blackmatter home-manager; changes land on `nix run
.#rebuild` from the nix repo.

## References

- `references/status-2026-08-30.md`: the measured daemon, ports, API groups and counts
- `references/repos-and-docs.md`: the repos, and which `engenho/docs/` file covers what
- `references/control-plane.md`: the full `engenho ctl <resource> <verb>` table
- `references/cluster-reader.md`: the `cluster_*` MCP tools
- `references/kikai.md`: kikai subcommands and its lifecycle FSM
- `references/contract-ring.md`: contract states, oracle verdicts, differential commands
- `references/no-producer-defect.md`: the defect-class receipts
- `references/service-layer.md`: engenho as a Linux node's whole service layer, and the node as a release
- `references/qualification.md`: qualifying manifests on engenho, and what to do when it lacks a capability
- `references/crate-map.md`: where each concern lives in the workspace
- `references/why-engenho.md`: the short case for engenho (testing / simulation / embedding)
