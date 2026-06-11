# Development Tasks

> Status: V2.49 Routing Accuracy Dashboard is completed and synchronized on `main`; V2.1 through V2.49 are synchronized baseline; V2.50+ remains the next roadmap line, not separate product branches.

## Current Baseline

- Current branch baseline: `main` after V2.16-V2.28 management/analysis/history/explainability/provenance/conflict-semantics line and 2026-06-10 real local Computer Use validation; V2.22 finding/conflict 语义、V2.23 Health Dashboard / Adapter Capability UX、V2.24 Detail 诊断口径、V2.25 Agent-config timeline、V2.26 Finding explainability、V2.27 Skill identity/provenance dedupe、V2.28 Conflict semantic closeout 均已收口。
- Product boundary: native macOS SwiftUI/AppKit shell plus Rust service protocol.
- Completed V2 milestones: first Codex slice, V2.1 through V2.49.
- Current priority: keep V2.26 finding explainability, V2.27 identity/provenance, V2.28 conflict semantics, V2.29 finding triage persistence, V2.30 read-only AI analysis, V2.31 read-only cleanup queue, V2.32 app-local rule tuning, V2.33 preview-first + explicit-confirm batch actions, V2.34 read-only comparison, V2.35 local redacted export, V2.36 disposable evidence, V2.37 guarded Pi toggle, V2.38 Hermes external roots, V2.39 OpenClaw workspace scope, V2.40 adapter diagnostics, V2.41 provider foundation, V2.42 prompt preview/redaction, V2.43 quality scoring, V2.44 task readiness, V2.45 routing confidence, V2.46 task benchmark set, V2.47 routing regression detection, V2.48 trace import, and V2.49 routing accuracy dashboard; V2.50 cross-agent task readiness is the next roadmap line.
- Current code gap: the macOS app and Rust service now expose user-configured OpenAI-compatible / Claude-compatible provider profiles, Keychain-first API key storage, explicit Test Connection, V2.42 prompt preview/redaction, confirmation-gated provider-backed draft output, budget fields, minimal redacted call metadata, V2.43 deterministic skill quality scoring, V2.44 deterministic task readiness, V2.45 deterministic routing confidence with `task.rankSkillRoutes`, V2.46 app-local task benchmark CRUD/evaluation with `task.listBenchmarks` / `task.saveBenchmark` / `task.deleteBenchmark` / `task.evaluateBenchmarks`, V2.47 app-local routing baseline/regression detection with `task.saveRoutingBaseline` / `task.detectRoutingRegression`, V2.48 app-local trace import/list/delete with `trace.importLocal` / `trace.listImports` / `trace.deleteImport`, V2.49 read-only routing accuracy dashboard with `routing.accuracyDashboard`, and native English / Simplified Chinese UI localization with an app-local language setting. Cross-agent task readiness and full provider observability remain planned for later.
- Real local Computer Use baseline: latest V2.48 validation on 2026-06-11 launched the current `dist/SkillsCopilot.app` bundle against real local HOME/app data/Claude/Codex/opencode roots and direct CG window capture found the app window. Computer Use is currently blocked for the current bundle: absolute bundle path returns `cgWindowNotFound`, and app-name lookup returns `timeoutReached`; keep that tool-layer blocker explicit until a new CU pass succeeds. Future user-visible, UI, or service protocol changes must rerun Computer Use against the current bundle path and must not use smoke screenshots as a substitute.
- Quality gate for code/UI/protocol work: `pnpm check:macos`; add focused Rust/Swift tests when touching shared behavior.

## Versioned Adapter Plan

