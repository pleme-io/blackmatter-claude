{ pkgs, lib }:
{
  claude,
  name,
  provider,
}:
let
  tierEnv =
    suffix: values:
    lib.mapAttrs' (
      tier: value: lib.nameValuePair "ANTHROPIC_DEFAULT_${lib.toUpper tier}_MODEL${suffix}" value
    ) values;
  env = {
    ANTHROPIC_BASE_URL = provider.baseUrl;
    ANTHROPIC_MODEL = provider.models.opus;
  }
  // tierEnv "" provider.models
  // tierEnv "_NAME" provider.modelNames
  // provider.env;
  shadowed = [
    "ANTHROPIC_API_KEY"
    "ANTHROPIC_AUTH_TOKEN"
    "CLAUDE_CODE_USE_BEDROCK"
    "CLAUDE_CODE_USE_VERTEX"
  ];
  key = lib.escapeShellArg provider.keyFile;
  settings = pkgs.writeText "claude-${name}-settings.json" (
    builtins.toJSON {
      apiKeyHelper = "${pkgs.coreutils}/bin/cat ${key}";
      disableClaudeAiConnectors = true;
      modelOverrides = {
        claude-opus-5-5 = provider.models.opus;
        claude-sonnet-5-5 = provider.models.sonnet;
        claude-haiku-5-5 = provider.models.haiku;
      };
    }
  );
  mcpConfig = pkgs.writeText "claude-${name}-mcp.json" (
    builtins.toJSON {
      mcpServers = lib.mapAttrs (_: url: {
        type = "http";
        inherit url;
        headersHelper = "${pkgs.jq}/bin/jq -cn --rawfile k ${key} '{Authorization: (\"Bearer \" + ($k | rtrimstr(\"\\n\")))}'";
      }) provider.mcpServers;
    }
  );
  command = if provider.command != null then provider.command else "claude-${name}";
in
pkgs.runCommand command
  {
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    passthru = { inherit env settings mcpConfig command; };
    meta.mainProgram = command;
  }
  ''
    makeBinaryWrapper ${claude}/bin/claude $out/bin/${command} \
      ${lib.concatMapStringsSep " " (v: "--unset ${v}") shadowed} \
      ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") env)} \
      --add-flags "--settings ${settings}" \
      ${lib.optionalString (provider.mcpServers != { }) ''--add-flags "--mcp-config=${mcpConfig}"''}
  ''
