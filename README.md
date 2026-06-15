# skills-copilot

> 桌面 GUI：把分散在多个 AI agent（Claude Code / Codex / Pi / Hermes / OpenClaw / opencode）的 **skills** 统一管理、配置和审计。

## 当前状态

**当前阶段**：V2.77 Real-local validation workbench 已完成。原生 app 现在有只读“验证工作台”，集中展示真实本机验证证据标准、13 个 canonical blocker、下一步动作、fixture smoke 仅辅助和稳定 `skills-copilot.validation-workbench` 可访问性标识。V2.77 不引入 raw prompt persistence、cloud sync、provider 默认调用、写入、执行、凭据、telemetry、scanner/catalog 事实层或新分析端点语义。

**V2.77 validation**：`pnpm verify:v2.77-docs` now requires completed evidence, including unlocked Computer Use against `<repo>/dist/SkillsCopilot.app`, PID `34909`, stable `skills-copilot.validation-workbench`, and screenshot evidence at `docs/ui-artifacts/v2.77-validation-workbench/completed.png`. V2.78-V2.83 remain planned.

**下一版本线**：V2.78 protocol / validation gate parity；V2.79 privacy fixture and evidence-surface localization sweep；V2.80 Detail navigation and visual density polish；V2.81 Swift service IPC cancellation cleanup；V2.82 provider-test env isolation + core model tests；V2.83 continued module splitting。2026-06-15 Minimax-m3 / GLM-5.1 review findings are assigned into V2.78-V2.83.

**近期主线**：V2.68-V2.72 的 post-V2.67 consolidation 已收口。事实层仍由本地 scanner/rules/catalog 提供；当前重点是保持 task cockpit、guided cleanup、screenshot-safe evidence、module boundaries、safe links 和 hardened validation 稳定。短期不做全平台 UI 适配、正式签名 release、notarization、DMG/ZIP 或 public distribution。OpenClaw/Hermes writable/install 与 Pi install 仍保持 blocked；Pi production toggle 仅限 V2.37 evidence-backed guarded native scope，不自动开放兼容根写入。

**已集成能力**：

