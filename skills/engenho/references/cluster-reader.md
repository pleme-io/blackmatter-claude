# engenho MCP cluster reader

## Reading live cluster state (engenho MCP)

The `cluster_*` tools are a **read-only** typed reader over kikai's on-disk state
and the live Kubernetes API (Kubernetes writes are P2, gated on saguão
authority). They take `{ "cluster": "<name>" }` from kikai's `clusters.yaml`.
Discover clusters first:

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