| Version | Goal | Status | Completion signal |
| --- | --- | --- | --- |
| V2.10 | Skill execution safety boundary and docs consistency | Closed | Safety boundary documented and release/docs consistency synchronized |
| V2.11 | Adapter Capability Matrix | Completed | Service protocol and macOS UI expose scan/toggle/install status and blockers for Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw |
| V2.12 | opencode writable support | Complete | Disposable local evidence verifies `permission.skill` writes, then guarded toggle/install is implemented and validated, or blocker remains explicit |
| V2.13 | Pi adapter support | Complete | Pi-native global/project scanner/parser is implemented read-only; writable toggle/install remains blocked pending settings mutation/rollback evidence |
| V2.14 | Hermes adapter support | Complete evidence-gate closeout; read-only later implemented in V2.17 | P0 evidence later confirmed first-class Hermes skills; writable/install remains blocked |
| V2.15 | OpenClaw adapter support | Complete evidence-gate closeout; read-only later implemented in V2.16 | P0 evidence later confirmed OpenClaw roots/schema for read-only scan; writable/install remains blocked |
| V2.16 | OpenClaw read-only scanner | Completed | OpenClaw documented roots appear in catalog read-only; scan is filesystem-only; project scan is workspace-scoped only (`<workspace>/skills`, `<workspace>/.agents/skills`); no arbitrary repo roots, CLI calls, writes, or installs |
| V2.17 | Hermes read-only scanner | Completed | Active/profile Hermes home `skills/**/SKILL.md` appears in catalog read-only; no generic project scan, cron mapping, writes, installs, CLI calls, or `.env`/`auth.json`/`logs`/`cron` mapping |
| V2.18 | Cross-agent skill analysis | Completed | Duplicate names, shadowing, precedence conflicts, malformed skills, disabled states, and source overlap are grouped across agents |
| V2.19 | Skill health dashboard and triage UX | Completed | `app.stateSnapshot.health` and native sidebar dashboard summarize health, findings, conflicts, risky scripts/permissions, and provide read-only triage filters |
| V2.20 | Read-only AI skill analysis assist | Completed | Disabled-by-default offline review preview summarizes skill purpose/risk/findings without provider calls, network, credentials, writes, configs, prompts, or script execution |
| V2.21 | Scan accuracy, dedupe behavior, and agent metric alignment | Completed | Normalize scan roots/path IDs, define deterministic duplicate handling across adapters, and align cross-agent visibility with catalog analysis + per-agent scan/activity and health metrics |
| V2.22 | finding/conflict 语义与验收同步 | Completed | Conflict=same-agent runtime/name collision; cross-agent duplicate/source-overlap lives in analysis; default findings use issue groups |
| V2.23 | Health Dashboard / Adapter Capability UX | Completed | Health card action summaries, selected-agent filtering, and scan/toggle/install/read-only/blocked capability status are aligned |
| V2.24 | Skill Detail 诊断工作台口径 | Completed | Detail=single skill workbench；Findings=issue groups；Conflicts=current-agent only；Analysis=read-only offline；History=toggle/config events only |
| V2.25 | Agent-config timeline | Completed | Per-agent config timeline, preview diff + confirm rollback, no skill-toggle snapshot, no skill-content snapshot |
| V2.26 | Finding explainability | Completed | Rule source, trigger reason/message, affected instances, scan entries, severity/risk mapping, and Health/Detail drill-down to concrete skill/rule/path are visible |
| V2.27 | Skill identity/provenance dedupe | Completed | Agent/scope/definition/path identity is deterministic; Pi `.md` noise stays excluded; opencode native and compatibility roots are explainable in UI |
| V2.28 | Conflict semantic closeout | Completed | Conflicts = selected/current agent runtime/name collisions only; cross-agent duplicate/source-overlap/enabled-mismatch = `Analysis` only; health conflict_count must not include cross-agent analysis groups |
| V2.29 | Finding triage persistence | Completed | reviewed/ignored/needs-follow-up are persisted in app-local catalog/app data; no agent-config writes, no skill-toggle snapshot, no skill-content snapshot; no script execution / AI write-back / credential persistence; findings reopen when fingerprint or affected-instance set changes |
| V2.30 | AI skill analysis workflow | Completed | User-triggered selected/batch read-only previews with summary + risk explanation + cleanup draft. Default local prepare/preview only; no background analysis; no writes, agent-config writes, snapshots, execution, or credential persistence |
| V2.31 | Cleanup Queue | Completed | Aggregate open findings, integrity issues, same-agent conflicts, and analysis insights into a read-only review queue; next actions map to existing safe affordances; no new automatic write/execute path |
| V2.32 | Rule tuning / suppression | Completed | Add app-local rule severity overrides and suppression with audit/revert semantics; no skill-file/agent-config writes, snapshots, provider calls, or credential side effects |
| V2.33 | Safe batch actions | Completed | Preview-first batch enable/disable for verified writable agents/roots only; show skipped items + reasons and explicit snapshot/rollback planning; Apply requires explicit confirmation and matching preview id |
| V2.34 | Cross-agent comparison view | Completed | Compare same-name/similar skills across agents by state, source, risk, writable capability, and differences; read-only by default |
| V2.35 | Local report export | Completed | Export redacted Markdown/JSON local audit reports for agent coverage, health summary, open findings, triage state, cleanup queue, and comparison insights |
| V2.36 | Pi writable evidence harness | Complete | Disposable agentDir/fixture project validates Pi global/project/package toggle, rollback, trust gate, invalid JSON/config handling, and re-enable behavior; production writable remains blocked |
| V2.37 | Pi writable guarded slice | Completed | Evidence-backed minimal Pi native toggle (global / project / package) with preview/snapshot/rollback/disabled-state rescan; Pi install remains blocked, no script execution, no AI automatic writes, no credential persistence, and no arbitrary compatibility write roots |
| V2.38 | Hermes external roots | Completed | Explicit `skills.external_dirs` are modeled as read-only external roots in adapter/scanner/UI provenance; no generic project scan, writable toggle, install, scripts, AI write-back, or credentials |
| V2.39 | OpenClaw workspace deepening | Completed | Tightened workspace-scope detection and skipped/blocked root explanations without arbitrary repo inference or writes |
| V2.40 | Adapter diagnostics | Completed | Surface discovered/skipped/blocked roots, config detected, read-only/writable reason, and last scan activity per agent via read-only protocol/status/state fields and sidebar UI; no new writes, execution, provider calls, credentials, or telemetry |
| V2.41 | AI Provider Foundation | Completed | User-configured OpenAI-compatible and Claude-compatible endpoint/API key/model settings, Keychain-first storage, explicit test connection, budget controls, disabled/unconfigured state, and minimal redacted test-call metadata; no automatic analysis, writes, scripts, telemetry, or credential leakage |
| V2.42 | Prompt preview / redaction / token estimate | Completed | Every AI call shows prompt scope, included/excluded fields, redaction summary, estimated tokens/cost, network destination, and explicit confirmation before network request; confirmed calls record minimal redacted audit metadata |
| V2.43 | AI Skill Quality Score | Completed | `analysis.scoreSkillQuality` and native Analysis UI provide user-triggered read-only local quality scoring from metadata/findings/conflicts/analysis/adapter diagnostics; optional provider explanation uses V2.42 prompt preview/redaction/confirmation and remains copy-only |
| V2.44 | AI Task Readiness Check | Completed | User enters a real task; app evaluates local candidate skills for availability, enabled/scope/risk state, gaps, blockers, evidence, and safety flags |
| V2.45 | AI Routing Confidence | Completed | Rank candidate skills for a task with confidence, match reasons, ambiguity/collision warnings, and likely wrong-pick / likely miss explanations |
| V2.46 | Task Benchmark Set | Completed | Users define common tasks and expected/acceptable skills for repeatable local readiness evaluation |
| V2.47 | Routing Regression Detection | Completed | Detect when skill changes, disablement, drift, or findings reduce task-to-skill readiness versus the benchmark baseline with `task.saveRoutingBaseline` + `task.detectRoutingRegression` |
| V2.48 | Agent Behavior Trace Import | Completed | Import local transcript/log evidence, redact sensitive content before persistence, and analyze deterministic expected-vs-actual routing（命中/漏选/错选/歧义）；默认不落 raw trace |
| V2.49 | Routing Accuracy Dashboard | Completed | Summarize benchmark/trace hit rate, miss rate, wrong-pick rate, ambiguity, gaps, per-agent rows, history buckets, and recent evidence |
| V2.50 | Cross-agent Task Readiness | Planned | Compare Claude/Codex/opencode/Pi/Hermes/OpenClaw readiness for the same task using skills, state, scope, quality, and routing confidence |
| V2.51 | Stale / Drift Detection | Planned | Identify stale skills, fingerprint drift, finding drift, source drift, and changed readiness impact |
| V2.52 | Local Knowledge Index | Planned | Build local-only search/index for purpose, tools, keywords, rules, source, task fit, and risk; no default network |
| V2.53 | Similar Skill Grouping | Planned | Detect duplicate/similar/confusable skills and explain whether they help coverage or create routing ambiguity |
| V2.54 | Capability Taxonomy | Planned | Classify skills into capability domains and map coverage across agents/workspaces |
| V2.55 | Workspace Readiness Check | Planned | Evaluate whether the current project has the right skills enabled and scoped per agent for expected work |
| V2.56 | AI Remediation Planner | Planned | Convert findings, gaps, ambiguity, and drift into prioritized read-only remediation plans |
| V2.57 | Fix Preview Drafts | Planned | Generate copy/edit-ready frontmatter, permission, dependency, and description drafts; no direct apply from AI output |
| V2.58 | Impact Preview | Planned | Preview task, agent, skill, snapshot, and rollback impact before enable/disable/edit/remediation actions |
| V2.59 | Batch Review Workflow | Planned | Batch review by task, risk, rule, agent, and workspace; writes remain preview-first and explicit-confirm only |
| V2.60 | Remediation History | Planned | Track local remediation decisions, recurrence, reopened issues, and task-readiness improvements |
| V2.61 | AI Review Session | Planned | Organize a skills review around a task/workspace/agent set with AI-generated summary and next-action queue |
| V2.62 | AI Governance Report | Planned | Generate local redacted AI-assisted reports for task readiness, routing accuracy, quality, policy, and remediation status |
| V2.63 | Policy Pack Schema | Planned | Define local policy packs for quality, risk, permissions, task readiness, routing thresholds, and provider usage rules |
| V2.64 | Policy Import / Export | Planned | Import/export policy packs locally with redaction and versioned compatibility checks; no cloud sync |
| V2.65 | Agent / Workspace Policy Profile | Planned | Apply different policy profiles per agent/workspace without writing skill files unless user explicitly confirms a safe path |
| V2.66 | Policy Compliance Report | Planned | Report compliance against local policy packs, including AI-assisted explanations and deterministic evidence |
| V2.67 | Local Skill Map | Planned | Visualize skill relationships, sources, capabilities, similar groups, conflicts, and task coverage locally |
| V2.68 | Governance Review Pack | Planned | Bundle review session, routing accuracy, policy compliance, remediation history, and export artifacts into one local pack |
| V2.69 | AI Provider Observability | Planned | Build full observability on top of V2.41-V2.42 minimal audit metadata: call history UI, cost trends, provider errors, rate limits, availability, cleanup/retention controls, and optional redacted export without storing secrets or raw prompts by default |
| V2.70 | Safe Write Expansion Planning | Planned | Produce evidence-based plans for future writable expansion only; no new writes without verified rollback-safe agent/root evidence |