- Claude Code MVP 与 native macOS 产品壳。
- Codex adapter 首个实现切片，以及 V2.1 到 V2.3 的 Codex/Claude 体验和硬化。
- V2.4 read-only opencode native-root adapter。
- V2.5 audit hardening、V2.6 manual readiness docs、V2.7 disabled-by-default LLM service/UI gate。
- V2.8 rules/permissions governance。
- V2.9 Tool-global local import/export/install flow。
- V2.10 skill execution safety docs/release consistency。
- V2.11 Adapter capability matrix 首个 service/UI 切片，用于展示六个 agent 的 scan/toggle/install 状态和 blocker。
- V2.12 opencode guarded writable：native roots 支持 exact `permission.skill` deny/re-enable、snapshot/rollback 和 tool-global install。
- V2.13 Pi read-only scanner/parser：支持 Pi-native global/project roots，Pi writes 继续 blocked。
- V2.14 Hermes evidence-gate closeout 与 V2.17 Hermes read-only scanner：active/profile Hermes home `skills/**/SKILL.md` 只读进入 catalog。
- V2.15 OpenClaw evidence-gate closeout 与 V2.16 OpenClaw read-only scanner：workspace/global documented filesystem roots 只读进入 catalog。
- V2.18-V2.40：cross-agent analysis、skill health dashboard、read-only AI skill analysis、scan accuracy/dedupe、finding/conflict 语义、Health/Adapter Capability UX、Detail 诊断口径、Agent-config timeline、Finding explainability、skill identity/provenance dedupe、conflict semantic closeout、finding triage persistence、AI skill analysis workflow、Cleanup Queue、Rule tuning / suppression、Safe batch actions、Cross-agent comparison view、Local report export、Pi writable evidence harness、Pi guarded writable toggle、Hermes external roots、OpenClaw workspace deepening、Adapter diagnostics 已收口。
- V2.41-V2.77：AI Provider Foundation、Prompt Preview/Redaction、AI Skill Quality、AI Task Readiness、AI Routing Confidence、Task Benchmark/Regression、Trace Analysis、Routing Accuracy Dashboard、Local Knowledge Index、Remediation Workflow、Remediation History、Prompt Run History、Agent Session Skill Review、Local Skill Map、AI Provider Observability、Task-first Cockpit、Skill Lifecycle Timeline、Guided Cleanup Flow、Task Cockpit primary entry / Analysis IA 重组、Privacy / Screenshot Mode + 本地化收束、Swift/Rust feature modularization、Guided Cleanup safe-action deep links、Validation harness hardening、Task/remediation performance + timeout recovery、Real-local launch/window targeting stability、Task input and input-method resilience、Progressive Cockpit feedback、Real-local validation workbench 已完成。
- 2026-06-12 V2.63 真实本机 app validation 通过：当前 `dist/SkillsCopilot.app` 的 single-skill Analysis 页显示 Local Skill Map，点击 `Build Map` 后渲染真实 local map 输出（nodes、edges、clusters、evidence、safety sections）。真实本机截图未提交，因为 live UI 会暴露本地路径；fixture smoke 截图仍只作为自动化证据。V2.63 focused Rust/protocol、Swift/model/store、`pnpm check:macos`、`pnpm check:privacy` 与 `git diff --check` 均已通过；后续 coordinator 复测 exact-path Computer Use 时因重复同 bundle app 进程出现 `cgWindowNotFound` / `remoteConnection`，记录为工具/窗口层 blocker。
- 2026-06-12 V2.64 validation：focused Rust/protocol checks、full service tests、focused/full Swift decode/store checks、service protocol fixture decode、`pnpm check:macos`、`pnpm check:privacy` 与 `git diff --check` 已通过；fixture macOS smoke 成功启动并捕获 `dist/SkillsCopilot.app` 窗口。真实本机验证中当前 bundle 进程可启动，但 System Events 在 activation 与 clean relaunch 后仍看到 0 个窗口，Computer Use 返回 `cgWindowNotFound`；该项记录为 V2.64 window/tool-layer blocker。真实本机截图未提交，因为 live UI 会暴露本地路径。
- 2026-06-12 V2.65 validation：focused Rust/protocol checks、full service tests、focused/full Swift model/store checks、service protocol fixture decode、`pnpm check:macos`、`pnpm check:privacy` 与 `git diff --check` 已通过；fixture macOS smoke 成功启动并捕获 `dist/SkillsCopilot.app` 窗口。真实本机验证中当前 bundle 进程可启动且 System Events 能看到 `SkillsCopilot` 进程，但 activation 后仍报告 0 windows，Computer Use 返回 `cgWindowNotFound`；该项记录为 V2.65 window/tool-layer blocker。真实本机截图未提交，因为 live UI 会暴露本地路径。
- 2026-06-12 V2.66 validation：focused Rust lifecycle/protocol checks、service protocol fixture decode、full service tests、focused/full Swift model/store checks、`pnpm check:macos`、`pnpm check:privacy`、`git diff --check` 与 fixture screenshot inspection 已通过；fixture smoke 成功启动并捕获 `dist/SkillsCopilot.app` 窗口。真实本机验证中当前 bundle 进程可启动且直接 capture helper 找到 app 窗口，但 System Events 仍报告 0 AX windows，Computer Use 对绝对 app path 返回 `cgWindowNotFound`；该项记录为 V2.66 window/tool-layer blocker。真实本机截图未提交，因为 live UI 会暴露本地路径。
- 2026-06-12 V2.67 validation：focused Rust guided-cleanup/protocol checks、full service tests、focused/full Swift model/store checks、`pnpm check:macos`、fixture screenshot inspection、`pnpm check:privacy`、`git diff --check` 与 `git diff --cached --check` 已通过；fixture smoke 成功启动并捕获 `dist/SkillsCopilot.app` 窗口。真实本机验证中当前 bundle 进程可启动且 direct capture helper 找到 app 窗口，但 System Events 仍报告 0 AX windows，Computer Use 对绝对 app path 返回 `cgWindowNotFound`；该项记录为 V2.67 window/tool-layer blocker。真实本机截图未提交，因为 live UI 会暴露本地路径。
- 2026-06-13 V2.68 validation：V2.68 multi-agent analysis completed, focused Rust service/protocol checks, Swift tests, native layout checks, full `pnpm check:macos`, fixture screenshot inspection, `pnpm check:privacy`, and `git diff --check` passed. Fixture smoke captured the cockpit-first IA with Work surfaces visible before diagnostic cards. Real local launch against the current bundle succeeded and CG window metadata found the `SkillsCopilot` window, but the macOS session was locked (`CGSSessionScreenIsLocked=Yes`), Computer Use timed out, and the final direct capture was all black; this is recorded as the V2.68 locked-session/window-capture blocker. No real-local screenshot was committed.
- 2026-06-13 V2.69 validation：V2.69 multi-agent analysis completed; screenshot privacy mode, path redaction/collapse/reveal, localized Task Cockpit/Guided Cleanup/Provider Observability labels, app-language propagation, screenshot artifact verifier, and lock/black capture rejection were added. Focused Swift/native checks, `swift test --package-path apps/macos`, screenshot artifact verification, no-capture fixture smoke, `pnpm check:privacy`, and `git diff --check` passed. Full `pnpm check:macos` reached fixture capture and then failed closed with `locked-session: macOS session is locked; refusing to create screenshot evidence`, so no fresh V2.69 screenshot was committed. Real-local Computer Use returned `timeoutReached`; `ioreg` reported `CGSSessionScreenIsLocked=Yes`; direct capture exited with `locked-session`. Real-local Computer Use must be rerun when the macOS session is unlocked; invalid locked/black captures are now blockers, not accepted UI evidence.
- 2026-06-13 V2.70 validation：V2.70 multi-agent analysis completed; Swift Task Cockpit/detail primitives and Rust cleanup queue were split into feature modules without service semantic changes. Focused Rust cleanup/protocol checks, Swift build/tests, native layout verification, screenshot artifact verification, no-capture fixture smoke, `pnpm check:privacy`, and `git diff --check` passed. Full `pnpm check:macos` passed build/test/service stages, then failed closed at fixture capture with `locked-session: macOS session is locked; refusing to create screenshot evidence`. Real-local Computer Use returned `timeoutReached`; `ioreg` reported `CGSSessionScreenIsLocked=Yes`; direct capture exited 6 with `locked-session`. No fresh V2.70 screenshot was committed, and real-local visual validation must be rerun after unlock.
- 2026-06-13 V2.71 validation：V2.71 multi-agent analysis completed; service safe-link DTOs, protocol fixture, Swift decoders, Guided Cleanup UI buttons, store routing, Analysis remediation panel mounting, and native UI verifier checks were updated. Focused Rust guided-cleanup/protocol/dispatch checks, full Swift tests, native layout verification, screenshot artifact verification, rebuilt no-capture fixture smoke, `pnpm check:privacy`, and `git diff --check` passed. Full `pnpm check:macos` passed build/test/service stages, then failed closed at fixture capture with `locked-session: macOS session is locked; refusing to create screenshot evidence`. Real-local Computer Use returned `timeoutReached`; no fresh V2.71 screenshot was committed, and unlocked visual validation remains required.
- 2026-06-13 V2.72 validation：V2.72 multi-agent analysis completed; validation blocker taxonomy, classifier CLI, smoke lock-session preflight, screenshot verifier canonical blocker failures, and validation docs/checklist were added. `pnpm verify:validation-blockers`, `pnpm classify:validation-blocker -- "Computer Use server error -10005: timeoutReached"`, synthetic black PNG rejection, `pnpm verify:screenshot-artifacts`, no-capture fixture smoke, `pnpm check:privacy`, and `git diff --check` passed. `pnpm smoke:macos-app -- --fixture-data --capture-window` and full `pnpm check:macos` fail closed at fixture capture with canonical `locked-session` in the current locked macOS session; real-local Computer Use still returns `timeoutReached`, so unlocked visual validation remains required.
- 2026-06-15 V2.73 validation：multi-agent V2.73 implementation completed; focused Rust service/protocol checks, full workspace Rust tests, workspace clippy, focused/full Swift tests, native list/layout checks, `pnpm check:privacy`, `pnpm check:macos`, screenshot artifact verification, and `git diff --check` passed. Unlocked Computer Use targeted the current workspace `dist/SkillsCopilot.app`, exercised Task Cockpit input/loading/fallback/retry, and captured evidence at [`docs/ui-artifacts/v2.73-task-cockpit-timeout-recovery/completed.png`](./docs/ui-artifacts/v2.73-task-cockpit-timeout-recovery/completed.png).
- 2026-06-15 V2.74 validation：multi-agent V2.74 implementation completed; launch/smoke/capture tooling now targets the current workspace bundle path/PID/window identity, duplicate same-bundle launches fail closed, the Swift app exposes a stable main-window identity and Task Cockpit accessibility IDs, `pnpm check:macos`, `pnpm check:privacy`, screenshot artifact verification, and `git diff --check` passed. Unlocked Computer Use targeted `dist/SkillsCopilot.app`, resolved PID `52193` and window ID `skills-copilot.main-window`, exercised Task Cockpit input/build/fallback result read-back, and captured evidence at [`docs/ui-artifacts/v2.74-launch-window-targeting/completed.png`](./docs/ui-artifacts/v2.74-launch-window-targeting/completed.png).
- 2026-06-15 V2.75 validation：multi-agent V2.75 implementation completed; Task Cockpit task entry now uses an AX-settable multiline input with stable IDs, preserves exact nonblank service-call text while rejecting whitespace-only submissions, and keeps task execution behind explicit Build. Focused Swift model/store tests, `pnpm verify:macos-ui-layout`, `pnpm check:macos`, `pnpm check:privacy`, screenshot artifact verification, and `git diff --check` passed. Unlocked Computer Use targeted `dist/SkillsCopilot.app`, resolved PID `43079`, verified `skills-copilot.task-cockpit.input` / `skills-copilot.task-cockpit.input.status`, set Chinese/emoji/multiline task text, observed `Ready for explicit submit.`, clicked Build, and captured evidence at [`docs/ui-artifacts/v2.75-task-input-resilience/completed.png`](./docs/ui-artifacts/v2.75-task-input-resilience/completed.png).
- 2026-06-15 V2.76 validation：multi-agent V2.76 implementation completed; Task Cockpit now shows progressive staged feedback for readiness/routing/cross-agent/remediation/provider/session, elapsed time, partial/fallback/skipped/blocked states, and stable `skills-copilot.task-cockpit.stage-progress` read-back while preserving V2.75 task input behavior. Focused Swift model/store tests, `pnpm verify:macos-ui-layout`, `pnpm check:macos`, `pnpm check:privacy`, screenshot artifact verification, `pnpm verify:v2.76-docs`, and `git diff --check` passed. Unlocked Computer Use targeted `dist/SkillsCopilot.app`, resolved PID `39728`, verified `skills-copilot.task-cockpit.input` / `skills-copilot.task-cockpit.input.status` / `skills-copilot.task-cockpit.stage-progress`, observed `耗时：5 秒` staged progress before fallback, then `耗时：6 秒`, `Fallback / 部分`, `10 个阻塞项`, `已超时`, partial and skipped stage rows, and captured evidence at [`docs/ui-artifacts/v2.76-progressive-cockpit-feedback/completed.png`](./docs/ui-artifacts/v2.76-progressive-cockpit-feedback/completed.png).
- 2026-06-15 V2.77 validation：multi-agent V2.77 implementation completed; the native Work surface now exposes a read-only Validation Workbench / 验证工作台 with `skills-copilot.validation-workbench`, canonical blocker rows, evidence standards, fixture-smoke supporting-only guidance, and no runnable validation actions. Focused Swift model tests, `pnpm verify:macos-ui-layout`, `pnpm check:macos`, `pnpm check:privacy`, screenshot artifact verification, `pnpm verify:v2.77-docs`, and `git diff --check` passed. Unlocked Computer Use targeted `dist/SkillsCopilot.app`, resolved PID `34909`, verified `skills-copilot.validation-workbench`, `skills-copilot.validation-workbench.summary`, `skills-copilot.validation-workbench.evidence-standards`, canonical blocker rows, and captured evidence at [`docs/ui-artifacts/v2.77-validation-workbench/completed.png`](./docs/ui-artifacts/v2.77-validation-workbench/completed.png). V2.78-V2.83 remain planned follow-ups.

