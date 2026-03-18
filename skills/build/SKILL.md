---
name: build
description: Build any software project using substrate recipes. Use when creating a new project, adding a build system, scaffolding a repo, or when you need to build something and want to use the right Nix pattern. Always invoked before language-specific skills.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-18"
  domain_keywords:
    - "build"
    - "scaffold"
    - "new project"
    - "flake"
    - "substrate"
    - "nix build"
---

# Build — Substrate-First Software Construction

This skill is the entry point for building any software. It discovers substrate
recipes, matches them to your intent, and either delegates to the right
domain skill or creates the missing recipe + skill.

## Step 1: Discover Available Recipes

Read the substrate lib directory to see what build recipes exist:

```bash
ls ~/code/github/pleme-io/substrate/lib/*.nix | head -60
```

Substrate recipes follow naming conventions:

| Pattern | Purpose | Example |
|---------|---------|---------|
| `{lang}-tool.nix` | CLI tool builder | `go-tool.nix`, `zig-tool-release.nix` |
| `{lang}-tool-release-flake.nix` | Complete flake wrapper for CLI tools | `rust-tool-release-flake.nix` |
| `{lang}-library.nix` | Library/package builder | `rust-library.nix`, `typescript-library.nix` |
| `{lang}-service.nix` | Dockerized service builder | `rust-service.nix`, `go-grpc-service.nix` |
| `{lang}-build.nix` | General build helper | `ruby-build.nix`, `web-build.nix` |
| `{lang}-overlay.nix` | Toolchain overlay | `rust-overlay.nix`, `go-overlay.nix` |
| `{lang}-*-flake.nix` | Zero-boilerplate flake wrapper | `ruby-gem-flake.nix` |

## Step 2: Match Intent to Recipe

Ask yourself:

1. **What language?** Rust, Go, TypeScript, Ruby, Python, Zig, Java, .NET, WASM
2. **What artifact?** CLI tool, library, service, web app, WASM app
3. **What deployment?** GitHub release, Docker image, crates.io, npm, none

Then find the matching recipe:

| Intent | Recipe | Flake wrapper |
|--------|--------|---------------|
| Rust CLI tool with releases | `rust-tool-release.nix` | `rust-tool-release-flake.nix` |
| Rust crates.io library | `rust-library.nix` | — |
| Rust simple binary | Use `rust-tool-release-flake.nix` with crate2nix | — |
| Rust microservice + Docker | `rust-service.nix` | `rust-service-flake.nix` |
| Rust WASM (Yew) | `wasm-build.nix` | — |
| Go CLI tool | `go-tool.nix` | — |
| Go multi-binary monorepo | `go-monorepo.nix` + `go-monorepo-binary.nix` | — |
| Go gRPC service | `go-grpc-service.nix` | — |
| TypeScript CLI tool | `typescript-tool.nix` | — |
| TypeScript npm library | `typescript-library.nix` | `typescript-library-flake.nix` |
| Vite/React web app | `web-build.nix` | — |
| Ruby gem library | `ruby-gem.nix` | `ruby-gem-flake.nix` |
| Ruby service + Docker | `ruby-build.nix` | — |
| Zig CLI tool with releases | `zig-tool-release.nix` | `zig-tool-release-flake.nix` |
| Python package (uv) | `python-uv.nix` | — |
| Python package (setuptools) | `python-package.nix` | — |
| Java Maven package | `java-maven.nix` | — |
| .NET/C# package | `dotnet-build.nix` | — |
| Helm chart | `helm-build.nix` | — |
| Terraform provider | `terraform-provider.nix` | — |
| OpenAPI SDK generation | `openapi-sdk.nix` | — |
| GitHub Action | `github-action.nix` | — |

## Step 3A: Recipe Exists — Use It

If the recipe matches, read the recipe file to understand its API:

```bash
cat ~/code/github/pleme-io/substrate/lib/{recipe}.nix | head -40
```

Then check if a domain skill exists for this recipe:

