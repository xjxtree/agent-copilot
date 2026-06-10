# AGENTS.md

This file is the shared project instruction entrypoint for coding agents such as Codex, Claude Code, Pi, opencode, and other compatible tools.

## Project State

- Current phase: **V2.31 Cleanup Queue active**。V2.21-V2.30 已收口：scan accuracy/dedupe、finding/conflict 语义、Health/Adapter Capability UX、single-skill Detail 诊断口径、Agent-config timeline、Finding explainability、Skill identity/provenance dedupe、Conflict semantic closeout、Finding triage persistence、AI skill analysis workflow 均已同步到主线。
- V2.28 completed 验收口径：`Conflicts` 仅保留当前/selected/current-agent 的 runtime/name 冲突；跨 agent 的 duplicate name / source overlap / enabled mismatch 只进入 `Analysis`；health 中 `conflict_count` 只能统计同-agent 冲突分组，不可叠加 cross-agent analysis 分组。
- Near-term priority: keep the product focused on skills management, inspection, analysis, and configuration audit. Next work should prioritize V2.31 cleanup queue while preserving V2.27 provenance/identity explainability, V2.28 conflict semantics, V2.29 finding triage persistence, and V2.30 read-only AI skill analysis workflow. Do not reintroduce full-platform UI adaptation, formal signed release/notarization/DMG/ZIP/public distribution, script execution, cloud sync, telemetry, or automatic write paths.
- V2.29 持久化边界：仅在 app-local triage state（catalog/app data）落盘，状态为 `Open` / `Reviewed` / `Ignored` / `Needs follow-up`；finding fingerprint 或受影响实例集合变化后，已持久化 triage 状态回到 `Open`；不写 agent config，不创建 skill-toggle snapshot 与 skill-content snapshot；不执行脚本，不做 AI 写回，不读/写凭据。
- V2.30 分析边界：`llm.prepareSkillAnalysis` 为用户显式触发、selected/batch 级别的 read-only preview；没有后台/周期性分析任务；未启用 provider 时保持本地 prepare/preview；provider 调用仅在未来显式 opt-in 模式下才应发生；AI 输出仅 draft/copy，不持久化 triage；不触发 agent-config/文件写入、snapshot 创建或 script execute。
- V2.11 scope: service/UI adapter capability matrix for Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw, exposing scan/toggle/install status and blockers before new write affordances are enabled.
- Versioned adapter plan: V2.12 opencode writable evidence and guarded implementation complete; V2.13 Pi read-only scanner/parser complete with writable still blocked and direct root `.md` cataloging disabled due to real local noise; V2.14 Hermes and V2.15 OpenClaw evidence gates closed without implementation because maintainer-confirmed specs are missing.
- Completed management/analysis line: V2.16 OpenClaw read-only scanner, V2.17 Hermes read-only scanner, V2.18 cross-agent skill analysis, V2.19 skill health dashboard and triage UX, V2.20 read-only AI skill analysis assist, V2.21 scan accuracy/dedupe/agent metrics, V2.22 finding/conflict semantics, V2.23 Health Dashboard / Adapter Capability UX, V2.24 Skill Detail diagnostics, V2.25 Agent-config timeline, V2.26 Finding explainability, V2.27 Skill identity/provenance dedupe, V2.28 Conflict semantic closeout, V2.29 Finding triage persistence, and V2.30 AI skill analysis workflow.
- Current mainline real local app Computer Use validation passed on 2026-06-10 with the developer's unlocked macOS session and the current `dist/SkillsCopilot.app` bundle path explicitly selected.
- V2.8 rules/permissions governance, V2.9 Tool-global skill pool, and V2.10 docs/release consistency are integrated.
- Earlier integrated phases: MVP, Product UI/UX Hardening, V1 native macOS baseline, macOS Native Productization, V2 Prep security gates, refresh-summary UX, native test hardening, adapter evidence gates, first Codex adapter slice, and V2.1 through V2.7.
- The V2.2/V2.3 historical macOS/AX window-resolution blocker was resolved for the current mainline validation pass on 2026-06-10. Future user-visible, UI, or service-protocol changes must rerun real local Computer Use validation against the developer's real environment and keep any new blocker explicit; do not substitute smoke screenshots for real local validation.
- V2.8 covers LLM status protocol compatibility, permissions roundtrip, explicit severity ordering, findings filtering/grouping UI, and `app.stateSnapshot` refresh optimization.
- V2.8 completed local rules: `frontmatter.tools-not-empty`, `permissions.network-declared`, `permissions.exec-needs-human`, `name.canonical-case`, `script.no-shebang`, `body.too-long`, and `dependency.unknown`.
- V2.9 covers tool-global catalog/staging records, local directory import with rule audit, reproducible local export bundle/manifest, manifest reimport stability, native read-only preview UI, and confirmed install to Claude/Codex verified skill roots. GitHub clone import and script-file install are removed from the active product backlog. V2.12 added guarded opencode install to native roots after evidence verified writable semantics.
- V2.10 covers the documented skill execution safety boundary only: no real execution by default, local audit records for blocked/cancelled/failure attempts, and hard separation from LLM actions. Current product direction does not plan a script runner, sandbox runtime, public execution API, or successful execution output log.
- Near-term work prioritizes making every visible count and issue actionable and explainable before adding broader write support. Pi direct root `.md` cataloging is intentionally disabled after real local validation showed it pulls ordinary resource documents into the skills list. Pi writable evidence remains a harness candidate, not production support. Do not reopen V2.1-V2.25 for closed items unless a regression is found.
- OpenClaw project scope is workspace-scoped only: `<workspace>/skills` and `<workspace>/.agents/skills`; do not infer arbitrary repository roots as OpenClaw projects.
- Hermes has no confirmed generic project-level skills. First read-only scope is active/profile Hermes home `skills/**/SKILL.md`; explicit `skills.external_dirs` must be modeled as external roots, not automatic project roots.
- V2.3 Codex adapter hardening covers config patch robustness, adapter state expression, security regressions, smoke coverage, and documentation/status synchronization.
- V2.4 opencode originally introduced native-root scanning for `~/.config/opencode/skills` and active project `.opencode/skills`; current opencode scan also follows official `.claude/skills` and `.agents/skills` compatibility roots. V2.12 guarded writable support remains limited to managed `permission.skill` config overrides and native opencode install targets.
- The maintained product UI is the native macOS app in `apps/macos`, built with SwiftUI and AppKit interop.
- The Rust service protocol in `crates/service` is the UI boundary for the macOS app.
- The old Tauri/React UI and Tauri IPC shell have been removed. Do not recreate `ui/`, `src-tauri/`, or Tauri IPC for product work.
- The only current app bundle path is `dist/SkillsCopilot.app`.
- V2.7 LLM local assist must remain disabled by default. The finished implementation boundary is service/UI gate plus request prepare/estimate; do not claim real provider clients, network calls, or credential storage exist.

