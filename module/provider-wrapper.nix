{
  pkgs,
  lib,
  credential,
}:
{
  claude,
  name,
  provider,
}:
let
  credentialBin = "${credential}/bin/claude-provider-credential";
  helper = mode: "${credentialBin} ${mode} ${lib.escapeShellArg provider.keyFile}";
  inherit (provider) models;
  env = {
    ANTHROPIC_BASE_URL = provider.baseUrl;
    ANTHROPIC_MODEL = models.opus.id;
  }
  // lib.concatMapAttrs (tier: model: {
    "ANTHROPIC_DEFAULT_${lib.toUpper tier}_MODEL" = model.id;
    "ANTHROPIC_DEFAULT_${lib.toUpper tier}_MODEL_NAME" = model.name;
  }) models
  // provider.env;
  shadowed = [
    "ANTHROPIC_API_KEY"
    "ANTHROPIC_AUTH_TOKEN"
    "CLAUDE_CODE_USE_BEDROCK"
    "CLAUDE_CODE_USE_VERTEX"
  ];
  settings = {
    apiKeyHelper = helper "key";
    disableClaudeAiConnectors = true;
    modelOverrides = {
      claude-opus-5-5 = models.opus.id;
      claude-sonnet-5-5 = models.sonnet.id;
      claude-haiku-5-5 = models.haiku.id;
    };
  };
  httpServers = lib.mapAttrs (_: url: {
    type = "http";
    inherit url;
    headersHelper = helper "bearer";
  }) provider.mcpServers;
  stdioServers = lib.mapAttrs (
    _: s:
    {
      type = "stdio";
      inherit (s) env;
    }
    // (
      if s.keyEnv == null then
        { inherit (s) command args; }
      else
        {
          command = credentialBin;
          args = [
            "exec"
            provider.keyFile
            s.keyEnv
            s.command
          ]
          ++ s.args;
        }
    )
  ) (lib.filterAttrs (_: s: s.enable) provider.stdioMcpServers);
  mcp.mcpServers = httpServers // stdioServers;
  plugins = lib.mapAttrsToList (_: p: p.path) (lib.filterAttrs (_: p: p.enable) provider.plugins);
  settingsFile = pkgs.writeText "claude-${name}-settings.json" (builtins.toJSON settings);
  mcpFile = pkgs.writeText "claude-${name}-mcp.json" (builtins.toJSON mcp);
  flags = [
    "--settings ${settingsFile}"
  ]
  ++ lib.optional (mcp.mcpServers != { }) "--mcp-config=${mcpFile}"
  ++ map (p: "--plugin-dir=${p}") plugins;
  command = if provider.command != null then provider.command else "claude-${name}";
in
pkgs.runCommand command
  {
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    passthru = {
      inherit
        env
        settings
        mcp
        mcpFile
        flags
        command
        ;
    };
    meta.mainProgram = command;
  }
  ''
    makeBinaryWrapper ${claude}/bin/claude $out/bin/${command} \
      ${lib.concatMapStringsSep " " (v: "--unset ${v}") shadowed} \
      ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") env)} \
      ${lib.concatMapStringsSep " " (f: "--add-flags ${lib.escapeShellArg f}") flags}
  ''