```bash
ls ~/.claude/skills/skill-map.d/ 2>/dev/null
# or check the skill map for the matching domain
```

If a domain skill exists (e.g., `/rust-tool` for `rust-tool-release-flake.nix`),
**delegate to it** — it has the detailed templates and conventions.

If no domain skill exists, **create one** (see Step 4).

## Step 3B: No Recipe Exists — Create It in Substrate

If no substrate recipe matches the intent:

1. **Identify the closest existing recipe** as a template
2. **Create the new recipe** in `substrate/lib/{name}.nix`
3. **Follow substrate conventions:**
   - Accept `{ pkgs, lib, ... }` as arguments
   - Return a function that takes project-specific config
   - Provide `packages`, `overlays`, `devShells`, `apps` outputs
   - Use `lib.cleanSource` for source filtering
   - Use `release-helpers.nix` for lifecycle apps (bump, release, check-all)
4. **If it's a common pattern, create a `-flake.nix` wrapper** for zero-boilerplate usage
5. **Test it:** `nix build`, `nix run .#check-all`
6. **Push substrate, update downstream flake locks**

Then proceed to Step 4 to create the corresponding domain skill.

## Step 4: Create the Domain Skill

Every substrate recipe should have a corresponding skill that teaches how to use it.

1. **Determine placement:**
   - Generic recipe (any org could use) → `blackmatter-claude/skills/{name}/`
   - Org-specific conventions → `blackmatter-pleme/skills/{name}/`

2. **Create the skill** with front matter + body:

```bash
mkdir -p ~/code/github/pleme-io/{repo}/skills/{skill-name}
```

Write `SKILL.md` covering:
- Pre-flight checks (language toolchain, substrate version)
- The substrate recipe API (function signature, required args)
- flake.nix template using the recipe
- Cargo.toml / package.json / go.mod conventions
- Build + test + release workflow
- Anti-patterns

3. **Add to the skill map** (per-domain file in `skill-map.d/`):

```bash
# Edit the appropriate domain file
vim ~/code/github/pleme-io/blackmatter-pleme/skill-map.d/{domain}.yaml
```

Add the entry with description, domain, repo, concerns, references.

4. **Run `skill-lint check`** to verify sync + references:

```bash
skill-lint check --skills-dir ~/code/github/pleme-io/blackmatter-pleme/skills
```

5. **Commit skill + map together**, push, flake update, rebuild.

## Decision Flowchart

```
User: "Build me a ___"
          │
    ┌─────▼─────┐
    │ What lang? │
    │ What type? │
    └─────┬─────┘
          │
    ┌─────▼──────────────┐
    │ Read substrate/lib/ │
    │ Match recipe?       │
    └─────┬──────────────┘
          │
    ┌─────┴─────┐
    │           │
  MATCH      NO MATCH
    │           │
    │     ┌─────▼──────────┐
    │     │ Create recipe  │
    │     │ in substrate   │
    │     └─────┬──────────┘
    │           │
    ├───────────┘
    │
    ┌─────▼──────────────┐
    │ Domain skill exists?│
    └─────┬──────────────┘
          │
    ┌─────┴─────┐
    │           │
  EXISTS    MISSING
    │           │
    │     ┌─────▼──────────┐
    │     │ Create skill   │
    │     │ + map entry    │
    │     │ + skill-lint   │
    │     └─────┬──────────┘
    │           │
    ├───────────┘
    │
    ┌─────▼──────────────┐
    │ Delegate to skill  │
    │ or scaffold project│
    └────────────────────┘
```

## Anti-Patterns

- **Never scaffold without checking substrate first** — there may already be a recipe
- **Never hardcode build logic in flake.nix** — extract to substrate if reusable
- **Never create a project skill without a substrate recipe** — the recipe is the source of truth
- **Never skip the skill-lint check** — the map must stay in sync
- **Never duplicate substrate recipe logic in a skill** — the skill teaches usage, the recipe IS the implementation
