{
  pkgs,
  lib,
  src,
  credential,
  keyFile,
}:
let
  token = "(await import('node:child_process')).execFileSync(${builtins.toJSON "${credential}/bin/claude-provider-credential"}, ['key', ${builtins.toJSON keyFile}], { encoding: 'utf8' })";
  plugin =
    name: script:
    pkgs.runCommand "zai-${name}" { } ''
      cp -r ${src}/plugins/${name} $out
      chmod -R u+w $out
      substituteInPlace $out/${script} \
        --replace-fail "process.env.ANTHROPIC_AUTH_TOKEN || '''" ${lib.escapeShellArg "process.env.ANTHROPIC_AUTH_TOKEN || ${token}"}
    '';
in
{
  glm-plan-usage = plugin "glm-plan-usage" "skills/usage-query-skill/scripts/query-usage.mjs";
  glm-plan-bug = plugin "glm-plan-bug" "skills/case-feedback-skill/scripts/submit-feedback.mjs";
}