## Baseline and Next Priority: V2.26-V2.70

**Goal**: keep the completed V2.26-V2.49 management/analysis/provider/prompt-safety/task-routing/benchmark/regression/trace/accuracy baseline stable, then move into AI-native task-centered governance. Users should understand why a finding exists, where a skill came from, whether a conflict is same-agent or cross-agent, which issues are already reviewed, and whether a real task can be routed to the right skill/agent with acceptable quality and risk over repeatable local benchmarks, saved baselines, redacted local trace evidence, and accuracy dashboards.

**Priority order**

1. V2.27 Skill identity/provenance dedupe: completed; keep agent/scope/definition/path identity deterministic, Pi `.md` resource noise excluded, and native vs compatibility roots explainable.
2. V2.28 Conflict semantic closeout: completed; keep same-agent runtime/name collisions in Conflicts for selected/current agent, keep cross-agent duplicate/source overlap/enabled-mismatch in Analysis, and ensure health conflict_count stays aligned to selected/current conflict groups.
3. V2.29 Finding triage persistence: completed; add reviewed/ignored/needs-follow-up state in app-local catalog/app data; do not write agent config, skill-toggle snapshot, or skill-content snapshot; no script execution / AI write-back / credential persistence; reopen when finding fingerprint or affected-instance set changes.
4. V2.30 AI skill analysis workflow: completed; disabled-by-default read-only AI summaries and suggestion drafts are prepared without provider calls by default, writes, execution, or credential storage.
5. V2.31 Cleanup Queue: completed; app-local review queue now aggregates open findings, integrity issues, same-agent conflicts, and analysis insights before later tuning/suppression/reporting work.
6. V2.32 Rule tuning / suppression: completed; local rule severity overrides and suppressions are auditable, reversible, and isolated from skill files, agent config, snapshots, provider calls, and credentials.
7. V2.33 Safe batch actions: completed; added preview-first batch enable/disable for verified writable agents/roots only, with explicit capability filtering, skipped item + reason reporting, rollback planning, and explicit confirmation before apply.
8. V2.34 Cross-agent comparison view: completed; compare same-name/similar skills across agents by state, source, risk, writable capability, and differences without adding write paths.
9. V2.35 Local report export: completed; generate redacted local Markdown/JSON audit reports from existing read models without distribution, provider calls, credentials, scripts, or automatic writes.
10. V2.36-V2.40 Adapter trust and diagnostics: completed; V2.36 Pi writable evidence harness, V2.37 minimal guarded Pi native toggle, V2.38 Hermes external roots, V2.39 OpenClaw workspace scope, and V2.40 read-only adapter diagnostics are complete. Do not extend write semantics without fresh rollback-safe evidence.
11. V2.41-V2.70 AI-native task-centered governance: V2.41 provider foundation, V2.42 prompt safety, V2.43 skill quality, V2.44 task readiness, V2.45 routing confidence, V2.46 task benchmark set, V2.47 routing regression detection, V2.48 trace import, and V2.49 routing accuracy dashboard are completed. V2.50+ cross-agent readiness/knowledge and governance lines remain future.

