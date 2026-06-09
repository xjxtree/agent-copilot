# Pi Adapter Evidence Spec

> Evidence date: 2026-06-08. This is a V2 prep evidence record only; do not implement a Pi adapter from this file until the remaining local round-trip checks are complete.

## Status

Read-only scanner/parser planning has enough official evidence for Pi skills. Writable toggle support is still blocked because Pi has multiple resource sources, package filters, and an interactive `pi config` resource manager that need disposable local round-trip verification before this app writes settings.

Local validation on 2026-06-08:

- `pi --version` returned `0.78.1`.
- `$HOME/.pi/agent/` exists locally.
- `$HOME/.pi/agent/skills/` exists locally.
- `$HOME/.pi/agent/settings.json` exists locally.
- `pi config --help` opened the interactive Resource Configuration UI instead of printing static help; no changes were made.
- No local Pi settings content was inspected or modified.

## Official Evidence

Official docs used on 2026-06-08:

- Pi Skills: <https://pi.dev/docs/latest/skills>
- Pi SDK resource discovery: <https://pi.dev/docs/latest/sdk>
- Pi Settings: <https://pi.dev/docs/latest/settings>
- Pi Extensions: <https://pi.dev/docs/latest/extensions>
- Pi Packages: <https://pi.dev/docs/latest/packages>

## Directory And Format Evidence

Default SDK resource discovery uses:

| Scope | Path |
| --- | --- |
| Global Pi skills | `~/.pi/agent/skills/` |
| Global agent-compatible skills | `~/.agents/skills/` |
| Project Pi skills | `.pi/skills/` |
| Project agent-compatible skills | `.agents/skills/` in `cwd` and ancestor directories up to the Git repo root, or filesystem root when outside a repo |
| Explicit local skill paths | `skills` entries in `~/.pi/agent/settings.json` or `.pi/settings.json` |
| Package skill paths | package resources declared through `packages` settings or `package.json` `pi.skills` |

Pi also discovers extensions, prompts, themes, settings, custom models, credentials, and sessions through the same `agentDir` / project structure. Those are not skills and should not be mapped into `SkillInstance` without a separate product decision.

Pi skill file rules:

- A skill is a directory with a required `SKILL.md`; everything else in the directory is freeform.
- In `~/.pi/agent/skills/` and `.pi/skills/`, direct root `.md` files are also discovered as individual skills.
- In `~/.agents/skills/` and project `.agents/skills/`, root `.md` files are ignored.
- Directories containing `SKILL.md` are discovered recursively in all skill locations.
- `--no-skills` disables discovery, but explicit `--skill` paths still load.

`SKILL.md` must start with YAML frontmatter. Official Pi frontmatter fields:

- `name` required, max 64 characters, lowercase letters/numbers/hyphens
- `description` required, max 1024 characters
- `license` optional
- `compatibility` optional
- `metadata` optional
- `allowed-tools` optional, experimental
- `disable-model-invocation` optional; when true, hidden from system prompt but still available through `/skill:name`

Pi validates against the Agent Skills standard. Most issues warn but still load; missing `description` does not load. Name collisions warn and keep the first skill found.

## Config And Toggle Evidence

Official settings paths:

- Global settings: `~/.pi/agent/settings.json`
- Project settings: `.pi/settings.json`

Project settings override global settings, with nested objects merged. Resource path settings include:

- `packages`
- `extensions`
- `skills`
- `prompts`
- `themes`
- `enableSkillCommands`

Paths in global settings resolve relative to `~/.pi/agent`; paths in project settings resolve relative to `.pi`; absolute paths and `~` are supported. Resource arrays support glob patterns, `!pattern` exclusions, `+path` force-includes, and `-path` force-excludes.

Package evidence:

- `pi install` and `pi remove` write to global settings by default.
- `pi install -l` writes to project `.pi/settings.json`.
- Object-form package entries can filter resources, including `skills: []` to load no skills from a package.
- `pi config` is the official enable/disable surface for extensions, skills, prompt templates, and themes from installed packages and local directories.

## Adapter Decision

Read-only state: **ready to plan**. The scanner can model Pi-native skills under `.pi/skills` and `~/.pi/agent/skills`, and can consider `.agents/skills` compatibility roots after conflict policy is decided.

Writable state: **blocked**. A future writable adapter must first verify:

- Exact JSON mutation produced by `pi config` when disabling a direct local skill path.
- Exact JSON mutation produced by `pi config` when disabling a package-provided skill.
- Whether default auto-discovered roots can be disabled per skill without removing files.
- Whether `disable-model-invocation` should be treated as a read-only/writable partial state; it hides a skill from automatic model invocation but does not disable `/skill:name`.
- Whether `enableSkillCommands: false` is a global command registration setting rather than per-skill enabled state.
- Project trust behavior before loading `.pi/settings.json` and project-local `.pi` resources.
- Merge behavior when global settings include a skill path and project settings exclude the same path.
- Whether `.agents/skills` compatibility roots should be exposed under Pi or left to the Codex/agent-compatible adapter decision to avoid duplicate catalog entries.

## Fixtures

Minimal evidence fixtures live under `fixtures/pi/`. They are evidence samples only, not parser contract fixtures yet.

- `fixtures/pi/global/agent/skills/global-pdf/SKILL.md`: global Pi skill shape, mirroring `~/.pi/agent/skills/<name>/SKILL.md`.
- `fixtures/pi/project/.pi/skills/project-plan/SKILL.md`: project Pi skill shape.
- `fixtures/pi/config/settings-package-filter-disabled.json`: candidate settings fragment showing package skill filtering; not verified as a direct local-skill toggle.
- `fixtures/pi/broken/missing-description/SKILL.md`: malformed sample that Pi docs say should not load.