**当前产品 UI**：SwiftUI/AppKit macOS 原生壳 + Rust service protocol。

**旧 UI 状态**：旧 Tauri/React UI 与 Tauri IPC 壳已删除，不再是当前代码的一部分。

## Adapter 支持状态

| Agent | 当前状态 | 备注 |
| --- | --- | --- |
| Claude Code | 已支持 | 支持 scan、catalog、toggle、settings editor、snapshot rollback。 |
| Codex | 已支持已验证范围 | 支持 verified user/project roots、cwd→repo-root discovery、`catalog.scanAll`、agent filter、project context 归属和用户级 `config.toml` toggle。 |
| opencode | 已支持已验证范围 | 支持 native roots：`~/.config/opencode/skills` 和当前项目 `.opencode/skills`；支持 guarded writable toggle/install，写入 exact `permission.skill.<name> = "deny"` 并保留 snapshot/rollback。 |
| Pi | guarded toggle + install blocked | V2.13 已实现 Pi-native global/project scanner/parser；V2.36 disposable evidence harness 已验证 global/project/package toggle、rollback、trust gate、invalid JSON/config 处理、re-enable；V2.37 已实现最小 guarded native global/project/package toggle，project/package 需要 trusted project settings，compatibility roots 不可写，install 仍 blocked。 |
| Hermes | read-only | V2.17 已实现 active/profile Hermes home `skills/**/SKILL.md` 只读扫描；V2.38 已支持显式 `skills.external_dirs` 作为 read-only external roots；不做 generic project scan；writable toggle/install 仍 blocked。 |
| OpenClaw | read-only | V2.16 已实现文档化 filesystem roots 只读扫描；V2.39 深化 workspace scope，仅 `<workspace>/skills` 和 `<workspace>/.agents/skills` 会被视为 OpenClaw workspace roots，不按任意 repo root 推断；writable toggle/install 仍 blocked。 |

