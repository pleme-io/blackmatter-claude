# "type + backend + no producer": receipts

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
