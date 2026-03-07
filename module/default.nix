# Claude Code configuration — LSP, MCP servers, skills
#
# Declaratively manages:
#   ~/.claude/lsp.json  — LSP server configuration
#   ~/.claude.json      — MCP servers (user-scope, deep-merged)
#   ~/.claude/skills/   — Bundled + extra skills (auto-discovered)
#   claude-code package — Centralized version management from claude-code flake
#
# MCP servers: zoekt, codesearch, github, kubernetes, fluxcd, chrome-devtools, curupira, umbra, typemill
# LSP servers: nixd, rust-analyzer, typescript-language-server,
#   basedpyright, gopls, lua-language-server, bash-language-server, zls, ruby-lsp, clangd
#
{ claude-code }:
{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.claude;
  lspCfg = cfg.lsp;
  mcpCfg = cfg.mcp;
  mcpPkgsCfg = cfg.mcpPackages;
  skillsCfg = cfg.skills;
  themeCfg = cfg.theme;

  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;

  # ── Bundled skills (auto-discovered from ../skills/) ────────────────
  skillsDir = ../skills;
  bundledSkillNames =
    if builtins.pathExists skillsDir
    then builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir skillsDir))
    else [];
  bundledSkillFiles = lib.listToAttrs (map (name:
    lib.nameValuePair name (skillsDir + "/${name}/SKILL.md")
  ) bundledSkillNames);
  allSkillFiles = bundledSkillFiles // skillsCfg.extraSkills;

  # ── GitHub MCP wrapper (maps GITHUB_TOKEN → GITHUB_PERSONAL_ACCESS_TOKEN) ──
  # Reads token from sops-managed file (if configured) as primary source,
  # falls back to GITHUB_TOKEN env var for flexibility.
  githubMcpScript = pkgs.writeShellScript "github-mcp-wrapper" ''
    ${lib.optionalString (mcpCfg.github.tokenFile != null) ''
    if [ -z "''${GITHUB_TOKEN:-}" ] && [ -f "${mcpCfg.github.tokenFile}" ]; then
      GITHUB_TOKEN="$(cat "${mcpCfg.github.tokenFile}")"
    fi
    ''}
    export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_TOKEN:-}"
    exec "${mcpCfg.github.package}/bin/github-mcp-server" stdio
  '';

  # ── LSP server map ──────────────────────────────────────────────────────

  serverEntries =
    {}
    // optionalAttrs lspCfg.nix.enable {
      nix = {
        command = "nixd";
        extensionToLanguage = {".nix" = "nix";};
      };
    }
    // optionalAttrs lspCfg.rust.enable {
      rust = {
        command = "rust-analyzer";
        extensionToLanguage = {".rs" = "rust";};
      };
    }
    // optionalAttrs lspCfg.typescript.enable {
      typescript = {
        command = "typescript-language-server";
        args = ["--stdio"];
        extensionToLanguage = {
          ".ts" = "typescript";
          ".tsx" = "typescriptreact";
          ".js" = "javascript";
          ".jsx" = "javascriptreact";
        };
      };
    }
    // optionalAttrs lspCfg.python.enable {
      python = {
        command = "basedpyright-langserver";
        args = ["--stdio"];
        extensionToLanguage = {".py" = "python";};
      };
    }
    // optionalAttrs lspCfg.go.enable {
      go = {
        command = "gopls";
        extensionToLanguage = {".go" = "go";};
      };
    }
    // optionalAttrs lspCfg.lua.enable {
      lua = {
        command = "lua-language-server";
        extensionToLanguage = {".lua" = "lua";};
      };
    }
    // optionalAttrs lspCfg.bash.enable {
      bash = {
        command = "bash-language-server";
        args = ["start"];
        extensionToLanguage = {
          ".sh" = "shellscript";
          ".bash" = "shellscript";
        };
      };
    }
    // optionalAttrs lspCfg.zig.enable {
      zig = {
        command = "zls";
        extensionToLanguage = {".zig" = "zig";};
      };
    }
    // optionalAttrs lspCfg.ruby.enable {
      ruby = {
        command = "ruby-lsp";
        extensionToLanguage = {".rb" = "ruby";};
      };
    }
    // optionalAttrs lspCfg.cpp.enable {
      cpp = {
        command = "clangd";
        args = ["--background-index" "--clang-tidy" "--header-insertion=iwyu"];
        extensionToLanguage = {
          ".c" = "c";
          ".h" = "c";
          ".cpp" = "cpp";
          ".cxx" = "cpp";
          ".cc" = "cpp";
          ".hpp" = "cpp";
          ".hxx" = "cpp";
        };
      };
    }
    // lspCfg.extraServers;

  # ── Chrome DevTools MCP wrapper (npx-based) ──────────────────────────
  # Connects to the chrome-dev Chrome instance (port 9222) via --browserUrl.
  # --browserUrl alone = connect to existing browser only, never launch a new one.
  # (--autoConnect means "use Chrome's default user data dir" — do NOT use it)
  chromeDevtoolsMcpScript = pkgs.writeShellScript "chrome-devtools-mcp-wrapper" ''
    exec ${pkgs.nodejs_20}/bin/npx -y chrome-devtools-mcp@latest \
      --browserUrl=http://127.0.0.1:9222
  '';

  # ── MCP server map ─────────────────────────────────────────────────────

  mcpServers =
    {}
    // optionalAttrs (mcpCfg.zoektMcp.enable && config.services.zoekt.mcp.serverEntry != {}) {
      zoekt = config.services.zoekt.mcp.serverEntry;
    }
    // optionalAttrs (mcpCfg.codesearch.enable && config.services.codesearch.mcp.serverEntry != {}) {
      codesearch = config.services.codesearch.mcp.serverEntry;
    }
    // optionalAttrs mcpCfg.github.enable {
      github = {
        type = "stdio";
        command = "${githubMcpScript}";
      };
    }
    // optionalAttrs mcpCfg.kubernetes.enable {
      kubernetes = {
        type = "stdio";
        command = "${mcpCfg.kubernetes.package}/bin/mcp-k8s-go";
      };
    }
    // optionalAttrs mcpCfg.fluxcd.enable {
      fluxcd = {
        type = "stdio";
        command = "${mcpCfg.fluxcd.package}/bin/flux-operator-mcp";
        args = ["serve"];
      };
    }
    // optionalAttrs mcpCfg.chromeDevtools.enable {
      chrome-devtools = {
        type = "stdio";
        command = "${chromeDevtoolsMcpScript}";
      };
    }
    // optionalAttrs mcpCfg.curupira.enable {
      curupira = {
        type = "stdio";
        command = "${mcpCfg.curupira.package}/bin/curupira-mcp";
        args = ["stdio"];
      };
    }
    // optionalAttrs mcpCfg.umbra.enable {
      umbra = {
        type = "stdio";
        command = "${mcpCfg.umbra.package}/bin/umbra";
      };
    }
    // optionalAttrs mcpCfg.typemill.enable {
      typemill = {
        type = "stdio";
        command = "${mcpCfg.typemill.package}/bin/mill";
        args = ["start"];
      };
    }
    // mcpCfg.extraServers;

  # ── Managed MCP config (deep-merged into ~/.claude.json) ──────────────

  managedConfig =
    optionalAttrs (mcpServers != {}) {inherit mcpServers;};
  hasManagedConfig = managedConfig != {};

  # JSON blob written to a nix store file for the activation script
  managedConfigFile = pkgs.writeText "claude-managed-config.json"
    (builtins.toJSON managedConfig);

  # Claude Code reads MCP servers from ~/.claude.json (user scope)
  claudeConfigPath = "${config.home.homeDirectory}/.claude.json";

  # ── Config merge tool (Rust, zero deps) ─────────────────────────────
  # Replaces the jq-based activation script. Deep-merges managed MCP config
  # into ~/.claude.json and removes entries with missing binaries (GC'd paths).
  configMergeBinary = pkgs.runCommand "claude-config-merge" {
    nativeBuildInputs = [ pkgs.rustc pkgs.stdenv.cc ];
  } ''
    mkdir -p $out/bin
    rustc --edition 2021 -O -o $out/bin/claude-config-merge ${./claude-config-merge.rs}
  '';

  # ── Nord frost statusline (Rust, zero deps) ─────────────────────────
  statuslineBinary = pkgs.runCommand "claude-nord-statusline" {
    nativeBuildInputs = [ pkgs.rustc pkgs.stdenv.cc ];
  } ''
    mkdir -p $out/bin
    rustc --edition 2021 -O -o $out/bin/claude-nord-statusline ${./statusline.rs}
  '';

  statuslineConfigFile = pkgs.writeText "claude-statusline-config.json"
    (builtins.toJSON {
      statusLine = {
        type = "command";
        command = "${statuslineBinary}/bin/claude-nord-statusline";
      };
    });

  claudeSettingsPath = "${config.home.homeDirectory}/.claude/settings.json";
