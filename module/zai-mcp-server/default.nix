{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:
buildNpmPackage (finalAttrs: {
  pname = "zai-mcp-server";
  version = "0.1.6";

  src = fetchurl {
    url = "https://registry.npmjs.org/@z_ai/mcp-server/-/mcp-server-${finalAttrs.version}.tgz";
    hash = "sha256-bPZ67b2fW6UBQMv10rCuLa4RF+xLFUDPY+79vuVAHFI=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${lib.getExe jq} 'del(.scripts.prepare)' package.json > package.json.new
    mv package.json.new package.json
  '';

  npmDepsHash = "sha256-AENicvmN0tK2b69ec0IrN+5qxbjNemSrvIpGkT7fdaU=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  meta = {
    description = "Z.ai's Vision MCP server: image, video, diagram and UI analysis on GLM's vision models";
    homepage = "https://docs.z.ai/devpack/mcp/vision-mcp-server";
    license = lib.licenses.asl20;
    mainProgram = "zai-mcp-server";
  };
})