### V2.41 Verification Checklist（文档同步）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`.
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并进行明确的 `SkillsCopilot` 窗口 `Computer Use`/AX 操作；若窗口分辨失败，显式记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 按 V2.41 边界复核：仅用户显式触发 provider 网络路径；无后台分析；无新写入脚本/执行/telemetry/AI write-back。

**Tasks**

- Keep finding/risk/analysis labels explainable: risk is a subset of findings; analysis is cross-agent insight; conflict is selected-agent runtime/name collision.
- Keep skill identity deterministic across all adapters and expose provenance labels in UI where user confusion is likely.
- Keep triage state in app-local storage only; never hide unresolved high-risk findings by default.
- Keep optional AI analysis user-triggered and separated from all write/config/script paths. Starting V2.41, provider calls are allowed only when the user explicitly configures an OpenAI-compatible or Claude-compatible endpoint/key/model and confirms a redacted prompt preview; AI output remains untrusted and cannot directly write, execute, or change triage/config state.
- Keep Hermes/OpenClaw writable/install blocked until individual skill disable schema, credential preservation, and rollback-safe writes are verified.
- Keep Pi install and compatibility-root writes blocked; Pi toggle support is limited to the V2.37 guarded native global/project/package scope with snapshot/rollback.
- Keep every new write path behind service protocol, snapshot, audit, permission, and privacy boundaries.
- Update native macOS UI only as needed to expose clearer explanations, statuses, filters, finding groups, and guarded writable actions.

### V2.42 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并进行明确的 `SkillsCopilot` 窗口 `Computer Use`/AX 操作；若窗口分辨失败，显式记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.42 口径：provider-backed 每次请求必须先显示 prompt scope、included/excluded 字段、redaction summary、token/cost estimate、destination；发送前必须用户确认；确认后记录最小 redacted metadata。
7. 复核 V2.42 关闭项：无背景调用、无脚本执行、无 telemetry、无 AI write-back/apply/config/snapshot side effects。

### V2.43 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并进行 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口解析失败，记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符。
6. 复核 V2.43 口径：quality score 必须是 user-triggered、selected/batch 范围、默认只读；无 background/周期性调度；本地输入仅限 metadata/findings/conflicts/analysis/adapter diagnostics。
7. 复核关闭边界：无脚本执行、无 telemetry、无 AI write-back / config mutation / snapshot / triage side effect；provider 可选路径需经过 V2.42 prompt preview + redaction + confirmation。
8. 复核隐私边界：不落盘 raw prompt/response，不引入 new credential path；provider path 若存在只允许 Keychain-first key 存储和 V2.42 级最小调用 metadata。

**Closeout status**: completed. V2.43 integrates service protocol, Rust deterministic scoring, native Analysis UI, prompt-preview compatibility, focused Rust/Swift tests, `pnpm check:macos`, real local Computer Use validation, fixture screenshot inspection, and `pnpm check:privacy`.

**Exit Criteria**

