# engenho crate map

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
| the daemon's supervisor + lifecycle machine, boot journal, control service | `engenho-runtime` (`lifecycle/`, `boot/`, `control/`) |
| control API types (spec-generated `OperationId`/`CATALOG`), SPKI pins | `engenho-control-types` |
| control socket, remote listener, grants, audit chain | `engenho-control-server` |
| control client (socket resolution, `render`, remotes) | `engenho-control-client` |
| MCP reader + control tools (writer trait: P2) | `engenho-mcp` |

Fast code search: `mcp__codesearch__search_exact` / `semantic_search`, or
`cargo test -p <crate>` to verify a change.

Newer crates not in the table above: `engenho-etcd` (etcd v3 façade + the
`/registry` keyspace), `engenho-csi` (CSI client, registration, the
`localpath` driver), `engenho-cni` (net.d config, chain exec, IPAM +
the `engenho-ipam` plugin).
