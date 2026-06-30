# Claude, fitted to mado

> The inverse of [`mado/docs/MADO-FOR-CLAUDE-CODE.md`](https://github.com/pleme-io/mado/blob/main/docs/MADO-FOR-CLAUDE-CODE.md).
> That doc makes **mado fit Claude Code**; this one makes **Claude Code fit
> mado** — declaratively, through the blackmatter Nix stack — so Claude becomes
> a first-class operator of mado and *all its session stuff*. Destination-first
> (Operating Principle #0): the whole shape is named here; the phases are the
> path to it.

## 1. The destination

**On every fleet node where the operator runs both, Claude Code can fully
control mado — and mado reacts to Claude's lifecycle — with zero hand-wired
config, because the blackmatter modules declare the whole integration.**

The control surface already exists: mado ships a **48-tool stdio MCP server**
(`mado mcp`) covering session/pane/output/attention/clipboard/marks/vigy/tear/
config. What's missing is the *declarative, fleet-wide, reproducible wiring* —
and the operator-facing knowledge for Claude to drive it well. That's what this
delivers.

Two directions, one integration:

| Direction | Mechanism | Status |
|---|---|---|
| **Claude → mado** (Claude controls mado) | mado's MCP server, registered in `~/.claude.json` by blackmatter-claude | the MCP exists; **wiring is this work** |
| **mado ← Claude** (mado reacts to Claude) | Claude Code hooks driving mado (Stop→attention, SessionStart→bind) + the safra Claude-session lane | needs a small `mado control` CLI (mado-side follow-on) |

## 2. What ships in this work (the declarative wiring)

### 2.1 mado as a first-class MCP server — `blackmatter-mado`

`blackmatter.components.mado.mcp.serverEntry` — a **read-only, hermetic** stdio
entry computed from the installed package:
`{ command = "${pkgs.mado}/bin/mado"; args = ["mcp"]; }`. Exposed the same way
`services.zoekt.mcp.serverEntry` is, so a consumer references it without knowing
the store path. `{}` when `mcp.enable = false`.

### 2.2 the registration — `blackmatter-claude`

`blackmatter.components.claude.mcp.madoMcp.enable` (mirrors `zoektMcp`/`kurageMcp`)
folds `config.blackmatter.components.mado.mcp.serverEntry` into the
`serviceMcpServers` set that deep-merges into `~/.claude.json`. Flip one bool →
mado's full tool surface is available to Claude Code on that node, reproducibly.

`madoMcp.autoAllow` (default **false**, safe) optionally lifts mado's
**read-only** tools (`status`, `list_sessions`, `get_output`, `snapshot_grid`,
`recent_dirs_list`, `frame_perf`, `version`) onto the permission allow-list so
Claude can *observe* mado without a prompt; the **mutating** tools
(`spawn_term`, `send_keys`, `switch_session`, `tear_new_session`, `config_set`,
`attention_set`, `simulate_chord`) stay on the ask path unless the operator opts
into hands-off control. (Today every mado tool is on the ask path — this makes
the read/observe half frictionless without surrendering the mutating half.)

### 2.3 the operator knowledge — the `drive-mado` skill

A skill teaching Claude *how* to use the tool surface to be a real mado
operator: enumerate + switch + spawn + name sessions, drive panes (tear), read
output for verification, set attention when a long job finishes, register a
`vigy` reconciler, and read the **safra** work-board. Without the skill the
tools are present but unidiomatic; with it, "Claude, open a session on that
failing deploy and watch it" is one fluent move.

## 3. The full Claude → mado capability (already in the MCP)

Once §2 lands, Claude can, on any node:

- **Sessions:** `list_sessions` / `switch_session` / `spawn_term` /
  `close_session` / `resize_session` — enumerate, jump, spawn pre-named
  sessions, tidy up.
- **tear panes:** `tear_new_session` (tagged `SessionSource::Agent`) /
  `tear_send_keys` / `tear_pane_snapshot` / `tear_pane_blocks_list` /
  `tear_pane_record_*` — full multiplexer + command-block + recording control.
- **I/O:** `send_keys` / `get_output` / `snapshot_grid` — type into a session,
  read its screen, introspect cell-level state (the verification loop).
- **Attention:** `attention_set` / `attention_get` — bounce the dock / signal
  "needs you" from Claude's own flow.
- **Navigation:** `recent_dirs_list` / `jump_to_recent_dir` — frecency cd.
- **Clipboard + marks:** `clipboard_{get,put,list,clear}` /
  `prompt_marks_list` / `user_marks_list` — content-addressed clipboard, OSC-133
  jump points.
- **Config:** `config_get` / `config_set` — read/hot-set the live `MadoConfig`.
- **vigy:** `vigy_register` / `vigy_list` / `vigy_inspect` / `vigy_tick` /
  `vigy_delete` — register + drive in-process tatara-lisp reconcilers.
- **Chords + switching:** `simulate_chord` — fire any keybind action into the
  GUI event loop.

That is "fully control mado and all its session stuff." The work in §2 makes it
*declared* rather than ad-hoc, on every node, by construction.

## 4. The reverse direction (mado ← Claude) — the named follow-on

mado's control is MCP-only today (no external CLI), so a Claude Code *hook*
(a shell command on a lifecycle event) can't yet drive mado. The clean fix is a
thin **`mado control`** CLI subcommand talking to the live GUI over the existing
`kanshou` IPC socket — e.g. `mado control attention --request` (a `Stop` hook
bounces the dock when Claude finishes), `mado control session-name <id> <name>`
(a `SessionStart` hook binds the pane to the Claude session). With that, this
module declares the hooks too. Until then, §2 (Claude → mado) is the full,
shippable half; the hooks are designed here and gated on the mado-side CLI.

Composes with the **safra** Claude-session lane (a `ClaudeCodeSessions`
SourceKind reading `~/.claude/projects` — see `mado/docs/SAFRA.md`) so live
Claude sessions also surface on the Ctrl-S board: the two integrations meet at
the work board.

## 5. The route

- **M0 (this work):** `blackmatter-mado.mcp.serverEntry` + `blackmatter-claude.mcp.madoMcp` + the `drive-mado` skill. Claude → mado, declared, fleet-wide.
- **M1:** `mado control` CLI (kanshou-backed) + the Claude→mado lifecycle hooks declared in this module.
- **M2:** the safra `ClaudeCodeSessions` lane (Claude sessions on the Ctrl-S board) + a statusline that renders Claude's model/cost/context in mado's chrome.

Per-node opt-in: `mcp.madoMcp.enable`. The whole integration is one bool plus
(optionally) `autoAllow` for hands-off control.
