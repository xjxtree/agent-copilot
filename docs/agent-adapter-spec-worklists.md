# Agent Adapter Spec Worklists

> Status: V2.1-V2.96 is the synchronized completed baseline.
> V2.92 expands Codex read-only roots and diagnostics without expanding writes.
> V2.93 adds opencode configured local `skills.paths` scanning without URL
> fetching or configured-root writes.
> V2.94 adds Pi `.agents/skills` compatibility scanning/toggles and native-root
> installs without package install/remove or `.agents` direct installs.
> V2.95 adds Hermes native `~/.hermes/skills` tool-global installs without
> config toggles, project installs, external_dirs writes, hub/URL/tap/update/
> uninstall/reset, or uncontrolled network fetch.
> V2.96 adds OpenClaw native `~/.openclaw/skills` and confirmed workspace
> `<workspace>/skills` tool-global installs without `.agents` direct installs,
> config toggles, `skills.entries` writes, ClawHub/Git/update/verify/workshop,
> or network-backed operations.
> opencode writable, Pi read-only scan, Pi guarded native toggle,
> OpenClaw read-only scan plus install-only native/workspace support,
> Hermes read-only scan, and Hermes explicit external-root scan are
> implemented.
> Pi package install/remove, Hermes config toggles, and OpenClaw config-toggle
> support remain blocked.
> Real local UI validation is version-specific and recorded in the matching verification checklist.
> Future user-visible, UI, or service-protocol candidates still require a fresh real local pass
> or explicit tool/session blocker.
> This document records what is verified enough to use for project instructions, and what is still missing before an adapter can be built.

## Current Rule

Claude Code remains the mature baseline adapter.
Codex has verified user/project roots, cwd-to-repo-root discovery,
project-context-scoped scanning, read-only `$CODEX_HOME/skills`, local plugin
marketplace, and `/etc/codex/skills` diagnostics, plus user-config writable
toggles only for native `.agents/skills` instances.
Opencode writable is enabled through managed `permission.skill` overrides;
opencode install targets remain native roots. Opencode configured local
`skills.paths` roots are scan-only; `skills.urls` is metadata-only/no-fetch.

Pi production direct install is limited to native `~/.pi/agent/skills` and
project `.pi/skills` roots. Production toggle supports V2.37 native roots and
V2.94 `.agents/skills` compatibility roots through guarded Pi settings writes
after V2.36/V2.94 disposable evidence passed.
Hermes is install-only for confirmed native-root local ToolGlobal `SKILL.md`
copies. OpenClaw is install-only for confirmed native/workspace local
ToolGlobal `SKILL.md` copies; config toggles stay blocked.

V2.95 的 Hermes 写入约束：

- tool-global install 仅写 native `~/.hermes/skills`。
- config toggle、per-platform enablement、project install、external_dirs write
  仍 blocked。
- hub / URL / tap / update / uninstall / reset / network-backed package
  operation 仍 blocked。
- 不执行脚本，不进行 AI 自动写回，不读取或保存 credentials。

V2.96 的 OpenClaw 写入约束：

- tool-global install 仅写 native `~/.openclaw/skills` 和 confirmed
  workspace `<workspace>/skills`。
- `.agents` roots 仅扫描，不作为 direct install target。
- config toggle、`skills.entries` write、ClawHub / Git / update / verify /
  workshop / network-backed operation 仍 blocked。
- 不执行脚本，不进行 AI 自动写回，不读取或保存 credentials。

The macOS app uses the service/UI adapter capability matrix as the front-door
status surface for all six agents. The matrix must make read-only,
install-only, planned, and blocked states explicit before any future write
affordance is exposed.

V2.94 的 Pi 写入约束：

- 仅启用 guarded native / `.agents` compatibility enable-disable 切换。
- tool-global install 仅写 native `~/.pi/agent/skills` 和 project `.pi/skills`。
- package install/remove 仍 blocked。
- 不执行脚本，不进行 AI 自动写回，不保存 credentials。
- `.agents/skills` 兼容根只允许通过 Pi settings toggle，不作为直接 skill-file install target。

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
| Skill discovery roots | Verified native roots: repository `.agents/skills` from CWD to repo root, and user `$HOME/.agents/skills`. V2.92 also scans read-only `$CODEX_HOME/skills`, local plugin marketplace skill roots, and `/etc/codex/skills` when present. Do not infer any of this from `AGENTS.md`. |
| Read-only expanded roots | `$CODEX_HOME/skills`, plugin marketplace roots, admin roots, and system roots are diagnostics/scan-only. They must not become config-toggle, install, snapshot, rollback, hook, MCP, or network-fetch targets without a new evidence pass. |
| Config path/schema | Verified for user writes: official docs and local CLI confirm user config at `~/.codex/config.toml` / `$CODEX_HOME/config.toml` with `[[skills.config]] path = ".../SKILL.md"; enabled = false`. Local CLI did not honor the folder-path form for disabling, so use absolute `SKILL.md` paths. |
| Enable/disable semantics | Verified for user config: user config can disable user and project skills by absolute `SKILL.md` path, and removing all matching entries re-enables default discovery. Project-local `.codex/config.toml` did not disable a project skill, even when the repo was trusted. |
| Fixture requirement | Minimal evidence fixtures added under `fixtures/codex/`. |
| Implementation decision | Complete through V2.92. Current code supports adapter context `project_cwd` walking upward to `project_root`, read-only expanded roots, and a native `.agents/skills` write allowlist through the user config override. Project-local writable toggles and plugin/admin/system/compat writes remain blocked. |

