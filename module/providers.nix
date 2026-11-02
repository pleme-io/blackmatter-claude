{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkDefault
    mkIf
    types
    ;
  cfg = config.blackmatter.components.claude;
  mkWrapper = import ./provider-wrapper.nix { inherit pkgs lib; };
  enabled = lib.filterAttrs (_: p: p.enable) cfg.providers;
  provider = types.submodule {
    options = {
      enable = mkEnableOption "a claude-<name> binary that runs Claude Code against this provider's Anthropic-compatible endpoint";
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Binary name. null renders claude-<name>.";
      };
      baseUrl = mkOption {
        type = types.str;
        description = "The provider's Anthropic Messages endpoint, set as ANTHROPIC_BASE_URL.";
      };
      keyFile = mkOption {
        type = types.str;
        description = "Absolute path of the file holding the provider's API key; read at each request through apiKeyHelper, never copied into the store.";
      };
      models = {
        opus = mkOption {
          type = types.str;
          description = "Model Claude Code's opus tier maps to; also the session default (ANTHROPIC_MODEL).";
        };
        sonnet = mkOption {
          type = types.str;
          description = "Model Claude Code's sonnet tier maps to.";
        };
        haiku = mkOption {
          type = types.str;
          description = "Model Claude Code's haiku tier maps to: subagents and background work.";
        };
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Further environment the provider documents for Claude Code.";
      };
    };
  };
in
{
  options.blackmatter.components.claude.providers = mkOption {
    type = types.attrsOf provider;
    default = { };
    description = ''
      Claude Code on another vendor's Anthropic-compatible endpoint, one binary
      per enabled entry. Every hook, MCP server, skill and setting of the main
      install applies; only the endpoint, the key and the model map change.
      An inherited ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN is unset, so an
      Anthropic key never reaches the other vendor.
    '';
  };

  config = lib.mkMerge [
    {
      blackmatter.components.claude.providers.glm = {
        baseUrl = mkDefault "https://api.z.ai/api/anthropic";
        models = {
          opus = mkDefault "glm-5.3[1m]";
          sonnet = mkDefault "glm-5.3[1m]";
          haiku = mkDefault "glm-5.3[1m]";
        };
        env = {
          API_TIMEOUT_MS = mkDefault "3000000";
          CLAUDE_CODE_AUTO_COMPACT_WINDOW = mkDefault "1000000";
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = mkDefault "1";
        };
      };
    }
    (mkIf cfg.enable {
      home.packages = lib.mapAttrsToList (
        name: p:
        mkWrapper {
          inherit name;
          provider = p;
          claude = cfg.package;
        }
      ) enabled;
    })
  ];
}
