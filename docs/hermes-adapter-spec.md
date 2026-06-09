# Hermes Adapter Spec Worklist

> Status: V2.17 read-only scanner implemented on 2026-06-10. Hermes Agent has confirmed first-class skills under active/profile Hermes home. Writable toggle/install remain blocked.

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
| Config path/schema | Partial service evidence | The doc mentions `<hermes-home>/cron/jobs.json` and generic `hermes config validate`, but no full schema, version, or user-local config path is provided. |
| Enable/disable semantics | Cron-only evidence | The doc says cron job entries should be disabled with `enabled: false` rather than deleted. Treat this only as cron task management evidence, not skill enable/disable semantics. |
| Read-only catalog feasibility | Implemented | Official docs and macmini checks confirm first-class skills under active Hermes home `skills/**/SKILL.md`; V2.17 scans only that root. |
| Writable adapter feasibility | Blocked | There is no verified rollback-safe individual skill toggle schema for Hermes skills. |

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
| Config writes | Blocked: no verified Hermes config schema or toggle target. |

## 4. Required Maintainer Evidence

- Hermes product docs or maintainer-provided local config samples.
- Whether Hermes exposes skills, service tasks, commands, cron jobs, or another unit that should be modeled as `SkillInstance`.
- Exact discovery roots and inheritance rules for any skill-like unit.
- File/directory format, metadata schema, required fields, malformed-case behavior, and conflict behavior.
- Config file path/schema and whether writes are supported.
- Enable/disable semantics, including whether disabling requires config patching, CLI calls, cron changes, or is unsupported.
- Safe rollback procedure for any write path.

Until writable evidence exists, Hermes remains only a scoped read-only scanner. Generic project scan, install, toggle, and writable actions must stay disabled.

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
- Do not enable writable support until individual skill disable/re-enable schema and rollback-safe writes are verified.

## 6. V2.17 Implementation Notes

- Adapter module: `crates/adapters/src/hermes/`.
- Scan root: `ctx.user_home/.hermes/skills` only, scoped as `agent-global`.
- No `project_root`, `project_cwd`, or `extra_roots` are consumed by the Hermes adapter.
- `config_paths` returns no paths so Hermes config snapshot/write flows remain blocked.
- `catalog.scanAll` includes Hermes after OpenClaw in the supported read-only scan set.