Required next evidence:

- Resolve project-local toggle behavior; local `codex-cli 0.137.0` did not honor project `.codex/config.toml` `[[skills.config]]` for the tested fixture.
- Keep future Codex changes within the implemented scope unless a new evidence pass expands it: project-local config writes, `/etc/codex/skills`, `$CODEX_HOME/skills`, plugin-distributed skills, and system skills remain out of writable scope.

## Pi Coding Agent

| Area | Status |
| --- | --- |
| Evidence spec | Added: [`docs/pi-adapter-spec.md`](./pi-adapter-spec.md). |
| Local distribution | Locally observed on 2026-06-08: `pi --version` returned `0.78.1`; `$HOME/.pi/agent/`, `$HOME/.pi/agent/skills/`, and `$HOME/.pi/agent/settings.json` exist. Local settings were not read or modified. |
| Project instruction entrypoint | Verified from official Pi SDK docs: default resource discovery includes `AGENTS.md` context files walking up from `cwd`; project trust affects whether project-local inputs are loaded. |
| Extension discovery | Verified as a separate Pi concept: global `~/.pi/agent/extensions/`, project `.pi/extensions/`, and settings/package extension paths. Extensions are not skills and must not be mapped into `SkillInstance` without a product decision. |
| Skill discovery roots | Verified from official Pi docs for read-only planning: global `~/.pi/agent/skills/` and `~/.agents/skills/`; project `.pi/skills/` and `.agents/skills/` from `cwd`/ancestors. Pi also supports settings/package skill paths. |
| Skill file/directory format | Verified: directories with `SKILL.md` are discovered recursively. Direct root `.md` files may be agent-visible in Pi-native roots, but Skills Copilot intentionally does not catalog them after real local validation showed they include many ordinary resource documents. Required frontmatter for cataloged `SKILL.md`: `name`, `description`. |
| Config path/schema | Partially verified from official docs, local path existence, V2.36 disposable evidence, and V2.94 compatibility-root coverage: global Pi settings and project `.pi/settings.json`; resource arrays include `packages`, `extensions`, `skills`, `prompts`, `themes`, and `enableSkillCommands`. V2.94 product writes use guarded service-selected global/project settings targets. |
| Enable/disable semantics | V2.94 verified guarded slice: local disable writes only the supported disabled-skill collection shape (`skills.disabled` / `disabledSkills`) and re-enable removes the disabled entry. Project/package writes require trusted project settings; `.agents/skills` compatibility instances can be toggled through Pi settings. |
| Fixture requirement | Minimal evidence fixtures added under `fixtures/pi/`. They are evidence samples, not parser contract fixtures. |
| Implementation decision | Scanner/parser is implemented for Pi-native and `.agents/skills` compatibility directory skills under `SKILL.md`; V2.94 implements guarded toggle for native and compatibility instances plus native-root direct install. Package install/remove, `.agents` direct installs, script execution, AI write-back, and credentials storage remain blocked; direct root `.md` cataloging remains intentionally excluded after real local validation showed ordinary resource noise. |

Required next evidence:

- Keep V2.94 product behavior inside the verified guarded scope and add new
  evidence before expanding into package install/remove, remote/package resource
  mutation, `.agents` direct installs, or arbitrary compatibility roots.
- Decide UI semantics for `disable-model-invocation`: hidden from automatic model invocation, but still callable through `/skill:name`.
- Promote `fixtures/pi/` from evidence samples to parser fixtures only after a
  future evidence pass requires broader package/resource mutation coverage.

## opencode

