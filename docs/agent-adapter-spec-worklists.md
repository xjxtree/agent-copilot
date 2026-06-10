# Agent Adapter Spec Worklists

> Status: Codex first implementation, V2.1 dual adapter experience, V2.2 project context implementation, V2.3 Codex adapter hardening, V2.4 opencode read-only adapter, V2.5 audit hardening, V2.6 adapter changelog tracking, V2.7 LLM gate safety notes, V2.8-V2.10 safety/docs closeout, V2.11 Adapter Capability Matrix, V2.12 opencode writable, V2.13 Pi read-only scanner/parser, V2.14 Hermes evidence-gate closeout, and V2.15 OpenClaw evidence-gate closeout are integrated. V2.36 Pi writable evidence harness is complete and evidence-only; V2.37 guarded Pi toggle is active.
> Real local UI validation passed for the current mainline app on 2026-06-10. Future user-visible, UI, or service-protocol candidates still require a fresh real local pass. opencode writable, Pi read-only scan, OpenClaw read-only scan, and Hermes read-only scan are implemented; Pi/Hermes/OpenClaw writable support remains blocked.
> This document records what is verified enough to use for project instructions, and what is still missing before an adapter can be built.

## Current Rule

Claude Code remains the mature baseline adapter. Codex has verified user/project roots, cwd-to-repo-root discovery, project-context-scoped scanning, and user-config writable toggles. V2.3 hardening added config patch robustness, explicit adapter states, root/config security regressions, and smoke/docs coverage. V2.4 added opencode as a read-only adapter for native roots; current opencode scan also follows official `.claude` / `.agents` compatibility roots.

Pi production install remains blocked; production toggle is only entering V2.37 as an evidence-backed guarded slice after V2.36 disposable evidence passed. Opencode writable is enabled through managed `permission.skill` overrides after V2.12 validation; opencode install targets remain native roots. Pi read-only scan is enabled for native roots after V2.13 validation. P0 evidence on 2026-06-10 promoted Hermes and OpenClaw from fully blocked to read-only scanner scope; OpenClaw read-only scan is enabled after V2.16 and Hermes read-only scan is enabled after V2.17, while writable/install stay blocked.

The macOS app now uses the service/UI adapter capability matrix as the front-door status surface for all six agents. The matrix must make read-only, planned, and blocked states explicit before any future write affordance is exposed.

Codex, Pi, Hermes, OpenClaw, and opencode must not be implemented from guessed paths or inferred config semantics. A new adapter needs verified evidence for:

- skill discovery roots
- skill file/directory format
- project inheritance behavior
- config file path and schema
- enable/disable semantics
- fixture data
- read-only fallback behavior when toggle semantics are absent

## Codex

| Area | Status |
| --- | --- |
| Project instruction entrypoint | Verified: Codex reads `AGENTS.md` and supports project/nested instruction files. |
| Skill file/directory format | Verified from official Codex Agent Skills docs: each skill is a directory with required `SKILL.md`, `name`, and `description`; optional `scripts/`, `references/`, `assets/`, and `agents/openai.yaml` may exist. Missing required frontmatter should produce a broken/malformed skill record, not abort scanning. |
| Skill discovery roots | Verified for first implementation read-only scanning: repository `.agents/skills` from CWD to repo root, and user `$HOME/.agents/skills`. Do not infer any of this from `AGENTS.md`. |
| Blocked/deferred roots | `/etc/codex/skills` is official but not locally validated; `$CODEX_HOME/skills` was locally observed but is not the official user authoring root; plugin/system bundled skills need a separate product decision. Do not scan these in the first implementation slice. |
| Config path/schema | Verified for user writes: official docs and local CLI confirm user config at `~/.codex/config.toml` / `$CODEX_HOME/config.toml` with `[[skills.config]] path = ".../SKILL.md"; enabled = false`. Local CLI did not honor the folder-path form for disabling, so use absolute `SKILL.md` paths. |
| Enable/disable semantics | Verified for user config: user config can disable user and project skills by absolute `SKILL.md` path, and removing all matching entries re-enables default discovery. Project-local `.codex/config.toml` did not disable a project skill, even when the repo was trusted. |
| Fixture requirement | Minimal evidence fixtures added under `fixtures/codex/`. |
| Implementation decision | Complete V2 first implementation; user-config writable only. Current code supports adapter context `project_cwd` walking upward to `project_root`. Project-local writable toggles remain blocked; plugin/admin/system compatibility roots remain out of first scope unless separately approved. |

