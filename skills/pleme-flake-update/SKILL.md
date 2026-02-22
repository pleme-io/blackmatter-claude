---
name: pleme-flake-update
description: Update nix flake.lock files across the pleme-io repository chain and commit+push each one. Use when changes have been pushed to any blackmatter-* repo and the downstream repos need to pick them up, or when advancing the full chain to latest. Handles the full dependency order so nothing is left stale.
allowed-tools: Bash, Read
metadata:
  version: "1.0.0"
  last_verified: "2026-02-19"
---

# Pleme-io Flake Update Chain

## Dependency Order

Update upstream repos first — downstream repos must see the new commits before their own lock files are updated.

```
blackmatter-nvim
    ↓
blackmatter-shell          (depends on blackmatter-nvim)
blackmatter-claude
blackmatter-desktop
blackmatter-kubernetes
blackmatter-security
    ↓
blackmatter                (aggregator — depends on all components above)
blackmatter-profiles       (depends on blackmatter-shell + blackmatter-nvim)
    ↓
nix                        (consumer — source of truth for cid rebuild)
```

## Repo Locations

| Repo | Path |
|------|------|
| `nix` | `~/code/github/pleme-io/nix` |
| `blackmatter` | `~/code/github/pleme-io/blackmatter` |
| `blackmatter-shell` | `~/code/github/pleme-io/blackmatter-shell` |
| `blackmatter-nvim` | `~/code/github/pleme-io/blackmatter-nvim` |
| `blackmatter-profiles` | `~/code/github/pleme-io/blackmatter-profiles` |
| `blackmatter-claude` | `~/code/github/pleme-io/blackmatter-claude` |
| `blackmatter-desktop` | `~/code/github/pleme-io/blackmatter-desktop` |
| `blackmatter-kubernetes` | `~/code/github/pleme-io/blackmatter-kubernetes` |
| `blackmatter-security` | `~/code/github/pleme-io/blackmatter-security` |

## Update Flows

### After pushing to `blackmatter-nvim`

blackmatter-shell and blackmatter-profiles depend on it directly.

```bash
# 1. blackmatter-shell picks up new blackmatter-nvim
cd ~/code/github/pleme-io/blackmatter-shell
nix flake update blackmatter-nvim
git add flake.lock && git commit -m "chore: update blackmatter-nvim" && git push

# 2. blackmatter-profiles picks up new blackmatter-nvim (and new blackmatter-shell)
cd ~/code/github/pleme-io/blackmatter-profiles
nix flake update blackmatter-nvim blackmatter-shell
git add flake.lock && git commit -m "chore: update blackmatter-nvim blackmatter-shell" && git push

# 3. nix picks up all three
cd ~/code/github/pleme-io/nix
nix flake update blackmatter-nvim blackmatter-shell blackmatter
git add flake.lock && git commit -m "chore: update blackmatter-nvim blackmatter-shell blackmatter" && git push
```

### After pushing to `blackmatter-shell`

```bash
# 1. blackmatter-profiles depends on it
cd ~/code/github/pleme-io/blackmatter-profiles
nix flake update blackmatter-shell
git add flake.lock && git commit -m "chore: update blackmatter-shell" && git push

# 2. nix + blackmatter aggregator
cd ~/code/github/pleme-io/nix
nix flake update blackmatter-shell blackmatter
git add flake.lock && git commit -m "chore: update blackmatter-shell" && git push
```

### After pushing to any other `blackmatter-*` component

(blackmatter-claude, blackmatter-desktop, blackmatter-kubernetes, blackmatter-security)

```bash
# 1. blackmatter aggregator
cd ~/code/github/pleme-io/blackmatter
nix flake update <component>
git add flake.lock && git commit -m "chore: update <component>" && git push

# 2. nix
cd ~/code/github/pleme-io/nix
nix flake update <component> blackmatter
git add flake.lock && git commit -m "chore: update <component>" && git push
```

### Update all blackmatter inputs at once

Use when you want to advance the entire blackmatter stack to latest in one pass.

```bash
# Step through in dependency order:

cd ~/code/github/pleme-io/blackmatter-shell
nix flake update blackmatter-nvim
git add flake.lock && git commit -m "chore: update blackmatter-nvim" && git push

cd ~/code/github/pleme-io/blackmatter-profiles
nix flake update blackmatter-nvim blackmatter-shell
git add flake.lock && git commit -m "chore: update blackmatter inputs" && git push

cd ~/code/github/pleme-io/nix
nix flake update blackmatter blackmatter-nvim blackmatter-shell \
    blackmatter-claude blackmatter-desktop blackmatter-kubernetes blackmatter-security
git add flake.lock && git commit -m "chore: update all blackmatter inputs" && git push
```

### Update `claude-code` only (floating input — no SHA pin)

```bash
cd ~/code/github/pleme-io/nix
nix flake update claude-code
git add flake.lock && git commit -m "chore: update claude-code" && git push
```

## Commit Message Convention

- Single input: `chore: update blackmatter-shell`
- Multiple: `chore: update blackmatter-nvim blackmatter-shell`
- Full sweep: `chore: update all blackmatter inputs`

## Important Constraints

- `nix flake update` only updates `flake.lock` — it does NOT change the SHA pins
  embedded in `flake.nix` URLs (those are for nixpkgs, sops-nix, home-manager, etc.)
- The SHA-pinned system inputs require a coordinated upgrade: remove the `/SHA` suffix
  from each URL, run `nix flake update`, test, re-add the new SHA from flake.lock
- `claude-code` is the only floating input — all other system inputs are SHA-pinned
- `blackmatter-profiles` is a separate consumer like `nix` — it needs its own
  `nix flake update` pass whenever its upstream inputs change
- After updating `nix/flake.lock`, apply the changes: `nix run .#darwin-rebuild`
