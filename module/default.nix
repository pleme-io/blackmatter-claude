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
  themeCfg = cfg.theme;

  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;

  # ── Helpers ────────────────────────────────────────────────────────────

  # Only include attribute if value is not null
  optAttr = name: value: optionalAttrs (value != null) { ${name} = value; };

  # Only include attribute if list is non-empty
  optList = name: value: optionalAttrs (value != []) { ${name} = value; };

  # Only include nested attrset if non-empty
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
  # into the user's ~/.claude/settings.json. Only includes non-null/non-empty
  # values so Nix-managed settings coexist with manual user settings.

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
    {}
    // optList "allowUnixSockets" sandboxCfg.network.allowUnixSockets
    // optAttr "allowAllUnixSockets" sandboxCfg.network.allowAllUnixSockets
    // optAttr "allowLocalBinding" sandboxCfg.network.allowLocalBinding
    // optList "allowedDomains" sandboxCfg.network.allowedDomains;

  sandboxObj =
    {}
    // optAttr "enabled" sandboxCfg.enabled
    // optAttr "autoAllowBashIfSandboxed" sandboxCfg.autoAllowBashIfSandboxed
    // optList "excludedCommands" sandboxCfg.excludedCommands
    // optAttr "allowUnsandboxedCommands" sandboxCfg.allowUnsandboxedCommands
    // optAttr "enableWeakerNestedSandbox" sandboxCfg.enableWeakerNestedSandbox
    // optAttr "enableWeakerNetworkIsolation" sandboxCfg.enableWeakerNetworkIsolation
    // optNested "filesystem" sandboxFsObj
    // optNested "network" sandboxNetObj;

  managedSettings =
    {}
    # Core settings
    // optAttr "model" settingsCfg.model
    // optAttr "effortLevel" settingsCfg.effortLevel
    // optAttr "language" settingsCfg.language
    // optAttr "outputStyle" settingsCfg.outputStyle
    // optAttr "apiKeyHelper" settingsCfg.apiKeyHelper
    // optAttr "cleanupPeriodDays" settingsCfg.cleanupPeriodDays
    // optAttr "autoMemoryEnabled" settingsCfg.autoMemoryEnabled
    // optAttr "alwaysThinkingEnabled" settingsCfg.alwaysThinkingEnabled
    // optAttr "includeGitInstructions" settingsCfg.includeGitInstructions
    // optAttr "fastModePerSessionOptIn" settingsCfg.fastModePerSessionOptIn
    // optAttr "autoUpdatesChannel" settingsCfg.autoUpdatesChannel
    // optAttr "plansDirectory" settingsCfg.plansDirectory
    // optList "claudeMdExcludes" settingsCfg.claudeMdExcludes
    // optNested "env" settingsCfg.env
    // optList "companyAnnouncements" settingsCfg.companyAnnouncements
    // optList "availableModels" settingsCfg.availableModels
    # UI settings
    // optAttr "showTurnDuration" settingsCfg.showTurnDuration
    // optAttr "terminalProgressBarEnabled" settingsCfg.terminalProgressBarEnabled
    // optAttr "prefersReducedMotion" settingsCfg.prefersReducedMotion
    // optAttr "spinnerTipsEnabled" settingsCfg.spinnerTipsEnabled
    // optAttr "respectGitignore" settingsCfg.respectGitignore
    // optAttr "skipDangerousModePermissionPrompt" settingsCfg.skipDangerousModePermissionPrompt
    // optAttr "disableAllHooks" settingsCfg.disableAllHooks
    // optAttr "enableAllProjectMcpServers" settingsCfg.enableAllProjectMcpServers
    // optList "enabledMcpjsonServers" settingsCfg.enabledMcpjsonServers
    // optList "disabledMcpjsonServers" settingsCfg.disabledMcpjsonServers
    // optAttr "teammateMode" settingsCfg.teammateMode
    # Auth
    // optAttr "forceLoginMethod" settingsCfg.forceLoginMethod
    // optAttr "forceLoginOrgUUID" settingsCfg.forceLoginOrgUUID
    # Nested objects
    // optNested "permissions" permsObj
    // optNested "attribution" attrObj
    // optNested "sandbox" sandboxObj
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

    # ── Core settings ──────────────────────────────────────────────────
    # All options map to keys in ~/.claude/settings.json (user scope).
    # Settings are deep-merged: Nix-managed values coexist with manual edits.
    # Null values are omitted (not written to JSON).

    settings = {
      model = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "opus";
        description = ''
          Default model for Claude Code sessions. Accepts aliases (opus, sonnet,
          haiku) or full model names (claude-opus-4-6). Can also use special values
          like "sonnet[1m]" for 1M context or "opusplan" for plan-mode switching.
          Override per-session with /model or --model flag.
        '';
      };

      effortLevel = mkOption {
        type = types.nullOr (types.enum ["low" "medium" "high"]);
        default = null;
        example = "high";
        description = ''
          Reasoning effort level. "low" = faster/cheaper, "high" = more thorough.
          Override with CLAUDE_CODE_EFFORT_LEVEL env var.
        '';
      };

      language = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "en";
        description = "Preferred language for Claude's responses.";
      };

      outputStyle = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Explanatory";
        description = ''
          Output style name. Built-in: "Default", "Explanatory", "Learning".
          Custom styles: add .md files to ~/.claude/output-styles/ or use the
          outputStyles option in this module.
        '';
      };

      apiKeyHelper = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Path to a script that outputs an authentication token on stdout.
          Called before each API request. Useful for rotating credentials.
        '';
      };

      cleanupPeriodDays = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 30;
        description = "Number of days before old sessions are automatically deleted.";
      };

      autoMemoryEnabled = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Enable/disable auto memory (MEMORY.md persistence across sessions).
          Override with CLAUDE_CODE_DISABLE_AUTO_MEMORY env var.
        '';
      };

      alwaysThinkingEnabled = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Enable extended thinking (chain-of-thought reasoning) by default.
          When enabled, Claude uses more tokens but produces better results
          for complex tasks. Toggle per-session with Cmd+T.
        '';
      };

      includeGitInstructions = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Include git workflow instructions in the system prompt (default: true).
          Disable to reduce prompt size in non-git environments.
        '';
      };

      fastModePerSessionOptIn = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Require per-session opt-in for fast mode (/fast). When true,
          fast mode must be explicitly enabled each session.
        '';
      };

      autoUpdatesChannel = mkOption {
        type = types.nullOr (types.enum ["stable" "latest"]);
        default = null;
        description = ''
          Auto-update channel. "stable" for production releases, "latest" for
          bleeding edge. Irrelevant when using Nix-managed package.
        '';
      };

      plansDirectory = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom directory for plan file storage.";
      };

      claudeMdExcludes = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["vendor/" "node_modules/"];
        description = ''
          Glob patterns to exclude CLAUDE.md files from being loaded.
          Useful for skipping vendored or third-party CLAUDE.md files.
        '';
      };

      env = mkOption {
        type = types.attrsOf types.str;
        default = {};
        example = {
          ANTHROPIC_MODEL = "opus";
          CLAUDE_CODE_EFFORT_LEVEL = "high";
        };
        description = ''
          Environment variables set for all Claude Code sessions. These are
          injected into every session's environment. Useful for API keys,
          model overrides, and feature flags.

          Common variables:
            ANTHROPIC_API_KEY — API key
            ANTHROPIC_MODEL — model override
            CLAUDE_CODE_EFFORT_LEVEL — low/medium/high
            CLAUDE_CODE_MAX_OUTPUT_TOKENS — max output tokens (default 32000, max 64000)
            CLAUDE_CODE_SHELL — override shell detection
            CLAUDE_CODE_USE_BEDROCK — use Amazon Bedrock
            CLAUDE_CODE_USE_VERTEX — use Google Vertex AI
            CLAUDE_CODE_DISABLE_AUTO_MEMORY — disable auto memory
            CLAUDE_CODE_DISABLE_FAST_MODE — disable fast mode
            MCP_TIMEOUT — MCP server startup timeout (ms)
            MAX_MCP_OUTPUT_TOKENS — max MCP tool output tokens (default 25000)
        '';
      };

      companyAnnouncements = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Announcements shown in random rotation during sessions.";
      };

      availableModels = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["opus" "sonnet"];
        description = ''
          Restrict which models users can select. When non-empty, only these
          models appear in the model picker. Accepts aliases and full names.
        '';
      };

      # ── UI settings ──

      showTurnDuration = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Show duration of each turn in the conversation (default: true).";
      };

      terminalProgressBarEnabled = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Show progress bar in terminal during long operations (default: true).";
      };

      prefersReducedMotion = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Reduce UI animations for accessibility.";
      };

      spinnerTipsEnabled = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Show tips in the loading spinner (default: true).";
      };

      respectGitignore = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Respect .gitignore patterns in the file picker (default: true).";
      };

      skipDangerousModePermissionPrompt = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Skip the confirmation prompt when entering bypass-permissions mode.";
      };

      disableAllHooks = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Disable all hooks and the status line command.";
      };

      enableAllProjectMcpServers = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Auto-approve all project-level MCP servers from .mcp.json files.";
      };

      enabledMcpjsonServers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Specific .mcp.json server names to auto-approve.";
      };

      disabledMcpjsonServers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Specific .mcp.json server names to reject.";
      };

      teammateMode = mkOption {
        type = types.nullOr (types.enum ["auto" "in-process" "tmux"]);
        default = null;
        description = ''
          Agent teams execution mode.
            auto — Claude chooses (default)
            in-process — teammates run as subprocesses
            tmux — teammates run in tmux panes (visible, debuggable)
        '';
      };

      # ── Auth settings ──

      forceLoginMethod = mkOption {
        type = types.nullOr (types.enum ["claudeai" "console"]);
        default = null;
        description = ''
          Force a specific login method. "claudeai" for claude.ai accounts,
          "console" for Anthropic API Console accounts.
        '';
      };

      forceLoginOrgUUID = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Auto-select organization by UUID during login.";
      };

      # ── Escape hatch ──

      extraSettings = mkOption {
        type = types.attrs;
        default = {};
        description = ''
          Arbitrary additional keys to merge into ~/.claude/settings.json.
          Use this for new or undocumented settings not yet exposed as typed options.
          These are deep-merged with all other managed settings.
        '';
      };
    };

    # ── Permissions ────────────────────────────────────────────────────
    # Controls which tools Claude can use and how.
    # Rules use the format: "Tool" or "Tool(specifier)" with glob * support.
    #
    # Examples:
    #   "Bash"                    — all bash commands
    #   "Bash(npm run *)"         — commands starting with "npm run"
    #   "Edit(/src/**)"           — editing files under src/
    #   "Read(./.env)"            — reading .env in project root
    #   "WebFetch(domain:*.com)"  — fetch to .com domains
    #   "mcp__github__*"          — all GitHub MCP tools
    #
    # Path prefixes: // = absolute, ~/ = home-relative, / = project-relative
    # Evaluation order: deny (first match) → ask → allow

    permissions = {
      defaultMode = mkOption {
        type = types.nullOr (types.enum [
          "default" "acceptEdits" "plan" "dontAsk" "bypassPermissions"
        ]);
        default = null;
        description = ''
          Default permission mode for new sessions.
            default — ask for dangerous operations
            acceptEdits — auto-approve file edits, ask for bash
            plan — read-only, no edits or commands
            dontAsk — auto-approve everything (still sandboxed)
            bypassPermissions — no restrictions (dangerous)
        '';
      };

      allow = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [
          "Bash(npm run *)"
          "Edit(/src/**)"
          "mcp__github__*"
        ];
        description = ''
          Tool patterns to auto-approve without prompting.
          Merged (unioned) across all settings scopes.
        '';
      };

      deny = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [
          "Bash(rm -rf *)"
          "Read(./.env)"
        ];
        description = ''
          Tool patterns to block entirely. Deny rules are checked first
          and take priority over allow/ask rules.
          Merged (unioned) across all settings scopes.
        '';
      };

      ask = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          Tool patterns that always require user confirmation,
          even if they would otherwise be auto-approved.
          Merged (unioned) across all settings scopes.
        '';
      };

      additionalDirectories = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["/tmp/builds" "~/shared"];
        description = ''
          Extra directories Claude Code can access beyond the project root.
          Equivalent to --add-dir CLI flag.
        '';
      };
    };

    # ── Attribution ────────────────────────────────────────────────────

    attribution = {
      commit = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Generated with Claude Code";
        description = "Text appended to git commit messages for attribution.";
      };

      pr = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Generated with Claude Code";
        description = "Text appended to pull request descriptions for attribution.";
      };
    };

    # ── Sandbox ────────────────────────────────────────────────────────
    # Restricts filesystem and network access for bash commands.
    #
    # Path prefixes:
    #   // — absolute from filesystem root
    #   ~/ — relative to home directory
    #   /  — relative to settings file location
    #   ./ — resolved at runtime (cwd-relative)

    sandbox = {
      enabled = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Enable command sandboxing (default: false). Restricts filesystem and network access.";
      };

      autoAllowBashIfSandboxed = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Auto-approve all bash commands when sandbox is enabled (default: true).";
      };

      excludedCommands = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["docker" "kubectl"];
        description = "Commands that run outside the sandbox even when sandboxing is enabled.";
      };

      allowUnsandboxedCommands = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Allow tools to use dangerouslyDisableSandbox escape hatch (default: true).";
      };

      enableWeakerNestedSandbox = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Use weaker sandbox inside Docker/containers where full sandboxing is unavailable.";
      };

      enableWeakerNetworkIsolation = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Allow TLS trust service access on macOS (needed for some network operations).";
      };

      filesystem = {
        allowWrite = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["~/tmp" "/tmp/builds"];
          description = "Paths where write access is allowed. Merged across settings scopes.";
        };

        denyWrite = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["~/.ssh" "~/.gnupg"];
          description = "Paths where write access is denied. Merged across settings scopes.";
        };

        denyRead = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["~/.ssh/id_*" "~/.gnupg"];
          description = "Paths where read access is denied. Merged across settings scopes.";
        };
      };

      network = {
        allowUnixSockets = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Unix socket paths that sandboxed commands can access. Merged across scopes.";
        };

        allowAllUnixSockets = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Allow access to all Unix sockets (overrides allowUnixSockets list).";
        };

        allowLocalBinding = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Allow binding to localhost ports (macOS sandbox).";
        };

        allowedDomains = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["api.github.com" "*.anthropic.com"];
          description = "Domain allowlist for outbound network traffic. Merged across scopes.";
        };
      };
    };

    # ── Hooks ──────────────────────────────────────────────────────────
    # Lifecycle event handlers that run shell commands, HTTP requests,
    # or LLM prompts at specific points in Claude Code's execution.
    #
    # Structure: { EventName = [ { matcher = "..."; hooks = [ hookEntry ]; } ]; }
    #
    # Hook events:
    #   PreToolUse         — before tool executes (can block with exit 2)
    #   PostToolUse        — after tool succeeds
    #   PostToolUseFailure — after tool fails
    #   UserPromptSubmit   — user submits a prompt
    #   Stop               — Claude finishes responding
    #   SessionStart       — session begins (matcher: startup/resume/clear/compact)
    #   SessionEnd         — session terminates
    #   Notification       — Claude sends notification
    #   SubagentStart      — subagent spawned
    #   SubagentStop       — subagent finishes
    #   TaskCompleted      — task marked complete
    #   InstructionsLoaded — CLAUDE.md/rules loaded
    #   ConfigChange       — config file changes
    #   WorktreeCreate     — git worktree being created
    #   WorktreeRemove     — git worktree being removed
    #   PreCompact         — before context compaction
    #   PermissionRequest  — permission dialog appears
    #   TeammateIdle       — teammate about to idle
    #
    # Hook entry types:
    #   command — { type = "command"; command = "path/to/script.sh"; timeout = 600; }
    #   http    — { type = "http"; url = "https://..."; method = "POST"; headers = {}; }
    #   prompt  — { type = "prompt"; prompt = "Check if..."; model = "haiku"; }
    #   agent   — { type = "agent"; prompt = "Verify tests pass. $ARGUMENTS"; timeout = 120; }
    #
    # Exit codes (command hooks):
    #   0 — proceed (stdout added to context for SessionStart/UserPromptSubmit)
    #   2 — block action (stderr fed back to Claude as feedback)
    #   other — proceed (stderr logged but not shown)
    #
    # Example:
    #   hooks.PreToolUse = [{
    #     matcher = "Bash";
    #     hooks = [{ type = "command"; command = "/path/to/validator.sh"; }];
    #   }];

    hooks = mkOption {
      type = types.attrsOf (types.listOf types.attrs);
      default = {};
      example = {
        PreToolUse = [{
          matcher = "Bash";
          hooks = [{ type = "command"; command = "/path/to/validate.sh"; }];
        }];
        Stop = [{
          hooks = [{ type = "command"; command = "/path/to/on-stop.sh"; }];
        }];
      };
      description = ''
        Lifecycle hooks mapped to Claude Code events. Each event maps to a list
        of rule objects. Each rule has an optional matcher (tool/event name pattern)
        and a hooks list containing hook entries.
        See option description above for complete event list and hook types.
      '';
    };

    # ── Keybindings ────────────────────────────────────────────────────
    # Custom keyboard shortcuts deployed to ~/.claude/keybindings.json.
    #
    # Contexts: Global, Chat, Autocomplete, Settings, Confirmation, Tabs,
    #   Help, Transcript, HistorySearch, Task, ThemePicker, Attachments,
    #   Footer, MessageSelector, DiffDialog, ModelPicker, Select, Plugin
    #
    # Common actions:
    #   app:interrupt (Ctrl+C), app:exit (Ctrl+D), app:toggleTodos (Ctrl+T),
    #   app:toggleTranscript (Ctrl+O), chat:submit (Enter), chat:cycleMode (Shift+Tab),
    #   chat:modelPicker (Cmd+P), chat:thinkingToggle (Cmd+T),
    #   chat:externalEditor (Ctrl+G), chat:stash (Ctrl+S),
    #   chat:imagePaste (Ctrl+V), history:search (Ctrl+R), task:background (Ctrl+B)
    #
    # Set action to null to unbind a key. Reserved: Ctrl+C, Ctrl+D (cannot rebind).
    # Keystroke syntax: ctrl/alt/shift/meta + key, chords: "ctrl+k ctrl+s"

    keybindings = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Deploy custom keybindings to ~/.claude/keybindings.json.";
      };

      bindings = mkOption {
        type = types.attrsOf (types.attrsOf (types.nullOr types.str));
        default = {};
        example = {
          Chat = {
            "ctrl+e" = "chat:externalEditor";
            "ctrl+u" = null;
          };
          Global = {
            "ctrl+t" = "app:toggleTodos";
          };
        };
        description = ''
          Keybinding overrides organized by context. Keys are context names
          (Chat, Global, etc.), values are maps of keystroke → action.
          Set action to null to unbind a key.
        '';
      };
    };

    # ── Subagents ──────────────────────────────────────────────────────
    # Custom subagent definitions deployed to ~/.claude/agents/.
    # Each agent is a .md file with YAML frontmatter defining its behavior.
    #
    # Frontmatter fields:
    #   name          — unique identifier (required)
    #   description   — when to delegate (required)
    #   tools         — allowlist of tools
    #   disallowedTools — denylist of tools
    #   model         — sonnet/opus/haiku/inherit (default: inherit)
    #   permissionMode — default/acceptEdits/dontAsk/bypassPermissions/plan
    #   maxTurns      — max agentic turns
    #   skills        — skills to preload
    #   mcpServers    — MCP servers for this agent
    #   hooks         — lifecycle hooks
    #   memory        — user/project/local
    #   background    — true to always run in background
    #   isolation     — "worktree" for isolated git worktree
    #
    # Built-in agents: Explore (read-only search), Plan (research),
    #   general-purpose (full tools), Bash (terminal), statusline-setup,
    #   Claude Code Guide (help queries)

    agents = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy custom subagent definitions to ~/.claude/agents/.";
      };

      definitions = mkOption {
        type = types.attrsOf types.path;
        default = {};
        example = literalExpression ''
          {
            test-runner = ./agents/test-runner.md;
            code-reviewer = ./agents/code-reviewer.md;
          }
        '';
        description = ''
          Custom subagent definitions. Keys are agent names (without .md extension),
          values are paths to markdown files with YAML frontmatter.
          Deployed to ~/.claude/agents/{name}.md.
        '';
      };
    };

    # ── Output styles ──────────────────────────────────────────────────
    # Custom output style definitions deployed to ~/.claude/output-styles/.
    # Each style is a .md file with optional YAML frontmatter.
    #
    # Frontmatter fields:
    #   name                   — display name
    #   description            — brief description
    #   keep-coding-instructions — false to replace default coding behavior (default: true)

    outputStyles = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy custom output styles to ~/.claude/output-styles/.";
      };

      definitions = mkOption {
        type = types.attrsOf types.path;
        default = {};
        example = literalExpression ''
          { concise = ./output-styles/concise.md; }
        '';
        description = ''
          Custom output style definitions. Keys are style names (without .md extension),
          values are paths to markdown files. Select with settings.outputStyle or /output-style.
          Deployed to ~/.claude/output-styles/{name}.md.
        '';
      };
    };

    # ── Rules ──────────────────────────────────────────────────────────
    # User-level instruction rules deployed to ~/.claude/rules/.
    # Each rule is a .md file, optionally with YAML frontmatter for path scoping.
    #
    # Rules without paths frontmatter are loaded unconditionally at session start.
    # Rules with paths are lazy-loaded when matching files are opened.
    #
    # Frontmatter example:
    #   ---
    #   paths:
    #     - "src/api/**/*.ts"
    #     - "**/*.{ts,tsx}"
    #   ---
    #
    # @path/to/file syntax imports and expands referenced files (max 5 hops).

    rules = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy instruction rules to ~/.claude/rules/.";
      };

      definitions = mkOption {
        type = types.attrsOf types.path;
        default = {};
        example = literalExpression ''
          {
            security = ./rules/security.md;
            api-conventions = ./rules/api-conventions.md;
          }
        '';
        description = ''
          Instruction rule files. Keys are rule names (without .md extension),
          values are paths to markdown files. Deployed to ~/.claude/rules/{name}.md.
          Rules without paths frontmatter are unconditional; with paths they're path-scoped.
        '';
      };
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
