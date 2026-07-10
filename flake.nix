{
  description = "Blackmatter Claude — Claude Code integration (LSP, Zoekt, Codesearch, MCP servers)";

  inputs = {
    nixpkgs.follows = "substrate/nixpkgs";
    substrate = {
      url = "github:pleme-io/substrate";
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
      # `claude-config-merge.rs` / `statusline.rs` are zero-dependency
      # binaries compiled directly with `rustc` (no Cargo.toml — see the
      # header comments in module/*.rs). Their `#[cfg(test)]` unit tests
      # therefore have no `cargo test` to run under; wire them into
      # `checks.<system>` directly via `rustc --test`, so `nix flake check`
      # (and the blackmatter aggregator's fleet-wide check roll-up) proves
      # them on every change instead of relying on a human remembering to
      # run them by hand.
      extraChecks = pkgs: {
        claude-config-merge-tests = pkgs.runCommand "claude-config-merge-tests" {
          nativeBuildInputs = [ pkgs.rustc pkgs.stdenv.cc ];
        } ''
          rustc --edition 2021 --test -o test-bin ${./module/claude-config-merge.rs}
          ./test-bin --test-threads=1
          touch $out
        '';
      };
    };
}
