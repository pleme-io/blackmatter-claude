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
      type = types.nullOr (types.enum ["low" "medium" "high" "xhigh" "max"]);
      default = null;
      example = "max";
      description = ''
        Reasoning effort level. Valid values: low, medium, high, xhigh, max.
        Fleet doctrine flows from `anvil.doctrine.intelligenceOverSpeed`
        via `anvil.translatedSettings.claude` (applied as `mkDefault`), so
        leaving this null in the fleet still resolves to "max" — anvil is
        the source of truth. Explicit values here override anvil. Null with
        no anvil overlay defers to claude-code's auto-detection.
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
      description = "Output style name. Built-in: Default, Explanatory, Learning.";
    };

    apiKeyHelper = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Script path that outputs an auth token on stdout.";
    };

    cleanupPeriodDays = mkOption {
      type = types.int;
      default = 90;
      description = ''
        Days before old session transcripts are deleted. `0` disables cleanup.

        Raised from Claude Code's built-in 30 to 90. Transcripts are the only
        record of how a decision was actually reached — they back `/usage`
        attribution and the archaeology this operator routinely does across
        past sessions — and the deletion is irrecoverable. A 30-day window
        silently discards a full quarter of that.

        Not measured against disk: if `~/.claude/projects/` turns out large,
        dial this down deliberately rather than letting it default.
      '';
    };

    autoMemoryEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable auto memory (MEMORY.md persistence across sessions).";
    };

    alwaysThinkingEnabled = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable extended thinking (chain-of-thought) by default. Fleet
        doctrine flows from `anvil.doctrine.intelligenceOverSpeed` via
        `anvil.translatedSettings.claude` (applied as `mkDefault`), so the
        fleet resolves this to `true` even when null here. Explicit values
        override anvil. Null with no anvil overlay defers to claude-code's
        auto-detection.
      '';
    };

    includeGitInstructions = mkOption {
      type = types.bool;
      default = true;
      description = "Include git workflow instructions in system prompt.";
    };

    fastModePerSessionOptIn = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Require per-session opt-in for fast mode (/fast). Fleet doctrine
        flows from `anvil.doctrine.intelligenceOverSpeed` via
        `anvil.translatedSettings.claude` (applied as `mkDefault`), so the
        fleet resolves this to `true` — fast mode must be explicitly
        chosen each session via /fast, never auto-enabled. Explicit values
        override anvil. Null with no anvil overlay falls back to
        claude-code's own default (false).
      '';
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
      default = false;
      description = ''
        Show rotating tips in the loading spinner.

        Defaulted OFF for this fleet. With `effortLevel = max` and
        always-thinking on, the spinner is the line the operator's eye is
        parked on for minutes at a stretch, and generic onboarding copy
        churning in that spot is motion without information. The duration and
        token counters beside it already carry the signal.

        Pure preference — flip it back per-profile if you miss them.
      '';
    };

    respectGitignore = mkOption {
      type = types.bool;
      default = true;
      description = "Respect .gitignore patterns in file picker.";
    };

    includeCoAuthoredBy = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether Claude Code appends a `Co-Authored-By: Claude` trailer to
        commits and PR bodies.

        Defaults to `false`, and that default is load-bearing rather than
        cosmetic: the STEALTH directive requires that every
        client-associated artifact be authored AS THE OPERATOR and never
        reveal AI involvement. An AI trailer on a commit is exactly the
        disclosure that rule forbids, and it is applied at commit time —
        after review, where nobody looks.

        Until now the live `~/.claude/settings.json` carried `false` as an
        unmanaged hand-edit with no option backing it, so the guarantee
        survived only as long as nobody re-ran the installer or set up a new
        node. Declaring it here makes it store-derived and reproducible.

        Tier-honest: this is only-mitigated, not unrepresentable — Claude
        Code can still rewrite settings.json at runtime, and Nix reconverges
        on rebuild rather than pinning the value continuously.
      '';
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
      default = [
        # The five always-on pleme-io MCPs are default-enabled below in
        # the `mcp` and `mcpPackages` blocks. Auto-approving their tool
        # invocations matches the fleet-wide expectation that these
        # are background substrate tools an agent uses without
        # operator-per-call confirmation. Other MCPs (atlassian, kurage,
        # mado, …) deliberately remain on the ask path because their
        # actions are external + visible.
        #
        # If you need to deviate per-host, append to `permissions.allow`
        # rather than overriding (lists merge), or move a pattern into
        # `permissions.ask` to explicitly require confirmation.
        "mcp__zoekt__search"
        "mcp__zoekt__list_repos"
        "mcp__codesearch__semantic_search"
        "mcp__codesearch__find_references"
        "mcp__codesearch__get_file_chunks"
        "mcp__codesearch__find_databases"
        "mcp__codesearch__index_status"
        "mcp__github__*"
        "mcp__kubernetes__*"
        "mcp__fluxcd__*"
        # engenho-mcp is read-only by construction (P0 ships 4 reader
        # tools sourced from kikai's on-disk state). All responses
        # are secret-material-free by type. Writer layer (P2) will
        # introduce a separate `mcp__engenho_writer__*` prefix that
        # stays on the ask path with saguão passport gating.
        "mcp__engenho__*"
      ];
      description = ''
        Tool patterns to auto-approve without prompting.

        Default approves the five always-on pleme-io MCPs (zoekt,
        codesearch, github, kubernetes, fluxcd) — they are background
        substrate tools used continuously by agents and prompting on
        every call breaks flow. Other MCPs stay on the ask path.
      '';
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
  # CLAUDE.md — the core-level steering file
  # ══════════════════════════════════════════════════════════════════════
  #
  # `~/.claude/CLAUDE.md` loads in EVERY session across EVERY org, and until
  # this option existed it was the one steering surface outside the
  # blackmatter+rebuild loop: a hand-maintained regular file, in no git repo,
  # rendered by nothing. No history, no review, no redistribution — one disk
  # loss from gone. Every sibling surface (skills, agents, rules, settings,
  # MCP) is declared here; this closes the gap.
  #
  # ★ IT IS AN OUT-OF-STORE SYMLINK, ON PURPOSE, AND `source` IS A STRING.
  #
  # The obvious wiring — `home.file.".claude/CLAUDE.md".source = ./CLAUDE.md`
  # — copies the file into the nix store and links it read-only. That is
  # correct for `rules` and `agents`, which change rarely and are authored as
  # a unit. It is wrong here: the operator edits this file mid-session, and
  # making each edit a push → flake bump → rebuild loop would push it back out
  # of maintenance by making maintenance expensive. The observed failure mode
  # is not "someone edited the store copy", it is "the file stopped being
  # anywhere at all".
  #
  # So the type is `str`, never `types.path`. A `types.path` — or a bare
  # unquoted `./CLAUDE.md` — is COPIED INTO THE STORE at evaluation, and the
  # deployed link then points at an immutable snapshot: edits still appear to
  # work (the file is writable in the checkout) while the session keeps
  # reading the frozen copy. Green, silent, and wrong. A string stays a plain
  # filesystem path, so `mkOutOfStoreSymlink` links the live checkout and an
  # edit is visible to the next session with no rebuild.
  claudeMd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Link ~/.claude/CLAUDE.md to a live git checkout via an out-of-store
        symlink, so the core steering file is version-controlled without
        making an edit cost a rebuild.

        Default false: the file is operator-personal, so a consumer opts in
        and supplies its own `source`.
      '';
    };

    source = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/Users/alice/code/github/pleme-io/nix/claude/CLAUDE.md";
      description = ''
        ABSOLUTE path to the CLAUDE.md inside a live checkout.

        Deliberately a string, not a path: a `types.path` is copied into the
        nix store, which freezes the content and silently breaks live editing
        (see the note above this option). An `assertion` rejects a relative
        value, which would otherwise render a dangling link.
      '';
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

    shinryuMcp.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable shinryu-mcp — Shinryū analytical query plane for cross-signal SQL over Parquet (reads from services.shinryu.mcp.serverEntry).";
    };

    madoMcp = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Register mado's MCP server (reads from
          `blackmatter.components.mado.mcp.serverEntry`) so Claude Code can fully
          control mado — sessions, panes, output, attention, vigy + the safra
          board. Requires the blackmatter-mado module on the same node. See
          CLAUDE-FOR-MADO.md.
        '';
      };
      autoAllow = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Lift mado's READ-ONLY MCP tools (status / list_sessions / get_output /
          snapshot_grid / recent_dirs_list / frame_perf / version) onto the
          permission allow-list so Claude can observe mado without a prompt. The
          MUTATING tools (spawn_term / send_keys / switch_session /
          tear_new_session / config_set / attention_set / simulate_chord) stay on
          the ask path regardless. Default false (every mado tool on ask).
        '';
      };
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
      sql     = mkOption { type = types.bool; default = true; description = "Deploy SQL guardrail suite (all engines + migration tools)."; };
      aws-generated = mkOption { type = types.bool; default = true; description = "Deploy auto-generated AWS guardrail suite (2,250 rules from 298 services)."; };
      akeyless-generated = mkOption { type = types.bool; default = true; description = "Deploy auto-generated Akeyless guardrail suite from OpenAPI spec."; };
      pleme-doctrine = mkOption { type = types.bool; default = true; description = "Deploy the pleme-io doctrine suite: org-CLAUDE.md absolutes expressible as a Bash pattern (in-place stream edits of structured files, hand-run tofu/terraform apply, docker build instead of Nix dockerTools). Two rules BLOCK (`sed-inplace-structured-file` and its chained variant — an in-place stream edit of a .nix/.yaml/.toml/.rs/.json file); the other three warn. Shadow-first applies to the warn tier only; the structured-file rules are already enforcing."; };
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
