# blackmatter-claude

Declarative Claude Code configuration as a Nix home-manager module. Manages LSP servers,
MCP (Model Context Protocol) servers, custom skills, and MCP package installation — all
from a single `blackmatter.components.claude` option set. Designed to wire up a complete
Claude Code development environment reproducibly across machines.

## Architecture

```
flake.nix
  └── homeManagerModules.default → module/default.nix
                                      ├── LSP config    → ~/.claude/lsp.json
                                      ├── MCP servers   → ~/.claude.json (deep-merged)
                                      ├── Skills        → ~/.claude/skills/{name}/SKILL.md
                                      └── MCP packages  → home.packages (PATH)

skills/
  └── {name}/SKILL.md   ← bundled skills (auto-discovered at build time)
```

The module reads `~/.claude.json` at activation time and deep-merges managed MCP server
entries into the existing file using `jq -s '.[0] * .[1]'`. This keeps the file writable
so Claude Code can update its own state while Nix manages the MCP server declarations.

## Features

### LSP Servers (10 languages)

All enabled by default; disable individually with `lsp.<lang>.enable = false`.

| Language       | Server                      | File Extensions             |
|----------------|-----------------------------|-----------------------------|
| Nix            | `nixd`                      | `.nix`                      |
| Rust           | `rust-analyzer`             | `.rs`                       |
| TypeScript/JS  | `typescript-language-server` | `.ts`, `.tsx`, `.js`, `.jsx` |
| Python         | `basedpyright`              | `.py`                       |
| Go             | `gopls`                     | `.go`                       |
| Lua            | `lua-language-server`       | `.lua`                      |
| Bash           | `bash-language-server`      | `.sh`, `.bash`              |
| Zig            | `zls`                       | `.zig`                      |
| Ruby           | `ruby-lsp`                  | `.rb`                       |
| C/C++          | `clangd`                    | `.c`, `.h`, `.cpp`, `.cc`, `.hpp` |

### MCP Servers (9 integrations)

Configured in `~/.claude.json` under `mcpServers`. Each server has its own `enable` toggle.

| Server          | Description                                      | Transport |
|-----------------|--------------------------------------------------|-----------|
| `zoekt`         | Trigram-indexed code search (via zoekt-mcp)       | stdio     |
| `codesearch`    | Semantic code search with BM25 + embeddings       | stdio     |
| `github`        | GitHub API — issues, PRs, repos, code search      | stdio     |
| `kubernetes`    | Kubernetes cluster management via mcp-k8s-go      | stdio     |
| `fluxcd`        | FluxCD GitOps lifecycle management                | stdio     |
| `chrome-devtools` | Browser debugging via Chrome DevTools Protocol  | stdio     |
| `curupira`      | React component inspection and state debugging    | stdio     |
| `umbra`         | Kubernetes container diagnostics and security      | stdio     |
| `typemill`      | LSP-powered code navigation and refactoring       | stdio     |

### MCP Packages (30+ tools)

Optional package installation to PATH, organized by category:

- **Nix ecosystem:** mcp-nixos (native on Linux, uvx on Darwin)
- **Version control:** github-mcp-server, gitea-mcp-server
- **Cloud/Infrastructure:** mcp-k8s-go, aks-mcp-server, mcp-grafana, terraform-mcp-server, fluxcd-operator-mcp
- **Datasources:** PostgreSQL, Loki, GraphQL, Redis (via npx)
- **Browser automation:** playwright-mcp
- **Development tools:** mcp-language-server
- **MCP infrastructure:** mcphost, toolhive, mcp-proxy (Linux), chatmcp (Linux)
- **Python SDK ecosystem:** mcp, fastmcp, mcpadapt, docling, fastapi-mcp, django-mcp (Linux)
- **Haskell ecosystem:** mcp, mcp-server, pty-mcp-server (disabled by default)

### Bundled Skills

Skills in `skills/` are auto-discovered at build time and deployed to `~/.claude/skills/`.

