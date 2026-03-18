# Claude Code typed options — comprehensive schema for all configuration
#
# Every option maps to a Claude Code config key. Types enforced by Nix module system.
# Extracted from default.nix for clarity and maintainability.
#
# Sources: https://docs.anthropic.com/en/docs/claude-code/settings
{ lib, ... }:
with lib;
let
  # ── Hook Entry Submodule ────────────────────────────────────────────
  # Typed hook entry with freeformType for forward compatibility.
  hookEntryOpts = { ... }: {
    freeformType = types.attrs;
    options = {
      type = mkOption {
        type = types.enum [ "command" "http" "prompt" "agent" ];
        description = "Hook handler type: command (shell), http (webhook), prompt (LLM), agent (sub-agent).";
      };

      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Shell command to execute (command type).";
      };
    };
  };

  # ── Hook Rule Submodule ─────────────────────────────────────────────
  # A rule matches events/tools and dispatches to hook entries.
  hookRuleOpts = { ... }: {
    freeformType = types.attrs;
    options = {
      matcher = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Tool or event name pattern to match. Null = match all.";
      };

      hooks = mkOption {
        type = types.listOf (types.submodule hookEntryOpts);
        default = [];
        description = "Hook entries to run when matcher matches.";
      };
    };
  };

in {
  # ══════════════════════════════════════════════════════════════════════
  # CORE SETTINGS → ~/.claude/settings.json
  # ══════════════════════════════════════════════════════════════════════

  settings = {
    model = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "opus";
      description = ''
        Default model for Claude Code sessions. Accepts aliases (opus, sonnet, haiku)
        or full model names (claude-opus-4-6). Leave null for auto-detection.
      '';
    };

    effortLevel = mkOption {
      type = types.nullOr (types.enum ["low" "medium" "high"]);
      default = null;
      example = "high";
      description = "Reasoning effort level. Leave null for auto-detection.";
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
      description = "Output style name. Built-in: Default, Explanatory, Learning.";
    };

    apiKeyHelper = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Script path that outputs an auth token on stdout.";
    };

    cleanupPeriodDays = mkOption {
      type = types.int;
      default = 30;
      description = "Days before old sessions are deleted. 0 = disable.";
    };

    autoMemoryEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable auto memory (MEMORY.md persistence across sessions).";
    };

    alwaysThinkingEnabled = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Enable extended thinking (chain-of-thought) by default.";
    };

    includeGitInstructions = mkOption {
      type = types.bool;
      default = true;
      description = "Include git workflow instructions in system prompt.";
    };

    fastModePerSessionOptIn = mkOption {
      type = types.bool;
      default = false;
      description = "Require per-session opt-in for fast mode (/fast).";
    };

    autoUpdatesChannel = mkOption {
      type = types.nullOr (types.enum ["stable" "latest"]);
      default = null;
      description = "Auto-update channel. Irrelevant with Nix-managed package.";
    };

    plansDirectory = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom directory for plan file storage.";
    };

    claudeMdExcludes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Glob patterns to exclude CLAUDE.md files from being loaded.";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Environment variables set for all Claude Code sessions.";
    };

    companyAnnouncements = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Announcements shown in random rotation during sessions.";
    };

    availableModels = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Restrict which models users can select. Empty = all.";
    };

    # ── UI settings ──

    showTurnDuration = mkOption {
      type = types.bool;
      default = true;
      description = "Show duration of each turn in conversation.";
    };

    terminalProgressBarEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Show progress bar during long operations.";
    };

    prefersReducedMotion = mkOption {
      type = types.bool;
      default = false;
      description = "Reduce UI animations for accessibility.";
    };

    spinnerTipsEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Show tips in the loading spinner.";
    };

    respectGitignore = mkOption {
      type = types.bool;
      default = true;
      description = "Respect .gitignore patterns in file picker.";
    };

    skipDangerousModePermissionPrompt = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Skip confirmation when entering bypass-permissions mode.";
    };

    disableAllHooks = mkOption {
      type = types.bool;
      default = false;
      description = "Disable all hooks and the status line command.";
    };

    enableAllProjectMcpServers = mkOption {
      type = types.bool;
      default = false;
      description = "Auto-approve all project-level MCP servers from .mcp.json.";
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
      type = types.enum ["auto" "in-process" "tmux"];
      default = "auto";
      description = "Agent teams execution mode: auto, in-process, or tmux.";
    };

    # ── Auth settings ──

    forceLoginMethod = mkOption {
      type = types.nullOr (types.enum ["claudeai" "console"]);
      default = null;
      description = "Force a specific login method.";
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
      description = "Arbitrary additional keys merged into ~/.claude/settings.json.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # PERMISSIONS
  # ══════════════════════════════════════════════════════════════════════

  permissions = {
    defaultMode = mkOption {
      type = types.nullOr (types.enum [
        "default" "acceptEdits" "plan" "dontAsk" "bypassPermissions"
      ]);
      default = null;
      description = "Default permission mode for new sessions.";
    };

    allow = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Tool patterns to auto-approve without prompting.";
    };

    deny = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Tool patterns to block entirely (checked first, highest priority).";
    };

    ask = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Tool patterns that always require user confirmation.";
    };

    additionalDirectories = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra directories Claude can access beyond project root.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # ATTRIBUTION
  # ══════════════════════════════════════════════════════════════════════

  attribution = {
    commit = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Text appended to git commit messages.";
    };

    pr = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Text appended to pull request descriptions.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # SANDBOX
  # ══════════════════════════════════════════════════════════════════════

  sandbox = {
    enabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable command sandboxing.";
    };

    autoAllowBashIfSandboxed = mkOption {
      type = types.bool;
      default = true;
      description = "Auto-approve all bash commands when sandbox is enabled.";
    };

    excludedCommands = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Commands that run outside the sandbox.";
    };

    allowUnsandboxedCommands = mkOption {
      type = types.bool;
      default = true;
      description = "Allow dangerouslyDisableSandbox escape hatch.";
    };

    enableWeakerNestedSandbox = mkOption {
      type = types.bool;
      default = false;
      description = "Use weaker sandbox inside Docker/containers.";
    };

    enableWeakerNetworkIsolation = mkOption {
      type = types.bool;
      default = false;
      description = "Allow TLS trust service access on macOS.";
    };

    filesystem = {
      allowWrite = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Paths where write access is allowed.";
      };

      denyWrite = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Paths where write access is denied.";
      };

      denyRead = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Paths where read access is denied.";
      };
    };

    network = {
      allowUnixSockets = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Unix socket paths that sandboxed commands can access.";
      };

      allowAllUnixSockets = mkOption {
        type = types.bool;
        default = false;
        description = "Allow access to all Unix sockets.";
      };

      allowLocalBinding = mkOption {
        type = types.bool;
        default = false;
        description = "Allow binding to localhost ports.";
      };

      allowedDomains = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Domain allowlist for outbound network traffic.";
      };
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # HOOKS — now with typed submodules
  # ══════════════════════════════════════════════════════════════════════

  hooks = mkOption {
    type = types.attrsOf (types.listOf (types.submodule hookRuleOpts));
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
      of rule objects with an optional matcher and a hooks list.

      Events: PreToolUse, PostToolUse, PostToolUseFailure, UserPromptSubmit,
      Stop, SessionStart, SessionEnd, Notification, SubagentStart, SubagentStop,
      TaskCompleted, InstructionsLoaded, ConfigChange, WorktreeCreate,
      WorktreeRemove, PreCompact, PermissionRequest, TeammateIdle.

      Hook types: command (shell script, exit 0=proceed, 2=block),
      http (webhook), prompt (LLM evaluation), agent (sub-agent task).
    '';
  };

  # ══════════════════════════════════════════════════════════════════════
  # KEYBINDINGS
  # ══════════════════════════════════════════════════════════════════════

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
        Chat = { "ctrl+e" = "chat:externalEditor"; };
        Global = { "ctrl+t" = "app:toggleTodos"; };
      };
      description = "Keybinding overrides by context. Set action to null to unbind.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # SUBAGENTS
  # ══════════════════════════════════════════════════════════════════════

  agents = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy custom subagent definitions to ~/.claude/agents/.";
    };

    definitions = mkOption {
      type = types.attrsOf types.path;
      default = {};
      description = "Custom subagent .md files. Keys = names, values = paths.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # OUTPUT STYLES
  # ══════════════════════════════════════════════════════════════════════

  outputStyles = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy custom output styles to ~/.claude/output-styles/.";
    };

    definitions = mkOption {
      type = types.attrsOf types.path;
      default = {};
      description = "Custom output style .md files. Keys = names, values = paths.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # RULES
  # ══════════════════════════════════════════════════════════════════════

  rules = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy instruction rules to ~/.claude/rules/.";
    };

    definitions = mkOption {
      type = types.attrsOf types.path;
      default = {};
      description = "Rule .md files. Keys = names, values = paths.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # LSP
  # ══════════════════════════════════════════════════════════════════════

  lsp = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable LSP server configuration via ~/.claude/lsp.json.";
    };

    nix.enable = mkOption { type = types.bool; default = true; description = "nixd — Nix language server"; };
    rust.enable = mkOption { type = types.bool; default = true; description = "rust-analyzer — Rust language server"; };
    typescript.enable = mkOption { type = types.bool; default = true; description = "typescript-language-server"; };
    python.enable = mkOption { type = types.bool; default = true; description = "basedpyright — Python language server"; };
    go.enable = mkOption { type = types.bool; default = true; description = "gopls — Go language server"; };
    lua.enable = mkOption { type = types.bool; default = true; description = "lua-language-server"; };
    bash.enable = mkOption { type = types.bool; default = true; description = "bash-language-server"; };
    zig.enable = mkOption { type = types.bool; default = true; description = "zls — Zig language server"; };
    ruby.enable = mkOption { type = types.bool; default = true; description = "ruby-lsp — Ruby language server"; };
    cpp.enable = mkOption { type = types.bool; default = true; description = "clangd — C/C++ language server"; };

    extraServers = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional LSP server entries for lsp.json.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # MCP (simplified — servers come from anvil)
  # ══════════════════════════════════════════════════════════════════════

  mcp = {
    zoektMcp.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable zoekt-mcp (reads from services.zoekt.mcp.serverEntry).";
    };

    codesearch.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable codesearch MCP (reads from services.codesearch.mcp.serverEntry).";
    };

    amimori.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable amimori MCP (reads from services.amimori.mcp.serverEntry).";
    };

    kurageMcp.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable kurage MCP — Cursor Cloud Agents bridge (reads from services.kurage.mcp.serverEntry).";
    };

    extraServers = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional MCP servers merged on top of anvil-generated and service-level.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # SKILLS
  # ══════════════════════════════════════════════════════════════════════

  skills = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy bundled skills to ~/.claude/skills/.";
    };

    extraSkills = mkOption {
      type = types.attrsOf types.path;
      default = {};
      description = "Additional skill files. Keys = names, values = SKILL.md paths.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # GUARDRAIL — defensive hooks to block destructive commands
  # ══════════════════════════════════════════════════════════════════════

  guardrail = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable guardrail defensive hooks for Bash tool calls.";
    };

    categories = {
      filesystem  = mkOption { type = types.bool; default = true; description = "Block destructive filesystem commands (rm -rf /, mkfs)."; };
      git         = mkOption { type = types.bool; default = true; description = "Block destructive git commands (force push main, reset --hard)."; };
      database    = mkOption { type = types.bool; default = true; description = "Block destructive SQL (DROP TABLE, TRUNCATE, DELETE without WHERE)."; };
      kubernetes  = mkOption { type = types.bool; default = true; description = "Block destructive K8s commands (delete namespace, delete --all)."; };
      nix         = mkOption { type = types.bool; default = true; description = "Warn on Nix garbage collection."; };
      docker      = mkOption { type = types.bool; default = true; description = "Warn on Docker prune commands."; };
      secrets     = mkOption { type = types.bool; default = true; description = "Warn on secret exposure patterns."; };
      terraform   = mkOption { type = types.bool; default = true; description = "Block destructive Terraform/Pulumi/Ansible commands."; };
      cloud       = mkOption { type = types.bool; default = true; description = "Block destructive cloud CLI commands (AWS, GCP, Azure)."; };
      flux        = mkOption { type = types.bool; default = true; description = "Block destructive FluxCD/GitOps commands."; };
      akeyless    = mkOption { type = types.bool; default = true; description = "Block destructive Akeyless CLI commands."; };
      process     = mkOption { type = types.bool; default = true; description = "Block destructive process/system commands."; };
      network     = mkOption { type = types.bool; default = true; description = "Block destructive network/firewall commands."; };
      nosql       = mkOption { type = types.bool; default = true; description = "Block destructive NoSQL/cache commands."; };
    };

    suites = {
      aws     = mkOption { type = types.bool; default = true; description = "Deploy AWS CLI guardrail suite."; };
      gcp     = mkOption { type = types.bool; default = true; description = "Deploy GCP CLI guardrail suite."; };
      azure   = mkOption { type = types.bool; default = true; description = "Deploy Azure CLI guardrail suite."; };
      akeyless = mkOption { type = types.bool; default = true; description = "Deploy Akeyless CLI guardrail suite."; };
      process = mkOption { type = types.bool; default = true; description = "Deploy process/system guardrail suite."; };
      network = mkOption { type = types.bool; default = true; description = "Deploy network/firewall guardrail suite."; };
      nosql   = mkOption { type = types.bool; default = true; description = "Deploy NoSQL/cache guardrail suite."; };
    };

    extraRules = mkOption {
      type = types.listOf (types.attrsOf types.anything);
      default = [];
      description = "Additional guardrail rules merged with compiled-in defaults.";
    };

    disabledRules = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Names of compiled-in rules to disable.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # THEME
  # ══════════════════════════════════════════════════════════════════════

  theme = {
    statusline.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy Nord frost statusline.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════
  # MCP PACKAGES
  # ══════════════════════════════════════════════════════════════════════

  mcpPackages = {
    enable = mkEnableOption "MCP server packages installed to PATH";

    # Nix ecosystem
    nixos.enable = mkOption { type = types.bool; default = true; description = "mcp-nixos (native Linux, uvx Darwin)"; };

    # Version control
    github.enable = mkOption { type = types.bool; default = true; description = "github-mcp-server"; };
    gitea.enable = mkOption { type = types.bool; default = false; description = "gitea-mcp-server"; };

    # Cloud & Infrastructure
    kubernetes.enable = mkOption { type = types.bool; default = true; description = "mcp-k8s-go"; };
    aks.enable = mkOption { type = types.bool; default = false; description = "aks-mcp-server"; };
    grafana.enable = mkOption { type = types.bool; default = false; description = "mcp-grafana"; };
    terraform.enable = mkOption { type = types.bool; default = false; description = "terraform-mcp-server"; };
    fluxcd.enable = mkOption { type = types.bool; default = true; description = "fluxcd-operator-mcp"; };

    # Browser automation
    playwright.enable = mkOption { type = types.bool; default = false; description = "playwright-mcp"; };

    # Development tools
    languageServer.enable = mkOption { type = types.bool; default = false; description = "mcp-language-server"; };

    # MCP infrastructure
    mcphost.enable = mkOption { type = types.bool; default = false; description = "mcphost"; };
    toolhive.enable = mkOption { type = types.bool; default = false; description = "toolhive"; };
    proxy.enable = mkOption { type = types.bool; default = false; description = "mcp-proxy (Linux only)"; };
    chatmcp.enable = mkOption { type = types.bool; default = false; description = "chatmcp (Linux only)"; };

    # Python ecosystem (Linux only)
    pythonSdk.enable = mkOption { type = types.bool; default = false; description = "python3Packages.mcp (Linux only)"; };
    fastmcp.enable = mkOption { type = types.bool; default = false; description = "python3Packages.fastmcp (Linux only)"; };
    mcpadapt.enable = mkOption { type = types.bool; default = false; description = "python3Packages.mcpadapt (Linux only)"; };
    docling.enable = mkOption { type = types.bool; default = false; description = "python3Packages.docling-mcp (Linux only)"; };
    fastapiMcp.enable = mkOption { type = types.bool; default = false; description = "python3Packages.fastapi-mcp (Linux only)"; };
    djangoMcp.enable = mkOption { type = types.bool; default = false; description = "python3Packages.django-mcp-server (Linux only)"; };

    # Haskell ecosystem (disabled by default — often broken)
    haskellMcp.enable = mkOption { type = types.bool; default = false; description = "haskellPackages.mcp (often broken)"; };
    haskellMcpServer.enable = mkOption { type = types.bool; default = false; description = "haskellPackages.mcp-server (often broken)"; };
    ptyMcpServer.enable = mkOption { type = types.bool; default = false; description = "haskellPackages.pty-mcp-server (often broken)"; };
  };
}
