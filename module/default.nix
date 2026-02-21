# Claude Code configuration — LSP, Zoekt daemon, Codesearch daemon, MCP servers
#
# Declaratively manages:
#   ~/.claude/lsp.json  — LSP server configuration
#   ~/.claude.json      — MCP servers (user-scope, deep-merged)
#   launchd agents      — Zoekt webserver + periodic indexer (Darwin)
#   launchd agents      — Codesearch serve daemon with file watching (Darwin)
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
  zoektCfg = cfg.zoekt;
  codesearchCfg = cfg.codesearch;
  mcpCfg = cfg.mcp;
  skillsCfg = cfg.skills;
  isDarwin = pkgs.stdenv.isDarwin;

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
  ctagsCfg = zoektCfg.ctags;
  webCfg = zoektCfg.webserver;

  # ── GitHub MCP wrapper (maps GITHUB_TOKEN → GITHUB_PERSONAL_ACCESS_TOKEN) ──
  githubMcpScript = pkgs.writeShellScript "github-mcp-wrapper" ''
    export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_TOKEN:-}"
    exec "${mcpCfg.github.package}/bin/github-mcp-server" stdio
  '';

  # ── Zoekt indexer wrapper (ensures ctags is on PATH) ─────────────────
  zoektIndexerScript = let
    ctagsArgs =
      if ctagsCfg.enable
      then
        (optionals ctagsCfg.require ["-require_ctags"])
      else ["-disable_ctags"];
    deltaArgs = optionals zoektCfg.delta ["-delta"];
    branchArgs = optionals (zoektCfg.branches != "HEAD") ["-branches" zoektCfg.branches];
    largeFileArgs = concatMap (p: ["-large_file" p]) zoektCfg.largeFiles;
    parallelismArgs = ["-parallelism" (toString zoektCfg.parallelism)];
    fileLimitArgs = ["-file_limit" (toString zoektCfg.fileLimit)];
    allArgs = ctagsArgs ++ deltaArgs ++ branchArgs ++ largeFileArgs ++ parallelismArgs ++ fileLimitArgs;
    repoArgs = concatStringsSep " " (map (r: ''"${r}"'') zoektCfg.repos);
    ctagsPath =
      if ctagsCfg.enable
      then "${ctagsCfg.package}/bin"
      else "";
    logDir = "${config.home.homeDirectory}/Library/Logs";
  in
    pkgs.writeShellScript "zoekt-indexer" ''
      # Truncate previous logs — stale output is noise for a periodic agent
      : > "${logDir}/zoekt-indexer.log"
      : > "${logDir}/zoekt-indexer.err"
      export PATH="${ctagsPath}:${zoektCfg.package}/bin:${pkgs.git}/bin:$PATH"
      exec zoekt-git-index \
        -index "${zoektCfg.indexDir}" \
        ${concatStringsSep " " allArgs} \
        ${repoArgs}
    '';

  # ── Codesearch serve wrapper (setup + initial index + serve) ────────────
  #
  # codesearch serve requires an existing index. This wrapper:
  # 1. Downloads the embedding model if not already cached (codesearch setup)
  # 2. Creates a global index for the repo if one doesn't exist yet
  # 3. Execs into codesearch serve for live file watching + incremental indexing
  codesearchServeScript = repo: let
    bin = "${codesearchCfg.package}/bin/codesearch";
    modelArgs = optionals (codesearchCfg.model != null) ["--model" codesearchCfg.model];
    modelArgsStr = concatStringsSep " " modelArgs;
    portArgs = ["-p" (toString codesearchCfg.port)];
    portArgsStr = concatStringsSep " " portArgs;
    # Derive a launchd-safe label from the repo path
    repoLabel = replaceStrings ["/"] ["-"] (removePrefix "/" repo);
  in
    pkgs.writeShellScript "codesearch-serve-${repoLabel}" ''
      set -euo pipefail
      export CODESEARCH_LMDB_MAP_SIZE_MB="${toString codesearchCfg.lmdbMapSizeMB}"

      cd "${repo}"

      # 0. Kill any stale codesearch serve process on our port
      #    (prevents duplicates after darwin-rebuild changes store path)
      existing=$(lsof -ti :${toString codesearchCfg.port} -sTCP:LISTEN 2>/dev/null || true)
      if [ -n "$existing" ]; then
        echo "Killing stale codesearch serve (PID $existing) on port ${toString codesearchCfg.port}"
        kill $existing 2>/dev/null || true
        sleep 1
      fi

      # 1. Ensure embedding model is downloaded
      ${bin} setup ${modelArgsStr} --quiet 2>/dev/null || ${bin} setup ${modelArgsStr}

      # 2. Create global index if not already present
      project_name="$(basename "${repo}")"
      global_db="$HOME/.codesearch.dbs/$project_name/.codesearch.db"
      if [ ! -d "$global_db" ]; then
        ${bin} index --add --global ${modelArgsStr}
      fi

      # Workaround: codesearch v0.1.142 global DB discovery bug — serve/search/mcp
      # look for .codesearch.db inside the repo dir but global index lives in
      # ~/.codesearch.dbs/<project>/. Symlink bridges the gap.
      if [ -d "$global_db" ] && [ ! -e "${repo}/.codesearch.db" ]; then
        ln -sf "$global_db" "${repo}/.codesearch.db"
      fi

      # 3. Serve with live file watching (keeps index updated)
      exec ${bin} serve ${portArgsStr} ${modelArgsStr}
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
    // optionalAttrs mcpCfg.zoektMcp.enable {
      zoekt = {
        type = "stdio";
        command = "${mcpCfg.zoektMcp.package}/bin/zoekt-mcp";
        env = {
          ZOEKT_URL = "http://localhost:${toString zoektCfg.port}";
        };
      };
    }
    // optionalAttrs mcpCfg.codesearch.enable {
      codesearch = {
        type = "stdio";
        command = "${mcpCfg.codesearch.package}/bin/codesearch";
        args = ["mcp"];
        env = {
          CODESEARCH_LMDB_MAP_SIZE_MB = toString codesearchCfg.lmdbMapSizeMB;
        };
      };
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

    # ── Zoekt daemon options ───────────────────────────────────────────

    zoekt = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Zoekt code search daemon (trigram-indexed search)";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.zoekt;
        description = "Zoekt package providing zoekt-webserver and zoekt-git-index";
      };

      ctags = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable universal-ctags for symbol extraction (enables sym: queries)";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.universal-ctags;
          description = "universal-ctags package";
        };

        require = mkOption {
          type = types.bool;
          default = true;
          description = "If true, ctags calls must succeed (-require_ctags). Set false to allow partial indexing.";
        };
      };

      repos = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Git repository paths to index (e.g. [\"/home/user/code/myrepo\"])";
      };

      indexDir = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.zoekt/index";
        description = "Directory for Zoekt index shards";
      };

      port = mkOption {
        type = types.int;
        default = 6070;
        description = "Zoekt webserver listen port";
      };

      indexInterval = mkOption {
        type = types.int;
        default = 300;
        description = "Re-index interval in seconds (launchd StartInterval)";
      };

      delta = mkOption {
        type = types.bool;
        default = true;
        description = "Only re-index changed files (-delta). Dramatically faster incremental updates.";
      };

      branches = mkOption {
        type = types.str;
        default = "HEAD";
        description = "Comma-separated branch list to index (-branches). Default HEAD indexes only the checked-out branch.";
      };

      largeFiles = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Glob patterns for files to index regardless of size (-large_file per entry).";
      };

      parallelism = mkOption {
        type = types.int;
        default = 4;
        description = "Number of concurrent indexing processes (-parallelism).";
      };

      fileLimit = mkOption {
        type = types.int;
        default = 2097152;
        description = "Maximum file size in bytes to index (-file_limit). Default 2 MiB matches upstream.";
      };

      webserver = {
        rpc = mkOption {
          type = types.bool;
          default = true;
          description = "Enable RPC interface (-rpc). Required for zoekt-mcp and programmatic access.";
        };

        html = mkOption {
          type = types.bool;
          default = true;
          description = "Enable HTML web UI. Set false to run headless API-only.";
        };

        pprof = mkOption {
          type = types.bool;
          default = false;
          description = "Enable pprof profiling endpoint (-pprof). For debugging only.";
        };

        logDir = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/Library/Logs/zoekt";
          description = "Directory for webserver log rotation (-log_dir).";
        };

        logRefresh = mkOption {
          type = types.str;
          default = "24h";
          description = "Log rotation interval (-log_refresh). Go duration format.";
        };
      };
    };

    # ── Codesearch daemon options ─────────────────────────────────────

    codesearch = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Codesearch daemon (semantic code search with live file watching)";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.codesearch;
        description = "codesearch package providing codesearch binary";
      };

      repos = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Repository paths to index (e.g. [\"/home/user/code/myrepo\"])";
      };

      model = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Embedding model to use (null = codesearch default mxbai-embed-xsmall-v1). Options: minilm-l6, bge-small, jina-code, etc.";
      };

      port = mkOption {
        type = types.int;
        default = 4444;
        description = "Codesearch serve port (HTTP API for search)";
      };

      lmdbMapSizeMB = mkOption {
        type = types.int;
        default = 2048;
        description = "LMDB map size in MB. Default 2GB handles large monorepos. Set via CODESEARCH_LMDB_MAP_SIZE_MB env var.";
      };
    };

    # ── MCP server options ─────────────────────────────────────────────

    mcp = {
      zoektMcp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable zoekt-mcp MCP server for Claude Code (wraps Zoekt search API)";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.zoekt-mcp;
          description = "zoekt-mcp package";
        };
      };

      codesearch = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable codesearch MCP server for semantic code search";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.codesearch;
          description = "codesearch package";
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

    # Zoekt daemon — launchd agents (Darwin only)
    (mkIf (cfg.enable && zoektCfg.enable && isDarwin && zoektCfg.repos != []) {
      # Ensure index + log directories exist before daemons start
      home.activation.zoekt-index-dir = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "${zoektCfg.indexDir}"
        run mkdir -p "${webCfg.logDir}"
      '';

      launchd.agents.zoekt-webserver = {
        enable = true;
        config = {
          Label = "io.pleme.zoekt-webserver";
          ProgramArguments = [
            "${zoektCfg.package}/bin/zoekt-webserver"
            "-index"
            zoektCfg.indexDir
            "-listen"
            ":${toString zoektCfg.port}"
            "-log_dir"
            webCfg.logDir
            "-log_refresh"
            webCfg.logRefresh
          ]
          ++ optionals webCfg.rpc ["-rpc"]
          ++ optionals webCfg.pprof ["-pprof"]
          ++ optionals (!webCfg.html) ["-html=false"];
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Adaptive";
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/zoekt-webserver.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/zoekt-webserver.err";
        };
      };

      launchd.agents.zoekt-indexer = {
        enable = true;
        config = {
          Label = "io.pleme.zoekt-indexer";
          ProgramArguments = ["${zoektIndexerScript}"];
          StartInterval = zoektCfg.indexInterval;
          RunAtLoad = true;
          ProcessType = "Background";
          LowPriorityIO = true;
          Nice = 10;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/zoekt-indexer.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/zoekt-indexer.err";
        };
      };
    })
    # Codesearch daemon — launchd agents (Darwin only)
    # Runs `codesearch serve` per repo with live file watching.
    # The wrapper script handles model setup and initial indexing.
    (mkIf (cfg.enable && codesearchCfg.enable && isDarwin && codesearchCfg.repos != []) (let
      mkCodesearchAgent = repo: let
        repoLabel = replaceStrings ["/"] ["-"] (removePrefix "/" repo);
        safeName = "codesearch-${repoLabel}";
      in
        nameValuePair safeName {
          enable = true;
          config = {
            Label = "io.pleme.${safeName}";
            ProgramArguments = ["${codesearchServeScript repo}"];
            RunAtLoad = true;
            KeepAlive = true;
            ProcessType = "Adaptive";
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/codesearch-serve.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/codesearch-serve.err";
          };
        };
    in {
      launchd.agents = builtins.listToAttrs (map mkCodesearchAgent codesearchCfg.repos);
    }))

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
