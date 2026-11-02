{ pkgs, lib }:
{
  claude,
  name,
  provider,
}:
let
  env = {
    ANTHROPIC_BASE_URL = provider.baseUrl;
    ANTHROPIC_MODEL = provider.models.opus;
    ANTHROPIC_DEFAULT_OPUS_MODEL = provider.models.opus;
    ANTHROPIC_DEFAULT_SONNET_MODEL = provider.models.sonnet;
    ANTHROPIC_DEFAULT_HAIKU_MODEL = provider.models.haiku;
  }
  // provider.env;
  shadowed = [
    "ANTHROPIC_API_KEY"
    "ANTHROPIC_AUTH_TOKEN"
    "CLAUDE_CODE_USE_BEDROCK"
    "CLAUDE_CODE_USE_VERTEX"
  ];
  settings = pkgs.writeText "claude-${name}-settings.json" (
    builtins.toJSON {
      apiKeyHelper = "${pkgs.coreutils}/bin/cat ${lib.escapeShellArg provider.keyFile}";
    }
  );
  command = if provider.command != null then provider.command else "claude-${name}";
in
pkgs.runCommand command
  {
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    passthru = { inherit env settings command; };
    meta.mainProgram = command;
  }
  ''
    makeBinaryWrapper ${claude}/bin/claude $out/bin/${command} \
      ${lib.concatMapStringsSep " " (v: "--unset ${v}") shadowed} \
      ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") env)} \
      --add-flags "--settings ${settings}"
  ''