- V2.26-V2.30 docs and code make finding/risk/conflict/analysis semantics explainable from Health, list, detail, and analysis views.
- Skill provenance and dedupe behavior are deterministic enough that Pi/opencode/compatibility-root surprises can be explained from the UI.
- Triage persistence helps reduce repeated noise while avoiding agent-config writes, script execution, AI write-back, and credential persistence; affected-instance drift should reopen triage automatically.
- AI-assisted analysis remains opt-in, read-only, privacy-safe, user-triggered, and impossible to use as an execution/write path. It must keep analysis scope read-only, copy-only draft outputs, and no background triggers.
- `docs/agent-adapters.md`, `docs/agent-adapter-spec-worklists.md`, `docs/development-tasks.md`, `docs/roadmap.md`, `docs/service-protocol.md`, `docs/data-model.md`, `docs/ui-delivery-standards.md`, and `AGENTS.md` agree on the current support state and next version line.

### V2.44 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并进行明确的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口解析失败，显式记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.44 口径：User provides a real task; service/UI evaluates candidate skills using local deterministic evidence（metadata / findings / conflicts / analysis / adapter diagnostics / V2.43 quality）并输出可读的 available/enabled/scoped/risky/missing 视图；无 background/周期性 readiness 轮询；结果保持 read-only。
7. 复核 V2.44 关闭边界：无脚本执行、无 telemetry、无 AI write-back、无 config/snapshot/triage side effect；未经 provider 的路径不发起网络。
8. 复核 optional provider explanation：必须走 V2.42 的 prompt preview / redaction / explicit confirmation；无 raw prompt/response 持久化；可保存的仅最小 redacted metadata。
9. 复核密钥与隐私：继续执行 V2.41 Keychain-first provider 密钥策略；不得将 secrets 落地到 SQLite、项目目录、日志、提示/响应 artifacts、截图或报告文件中。

**Closeout status**: completed. V2.44 integrates service protocol, Rust deterministic readiness scoring, native Analysis UI, prompt-preview compatibility, focused Rust/Swift tests, `pnpm check:macos`, real local Computer Use validation, fixture screenshot inspection, and `pnpm check:privacy`.

### V2.45 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并验证路由候选 ranking 流程；若窗口识别失败，记录 blocker（`cgWindowNotFound`/窗口不可见属于工具层 blocker）。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.45 目标口径：基于 user task 和可选 agent/candidate filter 生成 read-only ranking：
   - 输出项包含：`confidence`、`match_reasons`、`ambiguity/collision warnings`、`likely_wrong_pick`、`likely_miss`。
   - 证据源包括 `metadata`、`findings`、`conflicts`、`analysis`、`adapter diagnostics`、`quality_score`；`task.checkReadiness` 的本地 evidence remains primary.
   - optional provider explanation 继续走 V2.42 prompt preview + redaction + confirmation，不改变 candidate 排名。
7. 复核关闭边界：routing confidence 不可直接触发 `config.toggleSkill` / `snapshot.create/rollback`；不发起 provider 请求；不改 triage；不执行脚本；不写 agent config；不写 snapshots。
8. 验收触发条件：
   - [x] `task.rankSkillRoutes` 在 protocol 层可用且定义明确
   - [x] 返回 ranking/safety fields 与 evidence 结构经过 schema 定义
   - [x] 文档齐套（`AGENTS.md`、`docs/roadmap.md`、`docs/ai-layer.md`、`docs/service-protocol.md`、`docs/security-model.md`、`docs/v2.45-verification-checklist.md`）

**Closeout status**: completed. V2.45 integrates `task.rankSkillRoutes`, deterministic local route ranking, native Analysis UI, routing prompt preview compatibility, focused Rust/Swift tests, `pnpm check:macos`, real local Computer Use validation against the current bundle path, fixture screenshot inspection, and `pnpm check:privacy`.

### V2.46 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并执行 V2.46 目标流程的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口解析失败，记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符。
6. 复核 V2.46 目标口径：
   - 用户维护的本地 benchmark set（task、预期 skill refs/names、acceptable agent/scope、成功标准）持久化在 app-local `task-benchmarks.json`。
   - `task.listBenchmarks` / `task.saveBenchmark` / `task.deleteBenchmark` / `task.evaluateBenchmarks` 为 additive service protocol 方法。
   - 本地 evidence-only 评估复用 V2.44 `task.checkReadiness` 与 V2.45 `task.rankSkillRoutes`，输出 expected/acceptable match status、top route、score/band、gap/blocker notes、evidence refs 与 safety flags。
   - 本地 benchmark 评估不发起 provider 请求；可选说明性 provider 输出仅走 V2.42 `llm.previewPrompt` + `llm.confirmPromptAndSend`，并保持 copy-only。
7. 复核关闭边界：
   - 不调用 `config.toggleSkill` / `snapshot.create` / `snapshot.rollback` / `config.save`。
   - 不执行脚本。
   - 不改 triage。
   - 不读取 credentials；不持久化 raw prompt/response；不引入 cloud sync 或 telemetry。

**Closeout status**: completed with explicit Computer Use blocker. V2.46 integrates app-local task benchmark CRUD/evaluation in the Rust service, native Analysis benchmark UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, and `pnpm check:privacy`. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name even after stale same-bundle-id processes were removed. The captured real-local screenshot exposed local paths and was not committed.

### V2.47 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并执行 V2.47 目标流程的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口解析失败，显式记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.47 目标口径：
   - 方法层面由 `task.saveRoutingBaseline`（保存基线快照）与 `task.detectRoutingRegression`（读取/重跑基线对比）组成。
   - app-local baseline 来源为 V2.46 的 deterministic `TaskBenchmark` evaluation，保存于 `task-routing-baseline.json`，比较维度为 score/confidence delta、expected-match 状态变化、top-route 变化、gap/blocker 增量、missing/current-only benchmark 与 catalog 可用性。
   - `task.detectRoutingRegression` 采用本地证据输入（`TaskReadiness` + `TaskBenchmark` + `V2.43`~`V2.46` evidence），输出 `status`、`summary`、`items`、`baseline`、`current_evaluation`、`blocker_notes` 与 `safety_flags`，结果保持 app-local、deterministic、read-only。
