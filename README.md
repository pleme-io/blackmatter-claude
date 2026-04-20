# blackmatter-claude

Full declarative Claude Code configuration via home-manager.

## What it manages

| File | Content | Method |
|------|---------|--------|
| `~/.claude/settings.json` | Core settings, permissions, hooks, sandbox, attribution, statusline | Deep-merged |
| `~/.claude/lsp.json` | LSP server configuration (10 languages) | Written |
| `~/.claude.json` | MCP servers (user-scope) | Deep-merged |
| `~/.claude/skills/` | Bundled + extra skills | Written |
| `~/.claude/keybindings.json` | Keyboard shortcuts | Written |
| `~/.claude/agents/` | Custom subagent definitions | Written |
| `~/.claude/output-styles/` | Custom output style definitions | Written |
| `~/.claude/rules/` | Instruction rules | Written |
| claude-code binary | Package installation | home.packages |

Deep-merged files use a Rust activation script that preserves manual edits, removes stale nix store paths, and validates MCP server binaries.

## Flake outputs

- `homeManagerModules.default` -- home-manager module at `blackmatter.components.claude`

## Quick start

```nix
{
  inputs.blackmatter-claude.url = "github:pleme-io/blackmatter-claude";
}
```

```nix
blackmatter.components.claude = {
  enable = true;

  # Model and behavior. Fleet doctrine: intelligence over speed —
  # effortLevel defaults to "max", alwaysThinkingEnabled defaults to true,
  # and fastModePerSessionOptIn defaults to true. Override only if you
  # need to trade intelligence for something else.
  settings = {
    model = "opus";
    # effortLevel = "max";              # default
    # alwaysThinkingEnabled = true;     # default
    # fastModePerSessionOptIn = true;   # default
    autoMemoryEnabled = true;
    env.ANTHROPIC_MODEL = "opus";
  };

  # Permission rules
  permissions = {
    defaultMode = "default";
    allow = [ "Bash(npm run *)" "mcp__github__*" ];
    deny = [ "Read(./.env)" ];
  };

  # Sandbox
  sandbox = {
    enabled = true;
    filesystem.denyRead = [ "~/.ssh" "~/.gnupg" ];
    network.allowedDomains = [ "api.github.com" ];
  };

  # Lifecycle hooks
  hooks.PreToolUse = [{
    matcher = "Bash";
    hooks = [{ type = "command"; command = "/path/to/validate.sh"; }];
  }];

  # LSP servers (all enabled by default)
  lsp.nix.enable = true;
  lsp.rust.enable = true;

  # MCP servers
  mcp.github.enable = true;
  mcp.kubernetes.enable = true;

  # MCP packages on PATH
  mcpPackages.enable = true;
};
```

## Option groups

| Group | Description |
|-------|-------------|
| `settings.*` | Core settings: model, effort, language, UI, auth, env vars |
| `permissions.*` | Tool allow/deny/ask rules, default mode |
| `attribution.*` | Git commit/PR attribution text |
| `sandbox.*` | Filesystem and network sandboxing |
| `hooks.*` | Lifecycle event hooks (PreToolUse, Stop, etc.) |
| `keybindings.*` | Custom keyboard shortcuts |
| `agents.*` | Custom subagent definitions |
| `outputStyles.*` | Custom output style definitions |
| `rules.*` | Instruction rules (path-scoped or unconditional) |
| `lsp.*` | Language server configuration (10 languages + extra) |
| `mcp.*` | MCP server configuration (9 servers + extra) |
| `skills.*` | Bundled + extra skills |
| `theme.*` | Statusline theming |
| `mcpPackages.*` | MCP server packages installed to PATH (30+) |

## LSP servers

nixd, rust-analyzer, typescript-language-server, basedpyright, gopls, lua-language-server, bash-language-server, zls, ruby-lsp, clangd

## MCP servers

zoekt, codesearch, github, kubernetes, fluxcd, chrome-devtools, curupira, umbra, typemill

## Structure

- `module/` -- home-manager module (options + config)
- `module/claude-config-merge.rs` -- Rust deep-merge tool for JSON config
- `module/statusline.rs` -- Rust Nord frost statusline generator
- `skills/` -- bundled Claude Code skills (auto-discovered)

## References

- [Settings](https://docs.anthropic.com/en/docs/claude-code/settings)
- [Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [MCP](https://docs.anthropic.com/en/docs/claude-code/mcp)
- [Skills](https://docs.anthropic.com/en/docs/claude-code/skills)
- [Permissions](https://docs.anthropic.com/en/docs/claude-code/permissions)
- [Keybindings](https://docs.anthropic.com/en/docs/claude-code/keybindings)
- [Subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Sandbox](https://docs.anthropic.com/en/docs/claude-code/sandboxing)
