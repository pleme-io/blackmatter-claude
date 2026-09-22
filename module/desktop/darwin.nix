# Claude Desktop — nix-darwin arm: the managed-policy tier.
#
# Claude Desktop reads organisation policy on macOS from
# /Library/Managed Preferences/com.anthropic.claudefordesktop.plist, parsing
# the file with plutil (read from the app bundle, 2.2553.1). This arm renders
# that plist in the store and links it into place, so policy is a derivation
# like the rest of the app.
#
# The default policy disables the app's self-updater: the app lives in the
# read-only store, so the ONLY upgrade path is a new pin in ./pin.json.
#
# Enabled by default whenever any Home Manager user enables
# blackmatter.components.claude.desktop — one declaration drives both arms.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.blackmatter.components.claude.desktop;
  domain = "com.anthropic.claudefordesktop";
  target = "/Library/Managed Preferences/${domain}.plist";
  plist = pkgs.writeText "${domain}.plist" (lib.generators.toPlist { escape = true; } cfg.policy);
  anyUserEnabled = lib.any (u: u.blackmatter.components.claude.desktop.enable or false) (
    lib.attrValues (config.home-manager.users or { })
  );
in
{
  options.blackmatter.components.claude.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = anyUserEnabled;
      defaultText = lib.literalExpression "any Home Manager user enables blackmatter.components.claude.desktop";
      description = "Render Claude Desktop's managed policy into /Library/Managed Preferences.";
    };

    policy = lib.mkOption {
      type = lib.types.attrs;
      default = {
        disableAutoUpdates = true;
      };
      description = ''
        Managed policy keys, rendered to ${target}. Keys are Anthropic's
        (e.g. disableAutoUpdates); managed values override the app's own.
      '';
    };
  };

  config.system.activationScripts.postActivation.text = lib.mkAfter (
    if cfg.enable then
      ''
        mkdir -p "/Library/Managed Preferences"
        ln -sfn ${plist} "${target}"
      ''
    else
      # Retire cleanly: remove the link only if Nix put it there.
      ''
        if [ -L "${target}" ] && readlink "${target}" | grep -q '^/nix/store/'; then
          rm -f "${target}"
        fi
      ''
  );
}
