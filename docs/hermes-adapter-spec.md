# Hermes Adapter Spec Worklist

> Status: local evidence collected on 2026-06-08. Do not implement a Hermes adapter yet: no maintainer-provided skill/package layout, discovery roots, config schema, or skill toggle semantics are verified.

## 1. Evidence Summary

Sources checked:

- Local skill doc: `$HOME/.agents/skills/hermes-ops/SKILL.md`.
- Local machine checks: `command -v hermes`, `ls -ld "$HOME/.hermes"`.

No adapter code was added and no remote `ssh macmini` commands were run.

| Area | Status | Evidence |
| --- | --- | --- |
| Product identity | Service evidence only | `hermes-ops` describes Hermes as a hosted service with a user-local CLI, home directory, repository, and logs under a Hermes home path. |
| Local availability | Not installed locally | `command -v hermes` returned no local executable in this worktree session. `$HOME/.hermes` was not present in the inspected environment. |
| Skill-like unit | Not verified | The observed doc is itself a Codex/agent skill for operating Hermes. It does not prove Hermes has a local skill concept, a `SKILL.md` package format, or roots that should be scanned by skills-copilot. |
| Config path/schema | Partial service evidence | The doc mentions `<hermes-home>/cron/jobs.json` and generic `hermes config validate`, but no full schema, version, or user-local config path is provided. |
| Enable/disable semantics | Cron-only evidence | The doc says cron job entries should be disabled with `enabled: false` rather than deleted. Treat this only as cron task management evidence, not skill enable/disable semantics. |
| Read-only catalog feasibility | Blocked | There is no verified local Hermes skill directory or task schema that maps safely to `SkillInstance`. |
| Writable adapter feasibility | Blocked | There is no verified rollback-safe config path or toggle semantic for Hermes skills. |

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

Until those items exist, Hermes should remain documented as blocked/read-only evidence only.