| Skill  | Description                                     |
|--------|-------------------------------------------------|
| `tend` | Workspace repository management with tend CLI    |

Additional skills can be added via `skills.extraSkills`.

## Installation

Add as a flake input and enable the home-manager module:

```nix
# flake.nix
{
  inputs.blackmatter-claude = {
    url = "github:pleme-io/blackmatter-claude";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then import the module:

```nix
# home-manager configuration
{ inputs, ... }: {
  imports = [ inputs.blackmatter-claude.homeManagerModules.default ];
}
```

## Usage

### Minimal Configuration

```nix
{
  blackmatter.components.claude = {
    enable = true;
    mcp.github.enable = true;
    mcp.github.tokenFile = "/run/secrets/github-token";
  };
}
```

### Full Configuration

```nix
{
  blackmatter.components.claude = {
    enable = true;

    # LSP — all enabled by default, disable selectively
    lsp.ruby.enable = false;
    lsp.cpp.enable = false;

    # MCP servers
    mcp = {
      zoektMcp.enable = true;       # requires services.zoekt.mcp
      codesearch.enable = true;      # requires services.codesearch.mcp
      github = {
        enable = true;
        tokenFile = "/run/secrets/github-token";
      };
      kubernetes.enable = true;
      fluxcd.enable = true;
      chromeDevtools.enable = true;
      curupira.enable = true;
      umbra.enable = true;
      typemill.enable = true;
      extraServers = { /* custom MCP entries */ };
    };

    # Skills
    skills = {
      enable = true;
      extraSkills = {
        my-skill = ./my-skill/SKILL.md;
      };
    };

    # MCP packages (all default to true except Python/Haskell)
    mcpPackages.enable = true;
  };
}
```

## Configuration Reference

### GitHub MCP Token Resolution

The GitHub MCP server resolves its token in order:

1. `tokenFile` — reads from a file path (e.g., sops-managed secret)
2. `GITHUB_TOKEN` environment variable — fallback
3. Maps to `GITHUB_PERSONAL_ACCESS_TOKEN` for the upstream server

### Deep-Merge Behavior

MCP server config is deep-merged into `~/.claude.json` at home-manager activation.
Managed keys overwrite existing values; unmanaged keys are preserved. This allows
Claude Code to store its own runtime state in the same file.

## Development

```bash
# Check the flake
nix flake check

# Build the module (evaluated as part of home-manager)
nix build .#homeManagerModules.default
```

### Adding a New Skill

1. Create `skills/{name}/SKILL.md` with YAML frontmatter
2. The module auto-discovers it at build time
3. It deploys to `~/.claude/skills/{name}/SKILL.md`

### Adding a New MCP Server

1. Add an option block under `mcp` in `module/default.nix`
2. Add the server entry in the `mcpServers` attrset
3. Optionally add a package option under `mcpPackages`

## Project Structure

```
blackmatter-claude/
├── flake.nix              # Flake definition — exports homeManagerModules.default
├── module/
│   └── default.nix        # Home-manager module (LSP, MCP, skills, packages)
└── skills/
    └── tend/
        └── SKILL.md       # Workspace management skill for tend CLI
```

## Related Projects

| Project | Description |
|---------|-------------|
| [blackmatter](https://github.com/pleme-io/blackmatter) | Home-manager module aggregator — consumes this repo |
| [blackmatter-pleme](https://github.com/pleme-io/blackmatter-pleme) | Pleme-io org skills and workspace conventions |
| [zoekt-mcp](https://github.com/pleme-io/zoekt-mcp) | Zoekt trigram search MCP server |
| [codesearch](https://github.com/pleme-io/codesearch) | Semantic code search MCP server |
| [curupira](https://github.com/pleme-io/curupira) | React/browser debugging MCP server |
| [umbra](https://github.com/pleme-io/umbra) | Kubernetes diagnostics MCP server |
| [substrate](https://github.com/pleme-io/substrate) | Reusable Nix build patterns |

## License

MIT
