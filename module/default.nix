# Claude Code configuration — LSP, MCP servers
#
# Declaratively manages:
#   ~/.claude/lsp.json  — LSP server configuration
#   ~/.claude.json      — MCP servers (user-scope, deep-merged)
#
# MCP servers: zoekt, codesearch, github, kubernetes, fluxcd
# LSP servers: nixd, rust-analyzer, typescript-language-server,
#   basedpyright, gopls, lua-language-server, bash-language-server, zls, ruby-lsp
#
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
  skillsCfg = cfg.skills;

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
  githubMcpScript = pkgs.writeShellScript "github-mcp-wrapper" ''
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
    // lspCfg.extraServers;

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
in {
  options.blackmatter.components.claude = {
    enable = mkEnableOption "Claude Code configuration";

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
  };

  # ── Config ───────────────────────────────────────────────────────────

  config = mkMerge [
    # LSP config → ~/.claude/lsp.json
    (mkIf (cfg.enable && lspCfg.enable) {
      home.file.".claude/lsp.json".text = builtins.toJSON serverEntries;
    })

    # MCP servers → deep-merged into ~/.claude.json (user scope)
    # Keeps the file writable so Claude Code can update its own state
    (mkIf (cfg.enable && hasManagedConfig) {
      home.activation.claude-mcp-config = lib.hm.dag.entryAfter ["writeBoundary"] ''
        config_file="${claudeConfigPath}"
        managed="${managedConfigFile}"
        if [ -f "$config_file" ]; then
          # Deep-merge: managed keys win, existing keys preserved
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$config_file" "$managed" > "$config_file.tmp"
          mv "$config_file.tmp" "$config_file"
        else
          cp "$managed" "$config_file"
          chmod 644 "$config_file"
        fi
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
  ];
}
