# OpenClaw Adapter Spec Worklist

> Status: P0 evidence update on 2026-06-10. OpenClaw is now a read-only scanner candidate. Writable toggle/install remain blocked.

## 1. Evidence Summary

Sources checked:

- Local skill doc: `$HOME/.agents/skills/alibabacloud-openclaw-skill-security-scan/SKILL.md`.
- Local skill doc: `$HOME/.agents/skills/alibabacloud-openclaw-ecs-dingtalk/SKILL.md`.
- Local skill doc: `$HOME/.agents/skills/alibabacloud-tablestore-openclaw-memory/SKILL.md`.
- Local skill doc: `$HOME/.agents/skills/alibabacloud-sas-openclaw-security/SKILL.md`.
- Local machine checks: `command -v openclaw`, `ls -ld "$HOME/.openclaw"`, and redacted structure-only inspection of `$HOME/.openclaw/openclaw.json`.

V2.16 adds a read-only filesystem scanner. P0 evidence used official docs plus read-only `ssh macmini` checks. No OpenClaw list/check/install/restart/security scan command was run during ordinary scanning.

| Area | Status | Evidence |
| --- | --- | --- |
| Product identity | Partial local-doc evidence | `alibabacloud-openclaw-ecs-dingtalk` describes OpenClaw as an AI assistant and automation platform with chat integration. |
| Local availability | Config present, CLI absent | `command -v openclaw` returned no executable. `$HOME/.openclaw` and `$HOME/.openclaw/openclaw.json` existed in the inspected environment. The file is not strict JSON and was not copied because it may contain credentials. |
| Skill roots | Partial read-only evidence | The security-scan skill lists standard directories: `$HOME/.openclaw/skills`, `$HOME/.openclaw/workspace`, `$HOME/.openclaw/extensions`, `$HOME/openclaw/workspace`, `/usr/lib/node_modules/openclaw/skills`, `/usr/local/lib/node_modules/openclaw/skills`, and `/opt/jvs-claw/base/lib/node_modules/openclaw/skills`. It also mentions `openclaw skills list --eligible`. |
| Skill package format | Partial script-input evidence | The security-scan skill expects each skill path to be a directory containing `SKILL.md`; it reads the YAML `name:` field and falls back to the directory basename. This is evidence for one script workflow, not a complete OpenClaw adapter spec. |
| Config path/schema | Partial plugin evidence | The Tablestore Mem0 skill detects config with `openclaw config file` and patches `openclaw.json`. It writes plugin fields under `.plugins.slots`, `.plugins.entries`, `.plugins.entries["openclaw-mem0"].enabled`, and `.plugins.allow`. |
| Enable/disable semantics | Blocked | Plugin `enabled: true` evidence does not prove OpenClaw skill enable/disable behavior. It is unknown whether skills can be disabled without deleting files, whether `.plugins.allow` is an allow-list, and whether a CLI command is required. |
| Read-only catalog feasibility | Candidate after P0 evidence | Official docs confirm roots, `SKILL.md` schema, loading order, precedence, and JSON list commands. |
| Writable adapter feasibility | Blocked | Config mutation, credential preservation, and rollback-safe writes are not verified. |

## 2. Fixture Scope

Fixture files under `fixtures/openclaw/` now include V2.16 read-only scanner contract samples plus evidence-only config samples:

- `fixtures/openclaw/README.md`
- `fixtures/openclaw/skill-evidence/sample-openclaw-skill/SKILL.md`
- `fixtures/openclaw/config/openclaw.plugins.redacted.sample.json`

The `SKILL.md` fixtures cover parser and root-scope behavior for the read-only scanner. The config fixture models only the plugin fields seen in local docs; it must not be treated as skill toggle contract.

## 3. Adapter Mapping Status

Read-only filesystem mapping is approved for V2.16. Writable mapping remains blocked.

| Shared field | Status |
| --- | --- |
| `AgentId` | Implemented as `openclaw`. |
| `Scope::AgentGlobal` | Implemented read-only for documented roots such as `~/.openclaw/skills`, `~/.agents/skills`, and bundled package skill roots. |
| `Scope::AgentProject` | Implemented read-only only for confirmed OpenClaw home workspace roots: `<workspace>/skills` and `<workspace>/.agents/skills`; arbitrary repo roots are not OpenClaw projects. |
| `SkillInstance.name` | Implemented as YAML frontmatter `name:` with directory basename fallback. |
| `SkillInstance.description` | Implemented as optional YAML frontmatter `description`; missing descriptions stay visible with an empty description. |
| `SkillInstance.enabled` | Blocked: plugin `enabled` is not verified as skill enabled state. |
| Config writes | Blocked: `openclaw.json` can contain credentials and may be JSONC; no safe patch contract is verified. |

## 4. Required Maintainer Evidence

- Official or maintainer-provided docs for OpenClaw skills, root discovery, and `openclaw.json`.
- Whether `openclaw skills list --eligible` is authoritative and whether it has machine-readable output.
- Confirmed global/project roots, plus whether workspace/extensions roots should be scanned.
- Required `SKILL.md` frontmatter fields, malformed-case behavior, and conflict behavior.
- Permission model for skills and plugins.
- Disable/enable semantics for skills: config path, schema, CLI alternatives, default state, read-only fallback behavior, and rollback steps.
- Fixture set covering global, project, disabled/read-only, malformed, and conflict cases.

Ordinary skills-copilot scans must not run OpenClaw cloud intelligence, cloud deep analysis, security audit, plugin install, gateway restart, or Alibaba Cloud CLI workflows.

Until writable evidence exists, OpenClaw should be implemented only as a scoped read-only filesystem scanner. Install, toggle, and writable actions must stay disabled.

Project/workspace scope decision: OpenClaw's project-like layer is workspace-scoped. The first read-only scanner may treat a selected directory as `Scope::AgentProject` only when it is the confirmed OpenClaw workspace or inside one, and then only scan `<workspace>/skills` and `<workspace>/.agents/skills`. Do not invent `.openclaw/skills` project roots and do not scan arbitrary repository roots as OpenClaw projects.

## 5. 2026-06-10 P0 Evidence Update

Confirmed sources:

- Official GitHub: https://github.com/openclaw/openclaw
- Skills docs: https://docs.openclaw.ai/tools/skills
- Skills config docs: https://docs.openclaw.ai/tools/skills-config
- CLI skills docs: https://docs.openclaw.ai/cli/skills

Read-only macmini checks confirmed:

- OpenClaw CLI exists at `/usr/local/bin/openclaw`.
- Version observed: `OpenClaw 2026.5.26 (10ad3aa)`.
- `openclaw skills list --help` advertises `--eligible`, `--json`, and `--verbose`.
- `openclaw config file` points to `~/.openclaw/openclaw.json`.
- Observed roots include workspace skills, managed `~/.openclaw/skills`, personal `~/.agents/skills`, and bundled package skills.
- The config surface contains credential-sensitive fields such as `apiKey`, `token`, and `secret`.

Implementation policy:

- First scanner slice must be filesystem-only and must not call OpenClaw CLI during ordinary scans.
- Parse documented `SKILL.md` directories and frontmatter.
- Add fixtures for documented roots, missing-name fallback, missing description, duplicate name precedence, and bundled-vs-workspace override.
- Keep writable/install blocked until disposable config mutation proves credential-safe rollback.
