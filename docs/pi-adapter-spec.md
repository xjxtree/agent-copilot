# Pi Adapter Evidence Spec

> Evidence date: 2026-06-10. V2.13 implemented the evidence-backed read-only scanner/parser slice; V2.21 completed scan-accuracy / dedupe / agent-metric wording alignment; V2.37 completed the guarded native global/project/package toggle slice with preview, snapshot, rollback, trust gate, and disabled-state rescan.

## Status

Read-only scanner/parser support is implemented for Pi-native `~/.pi/agent/skills` and project `.pi/skills` roots, limited to directories containing `SKILL.md`. V2.37 guarded native toggle support is implemented for global/project/package disable/re-enable flows that passed disposable evidence checks. Pi install, `.agents/skills` compatibility-root writes, arbitrary compatibility-root writes, script execution, AI auto-write, and credential persistence remain blocked.

Real local catalog validation on 2026-06-10 found that treating direct root `.md` files as skills pulls large numbers of ordinary Pi resource documents into the product list as broken/non-skill rows. Skills Copilot therefore intentionally does not scan direct root `.md` files for Pi until a narrower official or harness-backed discriminator exists.

V2.21 scan-alignment focus (completed):

- 目录扫描优先以 canonical path + scope 为基准去重；不在当前版本加入基于猜测字段的重复抑制。
- 兼容根与原生根重叠导致的重复，优先保留可解释记录并通过 cross-agent 分析口径展示，不通过静默过滤解决。
- agent 维度统计以现有 protocol payload 为准，避免 UI filter 改变总量定义。

Local validation on 2026-06-08:

- `pi --version` returned `0.78.1`.
- `$HOME/.pi/agent/` exists locally.
- `$HOME/.pi/agent/skills/` exists locally.
- `$HOME/.pi/agent/settings.json` exists locally.
- `pi config --help` opened the interactive Resource Configuration UI instead of printing static help; no changes were made.
- No local Pi settings content was inspected or modified.

P0 validation on 2026-06-10:

- `pi --version` returned `0.79.0`.
- Disposable `HOME` and `PI_CODING_AGENT_DIR` were used for mutation checks.
- Real Pi settings and real skills were not modified.
- Pi-native global and project toggles write `-skills/<name>/SKILL.md` to disable and `+skills/<name>/SKILL.md` to re-enable.
- Package skill filters use the same `-skills/...` and `+skills/...` entries after converting package entries to object form.
- `.agents/skills` compatibility writable remains excluded from the first production slice due to documented and observed scope/symlink risks.

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
- In `~/.pi/agent/skills/` and `.pi/skills/`, direct root `.md` files may be agent-visible in Pi, but Skills Copilot does not catalog them because local validation showed they are indistinguishable from ordinary resource documents at scale.
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

Read-only state: **implemented in V2.13**. The scanner models Pi-native directory skills under `.pi/skills/**/SKILL.md` and `~/.pi/agent/skills/**/SKILL.md`. `.agents/skills` compatibility roots and direct root `.md` cataloging remain out of scope until conflict/noise policy is decided.

Writable state: **guarded production slice implemented in V2.37 for native global/project/package toggle only**. Disable/re-enable must stay preview-first, trust-gated where project/package settings are involved, snapshot-backed, read-back verified, rollback-safe, and followed by disabled-state rescan. Broader writable support remains blocked for:

- Whether `disable-model-invocation` should be treated as a read-only/writable partial state; it hides a skill from automatic model invocation but does not disable `/skill:name`.
- Whether `enableSkillCommands: false` is a global command registration setting rather than per-skill enabled state.
- Merge behavior when global settings include a skill path and project settings exclude the same path.
- Whether `.agents/skills` compatibility roots should be exposed under Pi or left to the Codex/agent-compatible adapter decision to avoid duplicate catalog entries.
- Package install/remove is a separate decision from direct skill copy/install; do not mix them in the first writable patch.

V2.21 validation scope:

- 校验扫描 root 与 settings path 在项目/用户上下文中是否稳定映射，避免同一 skill 因上下文漂移重复计入。
- 校验同 path 同名在同一会话只保留一条实例；重复关系仅作为 cross-agent 分析数据公开。
- 校验 `catalog.scanAll`/`catalog.analysis`/`app.stateSnapshot.health` 在同一上下文下可复核一致。

## Fixtures

Minimal evidence fixtures live under `fixtures/pi/`. They are evidence samples only, not parser contract fixtures yet.

- `fixtures/pi/global/agent/skills/global-pdf/SKILL.md`: global Pi skill shape, mirroring `~/.pi/agent/skills/<name>/SKILL.md`.
- `fixtures/pi/project/.pi/skills/project-plan/SKILL.md`: project Pi skill shape.
- `fixtures/pi/config/settings-package-filter-disabled.json`: package skill filtering evidence for the V2.37 guarded package toggle slice; it is not authority for Pi install/remove or compatibility-root writes.
- `fixtures/pi/broken/missing-description/SKILL.md`: malformed sample that Pi docs say should not load.
