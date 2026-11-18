# engenho — common tasks

## Common tasks

- **"Is this machine's engenho healthy / why won't it boot?"** → `engenho
  status` (whole-daemon report; `--remote <name>`, `--json`; exit 0 healthy,
  1 degraded, 4 unreachable). To dig in: `engenho ctl runtime show`, then `boot show` (the failed phase and its error), `config
  drift`, `logs list --level warn`. A held failure is fixed by `config set …`
  (an override) or a declared-file change, then `runtime retry` — no restart of
  the process.
- **"What's the state of cluster X?"** → `mcp__engenho__cluster_status` then
  `cluster_pods` / `cluster_resource_list`.
- **"Run OCI pods on a darwin host whose engenho is `native`"** → a second
  daemon with `kubelet_backend: podman` on a started podman machine, with its
  own `cluster.name`, `node_manifests_dir`, `data_dir`, ports and control
  socket. On defaults it loads `/etc/engenho/manifests.d` and runs the host's
  workloads (near miss 2026-11-06); check `config-show | rg /etc` first.
- **"A pod stays ClosureUntrusted"** → read the live
  `runtime.closure_signatures`; a refusal made under an earlier mode is not
  retried, so delete the pod (pangea-postgres, 42 d, 2026-11-06).
- **"Bring up / tear down the local cluster"** → kikai `up` / `destroy` (suggest the
  user run via `! kikai …` for interactive auth).
- **"Where is the <X> state machine?"** → `engenho/docs/STATE-MACHINES.md` index →
  the named source file (the doc names code, never a model; `ci/doc-sources.tlisp`
  fails CI on a pointer that stops resolving).
- **"Why engenho / is this worth it / what is it for?"** → read
  [`docs/WHY-ENGENHO.md`](https://github.com/pleme-io/engenho/blob/main/docs/WHY-ENGENHO.md). The short version: `why-engenho.md`.
- **"Add a new typed primitive to the typescape"** → impl `Typescape` (round-trip
  law) per `engenho/docs/TYPESCAPE.md`, through the sui bridge
  (`engenho-sui-typescape`); a foreign type takes a local newtype to dodge the
  orphan rule.

This skill is deployed via blackmatter home-manager; changes land on `nix run
.#rebuild` from the nix repo.