## 后续统一版本规划

| 版本 | 目标 | 状态 |
| --- | --- | --- |
| V2.31 | Cleanup Queue（默认 read-only 列表 + 现有安全动作入口） | 已完成 |
| V2.32 | Rule tuning / suppression（本地 rule override / suppression，可审计可撤销） | 已完成：仅 app-local 元数据，默认不改写 skill 文件/agent config，不新增快照，且无脚本执行/AI provider/凭据/telemetry 路径 |
| V2.33 | Safe batch actions（verified writable agents 的 preview-first 批量 enable/disable） | 已完成：Apply 前必须显式确认，且确认 preview id 必须仍匹配当前 preview |
| V2.34 | Cross-agent comparison view（跨 agent 同名/相似 skill 差异对比） | 已完成：Analysis 中只读展示，不新增写入/执行/provider/credential/snapshot 路径 |
| V2.35 | Local report export（脱敏 Markdown/JSON 本地审计报告） | 已完成：本地 app-data 导出、递归路径脱敏、无 public distribution/provider/credential/script/自动写回路径 |
| V2.36 | Pi writable evidence harness | 已完成：临时 agentDir/fixture project evidence-only 验证通过（global/project/package toggle 语义、rollback、trust gate、invalid JSON/config 处理、re-enable）；生产 writable 仍 blocked |
| V2.37 | Pi writable guarded slice | 已完成：Pi native global/project/package guarded toggle、preview/snapshot/rollback、disabled-state rescan；Pi install/兼容根写入/脚本执行/AI 自动写回/credentials 仍 blocked |
| V2.38 | Hermes external roots | 已完成：将配置 `skills.external_dirs` 作为 explicit external roots 进入只读扫描与 UI provenance，不推断 generic project roots；writable/install 继续 blocked |
| V2.39 | OpenClaw workspace 深化 | 已完成：精准识别 OpenClaw workspace scope，只扫描 confirmed workspace roots，不推断任意 repo；writable/install 继续 blocked |
| V2.40 | Adapter diagnostics | 已完成：read-only `adapter.listDiagnostics`、`service.status` / `app.stateSnapshot` diagnostics、scan activity summary 与 sidebar Adapter Capabilities 诊断展示已接入；无新增写入、执行、provider、credential 或 telemetry 路径 |
| V2.41-V2.45 | Provider + prompt safety + quality/readiness/routing | 已完成：Keychain-first provider profile、prompt preview/redaction/confirmation、deterministic quality/task readiness/routing confidence；provider explanation copy-only |
| V2.46-V2.50 | Task benchmark / trace / routing accuracy | 已完成：任务基准、routing regression、trace import、routing accuracy dashboard、cross-agent task readiness |
| V2.51-V2.55 | Drift / knowledge / taxonomy / workspace readiness | 已完成：stale/drift、local knowledge search、similar skill grouping、capability taxonomy、workspace readiness |
| V2.56-V2.60 | AI remediation workflow | 已完成：remediation plan、fix preview draft、impact preview、batch review、app-local remediation history |
| V2.61 | AI Analysis UX / Prompt Run History | 已完成：Analysis 页面精简为 3 个合并项目；provider-backed AI 分析 10 分钟超时；app-local redacted prompt run history 支持重启展示与 rerun 追加 |
| V2.62 | Agent Session Skill Review | 已完成：`session.reviewAgentSkillUse` / `session.listSkillReviews` / `session.deleteSkillReview`，用户触发、deterministic/read-only、app-local redacted metadata only；审查 pasted/imported agent sessions/traces 的 skill hit/miss/wrong-pick/ambiguity/unknown、expected vs detected skills、similar/duplicate interference、safe next steps 与 evidence refs |
| V2.63 | Local Skill Map | 已完成：`knowledge.buildLocalSkillMap` 基于 existing catalog/knowledge/similar/taxonomy/conflict/task/risk evidence 构建本地 skill map；用户触发、deterministic/read-only、no new source of truth、no map artifact persistence by default、无 skill/config writes、snapshot、triage、script、default provider、raw prompt/response/trace/secret、cloud/telemetry 路径 |
| V2.64 | AI Provider Observability | 已完成：`llm.providerObservability` 从 V2.61 prompt run metadata 与最小 provider call metadata 派生 read-only/app-local observability；输出调用历史、provider/model/destination grouping、status rows、budget usage hints、retention recommendations、evidence refs、prompt metadata 与 safety flags；无 provider/default network/write/execute/telemetry 路径 |
| V2.65-V2.72 | Cockpit / lifecycle / guided cleanup / IA / privacy / modularization / safe links / validation | 已完成：V2.65 Task-first Cockpit、V2.66 Skill Lifecycle Timeline、V2.67 Guided Cleanup Flow、V2.68 Task Cockpit primary entry / Analysis IA 重组、V2.69 Privacy / Screenshot Mode + 本地化收束、V2.70 Swift / Rust feature modularization、V2.71 Guided Cleanup safe-action deep links、V2.72 Validation harness hardening |
| V2.68 | Task Cockpit 主入口 / Analysis IA 重组 | 已完成：Task Cockpit 默认入口、Sidebar Work surfaces、菜单式 detail section switcher、Analysis 拆分为 Task Cockpit / Skill Map / Guided Cleanup / Observability / Review；复用 existing service methods，不新增写入/provider 默认调用 |
| V2.69 | Privacy / Screenshot Mode + 本地化收束 | 已完成：默认截图隐私模式、路径脱敏/折叠/reveal、本地化补齐、`app_language` 传递、截图 artifact verifier、锁屏/黑屏 capture 拒绝 |
| V2.70 | Swift / Rust feature modularization | 已完成：拆出 `TaskCockpitPanel.swift`、`DetailPresentationPrimitives.swift` 与 Rust `cleanup_queue.rs`；更新 native UI verifier 聚合拆分文件；不改变 service method / payload / persistence / provider / write 语义 |
| V2.71 | Guided Cleanup safe-action deep links | 已完成：guided cleanup steps/actions 暴露 safe deep-link metadata，Swift UI 可打开既有 `remediation.plan` / `remediation.previewDrafts` / `remediation.previewImpact` / `remediation.batchReview` / lifecycle / cockpit / cleanup / safe batch preview / metadata record 入口；不隐藏 apply，不绕过 preview/confirm |
| V2.72 | Validation harness hardening | 已完成：统一 validation blocker taxonomy、分类 CLI、新增 `verify:validation-blockers`、smoke 锁屏 preflight、截图 verifier canonical blocker 输出、fixture/real evidence matrix；锁屏/黑屏/单色/透明截图不能作为完成证据 |
| V2.73 | Task / remediation performance and timeout recovery | 已完成：真实 catalog 下 task/readiness/routing/remediation 聚合有 bounded metadata、scan/detail limits、fallback/partial diagnostics、取消/重试 UI 和 unlocked real-local Computer Use evidence |
| V2.74 | Real-local launch and window targeting stability | 已完成：dev launch/smoke/capture 以当前 bundle path/PID/window identity 为准；重复同 bundle app fail closed；主窗口和 Task Cockpit 暴露稳定 AX/Computer Use 标识；unlocked real-local evidence 已收口 |
| V2.75 | Task input and input-method resilience | 已完成：AX-settable 多行任务输入、中文/emoji/换行/前后空格保留、空白任务禁用、显式 Build submit、Computer Use exact-path evidence 和截图证据已收口 |
| V2.76 | Progressive Cockpit feedback | 已完成：把 Cockpit 的 readiness/routing/cross-agent/remediation/provider/session 阶段拆开呈现，显示 partial rows、elapsed time、timeout/fallback/blocked states；unlocked real-local Computer Use 和截图证据已收口 |
| V2.77 | Real-local validation workbench | 已完成：新增只读验证工作台，展示 lock/window/AX/Screen Recording/stale or duplicate bundle/invalid capture/Computer Use blocker 解释，稳定 `skills-copilot.validation-workbench`，并保留 unlocked manual visual review |
| V2.78 | Protocol / validation gate parity | 规划：同步 service protocol 方法文档与 gate，补 docs drift verifier、CI/local gate parity、V2.46-V2.64 verification-history 说明 |
| V2.79 | Privacy fixture and evidence-surface localization sweep | 规划：替换 local host-port fixture，扩展隐私扫描，并统一 Guided Cleanup、Skill Map、Review、Cockpit 等证据面板的路径脱敏/折叠/reveal 与中文本地化 |
| V2.80 | Detail navigation and visual density polish | 规划：切换 Work surface 时重置/恢复合理滚动位置，优化密集证据卡片、长列表、两列布局和阶段摘要，使真实 catalog 下的视觉层级更稳定 |
| V2.81 | Swift service IPC cancellation cleanup | 规划：为短生命周期 stdio sidecar 调用增加取消/超时/子进程清理，不默认引入 daemon/socket |
| V2.82 | Test isolation and core model test floor | 规划：隔离 provider env mutation 测试，并补 core model serde/stability 测试 |
| V2.83 | Continued module splitting | 规划：继续按既有 domain 拆分大型 Rust/Swift service、view、store、test 文件，不改变产品语义 |

