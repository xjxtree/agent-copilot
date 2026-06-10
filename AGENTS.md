# AGENTS.md

This file is the shared project instruction entrypoint for coding agents such as Codex, Claude Code, Pi, opencode, and other compatible tools.

## Project State

- Current phase: **V2.37 Pi writable guarded slice active**。V2.21-V2.36 已收口：scan accuracy/dedupe、finding/conflict 语义、Health/Adapter Capability UX、single-skill Detail 诊断口径、Agent-config timeline、Finding explainability、Skill identity/provenance dedupe、Conflict semantic closeout、Finding triage persistence、AI skill analysis workflow、Cleanup Queue、Rule tuning / suppression、Safe batch actions、Cross-agent comparison view、Local report export、Pi writable evidence harness 均已同步到主线。V2.37 聚焦 evidence-backed Pi guarded writable slice；Pi production toggle/install 仍 blocked，直到 V2.37 最小写入切片完成并验证。
- V2.36 已完成；Pi writable evidence harness 仅在可丢弃 disposable 根/fixture 项目内验证，不含生产写路径。completed evidence 包含 Pi global/project/package toggle 语义、rollback、trust gate、invalid JSON / config 破损兜底、re-enable 行为，以及生产写入继续 blocked 的真实 app 验证。V2.37 guarded Pi writable slice 仅允许基于这些证据实现最小 Pi native toggle；install 仍 blocked。
- V2.28 completed 验收口径：`Conflicts` 仅保留当前/selected/current-agent 的 runtime/name 冲突；跨 agent 的 duplicate name / source overlap / enabled mismatch 只进入 `Analysis`；health 中 `conflict_count` 只能统计同-agent 冲突分组，不可叠加 cross-agent analysis 分组。
- Near-term priority: keep the product focused on skills management, inspection, analysis, and configuration audit. Next work should prioritize V2.37 evidence-backed Pi guarded toggle while preserving V2.27 provenance/identity explainability, V2.28 conflict semantics, V2.29 finding triage persistence, V2.30 read-only AI skill analysis workflow, V2.31 Cleanup Queue, V2.32 local rule tuning/suppression, V2.33 safe batch actions, V2.34 cross-agent comparison, V2.35 local report export, and V2.36 Pi writable evidence harness. Do not reintroduce full-platform UI adaptation, formal signed release/notarization/DMG/ZIP/public distribution, script execution, cloud sync, telemetry, or automatic write paths.
- V2.29 持久化边界：仅在 app-local triage state（catalog/app data）落盘，状态为 `Open` / `Reviewed` / `Ignored` / `Needs follow-up`；finding fingerprint 或受影响实例集合变化后，已持久化 triage 状态回到 `Open`；不写 agent config，不创建 skill-toggle snapshot 与 skill-content snapshot；不执行脚本，不做 AI 写回，不读/写凭据。
- V2.30 分析边界：`llm.prepareSkillAnalysis` 为用户显式触发、selected/batch 级别的 read-only preview；没有后台/周期性分析任务；未启用 provider 时保持本地 prepare/preview；provider 调用仅在未来显式 opt-in 模式下才应发生；AI 输出仅 draft/copy，不持久化 triage；不触发 agent-config/文件写入、snapshot 创建或 script execute。
- V2.31 清理队列（Cleanup Queue）边界已完成：将 open findings、完整性问题与 cross-agent analysis insights 聚合为可复查列表；默认仅 read-only 显示，不新增自动清理、自动写入、自动执行或 provider 触发链路；可用的下一步动作仅指向已存在的安全入口（详情/过滤/复查/现有 toggle/save/rollback）。
- V2.32 Rule tuning / suppression 边界已完成：只允许 app-local rule severity override 与 suppression；必须可审计、可撤销；默认不影响 skill 文件或 agent config，不创建 skill-toggle / skill-content snapshot，不执行脚本，不调用 AI provider，不读写凭据，不触发快照写入。
- V2.33 Safe batch actions 边界已完成：只面向已 verified writable 的 agent/roots 提供预览优先（preview-first）的批量 enable/disable；必须先展示 agent/root 能力过滤、受影响 skill、不可写跳过项及跳过原因，并包含 snapshot/rollback 计划；Apply 必须经过显式确认且确认的 preview id 必须仍匹配当前 preview；Pi/Hermes/OpenClaw 保持 read-only；不新增 skill-content 写入、不执行脚本、不发起 AI provider 调用、不读写 credential，且不做 public distribution 任务。
- V2.34 Cross-agent comparison view 边界已完成：横向比较同名/相似 skills 在 Claude/Codex/opencode/Pi/Hermes/OpenClaw 中的状态、来源、风险、可写能力和差异；默认 read-only，不新增写入、执行、AI provider、credential 或 snapshot 路径。
- V2.35 Local report export 边界已完成：用户显式触发本地 Markdown/JSON 审计导出；输出写入 app data `report-exports`，报告内容递归脱敏 `$HOME`、`<project-root>`、`<project-cwd>`、`<app-data-dir>`；不做 public distribution、签名/notarization/DMG/ZIP、cloud sync、telemetry、provider 调用、credential 读写、脚本执行或自动写回。
- V2.11 scope: service/UI adapter capability matrix for Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw, exposing scan/toggle/install status and blockers before new write affordances are enabled.
- Versioned adapter plan: V2.12 opencode writable evidence and guarded implementation complete; V2.13 Pi read-only scanner/parser complete with writable still blocked and direct root `.md` cataloging disabled due to real local noise; V2.14 Hermes and V2.15 OpenClaw evidence gates closed without implementation because maintainer-confirmed specs are missing.
- Completed management/analysis line: V2.16 OpenClaw read-only scanner, V2.17 Hermes read-only scanner, V2.18 cross-agent skill analysis, V2.19 skill health dashboard and triage UX, V2.20 read-only AI skill analysis assist, V2.21 scan accuracy/dedupe/agent metrics, V2.22 finding/conflict semantics, V2.23 Health Dashboard / Adapter Capability UX, V2.24 Skill Detail diagnostics, V2.25 Agent-config timeline, V2.26 Finding explainability, V2.27 Skill identity/provenance dedupe, V2.28 Conflict semantic closeout, V2.29 Finding triage persistence, V2.30 AI skill analysis workflow, V2.31 Cleanup Queue, V2.32 Rule tuning / suppression, V2.33 Safe batch actions, V2.34 Cross-agent comparison view, and V2.35 Local report export.
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

## V2.35 Local report export (completed)
- `V2.35` is completed after integration, `pnpm check:macos`, real local App export validation, and generated report redaction verification on 2026-06-10.
- Report export is user-triggered, local-only, and redacted: generated on demand in the app flow and written to local files under app data only after explicit user action.
- Local exports support Markdown and JSON audit artifacts covering agent coverage/status, health summary, open findings with persisted triage state, cleanup queue items, and cross-agent comparison insights.
- Exported artifacts redact local filesystem-sensitive values with placeholders such as `$HOME`, `<project-root>`, `<project-cwd>`, `<app-data-dir>`, and `<redacted>` before write.
- V2.35 remains explicitly out of scope for public distribution, DMG/ZIP packaging/signing/notarization, cloud sync, telemetry, provider/AI calls, credential storage, script execution, and automatic write-back.
- V2.33 Safe Batch constraints (explicit preview, explicit confirm, apply pre-checks for writable capability, snapshot/rollback plan, and apply-time preview id matching) stay unchanged and continue to be enforced.
- V2.34 Cross-agent comparison remains completed/read-only in scope and should not be converted to write operations as part of export work.
