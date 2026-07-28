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
    skill-lint = {
      url = "github:pleme-io/skill-lint";
      inputs.substrate.follows = "substrate";
    };
  };

  outputs = inputs @ { self, nixpkgs, substrate, claude-code, guardrail, skill-lint, ... }:
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
      extraChecks = pkgs: let
        lib = nixpkgs.lib;

        # ── skill-lint BASELINE-DEBT LIST ─────────────────────────────
        # 13 of this repo's 22 skills are missing `metadata.last_verified`.
        # They are EXEMPTED here, not fixed, and deliberately not fixed by a
        # bot: skill-lint's own doctrine is that clearing a freshness field
        # means a human actually re-read the skill, and "a bot bumping a date
        # to go green manufactures a false claim, which is worse than the
        # stale one it replaced." This corpus already has 65 skills sharing
        # one identical date — the exact damage that made the field a weak
        # signal. Stamping 13 more would deepen it to buy a green.
        #
        # Same shape as the fleet's other baseline-debt gates
        # (tools/fluxlint.py + fluxlint-baseline.txt, action-shell-lint):
        # existing violations are recorded and do NOT fail the build; anything
        # NEW does. The debt shrinks only when a human verifies a skill and
        # deletes its line — never by the list growing.
        #
        # ONE HONEST WEAKNESS, named rather than buried: exemption is
        # DIRECTORY-level, not violation-level, because skill-lint has no
        # per-finding baseline flag. A skill on this list is not checked for
        # anything, so it could also lose its `description` or break its
        # frontmatter and stay green. Violation-level baselining is a
        # skill-lint change (a `--baseline <file>` argument), and it is the
        # load-bearing fix; this list is the honest interim until then.
        skillDebt = [
          "anomaly-recurrence"
          "cadence-review"
          "chargeback-rollout"
          "commitment-review"
          "controller-detection-axis"
          "cost-anomaly"
          "cost-attribution"
          "escalation-ladder"
          "lifecycle-policy"
          "rightsize-fleet"
          "starfish-protocol"
          "tag-architecture"
          "unit-economics"
        ];

        # The gated subset, as a REAL directory tree (builtins.path, not
        # linkFarm — skill-lint's skill_dirs() calls DirEntry::file_type(),
        # which does not follow symlinks, so a farm of symlinks discovers
        # zero skills and the gate would pass having scanned nothing).
        #
        # A skill is gated unless its top-level directory name is on the debt
        # list, so every NEWLY ADDED skill is gated automatically — which is
        # precisely the class that shipped broken elsewhere in the fleet (a
        # new SKILL.md with no frontmatter at all).
        gatedSkills = builtins.path {
          name = "blackmatter-claude-skills-gated";
          path = ./skills;
          filter = path: _type:
            let
              rel = lib.removePrefix "${toString ./skills}/" (toString path);
            in
            !(builtins.elem (builtins.head (lib.splitString "/" rel)) skillDebt);
        };
      in {
        claude-config-merge-tests = pkgs.runCommand "claude-config-merge-tests" {
          nativeBuildInputs = [ pkgs.rustc pkgs.stdenv.cc ];
        } ''
          rustc --edition 2021 --test -o test-bin ${./module/claude-config-merge.rs}
          ./test-bin --test-threads=1
          touch $out
        '';

        # ── The gate: per-skill STRUCTURE, over the non-baselined set ──
        # Wired 2026-07-27. Before this, skill-lint ran in exactly ONE repo
        # (blackmatter-pleme) and all 22 skills here were validated by nothing
        # — a gate that looks at 1 of 7 repos is green because it never looks,
        # which is indistinguishable from passing. Two real defects shipped in
        # that blind spot (a SKILL.md with no frontmatter at all, another whose
        # frontmatter fails a strict YAML parse) and were found only by
        # pointing the binary at those repos by hand.
        #
        # WHY THE EMPTY MAP DIR: skill-lint loads a skill map in
        # CheckContext::from_source BEFORE any --skip-* flag is consulted, so
        # a map argument is mandatory even when every map-dependent check is
        # off. This repo has no local skill-map.d — the fleet map lives in
        # blackmatter-pleme — so the gate is handed an empty one and the three
        # map-dependent checks are skipped explicitly:
        #   --skip-sync           dir <-> map parity (no local map)
        #   --skip-map-integrity  references/domains (likewise)
        #   --skip-version        map version/lastModified (likewise)
        #
        # WHAT IS AND IS NOT COVERED — do not round this up. COVERED: 9 of 22
        # skills, plus every skill added from here on. NOT COVERED: the 13
        # baselined above, and whether any of these skills appear in the fleet
        # map at all (measured 2026-07-27: none do).
        #
        # NOT VACUOUS: skill-lint's own DiscoveryChecker fails the run when
        # zero skills are found, so this can never pass having scanned
        # nothing — which also means emptying the gated set by baselining
        # everything is a hard error, not a silent green. Verified
        # red-on-broken-input before commit, not merely green.
        skill-map = pkgs.runCommand "skill-map-check" {
          nativeBuildInputs = [ skill-lint.packages.${pkgs.stdenv.hostPlatform.system}.default ];
        } ''
          skill-lint check --skills-dir ${gatedSkills} --map-dir ${pkgs.emptyDirectory} \
            --skip-sync --skip-map-integrity --skip-version
          touch $out
        '';
      };
    };
}
