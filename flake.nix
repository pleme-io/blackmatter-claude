{
  description = "Blackmatter Claude - Claude Code integration with LSP, Zoekt, Codesearch, and MCP servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }: {
    homeManagerModules.default = import ./module;
  };
}