## Architecture Rules

- Keep product logic in Rust workspace crates, not in the UI shell.
- `crates/core` is the no-I/O base layer. Higher crates may depend on it; it must not depend on higher crates.
- New UI work must call the typed Rust service protocol.
- Current implemented adapter scope is Claude Code, Codex, guarded writable opencode config/native install targets with native plus compatibility scan roots, and read-only Pi native directory skills under `SKILL.md`.
- Codex support is limited to verified user/project roots, cwd-to-repo-root project discovery, `catalog.scanAll`, project-context-scoped scanning, agent filtering/status display, and user-config writable toggles through `~/.codex/config.toml` / `$CODEX_HOME/config.toml`.
- Project-local Codex config writes, plugin/admin/system roots, Pi writable paths, Hermes, and OpenClaw remain blocked or read-only planning only per their evidence docs.
- Opencode writable support is limited to V2.12 verified exact managed `permission.skill` overrides and native opencode install targets; compatibility roots are scan-only sources.
- No cloud sync, accounts, telemetry, anonymous crash reports, or uncontrolled outbound network calls.
- Optional LLM features must be explicitly enabled by the user. V2.7 currently must not save credentials; V2.30 read-only analysis remains disabled-by-default local prepare/preview and explicit action-triggered while no provider calls run by default. Future macOS credential storage must prefer Keychain, and fallback `~/.config/skills-copilot/llm.yaml` must be permission-checked as `0600`. Credentials must never be written to SQLite, project directories, logs, prompts, or response artifacts.
- LLM output is untrusted. Draft frontmatter is display/copy-only in V2.7; do not add Apply/Write paths from LLM output. Real writes must go through the normal user edit/save flow and Rust service validation.
- Skill scripts are untrusted. V2.10 keeps script execution default-denied: LLM output, analyzer recommendations, imports, and tool-global previews must not trigger command execution. Do not add execution affordances while the product focus remains skill management, inspection, and analysis.