in {
  options.blackmatter.components.claude = {
    enable = mkEnableOption "Claude Code configuration";

    package = mkOption {
      type = types.package;
      default = claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = literalExpression "claude-code.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = ''
        Claude Code package to install. Defaults to the latest version from the
        claude-code flake input, ensuring consistent updates across all nodes.
      '';
    };

    # ── LSP options ────────────────────────────────────────────────────

    lsp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable LSP server configuration for Claude Code via ~/.claude/lsp.json";
      };

      nix.enable = mkOption {
        type = types.bool;
        default = true;
        description = "nixd - Nix language server";
      };

      rust.enable = mkOption {
        type = types.bool;
        default = true;
        description = "rust-analyzer - Rust language server";
      };

      typescript.enable = mkOption {
        type = types.bool;
        default = true;
        description = "typescript-language-server - TypeScript/JavaScript language server";
      };

      python.enable = mkOption {
        type = types.bool;
        default = true;
        description = "basedpyright - Python language server";
      };

      go.enable = mkOption {
        type = types.bool;
        default = true;
        description = "gopls - Go language server";
      };

      lua.enable = mkOption {
        type = types.bool;
        default = true;
        description = "lua-language-server - Lua language server";
      };

      bash.enable = mkOption {
        type = types.bool;
        default = true;
        description = "bash-language-server - Bash/Shell language server";
      };

      zig.enable = mkOption {
        type = types.bool;
        default = true;
        description = "zls - Zig language server";
      };

      ruby.enable = mkOption {
        type = types.bool;
        default = true;
        description = "ruby-lsp - Ruby language server";
      };

      cpp.enable = mkOption {
        type = types.bool;
        default = true;
        description = "clangd - C/C++ language server";
      };

      extraServers = mkOption {
        type = types.attrs;
        default = {};
        description = "Additional LSP server entries to merge into lsp.json";
      };
    };

    # ── MCP server options ─────────────────────────────────────────────

    mcp = {
      zoektMcp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable zoekt-mcp MCP server for Claude Code (reads serverEntry from services.zoekt.mcp)";
        };
      };

      codesearch = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable codesearch MCP server for semantic code search (reads serverEntry from services.codesearch.mcp)";
        };
      };

      github = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable GitHub MCP server for issues, PRs, repos, and code search";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.github-mcp-server;
          description = "github-mcp-server package";
        };

        tokenFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to file containing GitHub personal access token (e.g. sops-managed ~/.config/github/token). Read at MCP server startup. Falls back to GITHUB_TOKEN env var.";
        };
      };

      kubernetes = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Kubernetes MCP server for cluster management";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.mcp-k8s-go;
          description = "mcp-k8s-go package";
        };
      };

      fluxcd = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable FluxCD MCP server for GitOps lifecycle management";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.fluxcd-operator-mcp;
          description = "fluxcd-operator-mcp package";
        };
      };

      chromeDevtools = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Chrome DevTools MCP server for browser debugging and automation via CDP";
        };
      };

      curupira = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Curupira MCP server for React component inspection and state management debugging";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.curupira-mcp;
          description = "curupira-mcp package (from pleme-io/curupira flake)";
        };
      };

      umbra = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Umbra MCP server for Kubernetes container diagnostics and security scanning";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.umbra;
          description = "umbra package (from pleme-io/umbra flake)";
        };
      };

      typemill = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable TypeMill MCP server for LSP-powered code navigation (inspect, search, rename, refactor)";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.typemill;
          description = "typemill package (mill binary)";
        };
      };

      extraServers = mkOption {
        type = types.attrs;
        default = {};
        description = "Additional MCP server entries to merge into ~/.claude.json mcpServers";
      };
    };

    # ── Skills options ──────────────────────────────────────────────────

    skills = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy bundled Claude Code skills to ~/.claude/skills/ (user scope)";
      };

      extraSkills = mkOption {
        type = types.attrsOf types.path;
        default = {};
        description = ''
          Additional skill files to deploy. Keys are skill names,
          values are paths to SKILL.md files.
          Example: { my-skill = ./my-skill.md; }
        '';
      };
    };

    # ── Theme options ────────────────────────────────────────────────

    theme = {
      statusline = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Deploy Nord frost statusline — model, context usage, and cost using ANSI colors mapped to Nord via terminal palette";
        };
      };
    };

    # ── MCP packages options ─────────────────────────────────────────
    # Controls installation of MCP server packages to PATH.
    # Complements the mcp section above which configures servers in ~/.claude.json.
    #
    # Categories:
    #   - Nix ecosystem (nixos) [Linux only]
    #   - Version control (github, gitea)
    #   - Cloud/Infrastructure (kubernetes, aks, grafana, terraform, fluxcd)
    #   - Datasources (postgres, loki, graphql, redis) [via npx]
    #   - Browser automation (playwright)
    #   - Development tools (languageServer)
    #   - MCP infrastructure (mcphost, toolhive, proxy [Linux], chatmcp [Linux])
    #   - SDKs and libraries (Python ecosystem) [Linux only]
    #   - Haskell ecosystem (disabled by default - often broken)

    mcpPackages = {
      enable = mkEnableOption "MCP (Model Context Protocol) server packages";

      # ── NIX ECOSYSTEM (Linux only) ──
      nixos = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "mcp-nixos - Search 130K+ NixOS packages, 23K+ options, Home Manager, nix-darwin, Nixvim (native on Linux, via uvx on Darwin)";
        };
      };

      # ── VERSION CONTROL ──
      github = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "github-mcp-server - GitHub's official MCP server for repos, issues, PRs";
        };
      };

      gitea = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "gitea-mcp-server - Gitea/Forgejo MCP server";
        };
      };

      # ── CLOUD & INFRASTRUCTURE ──
      kubernetes = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "mcp-k8s-go - Kubernetes cluster integration";
        };
      };

      aks = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "aks-mcp-server - Azure Kubernetes Service integration";
        };
      };

      grafana = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "mcp-grafana - Grafana dashboards and monitoring integration";
        };
      };

      terraform = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "terraform-mcp-server - Terraform/OpenTofu Infrastructure as Code";
        };
      };

      fluxcd = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "fluxcd-operator-mcp - FluxCD GitOps lifecycle management";
        };
      };

      # ── DATASOURCE MCP SERVERS (via npx - not yet in nixpkgs) ──
      postgres = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "@modelcontextprotocol/server-postgres - Official PostgreSQL MCP server for schema inspection and read-only queries (via npx)";
        };
      };

      loki = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "grafana/loki-mcp - Direct Loki LogQL queries and log exploration (via npx)";
        };
      };

      graphql = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "mcp-graphql - GraphQL schema introspection and query execution (via npx)";
        };
      };

      redis = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "@modelcontextprotocol/server-redis - Official Redis/Valkey MCP server for key-value operations (via npx)";
        };
      };

      # ── BROWSER AUTOMATION ──
      playwright = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "playwright-mcp - Browser automation via accessibility snapshots";
        };
      };

      # ── DEVELOPMENT TOOLS ──
      languageServer = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "mcp-language-server - Interact with any LSP-compatible language server";
        };
      };

      # ── MCP INFRASTRUCTURE & UTILITIES ──
      mcphost = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "mcphost - CLI host enabling LLMs to use MCP tools";
        };
      };

      toolhive = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "toolhive - Run any MCP server securely, instantly, anywhere";
        };
      };

      proxy = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "mcp-proxy - Proxy MCP servers between stdio and SSE transports (Linux only)";
        };
      };

      chatmcp = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "chatmcp - AI chat client implementing MCP (Linux only)";
        };
      };

      # ── PYTHON MCP ECOSYSTEM (Linux only, disabled by default - python3.13 compat issues) ──
      pythonSdk = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "python3Packages.mcp - Official Python SDK for MCP servers and clients (Linux only)";
        };
      };

      fastmcp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "python3Packages.fastmcp - Fast, Pythonic way to build MCP servers (Linux only)";
        };
      };

      mcpadapt = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "python3Packages.mcpadapt - MCP servers adaptation tool (Linux only)";
        };
      };

      docling = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "python3Packages.docling-mcp - Document processing made agentic through MCP (Linux only)";
        };
      };

      fastapiMcp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "python3Packages.fastapi-mcp - Expose FastAPI endpoints as MCP tools (Linux only)";
        };
      };

      djangoMcp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "python3Packages.django-mcp-server - Django MCP server implementation (Linux only)";
        };
      };

      # ── HASKELL MCP ECOSYSTEM (disabled by default - packages often broken) ──
      haskellMcp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "haskellPackages.mcp - Haskell implementation of MCP (often broken)";
        };
      };

      haskellMcpServer = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "haskellPackages.mcp-server - Library for building MCP servers in Haskell (often broken)";
        };
      };

      ptyMcpServer = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "haskellPackages.pty-mcp-server - PTY-based MCP server (often broken)";
        };
      };
    };
  };

  # ── Config ───────────────────────────────────────────────────────────

  config = mkMerge [
    # Claude Code package installation
    (mkIf cfg.enable {
      home.packages = [ cfg.package ];
    })

    # Auto-enable service-level MCP flags when the claude module enables them.
    # This bridges the gap between blackmatter.components.claude.mcp.zoektMcp.enable
    # and services.zoekt.mcp.enable (which gates serverEntry generation).
    (mkIf (cfg.enable && mcpCfg.zoektMcp.enable) {
      services.zoekt.mcp.enable = mkDefault true;
    })
    (mkIf (cfg.enable && mcpCfg.codesearch.enable) {
      services.codesearch.mcp.enable = mkDefault true;
    })

    # LSP config → ~/.claude/lsp.json
    (mkIf (cfg.enable && lspCfg.enable) {
      home.file.".claude/lsp.json".text = builtins.toJSON serverEntries;
    })

    # MCP servers → deep-merged into ~/.claude.json (user scope)
    # Uses Rust binary for robust merge + stale path cleanup
    (mkIf (cfg.enable && hasManagedConfig) {
      home.activation.claude-mcp-config = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${configMergeBinary}/bin/claude-config-merge \
          "${managedConfigFile}" \
          --config "${claudeConfigPath}"
      '';
    })

    # Skills → ~/.claude/skills/{name}/SKILL.md (user scope)
    # Auto-discovers bundled skills from ../skills/ + merges extraSkills
    (mkIf (cfg.enable && skillsCfg.enable && allSkillFiles != {}) {
      home.file = lib.mapAttrs' (name: path:
        lib.nameValuePair ".claude/skills/${name}/SKILL.md" {
          source = path;
        }
      ) allSkillFiles;
    })

    # Statusline → deep-merged into ~/.claude/settings.json
    (mkIf (cfg.enable && themeCfg.statusline.enable) {
      home.activation.claude-statusline-config = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "$(dirname "${claudeSettingsPath}")"
        run ${configMergeBinary}/bin/claude-config-merge \
          "${statuslineConfigFile}" \
          --config "${claudeSettingsPath}"
      '';
    })

    # MCP packages → home.packages (installed to PATH)
    (mkIf (cfg.enable && mcpPkgsCfg.enable) (let
      # Helper: only include package if it exists in pkgs (many MCP servers not yet in nixpkgs)
      optPkg = name: if builtins.hasAttr name pkgs then [pkgs.${name}] else [];
      optPkgIf = cond: name: optionals cond (optPkg name);
    in {
      home.packages = with pkgs;
        # NIX ECOSYSTEM
        (optPkgIf (mcpPkgsCfg.nixos.enable && isLinux) "mcp-nixos")
        ++ (optionals (mcpPkgsCfg.nixos.enable && isDarwin) [uv])

        # VERSION CONTROL
        ++ (optPkgIf mcpPkgsCfg.github.enable "github-mcp-server")
        ++ (optPkgIf mcpPkgsCfg.gitea.enable "gitea-mcp-server")

        # CLOUD & INFRASTRUCTURE
        ++ (optPkgIf mcpPkgsCfg.kubernetes.enable "mcp-k8s-go")
        ++ (optPkgIf mcpPkgsCfg.aks.enable "aks-mcp-server")
        ++ (optPkgIf mcpPkgsCfg.grafana.enable "mcp-grafana")
        ++ (optPkgIf mcpPkgsCfg.terraform.enable "terraform-mcp-server")
        ++ (optPkgIf mcpPkgsCfg.fluxcd.enable "fluxcd-operator-mcp")

        # BROWSER AUTOMATION
        ++ (optPkgIf mcpPkgsCfg.playwright.enable "playwright-mcp")

        # DEVELOPMENT TOOLS
        ++ (optPkgIf mcpPkgsCfg.languageServer.enable "mcp-language-server")

        # MCP INFRASTRUCTURE & UTILITIES
        ++ (optPkgIf mcpPkgsCfg.mcphost.enable "mcphost")
        ++ (optPkgIf mcpPkgsCfg.toolhive.enable "toolhive")
        ++ (optPkgIf (mcpPkgsCfg.proxy.enable && isLinux) "mcp-proxy")
        ++ (optPkgIf (mcpPkgsCfg.chatmcp.enable && isLinux) "chatmcp")

        # PYTHON MCP ECOSYSTEM (Linux only)
        ++ (optionals (mcpPkgsCfg.pythonSdk.enable && isLinux && builtins.hasAttr "mcp" python313Packages) [python313Packages.mcp])
        ++ (optionals (mcpPkgsCfg.fastmcp.enable && isLinux && builtins.hasAttr "fastmcp" python313Packages) [python313Packages.fastmcp])
        ++ (optionals (mcpPkgsCfg.mcpadapt.enable && isLinux && builtins.hasAttr "mcpadapt" python313Packages) [python313Packages.mcpadapt])
        ++ (optionals (mcpPkgsCfg.docling.enable && isLinux && builtins.hasAttr "docling-mcp" python313Packages) [python313Packages.docling-mcp])
        ++ (optionals (mcpPkgsCfg.fastapiMcp.enable && isLinux && builtins.hasAttr "fastapi-mcp" python313Packages) [python313Packages.fastapi-mcp])
        ++ (optionals (mcpPkgsCfg.djangoMcp.enable && isLinux && builtins.hasAttr "django-mcp-server" python313Packages) [python313Packages.django-mcp-server])

        # HASKELL MCP ECOSYSTEM
        ++ (optionals (mcpPkgsCfg.haskellMcp.enable && builtins.hasAttr "mcp" haskellPackages) [haskellPackages.mcp])
        ++ (optionals (mcpPkgsCfg.haskellMcpServer.enable && builtins.hasAttr "mcp-server" haskellPackages) [haskellPackages.mcp-server])
        ++ (optionals (mcpPkgsCfg.ptyMcpServer.enable && builtins.hasAttr "pty-mcp-server" haskellPackages) [haskellPackages.pty-mcp-server]);
    }))
  ];
}