Required next evidence:

- Restore real local macOS app validation with Computer Use for V2.2/V2.3 when the macOS/AX session can see a SkillsCopilot window; current blocker is a launched app process with no resolvable visible window.
- Resolve project-local toggle behavior; local `codex-cli 0.137.0` did not honor project `.codex/config.toml` `[[skills.config]]` for the tested fixture.
- Decide whether to scan `/etc/codex/skills`, locally observed `$CODEX_HOME/skills`, and plugin-distributed skills in a later slice.
- Keep future Codex changes within the implemented scope unless a new evidence pass expands it: project-local config writes, `/etc/codex/skills`, `$CODEX_HOME/skills`, and plugin-distributed skills remain out of scope.

## Pi Coding Agent

| Area | Status |
| --- | --- |
| Evidence spec | Added: [`docs/pi-adapter-spec.md`](./pi-adapter-spec.md). |
| Local distribution | Locally observed on 2026-06-08: `pi --version` returned `0.78.1`; `$HOME/.pi/agent/`, `$HOME/.pi/agent/skills/`, and `$HOME/.pi/agent/settings.json` exist. Local settings were not read or modified. |
| Project instruction entrypoint | Verified from official Pi SDK docs: default resource discovery includes `AGENTS.md` context files walking up from `cwd`; project trust affects whether project-local inputs are loaded. |
| Extension discovery | Verified as a separate Pi concept: global `~/.pi/agent/extensions/`, project `.pi/extensions/`, and settings/package extension paths. Extensions are not skills and must not be mapped into `SkillInstance` without a product decision. |
| Skill discovery roots | Verified from official Pi docs for read-only planning: global `~/.pi/agent/skills/` and `~/.agents/skills/`; project `.pi/skills/` and `.agents/skills/` from `cwd`/ancestors. Pi also supports settings/package skill paths. |
| Skill file/directory format | Verified: directories with `SKILL.md` are discovered recursively. Direct root `.md` files may be agent-visible in Pi-native roots, but Skills Copilot intentionally does not catalog them after real local validation showed they include many ordinary resource documents. Required frontmatter for cataloged `SKILL.md`: `name`, `description`. |
| Config path/schema | Partially verified from official docs and local path existence: global `~/.pi/agent/settings.json`, project `.pi/settings.json`; resource arrays include `packages`, `extensions`, `skills`, `prompts`, `themes`, and `enableSkillCommands`. |
| Enable/disable semantics | Partially documented but not writable-verified: `pi config` is the official enable/disable surface for package/local resources, and settings arrays/package filters support exclusions. Exact JSON mutation for direct local skill toggles is not verified. |
| Fixture requirement | Minimal evidence fixtures added under `fixtures/pi/`. They are evidence samples, not parser contract fixtures. |
| Implementation decision | Writable adapter remains blocked. Read-only scanner/parser is implemented for Pi-native directory skills under `SKILL.md`; direct root `.md` cataloging is intentionally excluded after real local validation showed ordinary resource noise. |

Required next evidence:

- Run disposable local verification with a temporary `agentDir` / fixture project to confirm scan and write behavior for `~/.pi/agent/skills`, project `.pi/skills`、project `.agents/skills` in trusted/untrusted contexts.
- Capture exact `pi config` JSON mutations for direct local skills and package skills, and validate:
  - global/project/package toggle semantics
  - rollback proof
  - trust gate behavior (`pi config -l` 及 project trust state) before writing `.pi/settings.json`
  - invalid JSON / malformed settings handling（必须失败并保留文件完整性）
  - re-enable 行为（移除禁用 entry/恢复默认发现）
- Decide whether `.agents/skills` compatibility roots belong to the Pi adapter or to a shared/Codex-compatible adapter to avoid duplicate catalog entries.
- Decide UI semantics for `disable-model-invocation`: hidden from automatic model invocation, but still callable through `/skill:name`.
- Promote `fixtures/pi/` from evidence samples to parser fixtures only after the above evidence is complete.

## opencode

