{
  description = "Blackmatter Claude — Claude Code integration (LSP, Zoekt, Codesearch, MCP servers)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    guardrail = {
      url = "github:pleme-io/guardrail";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, substrate, claude-code, guardrail, ... }:
    (import "${substrate}/lib/blackmatter-component-flake.nix") {
      inherit self nixpkgs;
      name = "blackmatter-claude";
      description = "Claude Code integration — LSP, MCP servers, skills, guardrails";
      modules.homeManager = import ./module { inherit claude-code; };
      overlay = final: prev: {
        guardrail = guardrail.packages.${prev.stdenv.hostPlatform.system}.default;
        guardrail-rules = guardrail + "/rules";
      };
    };
}