| Area | Status |
| --- | --- |
| Evidence spec | Added: [`docs/opencode-adapter-spec.md`](./opencode-adapter-spec.md). |
| Local distribution | Locally observed on 2026-06-08: `opencode --version` returned `1.16.2`; `$HOME/.config/opencode/`, `$HOME/.config/opencode/skills/`, and `$HOME/.config/opencode/opencode.json` exist. Local config was not read or modified. |
| Project instruction entrypoint | Verified: opencode uses `AGENTS.md` for project rules and falls back to `CLAUDE.md` only when `AGENTS.md` is absent. |
| Agent definitions | Public docs describe opencode agent configuration and prompt files. Agents are not the same as this app's Skill model. |
| Command definitions | Public docs describe custom commands under opencode command locations. Commands are not needed for the skill adapter evidence gate. |
| Skill discovery roots | Current implementation scans official OpenCode roots: global/project `.opencode/skills`, `.claude/skills`, and `.agents/skills`, walking project roots from `project_cwd` upward to `project_root`; V2.93 also scans configured local `skills.paths` roots from readable JSON/JSONC opencode config. |
| Skill file/directory format | Verified: one folder per skill name with `SKILL.md`; required YAML frontmatter fields `name` and `description`; `name` must match the containing directory. Missing `name`, missing `description`, or name/directory mismatch should produce broken records rather than aborting the scan. |
| Config path/schema | Partially verified from official docs, schema, source evidence, and local path existence: global `~/.config/opencode/opencode.json` / `opencode.jsonc`, project `opencode.json` / `opencode.jsonc`, `.opencode` directories, `skills.paths`, `skills.urls`, and custom/managed config paths. |
| Enable/disable semantics | Partially documented but not writable-verified: pattern permissions under `permission.skill` support `allow`, `deny`, and `ask`; `deny` hides/rejects a skill. Exact write and re-enable semantics remain unverified. |
| Fixture requirement | Parser/scan contract fixtures promoted under `fixtures/opencode/`: valid global, valid project, nested project root, name mismatch, missing description, and missing name. The config fixture remains writable-evidence only. |
| Implementation decision | Native, compatibility, and configured local `skills.paths` roots are scanned. Writable config is guarded through exact `permission.skill` rules; tool-global installs remain limited to native opencode roots. `skills.urls` remains metadata-only/no-fetch. |

Required next evidence:

- Keep disposable local verification scoped to temporary `HOME`, `XDG_CONFIG_HOME`, `OPENCODE_CONFIG_DIR`, and fixture projects. The 2026-06-08 `opencode debug skill --pure` check confirmed synthetic native global/project/nested project skills were listed without reading or modifying real config.
- Capture exact config patch behavior for disabling one skill by exact name, re-enabling that skill, and resolving wildcard/exact-name conflicts.
- Keep configured local `skills.paths` read-only and covered by canonicalization/dedupe/project-boundary tests before expanding it.
- Scope a separate confirmation/cache/rollback design before any `skills.urls` fetch support is considered.
- Decide UI semantics for `ask`; it is neither fully enabled nor disabled.
- Verify behavior when managed config or `OPENCODE_CONFIG_CONTENT` overrides local writable config.

## Hermes

Project scope decision: Hermes has no confirmed generic project-level skills. The first read-only slice is limited to active/profile Hermes home `skills/**/SKILL.md`; explicit `skills.external_dirs` may be modeled later as external roots, not project roots.

V2.17 verifier checklist for this read-only phase:
- Scan only active/profile Hermes home `skills/**/SKILL.md`.
- No generic project scans.
- `skills.external_dirs` is modeled as explicit external roots, not auto scan roots.
- Exclude `.env`, `auth.json`, `logs`, `cron/jobs.json`, and cron task entries from `SkillInstance` mapping.
- No `hermes` CLI calls in read-only catalog scanning.
- Writable toggles/install remain blocked.

| Area | Status |
| --- | --- |
| Public product identity | Confirmed by official Nous Hermes Agent docs and read-only macmini evidence. |
| Skill discovery roots | Implemented read-only: active/profile Hermes home `skills/**/SKILL.md`. Generic project-local discovery is not confirmed; `skills.external_dirs` is an explicit external-root concept, not automatic project scope. |
| Config path/schema | Service evidence only: public docs describe `config.yaml` skill settings and per-platform management through Hermes UI/CLI, but no rollback-safe individual skill enable/disable schema is verified for this app. |
| Enable/disable semantics | Service cron evidence only: docs say cron jobs may be disabled with `enabled: false` rather than deleted. This is not verified as Hermes skill enable/disable behavior. |
| Fixture requirement | Scanner fixtures added under `fixtures/hermes/active-home/`; cron fixture remains evidence-only and not a parser contract. |
| Implementation decision | V2.17 implements read-only scanning for active Hermes home `skills/**/SKILL.md`; V2.38 models explicit `skills.external_dirs` as read-only external roots; V2.95 supports confirmed local ToolGlobal `SKILL.md` copy into native `~/.hermes/skills`. Config toggles, project installs, external_dirs writes, hub/URL/tap/update/uninstall/reset, and network-backed operations remain blocked. |

