---
name: tend
description: Manage workspace repositories with tend CLI. Use when syncing repos, checking workspace status, discovering org repos, editing workspace config, adding new workspaces, or troubleshooting clone failures (SSH keys, permissions).
allowed-tools: Bash, Read, Write, Edit
metadata:
  version: "1.0.0"
  last_verified: "2026-02-27"
  domain_keywords:
    - "workspace"
    - "repository"
    - "clone"
    - "sync"
    - "tend"
    - "git"
    - "github"
    - "org"
---

# Workspace Repository Manager (`tend`)

`tend` keeps workspace directories in sync with GitHub org repositories.
Config lives at `~/.config/tend/config.yaml`.

## Quick Reference

```bash
tend sync                              # Clone all missing repos
tend sync --workspace pleme-io         # Sync one workspace only
tend sync --quiet                      # Silent unless repos cloned
tend status                            # Show clean/dirty/missing/unknown
tend status --workspace pleme-io       # Status for one workspace
tend list                              # List all configured repos
tend discover <org>                    # Discover repos from GitHub API
tend init                              # Generate starter config
```

## Config Format

```yaml
# ~/.config/tend/config.yaml
workspaces:
  - name: pleme-io
    provider: github
    base_dir: ~/code/github/pleme-io
    clone_method: ssh          # ssh | https
    discover: true             # auto-discover from GitHub org API
    org: pleme-io              # GitHub org name
    exclude:                   # repos to skip
      - ".github"
    extra_repos: []            # repos to add beyond discover
```

### Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | yes | — | Workspace identifier |
| `provider` | no | `github` | Git provider |
| `base_dir` | yes | — | Where repos are cloned (`~` expanded) |
| `clone_method` | no | `ssh` | `ssh` or `https` |
| `discover` | no | `false` | Auto-discover repos from org API |
| `org` | no | `name` | GitHub org for discovery |
| `exclude` | no | `[]` | Repo names to skip |
| `extra_repos` | no | `[]` | Additional repos beyond discovery |

## Status Indicators

| Icon | Meaning |
|------|---------|
| `[ok]` | Repo present, working tree clean |
| `[!!]` | Repo present, has uncommitted changes |
| `[--]` | Expected but not cloned |
| `[??]` | Exists on disk but not in config |

## Authentication

For **private repos** or higher API rate limits, set a GitHub token:

```bash
export GITHUB_TOKEN="ghp_..."        # Standard GitHub token env
export TEND_GITHUB_TOKEN="ghp_..."   # tend-specific override
```

`TEND_GITHUB_TOKEN` takes priority over `GITHUB_TOKEN`.

## Direnv Integration

Add to any `.envrc` to auto-sync repos on directory entry:

```bash
use_tend                               # Sync all workspaces
use_workspace pleme-io                 # Sync one workspace
use_tend /path/to/custom-config.yaml   # Custom config path
```

Requires `blackmatter.components.shell.direnvLib.enable = true` (enabled by default).

## Troubleshooting

### SSH clone failures
- Verify SSH agent: `ssh-add -l`
- Test GitHub access: `ssh -T git@github.com`
- Switch to HTTPS: set `clone_method: https` in config

### API rate limiting
- Set `GITHUB_TOKEN` env var for authenticated requests (5000/hr vs 60/hr)
- Check rate limit: `curl -s https://api.github.com/rate_limit | jq .rate`

### Missing repos after discover
- Check if repo is archived (archived repos are excluded)
- Check `exclude` list in config
- Run `tend discover <org>` to see what the API returns

## Adding a New Workspace

1. Edit `~/.config/tend/config.yaml`
2. Add a new entry under `workspaces:`
3. Run `tend sync --workspace <name>`

## Workspace Hierarchy

Workspaces follow the convention `~/code/${git-service}/${org-or-user}/${repo}`:

```
~/code/
  github/
    org-a/        ← one tend workspace per org
      repo-1/
      repo-2/
    org-b/
  gitlab/
    my-team/
```

### CLAUDE.md at Each Level

Each directory level can have a `CLAUDE.md` providing progressively more specific guidance:

| Level | Example | Content |
|-------|---------|---------|
| Root | `~/code/CLAUDE.md` | Directory convention, how to add services/orgs |
| Service | `~/code/github/CLAUDE.md` | Service-specific conventions, list of orgs |
| Org | `~/code/github/org/CLAUDE.md` | Org repo map, architecture, contribution rules |
| Repo | `~/code/github/org/repo/CLAUDE.md` | Repo-specific build/test/deploy instructions |

Agents traversing the hierarchy should read CLAUDE.md at each level for context.

### .envrc Integration

Org-level `.envrc` files use `use_tend` to auto-sync repos on directory entry:

```bash
# ~/code/github/my-org/.envrc
use_tend
```

This runs `tend sync --quiet` scoped to workspaces matching the current directory.
Individual repo `.envrc` files (e.g., `use flake`) are independent — direnv is
directory-scoped and does not inherit from parent directories.

After deploying a new `.envrc`, run `direnv allow <path>` once (direnv security model).

### Adding a New Service + Org

1. Create directory: `mkdir -p ~/code/gitlab/my-team`
2. Add tend workspace config (see Config Format above)
3. Optionally create CLAUDE.md files at service and org levels
4. Optionally add `.envrc` with `use_tend` at the org level
5. Run `tend sync --workspace my-team`

## Nix Integration

Config is generated declaratively via `home.file` in the nix repo.
To modify the workspace config, edit `nix/nodes/cid/default.nix` and rebuild.
