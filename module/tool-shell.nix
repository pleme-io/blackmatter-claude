# The shell Claude Code runs its Bash tool through.
#
# Claude Code accepts a tool shell only if its PATH contains "bash" or "zsh"
# (the CLAUDE_CODE_SHELL override included; read from claude-code 2.1.278).
# So a frost-family login shell can never be the tool shell: Claude falls
# back to the first zsh on PATH, and the operator's shell options do not
# reach it.
#
# wordSplit gives that zsh `shwordsplit` via a compiled wrapper named `zsh`
# (the name is load-bearing for that path check), so an unquoted `$var`
# field-splits as it does in sh, bash and the fleet's frostmourne.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.blackmatter.components.claude.toolShell;
  wrapped = pkgs.runCommand "claude-tool-zsh" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
    makeWrapper ${cfg.zsh}/bin/zsh $out/bin/zsh --add-flags "-o shwordsplit"
  '';
in
{
  options.blackmatter.components.claude.toolShell = {
    wordSplit = lib.mkEnableOption "shwordsplit in the zsh Claude Code runs its Bash tool through";
    zsh = lib.mkOption {
      type = lib.types.package;
      default = pkgs.zsh;
      defaultText = lib.literalExpression "pkgs.zsh";
      description = "The zsh the tool-shell wrapper runs.";
    };
  };

  config = lib.mkIf cfg.wordSplit {
    blackmatter.components.claude.settings.env.CLAUDE_CODE_SHELL = "${wrapped}/bin/zsh";
  };
}