| Area | Status |
| --- | --- |
| Evidence spec | Added: [`docs/opencode-adapter-spec.md`](./opencode-adapter-spec.md). |
| Local distribution | Locally observed on 2026-06-08: `opencode --version` returned `1.16.2`; `$HOME/.config/opencode/`, `$HOME/.config/opencode/skills/`, and `$HOME/.config/opencode/opencode.json` exist. Local config was not read or modified. |
| Project instruction entrypoint | Verified: opencode uses `AGENTS.md` for project rules and falls back to `CLAUDE.md` only when `AGENTS.md` is absent. |
| Agent definitions | Public docs describe opencode agent configuration and prompt files. Agents are not the same as this app's Skill model. |
| Command definitions | Public docs describe custom commands under opencode command locations. Commands are not needed for the skill adapter evidence gate. |
| Skill discovery roots | Current implementation scans official OpenCode roots: global/project `.opencode/skills`, `.claude/skills`, and `.agents/skills`, walking project roots from `project_cwd` upward to `project_root`. |
| Skill file/directory format | Verified: one folder per skill name with `SKILL.md`; required YAML frontmatter fields `name` and `description`; `name` must match the containing directory. Missing `name`, missing `description`, or name/directory mismatch should produce broken records rather than aborting the scan. |
| Config path/schema | Partially verified from official docs and local path existence: global `~/.config/opencode/opencode.json`, project `opencode.json`, `.opencode` directories, and custom/managed config paths. |
| Enable/disable semantics | Partially documented but not writable-verified: pattern permissions under `permission.skill` support `allow`, `deny`, and `ask`; `deny` hides/rejects a skill. Exact write and re-enable semantics remain unverified. |
| Fixture requirement | Parser/scan contract fixtures promoted under `fixtures/opencode/`: valid global, valid project, nested project root, name mismatch, missing description, and missing name. The config fixture remains writable-evidence only. |
| Implementation decision | Native and compatibility roots are scanned. Writable config is guarded through exact `permission.skill` rules; tool-global installs remain limited to native opencode roots. Custom configured skill paths remain deferred. |

Required next evidence:

- Keep disposable local verification scoped to temporary `HOME`, `XDG_CONFIG_HOME`, `OPENCODE_CONFIG_DIR`, and fixture projects. The 2026-06-08 `opencode debug skill --pure` check confirmed synthetic native global/project/nested project skills were listed without reading or modifying real config.
- Capture exact config patch behavior for disabling one skill by exact name, re-enabling that skill, and resolving wildcard/exact-name conflicts.
- Decide in a later slice whether custom configured skill paths should be exposed through opencode after non-destructive evidence confirms their semantics.
- Decide in a later slice whether custom `skills.paths` / `skills.urls` are in scope, and what trust/provenance labels they need.
- Decide UI semantics for `ask`; it is neither fully enabled nor disabled.
- Verify behavior when managed config or `OPENCODE_CONFIG_CONTENT` overrides local writable config.

## Hermes

Project scope decision: Hermes has no confirmed generic project-level skills. The first read-only slice is limited to active/profile Hermes home `skills/**/SKILL.md`; explicit `skills.external_dirs` may be modeled later as external roots, not project roots.

V2.17 verifier checklist for this read-only phase:
- Scan only active/profile Hermes home `skills/**/SKILL.md`.
- No generic project scans.
- `skills.external_dirs` stays a future explicit external-root feature, not an auto scan root.
- Exclude `.env`, `auth.json`, `logs`, `cron/jobs.json`, and cron task entries from `SkillInstance` mapping.
- No `hermes` CLI calls in read-only catalog scanning.
- Writable toggles/install remain blocked.

| Area | Status |
| --- | --- |
| Public product identity | Confirmed by official Nous Hermes Agent docs and read-only macmini evidence. |
| Skill discovery roots | Implemented read-only: active/profile Hermes home `skills/**/SKILL.md`. Generic project-local discovery is not confirmed; `skills.external_dirs` is an explicit external-root concept, not automatic project scope. |
| Config path/schema | Service evidence only: local docs mention `<hermes-home>/cron/jobs.json`, `<hermes-home>/logs/`, a Hermes repository under `<hermes-home>/`, and `hermes config validate`; no schema or user-local config path is verified for this product. |
| Enable/disable semantics | Service cron evidence only: docs say cron jobs may be disabled with `enabled: false` rather than deleted. This is not verified as Hermes skill enable/disable behavior. |
| Fixture requirement | Scanner fixtures added under `fixtures/hermes/active-home/`; cron fixture remains evidence-only and not a parser contract. |
| Implementation decision | V2.17 implements read-only scanning for active Hermes home `skills/**/SKILL.md`. Writable toggle/install remains blocked until individual skill disable schema and rollback-safe writes are verified. |

Required next evidence:

