---
name: glm
description: "Hand a task to GLM through claude-glm; second opinion"
allowed-tools: Bash, Read
metadata:
  version: "0.1.0"
  last_verified: "2026-11-02"
  domain_keywords:
    - "glm"
    - "z.ai"
    - "zhipu"
    - "claude-glm"
    - "delegate"
    - "second opinion"
---

# glm — hand work to GLM through `claude-glm`

`claude-glm` is Claude Code running on Z.ai's Anthropic-compatible endpoint
(`blackmatter.components.claude.providers.glm`). It has the same hooks, MCP
servers, skills and CLAUDE.md as this session; only the model differs:
`glm-5.3[1m]` for the opus and sonnet tiers, `glm-5.3-flash[1m]` for haiku.

## When

- A second, independent read of a design or a diff, from a different model family.
- A bounded, separable task that can run while this session does other work.
- Bulk work where the cost per token matters more than the last bit of quality.

Not for akeyless-facing work, and not for anything that needs this session's
context: GLM sees only the prompt you give it.

## How

Run it headless in its own worktree, so its edits never meet this session's:

```bash
git worktree add -b glm/<slug> ../<repo>-glm-<slug>
cd ../<repo>-glm-<slug> && claude-glm -p "<brief>" --output-format json --permission-mode acceptEdits > /tmp/glm-<slug>.json
```

Run it with `run_in_background`, then read `.result` from the JSON. The brief is
the agent brief from `fan-out`: the goal, the files in scope, what done means,
and what to return. Review the diff yourself before you keep any of it; a GLM
claim is evidence about GLM until you check it.

For a read-only second opinion, drop the worktree and add
`--permission-mode plan`.

## When it fails

- `apiKeyHelper` error: the key file is missing; the node has no
  `zai/api-key` sops secret yet.
- 401 from `api.z.ai`: the key is wrong or the plan expired.
- An unknown model: Z.ai renamed it; change
  `providers.glm.models` in the nix repo, not here.