## Required Verification

- For code changes, run the focused checks needed for the touched area.
- For major changes, user-visible behavior, UI work, service protocol changes, or milestone completion, run `pnpm check:macos`, then run the real local app with `pnpm dev:macos` or `./script/build_and_run.sh run` and operate it with macOS Computer Use only after confirming the macOS session is unlocked and interactive.
- Smoke validation uses fixture data and must not touch the real user Claude config.
- Real local validation uses the developer's real local HOME, app data, and Claude config.
- Completed UI screenshots must capture only the full app window. Full desktop screenshots are forbidden.
- If the macOS session is locked, cannot be confirmed interactive, or Computer Use/window capture is blocked, state the blocker explicitly. Do not substitute a smoke screenshot for real local validation.
- Before committing, pushing, or handing off evidence, run `pnpm check:privacy`. Do not commit real local user paths, usernames, home directories, app-data paths, temp directories, credentials, tokens, proxy-managed credential placeholders, or screenshots that visibly expose those values. Use `$HOME`, `<repo>`, `<worktree>`, `<project-root>`, `<app-data-dir>`, and `<redacted>` placeholders in docs and fixtures. New screenshots require manual visual inspection because automated binary string scans do not perform OCR.

## Common Commands

```sh
cargo test --workspace
cargo clippy --workspace --all-targets --all-features
./script/build_and_run.sh --verify
pnpm build:macos
pnpm dev:macos
pnpm smoke:macos-app -- --fixture-data --capture-window
pnpm check:macos
pnpm check:privacy
pnpm capture:macos-window
swift test --package-path apps/macos
pnpm test:macos-list-model
pnpm benchmark:macos-list-model
pnpm verify:macos-ui-layout
```

## Read Before Editing

- Architecture changes: `docs/architecture.md`
- Agent workflow and verification rules: `docs/ai-agent-workflow.md`
- macOS app run and smoke rules: `docs/macos-app-runbook.md`
- UI prototype, screenshot, and verification standards: `docs/ui-delivery-standards.md`
- macOS native product plan: `docs/macos-native-plan.md`
- Data model: `docs/data-model.md`
- Security and privacy model: `docs/security-model.md`
- Roadmap and milestone status: `docs/roadmap.md`
- Current development task queue: `docs/development-tasks.md`
- Adapter scope and TBD specs: `docs/agent-adapters.md`
- Non-Claude adapter evidence gates: `docs/agent-adapter-spec-worklists.md`

## Git and Editing Rules

- Do not revert user changes unless explicitly asked.
- Keep edits scoped to the requested task and the relevant architecture boundary.
- Prefer existing project patterns over new abstractions.
- Update docs when behavior, commands, architecture, validation flow, or UI state changes.
- Before committing, check the working tree and only include intended changes.
- For multi-agent parallel work, create one isolated git worktree and branch per task before assigning subagents. Subagents must be told to work only in their assigned worktree, must not switch branches, and must not edit the coordinator checkout.