## 它做什么

- **统一视图**：按 agent × scope 扫描、聚合、对比 skills。
- **跨 agent 对比**：同名/相似 skills 在 Claude/Codex/opencode/Pi/Hermes/OpenClaw 的状态、来源、风险、可写能力与差异支持只读对比。
- **配置管理**：启用 / 禁用、读写 agent 配置文件，支持原子写、快照和回滚。
- **冲突与权限**：检测同名 skill 冲突，展示权限声明和规则 findings。
- **Tool-global skill 池**：本地目录导入到 app-controlled staging，审计后 read-only preview，并可经确认安装到 Claude/Codex verified skill root。
- **Cleanup Queue**：把 open findings、完整性问题和 analysis insights 聚合成可处理队列，主要支持查看详情、跳转到现有安全动作入口、或获取建议草稿进行人工处理。
- **Skill 执行安全边界**：默认不真实执行脚本；任何未来执行请求都必须展示 cwd/env/network/files 预览并逐次确认。
- **AI-native 分析 gate**：规则引擎和 scanner 默认离线提供事实层；provider-backed explanation 只在用户完成 prompt preview/redaction/confirmation 后发送，输出保持 copy-only。V2.61 起，已确认发送的 AI 分析会保存 redacted prompt run metadata 与 copy-only draft output，用于重启后恢复展示；V2.62 起，Agent Session Skill Review 只保存 app-local redacted review metadata 且不发送 provider requests；V2.63 起，Local Skill Map 只派生本地 read-only map，不创建新的 source of truth 或默认持久化 artifact；V2.64 起，Provider Observability 只汇总 app-local redacted prompt/call metadata 并返回 cleanup/retention recommendations；V2.65 起，Task-first Cockpit 只聚合现有 local task/readiness/routing/session/provider/remediation evidence，不创建 hidden task state；V2.66 起，Skill Lifecycle Timeline 只从 existing local catalog/evidence/history metadata 派生生命周期行，不默认持久化 raw lifecycle artifacts；V2.67 起，Guided Cleanup Flow 只把现有 evidence 组织成可复查步骤，`cleanup.recordGuidedStep` 仅可写 app-local redacted metadata；V2.68 起，Task Cockpit 成为默认可见入口但仍只是 UI/IA consolidation；V2.71 起，Guided Cleanup safe links 只打开既有安全入口，不执行 apply/write；V2.72 只加固验证证据口径，不改变产品语义。它们都不保存 raw transcript、raw prompt、raw response JSON、API key、credential、raw trace 或未脱敏本地路径，也不写 skill/config、不改 triage、不执行脚本、不发 telemetry。

