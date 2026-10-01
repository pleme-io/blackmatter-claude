# engenho control plane: every operation

The full table behind `## Managing the running daemon` in `SKILL.md`.

## Managing the running daemon (control plane — NOT the Kubernetes API)

A running engenho has its own control plane, separate from `:6443`: a local Unix
socket (always on — the recovery path, serving even when a boot has failed) and
an optional SPKI-pinned mTLS listener for other machines. It manages the daemon
itself — nothing about it is a Kubernetes object. Spec:
`engenho/spec/engenho-control.openapi.yaml`; every operation is one
`engenho ctl <resource> <verb>`:

| Want | Command |
|---|---|
| Is it up, and where in its lifecycle? | `engenho ctl runtime show` (`running` / `failed{phase, retry}` / `stopped` / `wedged`) |
| Why did a boot fail? | `engenho ctl boot show` · `boot attempts` (per-phase journal) |
| PKI, store, identity, data-dir layout | `engenho ctl init show` · `pki show` · `store show` |
| Change config while it runs | `engenho ctl config set <leaf> --value <v>` (persisted override; `--persist false` for memory only) · `config unset` · `config clear` · `config drift` (what overrides shadow in the declared file) |
| Leaf classes | `engenho ctl config leaves` — `live` (applied now), `respawn` (children moved now), `restart_runtime` (deferred unless `--restart-policy now`), `next_boot`, `not_overridable` |
| Children (drivers, listeners, lease) | `engenho ctl children list` · `children restart <child>` · `children enable\|disable <driver>` |
| Stop / start / restart / retry / exit | `engenho ctl runtime stop\|start\|restart\|retry\|exit` (the process stays up when the runtime stops) |
| What happened | `engenho ctl events list` · `logs list` · `audit list` (BLAKE3-chained) |
| Destructive re-init | `engenho ctl reinit rotate-admin-token\|reseed-pki\|wipe-store`, `control rotate-identity` — a confirmation handshake (type the cluster's name; `--confirm-phrase` off a terminal); replaced files go to `data_dir/control/attic/`, never deleted |
| Another machine | `engenho ctl --remote <name> …` (`~/.config/engenho/remotes.yaml`; `engenho remote keygen <name>` makes this machine's key, whose pin the server must list) |

Authority is the kernel's (socket peer uid; group members get `groupTier`) or
the pin's tier, capped by `--ceiling`. Exit codes: 0 answered, 2 usage, 3
refused (the reason and what would be accepted are printed), 4 blind — conclude
nothing — 5 confirmation aborted. Store-touching re-inits need the runtime
stopped (`runtime stop`) in the epoch the confirmation was prepared in.

**Agents:** the engenho MCP generates one `control_<resource>_<verb>` tool per
operation from the same catalog. Observe tier only unless the server was
launched with `--allow-mutate`; destructive operations are never tools. The
daemon caps every call at that tier and audits it as `agent`.
