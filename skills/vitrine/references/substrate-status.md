# vitrine: substrate status

Moved from `../SKILL.md` on 2026-10-09; verbatim.

## Substrate status

v0.1 (2026-05-18) — the `vitrine` Rust CLI exists. Implemented:

- ✅ `vitrine isolate <chart> --branch <feature> --cluster-terragrunt <path>`
- ✅ `vitrine release <chart> --cluster-terragrunt <path>`

Stubbed (this skill still walks the operator through these manually
until they're implemented):

- 🚧 `vitrine plan <module>` — capture `terragrunt plan` for evidence
- 🚧 `vitrine apply <module> --planfile <file>` — planfile-pinned apply with capture
- 🚧 `vitrine verify --config <path>` — three-layer evidence capture
- 🚧 `vitrine embed <pr> --evidence <path>` — `gh pr edit --body-file`
- 🚧 `vitrine ship --config <path> --pr <num>` — full workflow

Other deferred substrate (no work started):

- A `pleme-io/actions-vitrine` reusable workflow that auto-comments on PR
- A PR template (`.github/PULL_REQUEST_TEMPLATE.md`) lintable by CI

When `vitrine` is installed (`programs.vitrine.enable = true;` in
home-manager imports `vitrine.homeManagerModules.default` auto-emitted by
the substrate flake), prefer the binary path for any operation it
covers. Walk the operator manually for stubbed operations.