7. 复核 V2.47 安全边界：不发 provider 请求用于回归评分；不读 credentials；不写 agent config；不创建/回滚 snapshot；不改 triage；不执行脚本；无 cloud sync 与 telemetry；可选 provider 说明仅走现有 V2.42 `llm.previewPrompt` + `llm.confirmPromptAndSend` 的 preview/redaction/确认/ copy-only 路径。

**Closeout status**: completed with explicit Computer Use blocker. V2.47 integrates app-local routing baseline persistence and deterministic regression detection in the Rust service, native Analysis routing regression UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, and `pnpm check:privacy`. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name after stale same-bundle-id processes were removed. No real-local screenshot was committed.

### V2.48 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并执行 V2.48 目标流程的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口不可见，明确记录 blocker（例如 `cgWindowNotFound` / `timeoutReached`）。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.48 口径：
   - `trace.importLocal` 接收 pasted/local trace text 与可选 task/agent/expected skill refs/names。
   - redaction 先行，默认不落 raw trace（`raw_trace_persisted=false`）；仅持久化可复查 metadata、`redaction_summary`、redacted `excerpt` 与 deterministic `analysis` 到 `trace-imports.json`。
   - 判读输出为 deterministic local 结果：`analysis.outcome`（`hit` / `miss` / `wrong_pick` / `ambiguous` / `unknown`）、detected skills、expected skill refs/names、reasons、evidence refs 与 safety flags。
   - `trace.listImports` / `trace.deleteImport` 仅操作 app-local metadata，不改 triage、不改 agent config、不改 snapshot、不执行脚本。
   - 可选 provider 说明仍走 V2.42 preview/redaction/confirmation，保持 copy-only，不改变 deterministic 结果。

**Closeout status**: completed with explicit Computer Use blocker. V2.48 integrates app-local trace import/list/delete in the Rust service, redacted trace metadata persistence in `trace-imports.json`, deterministic trace outcome analysis, native Analysis trace import UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, and `pnpm check:privacy`. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name after stale same-bundle-id processes were removed. No real-local screenshot was committed.

### V2.49 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test -p skills-copilot-service -- --nocapture`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并执行 V2.49 routing accuracy dashboard 的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口不可见，明确记录 blocker（例如 `cgWindowNotFound` / `timeoutReached`）。
4. `pnpm check:privacy`。
5. Fixture screenshot 与 app-window-only 截图手工复核路径/凭据占位符脱敏；真实本机截图不得提交。
6. 复核 V2.49 口径：
   - `routing.accuracyDashboard` 只读聚合 V2.46 benchmark、V2.47 baseline/regression 与 V2.48 redacted trace import evidence。
   - 输出包含 `summary`、`agent_rows`、`history_rows`、`gap_issue_rows`、`recent_evidence_rows`、`blocker_notes`、`prompt_request` 与 `safety_flags`。
   - 指标覆盖 `hit` / `miss` / `wrong_pick` / `ambiguous` / `unknown`、accuracy rate、known outcome rate、benchmark gaps、regression count 与 recent evidence。
   - 本地 dashboard 不写新 artifact、不落 raw trace、不发 provider 请求、不改 triage/config/snapshot/skill 文件、不执行脚本、不读 credentials、不做 cloud sync/telemetry。
   - 可选 provider 说明仍走 V2.42 preview/redaction/confirmation，保持 copy-only，不改变 deterministic dashboard 结果。

**Closeout status**: completed with explicit Computer Use blocker. V2.49 integrates read-only `routing.accuracyDashboard` in the Rust service, native Analysis routing accuracy UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, and `pnpm check:privacy`. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name. No real-local screenshot was committed.

## Current Backlog

These items keep the product focused on managing, inspecting, and analyzing skills. Script execution, GitHub clone import, and script-file install are removed from the active backlog.

