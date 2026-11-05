---
name: glm
description: "Hand a task to GLM through claude-glm; second opinion"
allowed-tools: Bash, Read
metadata:
  version: "0.2.0"
  last_verified: "2026-11-05"
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
servers, skills and CLAUDE.md as this session; only the models differ.

| Tier | Model | Use |
|---|---|---|
| opus, sonnet, fable | `glm-5.3[1m]` | Default. 1M context, 128K output, text only. |
| haiku | `glm-5.3-flash[1m]` | Background work and `--model haiku`. About a third of the credits. Multimodal. |

Reasoning is always on. `/effort low` lowers it and `high` or `max` raise it. It
cannot be turned off.

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

## Web and repo tools

Anthropic's server-side `WebSearch` does not run on this endpoint. Use the Z.ai
MCP servers, which only this binary loads, with the plan key:

| Server | Tool | For |
|---|---|---|
| `web-search-prime` | `web_search_prime` | Web search |
| `web-reader` | `webReader` | Read a URL |
| `zread` | `search_doc`, `get_repo_structure`, `read_file` | Public GitHub repos |

Each call costs 1.2 credits. Nothing private belongs in a query.

## Quota

Max plan: 28,000 credits per 5 hours and 140,000 per week. Credits per call are
`(input x in + cached x cached + output x out) / 10000`.

| Model | in | cached | out |
|---|---|---|---|
| GLM-5.3 | 6.9 | 1.7 | 24 |
| GLM-5.3-Flash | 2.3 | 0.56 | 8 |

- Off-peak is half price. Peak is Monday to Friday, 14:00 to 18:00 Singapore
  time, which is 06:00 to 10:00 UTC.
- A large context costs on every turn: 500K cached is 85 credits per turn on
  GLM-5.3. Compact a long session.
- Only GLM-5.3 and GLM-5.3-Flash are on the plan. Do not pick another model from
  `/v1/models`.
- Max guidance is "2 or more projects simultaneously". Limits are dynamic, so
  back off when requests answer 429.
- See remaining quota at <https://z.ai/manage-apikey/subscription>. There is no
  API for it, and the `costUSD` in Claude Code's output is not real.

Terms limit plan quota to supported tools for one person. Never call the endpoint
from an app, a bot or an SDK with this key.

## When it fails

- `apiKeyHelper` error: the key file is missing; the node has no
  `glm/api/drzln/coding/key` sops secret yet, or the node is not in the row's
  `machines` in `lib/claude-providers.nix` in the nix repo.
- 429 with `1113`: a Standard key or a lapsed plan. The key must come from the
  Personal Coding Plan tab. It fails after four retries, about 15 seconds.
- 429 without `1113`: the 5-hour or weekly limit, or concurrency. Wait.
- 401 from `api.z.ai`: the key is wrong or the plan expired.
- An unknown model: Z.ai renamed it; change
  `providers.glm.models` in the nix repo, not here.
- `unrecognized_model` in stderr: Claude Code's Anthropic IDs moved, and
  `modelOverrides` in `module/provider-wrapper.nix` needs the new IDs. It is
  harmless until then.
