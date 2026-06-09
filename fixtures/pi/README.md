# Pi Evidence Fixtures

These fixtures are evidence samples gathered for `docs/pi-adapter-spec.md` on 2026-06-08. They are not parser contract fixtures yet.

- `global/agent/skills/global-pdf/SKILL.md` mirrors `~/.pi/agent/skills/global-pdf/SKILL.md`.
- `project/.pi/skills/project-plan/SKILL.md` mirrors `.pi/skills/project-plan/SKILL.md`.
- `config/settings-package-filter-disabled.json` shows official package resource filtering syntax for disabling package-provided skills.
- `broken/missing-description/SKILL.md` is intentionally invalid because Pi docs say skills with missing descriptions are not loaded.

Before implementation, verify these samples against a disposable `agentDir` and fixture project with `pi 0.78.1` or newer.