| Priority | Work item | Current status | Next concrete task | Completion signal |
| --- | --- | --- | --- | --- |
| P0 | Real local Computer Use rerun gate | Previous mainline pass completed on 2026-06-10; V2.37 slice hit Computer Use `cgWindowNotFound` despite direct CG/AX window evidence | Rerun the real app against local HOME after UI/service/protocol changes, explicitly targeting the current `dist/SkillsCopilot.app` bundle when stale same-bundle-id worktree apps exist, covering project context, scan-all, agent filter, findings filtering/grouping, health dashboard, AI review preview, and script safety preview | App-window-only evidence and runbook notes updated for the new slice, or an explicit tool/session blocker is recorded |
| P0 | V2.41 AI Provider Foundation | Completed | Keep provider profiles, Keychain-first storage, explicit Test Connection, budget fields, and minimal redacted metadata stable while building V2.45+ | Users can safely configure their own endpoint/key/model without any background calls, writes, scripts, telemetry, or credential leakage; minimal call metadata exists before full observability |
| P0 | V2.42 Prompt Preview / Redaction | Completed | Keep prompt preview, redaction summary, included/excluded field display, token/cost estimate, destination preview, explicit confirmation, and minimal redacted audit metadata stable while building V2.45+ | Every model call is visible, redacted, user-confirmed, and auditable before network egress |
| P0 | V2.44 AI Task Readiness Check | Completed | Keep deterministic task readiness aligned with local evidence, V2.43 quality, safety flags, and V2.42-gated optional provider explanation | Users can judge whether a real task has available, enabled, scoped, low-risk candidate skills before routing confidence is added |
| P0 | V2.45 AI Routing Confidence | Completed | Keep route ranking confidence aligned with local readiness evidence plus V2.42-gated optional provider explanation | Users can understand which candidate skill is most likely to be selected correctly and where ambiguity may cause wrong picks |
| P1 | V2.50 Cross-agent task readiness | Planned | Build on completed V2.47 regression, V2.48 trace import, and V2.49 routing accuracy to compare readiness across supported agents for the same task | Users can compare expected vs actual skill selection and choose the best agent/skill route for a task |
| P1 | V2.51-V2.60 Knowledge / remediation workflow | Planned | Add stale/drift detection, local knowledge index, similar skill grouping, capability taxonomy, workspace readiness, AI remediation planner, fix drafts, impact preview, batch review, and remediation history | Users can find, prioritize, and safely work through skill quality/routing issues |
| P1 | V2.61-V2.70 Policy / governance / provider observability | Planned | Add AI review session, governance report, policy packs, compliance reports, local skill map, full provider observability UX, and evidence-only safe write expansion planning | Users can produce local governance artifacts, inspect provider usage/cost/failures from V2.41-V2.42 audit metadata, and plan future write expansion without guessing unsafe writes |
| P0 | V2.11 Adapter Capability Matrix | Completed and in use | Run focused protocol/UI checks when needed, then use the matrix as the gate for future Pi/opencode/Hermes/OpenClaw work | macOS UI shows precise scan/toggle/install status and blockers for all six agents |
| P0 | Pi comprehensive adapter support | Read-only scanner complete; V2.37 guarded native toggle complete; install and compatibility-root writes blocked | Keep Pi toggle limited to global/project/package write scope and keep install/AI auto-write/script execution credentials-unsafe paths blocked; exclude arbitrary compatibility roots from write path | Guarded native toggle preserves preview/snapshot/rollback, trust gate, invalid JSON/config handling, re-enable behavior, and disabled-state rescan |
| P0 | opencode support | Native and official compatibility roots are scanned; guarded `permission.skill` writes are implemented; install targets remain native roots | Keep compatibility-root scan coverage and managed permission/write tests current; custom `skills.paths` / `skills.urls` remain deferred pending evidence | opencode-visible skills match current official discovery roots without enabling unverified custom paths or unsafe file writes |
| P0 | Hermes adapter support | Read-only scanner implemented; writable/install blocked | Keep scoped read-only scan of active Hermes home `skills/**/SKILL.md`; treat `skills.external_dirs` as explicit external roots only (not generic project-scope inference); keep `.env`/`auth.json`/`logs`/cron content filtered and CLI-only scan read-only | Hermes skills appear in catalog read-only; generic project scan and writes remain blocked |
| P0 | OpenClaw adapter support | Read-only scanner implemented; writable/install blocked | Keep scoped read-only filesystem scan over documented roots; project scan only for confirmed OpenClaw workspace roots; no OpenClaw CLI calls during ordinary scan | OpenClaw skills appear in catalog read-only; arbitrary repo roots and writes/install remain blocked |
| P0 | Cross-agent skill analysis | Implemented read-only | Keep catalog summaries for duplicate/conflict/precedence/source-overlap groups aligned with fixtures and UI needs | Users can identify conflicting or duplicated skills across agents without manually comparing lists |
| P0 | Skill health dashboard | Implemented read-only | Keep dashboard summary cards and actionable filters for findings, conflicts, disabled skills, malformed metadata, risky scripts, and permission issues aligned with service health payload | Users can prioritize cleanup from a single management view |
| P0 | V2.21 scan accuracy / dedupe / agent metrics | Completed | Add scan contract coverage for canonical path/id collision handling, source overlap handling, and per-agent stats consistency checks across scan activity + health payloads | Duplicate and overlap records are deterministic; per-agent counts in scan/activity and health payloads are documented and testable |
| P0 | V2.22 finding/conflict semantics sync | Completed | Keep conflict definition / cross-agent analysis separation stable when adding new UI | Conflict/finding behavior is uniform across roadmap/tasks/service-protocol/data-model/adapter docs and can be traced in same scan context |
| P0 | V2.23 Health Dashboard / Adapter Capability UX 同步 | Completed | Keep selected-agent health card and capability matrix semantics stable when adding triage/explainability | 核心工作流（侧栏、adapter matrix、findings 过滤）口径一致 |
| P0 | V2.24 Skill Detail 诊断口径 | Completed | Keep Detail=single skill workbench; Findings=issue groups; Conflicts=current-agent; Analysis read-only/offline; History=toggle/config events | catalog.detail（single skill）与 list/health/analysis 数字口径一致 |
| P0 | V2.26 Finding explainability | Completed | Keep rule source, trigger reason/message, affected instances, severity/risk mapping, and next action visible in finding/detail surfaces | Users can understand every finding count and drill down from Health to concrete skill/rule/path context |
| P0 | V2.27 Skill identity/provenance dedupe | Completed | Keep agent/scope/definition/path identity deterministic; keep Pi `.md` noise excluded; label opencode native vs compatibility roots | Users can explain why each skill appears once, appears under multiple agents, or is intentionally excluded |
| P0 | V2.28 Conflict semantic closeout | Completed | Keep UI/protocol wording so same-agent conflicts and cross-agent analysis never share the same counter | Conflict tabs only show current-agent collisions; Analysis owns cross-agent duplicate/source-overlap |
| P0 | V2.29 Finding triage persistence | Completed | Add app-local reviewed/ignored/needs-follow-up state in catalog/app data with automatic reopen on changed finding fingerprint or affected-instance set; no agent-config writes, no skill-toggle snapshot, no skill-content snapshot; no script execution / AI write-back / credential persistence | Users can separate known issues from new actionable findings without write-path side effects |
| P0 | V2.30 AI skill analysis workflow | Completed | Extend disabled-by-default read-only AI analysis to batch summaries and suggestion drafts | Users get readable skill analysis with no writes, no script execution, no provider calls by default, and no credential storage |
| P0 | V2.31 Cleanup Queue | Completed | Turn open findings, integrity issues, and analysis insights into an app-local read-only queue with clear next actions that only point to existing safe action paths | Users can work down skill cleanup items without introducing new automatic write/execute paths |
| P0 | V2.32 Rule tuning / suppression | Completed | Add app-local rule severity overrides and suppression records with audit/revert semantics, without touching skill files/agent config/snapshots or provider/credential paths | Users can quiet intentional findings and tune priority while preserving reviewability |
| P0 | V2.33 Safe batch actions | Completed | Add preview-first batch enable/disable for verified writable agents/roots only, with skipped-item reasons for read-only scope, snapshot/rollback plans, explicit confirmation, and matching preview id before any write | Users can safely act on multiple selected skills without hidden writes |
| P0 | V2.34 Cross-agent comparison view | Completed | Add read-only comparison for same-name/similar skills across agents, including state/source/risk/capability/diff summaries | Users can understand cross-agent drift before cleanup/export |
| P0 | V2.35 Local report export | Completed | Add user-triggered redacted Markdown/JSON local audit export from existing read models; no public distribution, provider calls, credentials, scripts, or automatic writes | Users can share/review skill inventory and risk state without leaking local paths or widening write scope |
| P0 | V2.36 Pi writable evidence harness | Complete | Validate Pi writable semantics only in disposable roots with rollback proof before any production toggle/install surface is enabled | Pi writable can advance only with evidence instead of assumptions |
| P1 | Finding triage usability and grouping | Planned | Add grouping and shortcut filters for reviewed/ignored/needs follow-up findings (by rule / severity / agent / source) without writing agent config, script execution, AI write-back, or credentials | Users can act on persistent triage faster without widening state persistence scope |
| P1 | Agent-config timeline | Completed | Keep per-agent config snapshots and activity history only for config/toggle events; enforce preview diff and second-step confirmation for rollback; do not add skill-content snapshot or skill-toggle snapshot | Users can understand config changes and rollback points |
| P1 | Read-only AI skill analysis assist | Implemented offline preview | Keep V2.7 disabled-by-default gate and V2.20 offline purpose/risk/finding summaries free of provider/client/storage/write/execution paths | Users get human-readable analysis without any write, execution, or credential risk |

