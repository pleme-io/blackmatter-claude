{ zai-coding-plugins }:
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
  credential = pkgs.blueApp {
    name = "claude-provider-credential";
    program = ./provider-credential.b;
  };
  mkWrapper = import ./provider-wrapper.nix { inherit pkgs lib credential; };
  zaiPlugins = import ./zai-coding-plugins.nix {
    inherit pkgs lib credential;
    src = zai-coding-plugins;
    inherit (cfg.providers.glm) keyFile;
  };
  enabled = lib.filterAttrs (_: p: p.enable) cfg.providers;
  model = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "The model ID sent to the provider.";
      };
      name = mkOption {
        type = types.str;
        description = "The model's name in the picker.";
      };
    };
  };
  stdioServer = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this binary loads the server.";
      };
      command = mkOption {
        type = types.str;
        description = "The server's executable.";
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Arguments after the command.";
      };
      keyEnv = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The variable the server reads the provider's key from. It is set from keyFile when the server starts, and never written to the store or the MCP config. null starts the server without the key.";
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Further environment for the server; never the key.";
      };
    };
  };
  plugin = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this binary loads the plugin.";
      };
      path = mkOption {
        type = types.path;
        description = "The plugin's directory, loaded with --plugin-dir.";
      };
    };
  };
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
      models = lib.genAttrs [ "opus" "sonnet" "haiku" "fable" ] (
        tier:
        mkOption {
          type = model;
          description = "The model Claude Code's ${tier} tier maps to. The opus tier is also the session default, the haiku tier also runs background work, and every tier is mapped so no Anthropic ID reaches this endpoint.";
        }
      );
      mcpServers = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "The provider's own HTTP MCP servers, name to URL. Each authenticates with the provider's key as a bearer token, read from keyFile at connect time, and loads only in this binary.";
      };
      stdioMcpServers = mkOption {
        type = types.attrsOf stdioServer;
        default = { };
        description = "The provider's local stdio MCP servers. They load only in this binary.";
      };
      plugins = mkOption {
        type = types.attrsOf plugin;
        default = { };
        description = "Claude Code plugins that load only in this binary, each through --plugin-dir; nothing is written to ~/.claude.";
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
      blackmatter.components.claude.providers.glm =
        let
          glm53 = {
            id = "glm-5.3[1m]";
            name = "GLM-5.3";
          };
          flash = {
            id = "glm-5.3-flash[1m]";
            name = "GLM-5.3-Flash";
          };
        in
        {
          baseUrl = mkDefault "https://api.z.ai/api/anthropic";
          models = lib.mapAttrs (_: mkDefault) {
            opus = glm53;
            sonnet = glm53;
            fable = glm53;
            haiku = flash;
          };
          mcpServers = lib.mapAttrs (_: mkDefault) {
            web-search-prime = "https://api.z.ai/api/mcp/web_search_prime/mcp";
            web-reader = "https://api.z.ai/api/mcp/web_reader/mcp";
            zread = "https://api.z.ai/api/mcp/zread/mcp";
          };
          stdioMcpServers.zai-mcp-server = {
            enable = mkDefault true;
            command = mkDefault (lib.getExe (pkgs.callPackage ./zai-mcp-server { }));
            keyEnv = mkDefault "Z_AI_API_KEY";
            env = lib.mapAttrs (_: mkDefault) {
              Z_AI_MODE = "ZAI";
            };
          };
          plugins = lib.mapAttrs (_: path: {
            enable = mkDefault true;
            path = mkDefault path;
          }) zaiPlugins;
          env = lib.mapAttrs (_: mkDefault) {
            API_TIMEOUT_MS = "3000000";
            CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000";
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
            CLAUDE_CODE_MAX_OUTPUT_TOKENS = "128000";
            CLAUDE_CODE_MAX_RETRIES = "4";
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
