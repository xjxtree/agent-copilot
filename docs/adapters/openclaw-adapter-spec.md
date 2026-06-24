# OpenClaw Adapter Spec

This document records the current OpenClaw adapter contract.

## Scan Roots

- Native `~/.openclaw/skills`.
- Shared `~/.agents/skills`.
- Bundled roots.
- Confirmed workspace `<workspace>/skills`.
- Confirmed workspace `<workspace>/.agents/skills`.

OpenClaw project scope is workspace-scoped. Do not infer arbitrary repository
roots or `.openclaw/skills` directories.

## Skill Format

- A skill is a directory containing `SKILL.md`.
- `name` is read from YAML frontmatter when present; directory name is the
  fallback.
- Missing description may remain loaded with an empty description when the
  adapter has enough local evidence to identify the skill.

## Writable Scope

- Tool-global install may copy confirmed local `SKILL.md` records into
  `~/.openclaw/skills`.
- Workspace install may copy confirmed local `SKILL.md` records into confirmed
  `<workspace>/skills`.
- Guarded toggles may update only `skills.entries.<key>.enabled` in
  `~/.openclaw/openclaw.json`.
- JSON5 input is parsed and strict JSON is written back.

## Blocked Scope

- No `.agents` direct installs.
- No allowlist, env/apiKey, install policy, or load-root writes.
- No ClawHub, Git, update, verify, workshop, cloud, telemetry, script,
  credential, or network-backed operations.

## Fixtures

OpenClaw fixtures live under `fixtures/openclaw/` and cover read-only roots,
install boundaries, malformed records, and guarded config-toggle behavior.