## Version Selection Rule

- If the task is OpenClaw/Hermes scanner work, use V2.16/V2.17.
- If the task is already-completed cross-agent analysis, dashboard, scan accuracy, dedupe, finding/conflict semantics, single-skill detail, or agent-config timeline maintenance, reference V2.18-V2.25.
- If the task improves finding explanations, skill identity/provenance, conflict semantics, triage persistence, or read-only AI analysis workflow, use V2.26-V2.30.
- If the task builds cleanup queue, policy tuning, safe batch actions, cross-agent comparison, or local report export, use V2.31-V2.35.
- If the task is Pi writable evidence, Hermes external roots, OpenClaw workspace deepening, or adapter diagnostics, use V2.36-V2.40.
- If the task is AI provider foundation, prompt safety, AI quality/readiness/routing, task benchmark/regression, trace analysis, knowledge index, remediation, policy, governance report, provider observability, or safe write expansion planning, use V2.41-V2.70.
- Do not create versions for script execution, GitHub clone import, script-file install, signing, notarization, DMG/ZIP, public distribution, or full-platform UI adaptation unless the product direction changes explicitly.

## V2.35 Local report export — completed
- [x] Document local export intent and completed status in user-facing docs (README + roadmap + AGENTS).
- [x] Record report scope: agent coverage/status, health summary, open findings/triage state, cleanup queue, cross-agent comparison insights.
- [x] Document redaction requirements for exported data: local paths and environment roots must be replaced with placeholders.
- [x] Document explicit non-goals: public distribution, DMG/ZIP/signing/notarization, cloud sync, telemetry, provider calls, credential storage, script execution, automatic write-back.
- [x] Confirm V2.33/V2.34 semantics are preserved in updated docs.
- [x] Validate with `pnpm check:macos`, real local App export, and generated report path-redaction check.

## V2.39 OpenClaw workspace deepening (completed)

- Task definition: perform OpenClaw workspace-scoped deepening, constrained to `<workspace>/skills` and `<workspace>/.agents/skills`.
- Explicitly avoid arbitrary repo-root inference.
- Keep capabilities read-only; writable/install, scripts, AI auto-write, and credentials remain blocked.
- Completed after implementation, focused checks, `pnpm check:macos`, and explicit real-app Computer Use/window blocker documentation.
