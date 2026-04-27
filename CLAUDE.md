# blackmatter-claude

> **★★★ CSE / Knowable Construction.** This repo operates under **Constructive Substrate Engineering** — canonical specification at [`pleme-io/theory/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md`](https://github.com/pleme-io/theory/blob/main/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md). The Compounding Directive (operational rules: solve once, load-bearing fixes only, idiom-first, models stay current, direction beats velocity) is in the org-level pleme-io/CLAUDE.md ★★★ section. Read both before non-trivial changes.


Declarative Claude Code configuration via Nix home-manager. Generic (not org-specific) — pleme-io-specific skills live in `blackmatter-pleme`.

## Fleet doctrine: intelligence over speed

Three settings enforce the "always reason deeply" preference and are set
as the module defaults — override only with deliberate justification:

| Option | Default | Effect |
|--------|---------|--------|
| `settings.effortLevel` | `"max"` | Deepest reasoning mode (low/medium/high/xhigh/max) |
| `settings.alwaysThinkingEnabled` | `true` | Always emit explicit chain-of-thought |
| `settings.fastModePerSessionOptIn` | `true` | Fast mode (`/fast`) requires per-session opt-in |

`/effort` and `/fast` slash commands still work for per-session overrides.
The doctrine applies to every agent wired through `blackmatter-anvil`
(Claude Code, Cursor, OpenCode, future tools) — see `blackmatter-anvil/CLAUDE.md`.

## Architecture

Single home-manager module at `blackmatter.components.claude` managing all Claude Code config files:

```
blackmatter.components.claude
├── enable, package
├── settings.*          → ~/.claude/settings.json (deep-merged)
│   ├── model, effortLevel, language, outputStyle
│   ├── autoMemoryEnabled, alwaysThinkingEnabled
│   ├── env (session environment variables)
│   ├── UI: showTurnDuration, spinnerTipsEnabled, ...
│   └── extraSettings (escape hatch)
├── permissions.*       → ~/.claude/settings.json
│   ├── defaultMode (default/acceptEdits/plan/dontAsk/bypassPermissions)
│   └── allow, deny, ask (tool pattern rules)
├── attribution.*       → ~/.claude/settings.json
├── sandbox.*           → ~/.claude/settings.json
│   ├── enabled, filesystem.{allowWrite,denyWrite,denyRead}
│   └── network.{allowUnixSockets,allowedDomains,...}
├── hooks.*             → ~/.claude/settings.json
├── keybindings.*       → ~/.claude/keybindings.json
├── agents.*            → ~/.claude/agents/*.md
├── outputStyles.*      → ~/.claude/output-styles/*.md
├── rules.*             → ~/.claude/rules/*.md
├── lsp.*               → ~/.claude/lsp.json
├── mcp.*               → ~/.claude.json (deep-merged)
├── skills.*            → ~/.claude/skills/*/SKILL.md
├── theme.statusline    → ~/.claude/settings.json
└── mcpPackages.*       → home.packages
```

## Key patterns

### Deep merge (settings.json, .claude.json)
Uses `claude-config-merge` (zero-dep Rust binary) to deep-merge Nix-managed JSON into existing user config. Managed values win for scalars; objects merge recursively. Stale nix store paths are cleaned automatically.

### Direct write (lsp.json, keybindings.json, skills, agents, rules, output-styles)
Uses `home.file` for files fully managed by Nix. These overwrite on rebuild.

### Settings construction
Each typed Nix option maps to a JSON key. Only non-null/non-empty values are included via `optAttr`/`optList`/`optNested` helpers. The `extraSettings` escape hatch merges arbitrary keys.

### Bundled skills
Auto-discovered from `../skills/` at build time via `builtins.readDir`. Each subdirectory with a `SKILL.md` becomes a deployed skill.

## File layout

```
flake.nix                       # homeManagerModules.default
module/
  default.nix                   # ~1350-line HM module (options + config)
  claude-config-merge.rs        # Zero-dep Rust JSON deep-merge tool
  statusline.rs                 # Zero-dep Rust Nord statusline generator
skills/
  tend/SKILL.md                 # Bundled: workspace repo management
```

## Adding new settings

1. Add typed option in the `settings` group (or appropriate group)
2. Add `// optAttr "keyName" settingsCfg.keyName` to `managedSettings` construction
3. The activation script automatically includes it in the deep merge

## Adding new MCP servers

1. Add option group under `mcp` with `enable` + `package` options
2. Add entry to `mcpServers` map with `optionalAttrs`
3. Optionally add corresponding `mcpPackages` toggle

## Adding new skills

Drop a directory with `SKILL.md` into `skills/`. Auto-discovered at build time.

## Consumption chain

```
blackmatter-claude/flake.nix
  → homeManagerModules.default
    → imported by blackmatter (aggregator)
      → imported by nix (user config)
        → darwinConfigurations/nixosConfigurations
```

User-specific overrides (token files, enable flags) are set in the `nix` repo profiles.