## 它不做什么

- 不替代任何 agent 运行时。
- 不云端同步，不做账号系统。
- 不在默认路径真实执行 skill 自带脚本。
- 不触发后台自动分析；LLM 不会在未显式用户操作时发起 provider 请求。
- 不让 LLM 触发执行、写入或确认用户动作。
- 不在 Cleanup Queue 或 Guided Cleanup Flow 阶段新增自动清理、隐藏 apply、自动写入或自动执行链路。
- 不把未来版本规划文档视为已实现能力；对应版本必须完成代码、验证和文档 closeout 后才能标记 completed。

## 文档导航

| 想看 | 路径 |
| --- | --- |
| 整体架构 | [`docs/architecture.md`](./docs/architecture.md) |
| macOS 原生产品壳计划 | [`docs/macos-native-plan.md`](./docs/macos-native-plan.md) |
| Service protocol | [`docs/service-protocol.md`](./docs/service-protocol.md) |
| AI agent 工作流与验证规则 | [`docs/ai-agent-workflow.md`](./docs/ai-agent-workflow.md) |
| UI 交付标准 | [`docs/ui-delivery-standards.md`](./docs/ui-delivery-standards.md) |
| macOS app 运行与检查规范 | [`docs/macos-app-runbook.md`](./docs/macos-app-runbook.md) |
| V2 adapter changelog / risk tracking | [`CHANGELOG.md`](./CHANGELOG.md) |
| 6 个 agent 适配要点 | [`docs/agent-adapters.md`](./docs/agent-adapters.md) |
| 非 Claude adapter spec 工作单 | [`docs/agent-adapter-spec-worklists.md`](./docs/agent-adapter-spec-worklists.md) |
| Codex adapter spec 工作单 | [`docs/codex-adapter-spec.md`](./docs/codex-adapter-spec.md) |
| 统一数据模型 | [`docs/data-model.md`](./docs/data-model.md) |
| AI 层（规则 + LLM） | [`docs/ai-layer.md`](./docs/ai-layer.md) |
| 安全模型 | [`docs/security-model.md`](./docs/security-model.md) |
| 当前开发任务清单 | [`docs/development-tasks.md`](./docs/development-tasks.md) |
| V2.66 验证清单 | [`docs/v2.66-verification-checklist.md`](./docs/v2.66-verification-checklist.md) |
| V2.67 验证清单 | [`docs/v2.67-verification-checklist.md`](./docs/v2.67-verification-checklist.md) |
| V2.68 验证清单 | [`docs/v2.68-verification-checklist.md`](./docs/v2.68-verification-checklist.md) |
| V2.69 验证清单 | [`docs/v2.69-verification-checklist.md`](./docs/v2.69-verification-checklist.md) |
| V2.70 验证清单 | [`docs/v2.70-verification-checklist.md`](./docs/v2.70-verification-checklist.md) |
| V2.71 验证清单 | [`docs/v2.71-verification-checklist.md`](./docs/v2.71-verification-checklist.md) |
| V2.72 验证清单 | [`docs/v2.72-verification-checklist.md`](./docs/v2.72-verification-checklist.md) |
| V2.73 验证清单（completed） | [`docs/v2.73-verification-checklist.md`](./docs/v2.73-verification-checklist.md) |
| V2.74 验证清单（completed） | [`docs/v2.74-verification-checklist.md`](./docs/v2.74-verification-checklist.md) |
| V2.75 验证清单（completed） | [`docs/v2.75-verification-checklist.md`](./docs/v2.75-verification-checklist.md) |
| V2.76 验证清单（completed） | [`docs/v2.76-verification-checklist.md`](./docs/v2.76-verification-checklist.md) |
| V2.77 验证清单（completed） | [`docs/v2.77-verification-checklist.md`](./docs/v2.77-verification-checklist.md) |
| MVP 施工图 | [`docs/mvp-implementation-plan.md`](./docs/mvp-implementation-plan.md) |
| 路线图 | [`docs/roadmap.md`](./docs/roadmap.md) |

