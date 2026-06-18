# Hermes Adapter Spec Worklist

> Status: V2.95 native-root install implemented on 2026-06-18. Hermes Agent has confirmed first-class skills under active/profile Hermes home. Local ToolGlobal `SKILL.md` installs into native `~/.hermes/skills` are supported after confirmation; config toggles, project installs, external_dirs writes, hub/URL/tap/update/uninstall/reset, and network-backed operations remain blocked.

## 1. Evidence Summary

Sources checked:

- Local skill doc: `$HOME/.agents/skills/hermes-ops/SKILL.md`.
- Local machine checks: `command -v hermes`, `ls -ld "$HOME/.hermes"`.

V2.17 adds scoped adapter code for read-only scanning only. P0 evidence used public Hermes Agent docs plus read-only `ssh macmini` checks to confirm the product identity and local skill layout.

| Area | Status | Evidence |
| --- | --- | --- |
| Product identity | Confirmed | Official docs identify this as Nous Research Hermes Agent, not the Meta/Facebook Hermes JavaScript engine. |
| Local availability | Not installed locally | `command -v hermes` returned no local executable in this worktree session. `$HOME/.hermes` was not present in the inspected environment. |
| Skill-like unit | Confirmed | Official docs and macmini checks confirm first-class skills as directories containing `SKILL.md`. |
| Config path/schema | Partial service evidence | Public docs describe skill settings under `config.yaml` and per-platform management through Hermes UI/CLI, but no rollback-safe individual skill enable/disable config schema is verified for this app. |
| Enable/disable semantics | Cron-only evidence | The doc says cron job entries should be disabled with `enabled: false` rather than deleted. Treat this only as cron task management evidence, not skill enable/disable semantics. |
| Read-only catalog feasibility | Implemented | Official docs and macmini checks confirm first-class skills under active Hermes home `skills/**/SKILL.md`; V2.17 scans only that root. |
| Native-root install feasibility | Implemented | Official docs identify `~/.hermes/skills` as the primary source of truth and document creating a skill by writing a directory containing `SKILL.md`; V2.95 supports confirmed local ToolGlobal copy into that native root. |
| Writable toggle feasibility | Blocked | There is no verified rollback-safe individual skill toggle schema for Hermes skills. |

## 2. Fixture Scope

Fixture files under `fixtures/hermes/` cover the V2.17 read-only scanner plus evidence-only cron samples:

- `fixtures/hermes/README.md`
- `fixtures/hermes/active-home/.hermes/skills/nested/research-brief/SKILL.md`
- `fixtures/hermes/active-home/.hermes/skills/broken/malformed-metadata/SKILL.md`
- `fixtures/hermes/active-home/.hermes/.env`
- `fixtures/hermes/active-home/.hermes/auth.json`
- `fixtures/hermes/active-home/.hermes/cron/jobs.json`
- `fixtures/hermes/active-home/.hermes/logs/session.log`
- `fixtures/hermes/service-evidence/cron-jobs.sample.json`

The cron fixture is a minimal shape derived from the local `hermes-ops` doc's cron guidance. It is not a parser contract and must not be mapped to `SkillInstance`.

## 3. Adapter Mapping Status

Read-only skill mapping is approved for active/profile Hermes home only.

| Shared field | Status |
| --- | --- |
| `AgentId` | Implemented as `hermes`. |
| `Scope::AgentGlobal` | Implemented for active/profile Hermes home `~/.hermes/skills/**/SKILL.md`. |
| `Scope::AgentProject` | Blocked for generic project-local discovery; `skills.external_dirs` may later be modeled as explicit external roots, not automatic project roots. |
| `SkillInstance.name` | Implemented as required YAML frontmatter `name`; malformed metadata becomes a broken record. |
| `SkillInstance.description` | Implemented as required YAML frontmatter `description`. |
| `SkillInstance.enabled` | Implemented as default enabled for discovered valid skills; no config-derived disable state is inferred. |
| Native skill-file installs | Implemented for confirmed local ToolGlobal `SKILL.md` copy into `~/.hermes/skills` only. |
| Config writes | Blocked: no verified Hermes config toggle target. |

## 4. Required Maintainer Evidence

- Hermes product docs or maintainer-provided local config samples.
- Whether Hermes exposes skills, service tasks, commands, cron jobs, or another unit that should be modeled as `SkillInstance`.
- Exact discovery roots and inheritance rules for any skill-like unit.
- File/directory format, metadata schema, required fields, malformed-case behavior, and conflict behavior.
- Config file path/schema for individual skill enable/disable writes.
- Enable/disable semantics, including whether disabling requires config patching, CLI calls, cron changes, per-platform state, or is unsupported.
- Safe rollback procedure for config toggle write paths.

Until toggle evidence exists, Hermes remains install-only for native-root local skill-file copies. Generic project scan, project install, external_dirs writes, hub/URL/tap/update/uninstall/reset operations, config toggles, and network-backed installs must stay disabled.

Project scope decision: Hermes does not currently have verified generic project-local skill discovery. The first scanner must ignore arbitrary project roots and scan only the active/profile Hermes home. `skills.external_dirs` can be evaluated later as explicit external read-only roots, and `cron.workdir` is execution context, not a skill root.

## 5. 2026-06-10 P0 Evidence Update

Confirmed sources:

- Official docs: https://hermes-agent.nousresearch.com/docs/
- Skills system: https://hermes-agent.nousresearch.com/docs/user-guide/features/skills
- Working with skills: https://hermes-agent.nousresearch.com/docs/guides/work-with-skills
- Creating skills: https://hermes-agent.nousresearch.com/docs/developer-guide/creating-skills
- CLI commands: https://hermes-agent.nousresearch.com/docs/reference/cli-commands
- GitHub repository: https://github.com/NousResearch/hermes-agent

Read-only macmini checks confirmed:

- Hermes CLI exists at `~/.local/bin/hermes`.
- Version observed: `Hermes Agent v0.16.0 (2026.6.5)`.
- Active Hermes home contains `config.yaml`, `.env`, `auth.json`, `cron/jobs.json`, `logs/`, and `skills/`.
- Active Hermes home contains many nested `skills/**/SKILL.md` files.

Implementation policy:

- First scanner slice may parse `name`, `description`, optional Hermes metadata, raw frontmatter, path, and source.
- Skip secrets, `.env`, `auth.json`, logs, and cron job content.
- Do not map cron jobs to `SkillInstance`.
- Do not enable config toggle support until individual skill disable/re-enable schema and rollback-safe writes are verified.

## 6. V2.17 Implementation Notes

- Adapter module: `crates/adapters/src/hermes/`.
- Scan root: `ctx.user_home/.hermes/skills` only, scoped as `agent-global`.
- No `project_root`, `project_cwd`, or `extra_roots` are consumed by the Hermes adapter.
- `config_paths` returns no paths so Hermes config snapshot/toggle flows remain blocked.
- `catalog.scanAll` includes Hermes after OpenClaw in the supported read-only scan set.

## 7. V2.95 Implementation Notes

- `skill.install` supports `AgentId::Hermes` only with
  `Scope::AgentGlobal`.
- The target path is `ctx.user_home/.hermes/skills/<skill-name>/SKILL.md`.
- Source records must remain ToolGlobal local `SKILL.md` records and still pass
  the existing source validation, target validation, lock, atomic write, and
  readback verification path.
- Hermes project installs remain blocked because generic project-local
  discovery is not confirmed.
- Hermes explicit `skills.external_dirs` roots remain read-only scan roots and
  are not install targets.
- Hermes hub, URL, tap, update, uninstall, reset, and network-backed package
  operations remain out of scope for this app.
