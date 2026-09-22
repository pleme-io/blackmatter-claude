# Claude Desktop (macOS) from Anthropic's signed universal zip.
# The pin is written by `nix run .#claude-desktop-bump` (then commit pin.json); never edit it by hand.
# No fixup: patching any byte would invalidate Anthropic's code signature.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
let
  pin = lib.importJSON ./pin.json;
in
stdenvNoCC.mkDerivation {
  pname = "claude-desktop";
  inherit (pin) version;
  src = fetchurl { inherit (pin) url hash; };
  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    mkdir -p $out/Applications
    cp -R Claude.app $out/Applications/
  '';
  meta = {
    description = "Claude Desktop";
    homepage = "https://claude.ai/download";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
