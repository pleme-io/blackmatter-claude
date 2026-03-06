# blackmatter-claude

Claude Code integration -- LSP servers, MCP servers, skills, and package management.

## Overview

Declaratively manages Claude Code's configuration via home-manager: LSP servers (`~/.claude/lsp.json`), MCP servers (deep-merged into `~/.claude.json`), and skills (`~/.claude/skills/`). Supports 10 LSP servers and 9+ MCP servers out of the box, all individually toggleable.

## Flake Outputs

- `homeManagerModules.default` -- home-manager module at `blackmatter.components.claude`

## Usage

```nix
{
  inputs.blackmatter-claude.url = "github:pleme-io/blackmatter-claude";
}
```

```nix
blackmatter.components.claude = {
  enable = true;
  lsp.nix.enable = true;
  lsp.rust.enable = true;
  mcp.github.enable = true;
  mcp.kubernetes.enable = true;
  mcpPackages.enable = true;
};
```

## LSP Servers

nixd, rust-analyzer, typescript-language-server, basedpyright, gopls, lua-language-server, bash-language-server, zls, ruby-lsp, clangd

## MCP Servers

zoekt, codesearch, github, kubernetes, fluxcd, chrome-devtools, curupira, umbra, typemill

## Structure

- `module/` -- home-manager module (options + config)
- `skills/` -- bundled Claude Code skills (auto-discovered)
