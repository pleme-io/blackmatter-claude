---
name: service
description: Manage service lifecycle with forge — release, deploy, migrate, monitor. Use when releasing a service, deploying to staging/production, running migrations, checking deployment health, setting up CI/CD, or configuring deploy.yaml for a new service.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-18"
  domain_keywords:
    - "service"
    - "deploy"
    - "release"
    - "forge"
    - "SDLC"
    - "CI/CD"
    - "migration"
    - "docker"
    - "kubernetes"
    - "GitOps"
---

# Service — Forge SDLC Lifecycle Management

This skill is the entry point for service lifecycle operations. It discovers
forge SDLC patterns, matches them to your intent, and either delegates to the
right domain skill or creates the missing pattern + skill.

## Step 1: Understand the Intent

Service lifecycle breaks into six phases:

| Phase | Intent | Forge command | When |
|-------|--------|---------------|------|
| 0 | Pre-release gates (lint, test, validate) | `forge prerelease` | Before any release |
| 1 | Build (Nix → Docker image + cache) | `forge build` | On code change |
| 2 | Push (image → registry) | `forge push` | After successful build |
| 3 | Deploy (GitOps → K8s) | `forge deploy` | After push |
| 4 | Migrate + federate (DB + GraphQL) | `forge run-migrations` | After deploy |
| 5 | Verify (health checks, smoke tests) | `forge status` | After migrate |

Orchestration commands combine phases:

| Command | Phases | Use when |
|---------|--------|----------|
| `forge comprehensive-release` | 1→3 | Single service, full pipeline |
| `forge product-release` | 0→5 | Multi-service product release |
| `forge orchestrate-release` | 1→3 | Multi-arch, multi-environment |
| `nix run .#release` | All | Standard substrate SDLC app |

## Step 2: Discover Forge Patterns

Check if the project already has forge integration:

```bash
# Does deploy.yaml exist?
find . -name "deploy.yaml" -maxdepth 3 2>/dev/null

# What SDLC apps does the flake expose?
nix flake show 2>/dev/null | grep -E "release|deploy|build|test|migrate"

# Is forge in the flake inputs?
grep "forge" flake.nix 2>/dev/null
```

Check substrate for SDLC patterns:

```bash
ls ~/code/github/pleme-io/substrate/lib/ | grep -E "release|sdlc|service|docker|helm"
```

Key substrate SDLC files:

| File | Purpose |
|------|---------|
| `release-helpers.nix` | Release, bump, check-all app factories |
| `product-sdlc.nix` | Full SDLC app suite for product monorepos |
| `rust-service.nix` | Rust service builder with Docker + deploy |
| `rust-service-flake.nix` | Zero-boilerplate flake wrapper for Rust services |
| `image-release.nix` | Multi-arch OCI image builder |
| `helm-build.nix` | Helm chart lifecycle |
| `db-migration.nix` | Database migration runner |
| `go-grpc-service.nix` | Go gRPC service builder with health checks |
| `go-docker.nix` | Minimal Docker image for Go services |
| `web-docker.nix` | Docker image for web apps |

## Step 3A: Pattern Exists — Configure It

If the project already has forge integration, configure `deploy.yaml`:

### Global config (repo root)

```yaml
registry:
  host: ghcr.io
  organization: pleme-io
cache:
  server: http://attic-server
  name: default
```

### Product config (product root)

```yaml
name: my-product
environments:
  staging:
    cluster: zek
    namespace: my-product-staging
  production:
    cluster: plo
    namespace: my-product-prod
release:
  services:
    - name: my-service
      path: services/rust/my-service
      migrations: true
      prerelease: true
```

### Service config (service directory)

```yaml
migrations:
  path: migrations
  validation: true
federation:
  subgraph: my-service
  port: 8080
```

Then verify the SDLC apps work:

```bash
nix run .#check-all    # Phase 0: lint + test
nix run .#build        # Phase 1: Nix → Docker
nix run .#release      # Full pipeline
```

## Step 3B: No Pattern Exists — Create It

If the project needs forge integration but doesn't have it:

1. **Add forge to flake inputs:**

```nix
forge = {
  url = "github:pleme-io/forge";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

2. **Use the right substrate recipe** (invoke `/build` skill to find it):

| Service type | Recipe | SDLC apps |
|-------------|--------|-----------|
| Rust microservice | `rust-service-flake.nix` | release, build, test, deploy |
| Go gRPC service | `go-grpc-service.nix` + `go-docker.nix` | build, push, deploy |
| Web app (React/Vite) | `web-build.nix` + `web-docker.nix` | build, push, deploy |
| Product monorepo | `product-sdlc.nix` | Full 30+ app suite |

3. **Create `deploy.yaml`** at the appropriate level (global, product, service)

4. **Wire SDLC apps** in `flake.nix`:

For a single service:
```nix
apps = {
  release = substrateLib.mkReleaseApp { inherit pname version; };
  check-all = substrateLib.mkCheckAllApp { inherit pname; };
};
```

For a product monorepo:
```nix
apps = substrateLib.productSdlcApps;
```

5. **Test the pipeline:**

```bash
nix run .#check-all        # Should pass
nix run .#build            # Should produce Docker image
nix run .#release -- --dry-run  # Should show what would happen
```

## Step 4: Create the Domain Skill (If Missing)

If a service type lacks a dedicated skill:

1. **Check existing skills:** Does `/rust-service`, `/helm-k8s-charts`, etc. already cover this?
2. **If not, create one** — follow the `/claude-skills` workflow:
   - Create `skills/{name}/SKILL.md` in the appropriate repo
   - Add entry to `skill-map.d/{domain}.yaml`
   - Run `skill-lint check`
   - Commit together

The new skill should teach:
- The substrate recipe for building this service type
- The `deploy.yaml` configuration schema
- The forge commands for each SDLC phase
- Common failure modes and debugging

## Decision Flowchart

```
User: "Release/deploy/migrate ___"
          │
    ┌─────▼──────────────┐
    │ Which SDLC phase?  │
    │ (build/push/deploy/ │
    │  migrate/verify)    │
    └─────┬──────────────┘
          │
    ┌─────▼──────────────┐
    │ deploy.yaml exists? │
    │ forge in flake?     │
    └─────┬──────────────┘
          │
    ┌─────┴─────┐
    │           │
  EXISTS    MISSING
    │           │
    │     ┌─────▼──────────────┐
    │     │ Find substrate     │
    │     │ recipe (/build)    │
    │     │ Wire forge + SDLC  │
    │     │ Create deploy.yaml │
    │     └─────┬──────────────┘
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
    │     ┌─────▼──────────────┐
    │     │ Create skill       │
    │     │ + map entry        │
    │     │ + skill-lint       │
    │     └─────┬──────────────┘
    │           │
    ├───────────┘
    │
    ┌─────▼──────────────┐
    │ Run forge command  │
    │ or delegate to     │
    │ domain skill       │
    └────────────────────┘
```

## Anti-Patterns

- **Never deploy without `deploy.yaml`** — forge reads config hierarchically, missing config = silent defaults
- **Never skip pre-release gates** — `forge prerelease` catches issues before images are built
- **Never push images without tagging from git SHA** — set `RELEASE_GIT_SHA` or use `--auto-tags`
- **Never deploy to production without staging first** — use `--environment staging` then `--environment prod`
- **Never manually `kubectl apply`** — use forge's GitOps deploy which commits to the k8s repo and triggers FluxCD
- **Never create a service SDLC skill without a corresponding substrate build recipe** — the build recipe + forge config are both required
