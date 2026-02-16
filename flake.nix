{
  description = "Blackmatter Claude - Claude Code integration with LSP, Zoekt, Codesearch, and MCP servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/d6c71932130818840fc8fe9509cf50be8c64634f";
  };

  outputs = { self, nixpkgs }: {
    homeManagerModules.default = import ./module;
  };
}
