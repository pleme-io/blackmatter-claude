# Claude Desktop — Home Manager arm.
#
# Everything the app READS as configuration is a derivation: the package
# (./package.nix, pinned in ./pin.json) and claude_desktop_config.json (a
# read-only store symlink). Settings changed in the app's UI therefore do not
# survive the next activation; declare them here.
#
# What stays mutable, by necessity: login tokens (config.json's oauth cache),
# cookies, caches and session state the app writes at runtime. Tokens cannot
# live in the world-readable store.
#
# The system-side half (managed policy, e.g. disableAutoUpdates) is
# ./darwin.nix; it enables itself when any Home Manager user enables this.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.blackmatter.components.claude.desktop;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.blackmatter.components.claude.desktop = {
    enable = mkEnableOption "Claude Desktop (macOS) from Nix, with a store-rendered config";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "Claude Desktop package, pinned in module/desktop/pin.json.";
    };

    mcpServers = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Claude Desktop MCP servers. `{ }` means none.";
    };

    preferences = mkOption {
      type = types.attrs;
      default = { };
      description = "The config's `preferences` object, verbatim.";
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Other top-level config keys (e.g. coworkUserFilesPath).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isDarwin;
        message = "blackmatter.components.claude.desktop: Claude Desktop is packaged for macOS only.";
      }
    ];

    home.packages = [ cfg.package ];

    home.file."Library/Application Support/Claude/claude_desktop_config.json" = {
      # The app rewrites this file at runtime; force re-links over its copy.
      force = true;
      text = builtins.toJSON (
        cfg.settings
        // {
          inherit (cfg) mcpServers preferences;
        }
      );
    };
  };
}
