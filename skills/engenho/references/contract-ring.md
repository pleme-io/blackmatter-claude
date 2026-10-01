# engenho contract ring: state, oracles, differentials

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
