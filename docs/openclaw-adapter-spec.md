# OpenClaw Adapter Spec Worklist

> Status: V2.15 evidence-gate closeout on 2026-06-09. Do not implement an OpenClaw adapter yet: read-only discovery has useful clues, but maintainer-confirmed roots, schema, and enable/disable semantics are still missing.

## 1. Evidence Summary

Sources checked:

- Local skill doc: `$HOME/.agents/skills/alibabacloud-openclaw-skill-security-scan/SKILL.md`.
- Local skill doc: `$HOME/.agents/skills/alibabacloud-openclaw-ecs-dingtalk/SKILL.md`.
- Local skill doc: `$HOME/.agents/skills/alibabacloud-tablestore-openclaw-memory/SKILL.md`.
- Local skill doc: `$HOME/.agents/skills/alibabacloud-sas-openclaw-security/SKILL.md`.
- Local machine checks: `command -v openclaw`, `ls -ld "$HOME/.openclaw"`, and redacted structure-only inspection of `$HOME/.openclaw/openclaw.json`.

No adapter code was added, no `openclaw` command was available locally, and no OpenClaw security scan/audit command was run. V2.15 intentionally kept OpenClaw out of `catalog.scanAll`.

| Area | Status | Evidence |
| --- | --- | --- |
| Product identity | Partial local-doc evidence | `alibabacloud-openclaw-ecs-dingtalk` describes OpenClaw as an AI assistant and automation platform with chat integration. |
| Local availability | Config present, CLI absent | `command -v openclaw` returned no executable. `$HOME/.openclaw` and `$HOME/.openclaw/openclaw.json` existed in the inspected environment. The file is not strict JSON and was not copied because it may contain credentials. |
| Skill roots | Partial read-only evidence | The security-scan skill lists standard directories: `$HOME/.openclaw/skills`, `$HOME/.openclaw/workspace`, `$HOME/.openclaw/extensions`, `$HOME/openclaw/workspace`, `/usr/lib/node_modules/openclaw/skills`, `/usr/local/lib/node_modules/openclaw/skills`, and `/opt/jvs-claw/base/lib/node_modules/openclaw/skills`. It also mentions `openclaw skills list --eligible`. |
| Skill package format | Partial script-input evidence | The security-scan skill expects each skill path to be a directory containing `SKILL.md`; it reads the YAML `name:` field and falls back to the directory basename. This is evidence for one script workflow, not a complete OpenClaw adapter spec. |
| Config path/schema | Partial plugin evidence | The Tablestore Mem0 skill detects config with `openclaw config file` and patches `openclaw.json`. It writes plugin fields under `.plugins.slots`, `.plugins.entries`, `.plugins.entries["openclaw-mem0"].enabled`, and `.plugins.allow`. |
| Enable/disable semantics | Blocked | Plugin `enabled: true` evidence does not prove OpenClaw skill enable/disable behavior. It is unknown whether skills can be disabled without deleting files, whether `.plugins.allow` is an allow-list, and whether a CLI command is required. |
| Read-only catalog feasibility | Blocked after V2.15 closeout | There is enough evidence to design questions and fixtures, but not enough to ship a scanner against guessed roots. |
| Writable adapter feasibility | Blocked after V2.15 closeout | No verified skill toggle schema or rollback-safe write path. |

## 2. Fixture Scope

Fixture files under `fixtures/openclaw/` are evidence samples only:

- `fixtures/openclaw/README.md`
- `fixtures/openclaw/skill-evidence/sample-openclaw-skill/SKILL.md`
- `fixtures/openclaw/config/openclaw.plugins.redacted.sample.json`

The `SKILL.md` fixture is a future parser candidate only if maintainers confirm the local-doc evidence as canonical. The config fixture models only the plugin fields seen in local docs; it must not be treated as skill toggle contract.

## 3. Adapter Mapping Status

No mapping is approved yet.

| Shared field | Status |
| --- | --- |
| `AgentId` | Reserved as `openclaw` in planning docs only. |
| `Scope::AgentGlobal` | Blocked: candidate roots are local-doc evidence, not maintainer-confirmed adapter roots. |
| `Scope::AgentProject` | Blocked: no project inheritance behavior is verified. |
| `SkillInstance.name` | Candidate only: YAML frontmatter `name:` or directory basename fallback appears in security-scan docs. |
| `SkillInstance.description` | Candidate only: likely YAML frontmatter, but required/optional status is unknown. |
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

Until maintainer-confirmed evidence exists, OpenClaw remains documented as blocked/evidence-only. The macOS app may show OpenClaw in the capability matrix, but scan, project scan, config snapshot, install, toggle, and writable actions must stay disabled.
