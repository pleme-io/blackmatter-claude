# Claude Code configuration — full declarative management
#
# Declaratively manages every aspect of Claude Code's configuration:
#   ~/.claude/settings.json     — Core settings, permissions, hooks, sandbox, attribution (deep-merged)
#   ~/.claude/lsp.json          — LSP server configuration
#   ~/.claude.json              — MCP servers (user-scope, deep-merged)
#   ~/.claude/skills/           — Bundled + extra skills (auto-discovered)
#   ~/.claude/keybindings.json  — Keyboard shortcuts
#   ~/.claude/agents/           — Custom subagent definitions
#   ~/.claude/output-styles/    — Custom output style definitions
#   ~/.claude/rules/            — Instruction rules
#   claude-code package         — Centralized version management from claude-code flake
#
# Settings reference: https://docs.anthropic.com/en/docs/claude-code/settings
# Hooks reference:    https://docs.anthropic.com/en/docs/claude-code/hooks
# MCP reference:      https://docs.anthropic.com/en/docs/claude-code/mcp
# Skills reference:   https://docs.anthropic.com/en/docs/claude-code/skills
# Keybindings:        https://docs.anthropic.com/en/docs/claude-code/keybindings
# Subagents:          https://docs.anthropic.com/en/docs/claude-code/sub-agents
# Permissions:        https://docs.anthropic.com/en/docs/claude-code/permissions
# Sandbox:            https://docs.anthropic.com/en/docs/claude-code/sandboxing
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
  settingsCfg = cfg.settings;
  permsCfg = cfg.permissions;
  attrCfg = cfg.attribution;
  sandboxCfg = cfg.sandbox;
  hooksCfg = cfg.hooks;
  keybindingsCfg = cfg.keybindings;
  agentsCfg = cfg.agents;
  outputStylesCfg = cfg.outputStyles;
  rulesCfg = cfg.rules;
  lspCfg = cfg.lsp;
  mcpCfg = cfg.mcp;
  mcpPkgsCfg = cfg.mcpPackages;
  skillsCfg = cfg.skills;
  guardrailCfg = cfg.guardrail;
  themeCfg = cfg.theme;

  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;

  # ── Helpers ────────────────────────────────────────────────────────────

  # Import typed options from separate file
  claudeOpts = import ./claude-options.nix { inherit lib; };

  # Conditional attribute helpers (also available via substrate hm-typed-config-helpers.nix)
  optAttr = name: value: optionalAttrs (value != null) { ${name} = value; };
  optList = name: value: optionalAttrs (value != []) { ${name} = value; };
  optNested = name: value: optionalAttrs (value != {}) { ${name} = value; };

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

  # ── MCP servers from anvil + service-level + extras ────────────────────
  anvilServers = config.blackmatter.components.anvil.generatedServers;

  # Service-level MCP servers (zoekt, codesearch, amimori) still read from services.*
  serviceMcpServers =
    {}
    // optionalAttrs (mcpCfg.zoektMcp.enable && config.services.zoekt.mcp.serverEntry != {}) {
      zoekt = config.services.zoekt.mcp.serverEntry;
    }
    // optionalAttrs (mcpCfg.codesearch.enable && config.services.codesearch.mcp.serverEntry != {}) {
      codesearch = config.services.codesearch.mcp.serverEntry;
    }
    // optionalAttrs (mcpCfg.amimori.enable && config.services.amimori.mcp.serverEntry != {}) {
      amimori = config.services.amimori.mcp.serverEntry;
    }
    // optionalAttrs (mcpCfg.kurageMcp.enable && config.services.kurage.mcp.serverEntry != {}) {
      kurage = config.services.kurage.mcp.serverEntry;
    };

  mcpServers = anvilServers // serviceMcpServers // mcpCfg.extraServers;

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
  # Deep-merges Nix-managed JSON into user config files and removes
  # stale entries with missing binaries (GC'd nix store paths).
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

  # ── Managed settings (deep-merged into ~/.claude/settings.json) ─────
  #
  # Assembles all typed Nix options into a JSON blob that gets deep-merged
  # into the user's ~/.claude/settings.json.
  #
  # Settings with confirmed defaults are ALWAYS written (fully explicit config).
  # Settings without defaults (nullOr) are only written when explicitly set.
  # Lists are only written when non-empty.

  permsObj =
    {}
    // optAttr "defaultMode" permsCfg.defaultMode
    // optList "allow" permsCfg.allow
    // optList "deny" permsCfg.deny
    // optList "ask" permsCfg.ask
    // optList "additionalDirectories" permsCfg.additionalDirectories;

  attrObj =
    {}
    // optAttr "commit" attrCfg.commit
    // optAttr "pr" attrCfg.pr;

  sandboxFsObj =
    {}
    // optList "allowWrite" sandboxCfg.filesystem.allowWrite
    // optList "denyWrite" sandboxCfg.filesystem.denyWrite
    // optList "denyRead" sandboxCfg.filesystem.denyRead;

  sandboxNetObj =
    {
      # Confirmed defaults — always written
      inherit (sandboxCfg.network) allowAllUnixSockets allowLocalBinding;
    }
    // optList "allowUnixSockets" sandboxCfg.network.allowUnixSockets
    // optList "allowedDomains" sandboxCfg.network.allowedDomains;

  sandboxObj =
    {
      # Confirmed defaults — always written
      inherit (sandboxCfg) enabled autoAllowBashIfSandboxed
        allowUnsandboxedCommands enableWeakerNestedSandbox
        enableWeakerNetworkIsolation;
    }
    // optList "excludedCommands" sandboxCfg.excludedCommands
    // optNested "filesystem" sandboxFsObj
    // optNested "network" sandboxNetObj;

  managedSettings =
    {
      # ── Confirmed defaults (always written to settings.json) ──
      # These match Claude Code's built-in defaults per the JSON schema.
      # Setting them explicitly makes the config fully reproducible and
      # visible at the Nix layer without consulting external docs.
      inherit (settingsCfg)
        showTurnDuration              # true
        terminalProgressBarEnabled    # true
        spinnerTipsEnabled            # true
        respectGitignore              # true
        includeGitInstructions        # true
        autoMemoryEnabled             # true
        cleanupPeriodDays             # 30
        fastModePerSessionOptIn       # false
        prefersReducedMotion          # false
        disableAllHooks               # false
        enableAllProjectMcpServers    # false
        teammateMode;                 # "auto"
    }
    # ── No confirmed default (only written when explicitly set) ──
    // optAttr "model" settingsCfg.model
    // optAttr "effortLevel" settingsCfg.effortLevel
    // optAttr "language" settingsCfg.language
    // optAttr "outputStyle" settingsCfg.outputStyle
    // optAttr "apiKeyHelper" settingsCfg.apiKeyHelper
    // optAttr "alwaysThinkingEnabled" settingsCfg.alwaysThinkingEnabled
    // optAttr "autoUpdatesChannel" settingsCfg.autoUpdatesChannel
    // optAttr "plansDirectory" settingsCfg.plansDirectory
    // optList "claudeMdExcludes" settingsCfg.claudeMdExcludes
    // optNested "env" settingsCfg.env
    // optList "companyAnnouncements" settingsCfg.companyAnnouncements
    // optList "availableModels" settingsCfg.availableModels
    // optAttr "skipDangerousModePermissionPrompt" settingsCfg.skipDangerousModePermissionPrompt
    // optList "enabledMcpjsonServers" settingsCfg.enabledMcpjsonServers
    // optList "disabledMcpjsonServers" settingsCfg.disabledMcpjsonServers
    # Auth
    // optAttr "forceLoginMethod" settingsCfg.forceLoginMethod
    // optAttr "forceLoginOrgUUID" settingsCfg.forceLoginOrgUUID
    # Nested objects
    // optNested "permissions" permsObj
    // optNested "attribution" attrObj
    // { sandbox = sandboxObj; }
    // optNested "hooks" hooksCfg
    # Statusline
    // optionalAttrs themeCfg.statusline.enable {
      statusLine = {
        type = "command";
        command = "${statuslineBinary}/bin/claude-nord-statusline";
      };
    }
    # Escape hatch
    // settingsCfg.extraSettings;

  hasManagedSettings = managedSettings != {};
  managedSettingsFile = pkgs.writeText "claude-managed-settings.json"
    (builtins.toJSON managedSettings);

  claudeSettingsPath = "${config.home.homeDirectory}/.claude/settings.json";

  # ── Keybindings JSON ─────────────────────────────────────────────────
  keybindingsJson =
    { bindings = map (context: {
        inherit context;
        bindings = keybindingsCfg.bindings.${context};
      }) (attrNames keybindingsCfg.bindings);
    };

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

    # All typed options imported from claude-options.nix
    # Covers: settings, permissions, attribution, sandbox, hooks (typed submodules),
    # keybindings, agents, outputStyles, rules, lsp, mcp, skills, theme, mcpPackages
  } // claudeOpts;

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
    (mkIf (cfg.enable && mcpCfg.amimori.enable) {
      services.amimori.mcp.enable = mkDefault true;
    })
    (mkIf (cfg.enable && mcpCfg.kurageMcp.enable) {
      services.kurage.mcp.enable = mkDefault true;
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

    # Guardrail → defensive hooks for Bash tool calls
    (mkIf (cfg.enable && guardrailCfg.enable) {
      # Generate shikumi config at ~/.config/guardrail/guardrail.yaml
      home.file.".config/guardrail/guardrail.yaml".text = builtins.toJSON {
        categories = {
          filesystem = guardrailCfg.categories.filesystem;
          git = guardrailCfg.categories.git;
          database = guardrailCfg.categories.database;
          kubernetes = guardrailCfg.categories.kubernetes;
          nix = guardrailCfg.categories.nix;
          docker = guardrailCfg.categories.docker;
          secrets = guardrailCfg.categories.secrets;
        };
        extraRules = guardrailCfg.extraRules;
        disabledRules = guardrailCfg.disabledRules;
      };

      # Inject PreToolUse hook for Bash
      blackmatter.components.claude.hooks.PreToolUse = [{
        matcher = "Bash";
        hooks = [{
          type = "command";
          command = "${pkgs.guardrail}/bin/guardrail check";
        }];
      }];
    })

    # Settings → deep-merged into ~/.claude/settings.json
    # Consolidates all settings: core, permissions, hooks, sandbox,
    # attribution, statusline, and extraSettings into a single merge.
    (mkIf (cfg.enable && hasManagedSettings) {
      home.activation.claude-settings-config = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "$(dirname "${claudeSettingsPath}")"
        run ${configMergeBinary}/bin/claude-config-merge \
          "${managedSettingsFile}" \
          --config "${claudeSettingsPath}"
      '';
    })

    # Keybindings → ~/.claude/keybindings.json
    (mkIf (cfg.enable && keybindingsCfg.enable && keybindingsCfg.bindings != {}) {
      home.file.".claude/keybindings.json".text = builtins.toJSON keybindingsJson;
    })

    # Subagents → ~/.claude/agents/{name}.md
    (mkIf (cfg.enable && agentsCfg.enable && agentsCfg.definitions != {}) {
      home.file = lib.mapAttrs' (name: path:
        lib.nameValuePair ".claude/agents/${name}.md" {
          source = path;
        }
      ) agentsCfg.definitions;
    })

    # Output styles → ~/.claude/output-styles/{name}.md
    (mkIf (cfg.enable && outputStylesCfg.enable && outputStylesCfg.definitions != {}) {
      home.file = lib.mapAttrs' (name: path:
        lib.nameValuePair ".claude/output-styles/${name}.md" {
          source = path;
        }
      ) outputStylesCfg.definitions;
    })

    # Rules → ~/.claude/rules/{name}.md
    (mkIf (cfg.enable && rulesCfg.enable && rulesCfg.definitions != {}) {
      home.file = lib.mapAttrs' (name: path:
        lib.nameValuePair ".claude/rules/${name}.md" {
          source = path;
        }
      ) rulesCfg.definitions;
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