## 技术栈

| 层 | 技术 |
| --- | --- |
| macOS 产品壳 | SwiftUI + AppKit interop，位于 `apps/macos`。 |
| 内核 | Rust workspace crates：core / adapters / scanner / catalog / ai-core / commands / service。 |
| Service protocol | typed JSON / JSON-RPC stdio sidecar，位于 `crates/service`。 |
| 持久化 | SQLite catalog + JSON runtime state。 |
| LLM / AI Analysis | V2.41+ 已支持用户自配 OpenAI-compatible / Claude-compatible endpoint、Keychain-first API key、prompt preview/redaction/confirmation 和 provider-backed draft output；V2.61 起 provider-backed 分析 10 分钟等待并保存 redacted prompt run history；V2.62 起支持 `session.*` deterministic Agent Session Skill Review 的 app-local redacted metadata；V2.63 起支持 `knowledge.buildLocalSkillMap` deterministic/read-only local skill map；V2.64 起支持 `llm.providerObservability` read-only/app-local provider observability；V2.65 起支持 `task.buildCockpit` task-first cockpit；V2.66 支持 `skill.lifecycleTimeline` deterministic/read-only lifecycle rows；V2.67 支持 `cleanup.planGuidedFlow` read-only guidance and `cleanup.recordGuidedStep` app-local redacted step metadata；V2.68 把这些既有 read-only surfaces 重新组织为 cockpit-first IA；V2.71 为 guided cleanup 增加只通往 existing safe surfaces 的 deep links。所有输出仍为 copy-only/read-only，不写 skill/config、不执行脚本、不保存 raw transcript/raw prompt/raw response JSON/secrets/unredacted paths。 |

## 开发运行

### 常用命令

```sh
PATH="$HOME/.cargo/bin:$PATH" cargo test --workspace
PATH="$HOME/.cargo/bin:$PATH" cargo clippy --workspace --all-targets --all-features
./script/build_and_run.sh --verify
pnpm build:macos
pnpm check:privacy
pnpm capture:macos-window
pnpm check:macos
pnpm smoke:macos-app
pnpm smoke:macos-app -- --fixture-data --capture-window
pnpm smoke:macos-app -- --fixture-data --capture-window --check-logs
pnpm benchmark:10k
pnpm test:macos-list-model
pnpm benchmark:macos-list-model
pnpm verify:macos-ui-layout
pnpm verify:screenshot-artifacts
pnpm verify:v2.73-docs
pnpm verify:v2.74-docs
pnpm verify:v2.75-docs
pnpm verify:v2.76-docs
pnpm verify:v2.77-docs
```

### App 运行入口

| 命令 | 用途 |
| --- | --- |
| `./script/build_and_run.sh run` / `pnpm dev:macos` | 重新组装 `dist/SkillsCopilot.app`，并用真实本机环境启动，用于看实际效果。 |
| `./script/build_and_run.sh --verify` / `pnpm build:macos` | 重新组装 app，启动并确认进程存在。 |
| `pnpm smoke:macos-app` | 不打包 app，只检查并启动已有的 `dist/SkillsCopilot.app`。 |
| `pnpm smoke:macos-app -- --fixture-data --capture-window` | 使用临时 fixture HOME/app data/project roots 验证核心流程，不触碰真实用户配置。 |
| `pnpm capture:macos-window` | 用窗口 ID 截取完整 app 窗口；禁止整桌面截图；锁屏、近黑或近单色 capture 会失败。 |

### 组合检查