Required next evidence:

- Maintainer-provided docs or local config samples for Hermes itself.
- Whether Hermes exposes local skills, service tasks, commands, cron jobs, or another unit that should map to `SkillInstance`.
- If cron jobs are in scope, a documented `jobs.json` schema, stable ID/name fields, enable/disable semantics, and rollback-safe config path.
- If skills are in scope, exact skill package format, root discovery behavior, malformed-case behavior, and fixture data.
- Writable toggle policy: whether disabling means patching config, patching cron jobs, calling a CLI/TUI state, or read-only display only.

## OpenClaw

Project scope decision: OpenClaw project semantics are workspace-scoped only. Treat `<workspace>/skills` and `<workspace>/.agents/skills` as project roots only for a confirmed OpenClaw workspace; do not infer arbitrary repository roots or `.openclaw/skills`.

| Area | Status |
| --- | --- |
| Public product identity | Partially observed from local OpenClaw-related skill docs: OpenClaw is described as an AI assistant and automation platform with plugins, gateway restart, and skill/package scanning workflows. |
| Skill discovery roots | Confirmed read-only scope from official docs and read-only macmini evidence: native `~/.openclaw/skills`, shared `~/.agents/skills`, bundled roots, and workspace roots `<workspace>/skills` / `<workspace>/.agents/skills`, with no arbitrary repository inference. Project scope is workspace-scoped only. |
| Skill file/directory format | Partial read-only evidence: the local security-scan skill expects skill directories containing `SKILL.md`, extracts `name:` from YAML frontmatter, and falls back to the directory basename. This is script input evidence, not a full product spec. |
| Config path/schema | Partial evidence only: local plugin docs use `openclaw config file` to locate `openclaw.json`; a user-local `~/.openclaw/openclaw.json` exists on this machine but is JSONC/non-strict JSON and was not copied because it may contain credentials. |
| Enable/disable semantics | Plugin evidence only: local Tablestore Mem0 docs patch `.plugins.entries["openclaw-mem0"].enabled = true`, `.plugins.slots.memory`, and `.plugins.allow`. This does not verify skill enable/disable semantics. |
| Fixture requirement | Minimal evidence fixtures added under `fixtures/openclaw/`, marked as read-only evidence samples plus V2.96 install-only boundary; config samples remain not writable toggle contract. |
| Implementation decision | Read-only filesystem scanner over documented roots is implemented. V2.96 supports confirmed local ToolGlobal installs into native `~/.openclaw/skills` and confirmed workspace `<workspace>/skills`. Config toggles, `skills.entries` writes, `.agents` direct installs, ClawHub/Git/update/verify/workshop, and network-backed operations remain blocked until config mutation, credential preservation, and rollback behavior are verified. |

Required next evidence:

- Maintainer-provided docs or config samples for credential-safe `openclaw.json` / `skills.entries` patching.
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

## OpenClaw Workspace-Scoped Scope Clarification (V2.39 completed)

- V2.39 OpenClaw deepening is limited to confirmed workspace roots only: `<workspace>/skills` and `<workspace>/.agents/skills`.
- No inference of arbitrary repo roots or additional workspace roots should be used.
- V2.96 adds install-only support for native `~/.openclaw/skills` and
  confirmed workspace `<workspace>/skills`.
- OpenClaw remains config-toggle blocked: no `.agents` direct install,
  `skills.entries` write, ClawHub/Git/update/verify/workshop/network-backed
  operation, script execution, AI auto-write, or credential write.
- This scope is the completed V2.39 scanner and V2.96 install-only boundary.

## 2.5 V2.40 Adapter diagnostics

- **状态**：完成；已作为 read-only protocol/status/state/UI 诊断能力集成。
- **目标**：为每个适配器补齐可执行诊断视图，支持只读核验：
  - `discovered / skipped / blocked` 根目录分类与来源；
  - 适配器配置是否检测到（来源、命名路径、有效性）；
  - 逐根目录读写能力说明（只读或可写）与阻断原因；
  - 每次扫描的活动信息（上次扫描时间、状态、耗时、失败原因）。
- **验证结果**：focused Rust/Swift checks、`pnpm check:macos`、真实 app smoke launch/window id、`pnpm check:privacy` 与截图人工检查通过；Computer Use/AX/capture 仍返回 `cgWindowNotFound` / 0 visible windows，作为工具/窗口 blocker 记录。
- **边界**：仅读取型诊断，不产生写入、不执行脚本、不发起 AI 自动写回，不涉及凭据读取/保存。
