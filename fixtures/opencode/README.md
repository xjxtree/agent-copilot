# opencode Parser/Scan Contract Fixtures

These fixtures define the V2.4 opencode read-only parser/scan contract from `docs/opencode-adapter-spec.md`.

- `user-home/.config/opencode/skills/global-review/SKILL.md` mirrors `~/.config/opencode/skills/global-review/SKILL.md`.
- `project/.opencode/skills/project-release/SKILL.md` mirrors `.opencode/skills/project-release/SKILL.md`.
- `project/packages/app/.opencode/skills/nested-local/SKILL.md` confirms project scanning walks from `project_cwd` upward to `project_root`.
- `broken/name-mismatch/SKILL.md` is intentionally invalid because opencode requires the frontmatter `name` to match the containing directory.
- `broken/missing-description/SKILL.md` is intentionally invalid because `description` is required.
- `broken/missing-name/SKILL.md` is intentionally invalid because `name` is required.

The V2.4 opencode adapter must scan only first-class native roots: global `~/.config/opencode/skills` and project `.opencode/skills` from `project_cwd` upward to `project_root`. Do not add `.agents/skills` or `.claude/skills` compatibility fixtures to this adapter contract.

`config/opencode-deny-skill.json` remains writable-evidence only. It shows the official permission shape that can hide a skill from agents, but V2.4 must not write opencode config.

V2.12 writable evidence note:

- Keep this directory as the parser/scan contract.
- V2.12 writable validation uses disposable local `HOME` / fixture project paths and keeps real opencode config isolated.
- Managed writes use exact `permission.skill.<name> = "deny"` disable semantics and re-enable by removing only that exact deny.
- Commented JSONC configs are not rewritten because comments cannot be preserved by the current managed writer.
