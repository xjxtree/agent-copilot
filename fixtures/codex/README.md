# Codex Evidence Fixtures

These fixtures document Codex adapter evidence and provide implementation test inputs for the first V2 Codex adapter slice.

Evidence status:

- Read-only discovery is locally verified for `$HOME/.agents/skills` and repository `.agents/skills` roots with `codex-cli 0.137.0`.
- User config disable is locally verified with `[[skills.config]]` in `$CODEX_HOME/config.toml` for both user and project skills.
- User config re-enable is locally verified by removing all matching `[[skills.config]]` entries and returning to default discovery.
- Project config disable is blocked: local verification did not show `<repo>/.codex/config.toml` disabling a project skill, even when the repo was trusted.

When testing `config/user-config-disabled.toml` or `config/user-config-disabled-project.toml`, rewrite the placeholder absolute path to the temp fixture copy's real `SKILL.md` path before running Codex. Use absolute `SKILL.md` paths; local verification with the skill directory path did not disable the fixture skill.
