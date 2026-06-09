# Hermes Adapter Spec Worklist

> Status: P0 evidence update on 2026-06-10. Hermes Agent has confirmed first-class skills and is now a read-only scanner candidate. Writable toggle/install remain blocked.

## 1. Evidence Summary

Sources checked:

- Local skill doc: `$HOME/.agents/skills/hermes-ops/SKILL.md`.
- Local machine checks: `command -v hermes`, `ls -ld "$HOME/.hermes"`.

No adapter code has been added yet. P0 evidence used public Hermes Agent docs plus read-only `ssh macmini` checks to confirm the product identity and local skill layout.

| Area | Status | Evidence |
| --- | --- | --- |
| Product identity | Confirmed | Official docs identify this as Nous Research Hermes Agent, not the Meta/Facebook Hermes JavaScript engine. |
| Local availability | Not installed locally | `command -v hermes` returned no local executable in this worktree session. `$HOME/.hermes` was not present in the inspected environment. |
| Skill-like unit | Confirmed | Official docs and macmini checks confirm first-class skills as directories containing `SKILL.md`. |
| Config path/schema | Partial service evidence | The doc mentions `<hermes-home>/cron/jobs.json` and generic `hermes config validate`, but no full schema, version, or user-local config path is provided. |
| Enable/disable semantics | Cron-only evidence | The doc says cron job entries should be disabled with `enabled: false` rather than deleted. Treat this only as cron task management evidence, not skill enable/disable semantics. |
| Read-only catalog feasibility | Candidate after P0 evidence | Official docs and macmini checks confirm first-class skills under active Hermes home `skills/**/SKILL.md`. |
| Writable adapter feasibility | Blocked | There is no verified rollback-safe individual skill toggle schema for Hermes skills. |

## 2. Fixture Scope

Fixture files under `fixtures/hermes/` are evidence samples only:

- `fixtures/hermes/README.md`
- `fixtures/hermes/service-evidence/cron-jobs.sample.json`

The cron fixture is a minimal shape derived from the local `hermes-ops` doc's cron guidance. It is not a parser contract and must not be used to implement a Hermes adapter without maintainer confirmation.

## 3. Adapter Mapping Status

No mapping is approved yet.

| Shared field | Status |
| --- | --- |
| `AgentId` | Reserved as `hermes` in planning docs only. |
| `Scope::AgentGlobal` | Blocked: no verified local skill root. |
| `Scope::AgentProject` | Blocked: no verified project inheritance behavior. |
| `SkillInstance.name` | Blocked: unknown whether Hermes has skills, commands, jobs, or tasks with stable names. |
| `SkillInstance.description` | Blocked. |
| `SkillInstance.enabled` | Blocked: cron `enabled: false` may not apply to skills. |
| Config writes | Blocked: no verified Hermes config schema or toggle target. |

## 4. Required Maintainer Evidence

- Hermes product docs or maintainer-provided local config samples.
- Whether Hermes exposes skills, service tasks, commands, cron jobs, or another unit that should be modeled as `SkillInstance`.
- Exact discovery roots and inheritance rules for any skill-like unit.
- File/directory format, metadata schema, required fields, malformed-case behavior, and conflict behavior.
- Config file path/schema and whether writes are supported.
- Enable/disable semantics, including whether disabling requires config patching, CLI calls, cron changes, or is unsupported.
- Safe rollback procedure for any write path.

Until writable evidence exists, Hermes should be implemented only as a scoped read-only scanner. Project scan, install, toggle, and writable actions must stay disabled.

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