| 命令 | 覆盖内容 |
| --- | --- |
| `pnpm check:macos` | fmt / test / clippy / native list model / layout check / SwiftPM test / Swift build / Local App Launch Verify / Smoke App Run / screenshot artifact verification。 |
| `pnpm check:privacy` | 检查真实本机路径、用户目录、临时 app-data 路径、常见 token/key 形态和二进制证据文件中的敏感字符串。 |
| `pnpm benchmark:10k` | 生成 10k 个临时 Claude skills，跑 scan → catalog 基准并输出耗时与最大 RSS。 |
| `pnpm test:macos-list-model` | 编译真实 Swift list model 并验证 search / filter / sort 行为。 |
| `pnpm benchmark:macos-list-model` | 用 10k 条 synthetic native records 测量 Swift list model 搜索、过滤、排序性能。 |
| `pnpm verify:macos-ui-layout` | 静态检查原生 macOS shell 的关键布局约束。 |
| `pnpm verify:screenshot-artifacts` | 验证 `docs/ui-artifacts/**/*.png` 可读、非黑屏/非单色，并扫描二进制字符串中的明显路径或 token；仍需人工视觉复核。 |
| `pnpm verify:v2.73-docs` | 验证 V2.73 completed checklist 覆盖 Cockpit bounded loading、timeout/fallback/cancel/retry、unlocked real-local Computer Use、截图证据、命令记录和 safety-boundary gates。 |
| `pnpm verify:v2.74-docs` | 验证 V2.74 completed checklist 覆盖 exact workspace bundle/PID targeting、duplicate same-bundle detection、canonical blocker handling、unlocked real-local Computer Use evidence、截图证据和 no signing/notarization/distribution scope。 |
| `pnpm verify:v2.75-docs` | 验证 V2.75 completed checklist 覆盖 AX-settable task input、Chinese text、paste/automation text、multiline tasks、leading/trailing whitespace、emoji、explicit submit、focus/result stability、real-local Computer Use evidence、截图证据和 no raw prompt persistence/cloud/provider/write/execute/credential/telemetry scope。 |
| `pnpm verify:v2.76-docs` | 验证 V2.76 completed checklist 覆盖 Progressive Cockpit staged feedback、partial rows、elapsed time、timeout/fallback/blocked states、real-local Computer Use evidence、截图证据，以及 no provider/write/execute/credential/cloud/telemetry safety gates。 |
| `pnpm verify:v2.77-docs` | 验证 V2.77 completed checklist 覆盖 `skills-copilot.validation-workbench`、PID `34909`、`docs/ui-artifacts/v2.77-validation-workbench/completed.png`、canonical blocker explanations、unlocked Computer Use evidence，以及 no provider/write/apply/script/credential/cloud/telemetry safety gates。 |

### Fixture smoke 说明

`--fixture-data` 会注入临时 Claude、Codex 和 opencode fixture skills 与 app data。

Fixture smoke 会验证：

- scan / Enable-Disable / Settings save。
- Snapshot Preview / Snapshot Rollback。
- opencode native roots 的 read-only toggle 拒绝。
- app-window-only screenshot capture。

Fixture smoke 不触碰真实 Claude、Codex 或 opencode 配置。

## 贡献

当前贡献重点：

1. 实现 OpenClaw read-only scanner，不调用 OpenClaw CLI，不做 install/toggle。
2. 实现 Hermes read-only scanner，只扫描 active Hermes home skills，不做 project scan/toggle/install。
3. 实现 Pi writable evidence harness，覆盖 disposable settings mutation、rollback、trust gate 和 package filters。
4. 改进 native macOS app 的测试、文档和 service protocol。
5. 后续 UI 或 service protocol 变更继续重跑真实本机 app Computer Use 验证。

AI coding agents should use [`AGENTS.md`](./AGENTS.md) as the shared instruction entrypoint. Claude Code uses [`CLAUDE.md`](./CLAUDE.md), which imports the shared rules and only adds Claude-specific behavior.

详细贡献流程见 [`CONTRIBUTING.md`](./CONTRIBUTING.md)。

## 许可证

MIT — 详见 [`LICENSE`](./LICENSE)。

## V2.35 Local report export (completed)
Skills-copilot V2.35 covers local report export as a user-triggered, redacted audit artifact flow. It is completed after `pnpm check:macos`, real local App export validation, and generated report redaction verification.

- Exports are local-only, written under app data, and require explicit user action.
- Export formats: Markdown and JSON.
- Contents include:
  - Agent coverage and agent status snapshot
  - Health summary
  - Open findings and triage state (`Open`, `Reviewed`, `Ignored`, `Needs follow-up`)
  - Cleanup Queue state
  - Cross-agent comparison insights
- Sensitive local paths and roots are replaced with placeholders (`$HOME`, `<project-root>`, `<project-cwd>`, `<app-data-dir>`, `<redacted>`).
- V2.35 does not add public distribution, DMG/ZIP/signing/notarization, cloud sync, telemetry, provider/AI execution, credential persistence, script execution, or automatic write-back.
- Preserve existing V2.33 Safe Batch explicit-confirm behavior and V2.34 completed read-only comparison status.

## V2.39 OpenClaw workspace deepening (completed)

- V2.39 is defined as an OpenClaw, workspace-scoped read-only deepening pass.
- Scope is explicitly limited to confirmed workspace roots: `<workspace>/skills` and `<workspace>/.agents/skills`.
- OpenClaw must not infer arbitrary repository roots or generic project roots.
- OpenClaw writable/install paths, script execution, AI auto-write, credential handling, and public distribution workflows remain blocked in this milestone.
- V2.39 is complete after implementation, focused checks, `pnpm check:macos`, and explicit real-app Computer Use/window blocker documentation.