- Maintainer-provided docs or local config samples for Hermes itself.
- Whether Hermes exposes local skills, service tasks, commands, cron jobs, or another unit that should map to `SkillInstance`.
- If cron jobs are in scope, a documented `jobs.json` schema, stable ID/name fields, enable/disable semantics, and rollback-safe config path.
- If skills are in scope, exact skill package format, root discovery behavior, malformed-case behavior, and fixture data.
- Writable toggle policy: whether disabling means patching config, patching cron jobs, calling a CLI, or read-only display only.

## OpenClaw

Project scope decision: OpenClaw project semantics are workspace-scoped only. Treat `<workspace>/skills` and `<workspace>/.agents/skills` as project roots only for a confirmed OpenClaw workspace; do not infer arbitrary repository roots or `.openclaw/skills`.

| Area | Status |
| --- | --- |
| Public product identity | Partially observed from local OpenClaw-related skill docs: OpenClaw is described as an AI assistant and automation platform with plugins, gateway restart, and skill/package scanning workflows. |
| Skill discovery roots | Confirmed read-only scope from official docs and read-only macmini evidence: workspace roots `<workspace>/skills` and `<workspace>/.agents/skills`, global/shared roots, bundled roots, and configured extra dirs. Project scope is workspace-scoped only. |
| Skill file/directory format | Partial read-only evidence: the local security-scan skill expects skill directories containing `SKILL.md`, extracts `name:` from YAML frontmatter, and falls back to the directory basename. This is script input evidence, not a full product spec. |
| Config path/schema | Partial evidence only: local plugin docs use `openclaw config file` to locate `openclaw.json`; a user-local `~/.openclaw/openclaw.json` exists on this machine but is JSONC/non-strict JSON and was not copied because it may contain credentials. |
| Enable/disable semantics | Plugin evidence only: local Tablestore Mem0 docs patch `.plugins.entries["openclaw-mem0"].enabled = true`, `.plugins.slots.memory`, and `.plugins.allow`. This does not verify skill enable/disable semantics. |
| Fixture requirement | Minimal evidence fixtures added under `fixtures/openclaw/`, marked as read-only evidence samples and not writable toggle contract. |
| Implementation decision | Read-only filesystem scanner over documented roots is implemented. Writable adapter and install remain blocked until config mutation, credential preservation, and rollback behavior are verified. |

Required next evidence:

- Maintainer-provided docs or config samples for OpenClaw skill discovery and `openclaw.json`.
- Exact meaning of `openclaw skills list --eligible`, including whether it is authoritative, whether it includes disabled skills, and whether it returns machine-readable output.
- Skill package format, root layout, metadata/frontmatter requirements, malformed-case behavior, and conflict behavior.
- Permission model, if any, and whether plugin permissions differ from skill permissions.
- Toggle semantics and rollback-safe config path: whether disabling a skill is supported, whether plugin `enabled` applies to skills, whether `.plugins.allow` is an allow-list, and whether CLI calls are required.
- Policy decision for cloud/security-scan workflows: the adapter must not trigger OpenClaw cloud scanning or security audit commands during ordinary catalog scans.

## Adapter PR Gate

This is the future gate for non-Claude adapter work. Unchecked items are intentional until a specific adapter enters scope.

Before any non-Claude adapter PR:

- [ ] Add a verified spec section or link from this file.
- [ ] Add fixtures for global, project, disabled/read-only, malformed, and conflict cases.
- [ ] Add scanner/parser tests.
- [ ] Add catalog round-trip tests.
- [ ] Add service contract examples if the UI will expose the adapter.
- [ ] Document whether writes are supported or the adapter is read-only.
- [ ] Run `cargo test --workspace`.

## Sources

- Codex AGENTS.md guide: <https://developers.openai.com/codex/guides/agents-md>
- Codex Agent Skills: <https://developers.openai.com/codex/skills>
- Codex config basics: <https://developers.openai.com/codex/config-basic>
- Pi SDK resource discovery: <https://pi.dev/docs/latest/sdk>
- Pi Skills: <https://pi.dev/docs/latest/skills>
- Pi Settings: <https://pi.dev/docs/latest/settings>
- Pi Extensions: <https://pi.dev/docs/latest/extensions>
- Pi Packages: <https://pi.dev/docs/latest/packages>
- opencode rules: <https://opencode.ai/docs/rules/>
- opencode skills: <https://opencode.ai/docs/skills/>
- opencode config: <https://opencode.ai/docs/config>
- opencode agents: <https://opencode.ai/docs/agents/>
- opencode commands: <https://opencode.ai/docs/commands/>
