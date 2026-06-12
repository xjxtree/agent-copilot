# skills-copilot

> 桌面 GUI：把分散在多个 AI agent（Claude Code / Codex / Pi / Hermes / OpenClaw / opencode）的 **skills** 统一管理、配置和审计。

## 当前状态

**当前阶段**：V2.66 Skill Lifecycle Timeline complete。V2.65 `task.buildCockpit` 已完成并保持 task-first cockpit 本地只读边界。V2.66 新增 `skill.lifecycleTimeline`，基于 existing catalog evidence、scan/provenance/fingerprint state、stale/drift、finding/triage/remediation history、prompt run metadata、provider observability metadata 与 session review outcomes 派生 per-skill/per-agent/per-workspace lifecycle timeline rows。该路径是用户触发、deterministic/read-only、app-local evidence only，不默认持久化 new raw lifecycle artifacts，不保存 raw prompt/raw response JSON、API keys、credentials、raw traces、secrets 或 unredacted paths，不写 skill/config、不改 triage、不创建或回滚 snapshot、不执行脚本、不默认发 provider/network request、不云同步、不发 telemetry。

**近期主线**：后续统一为 **AI-native Skill Review and Observability**。本地 scanner/rules/catalog 继续负责事实层；围绕真实 agent 会话的 skill 发现/选择/漏用/错用审查、本地 skill map、provider 调用可观测性、task-first cockpit、skill lifecycle timeline 和 guided cleanup 作为连续短期规划。短期不做全平台 UI 适配、正式签名 release、notarization、DMG/ZIP 或 public distribution。OpenClaw/Hermes writable/install 与 Pi install 仍保持 blocked；Pi production toggle 仅限 V2.37 evidence-backed guarded native scope，不自动开放兼容根写入。

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
- V2.41-V2.65：AI Provider Foundation、Prompt Preview/Redaction、AI Skill Quality、AI Task Readiness、AI Routing Confidence、Task Benchmark/Regression、Trace Analysis、Routing Accuracy Dashboard、Local Knowledge Index、Remediation Workflow、Remediation History、Prompt Run History、Agent Session Skill Review、Local Skill Map、AI Provider Observability 与 Task-first Cockpit 已完成。V2.66 Skill Lifecycle Timeline 已完成。
- 2026-06-12 V2.63 真实本机 app validation 通过：当前 `dist/SkillsCopilot.app` 的 single-skill Analysis 页显示 Local Skill Map，点击 `Build Map` 后渲染真实 local map 输出（nodes、edges、clusters、evidence、safety sections）。真实本机截图未提交，因为 live UI 会暴露本地路径；fixture smoke 截图仍只作为自动化证据。V2.63 focused Rust/protocol、Swift/model/store、`pnpm check:macos`、`pnpm check:privacy` 与 `git diff --check` 均已通过；后续 coordinator 复测 exact-path Computer Use 时因重复同 bundle app 进程出现 `cgWindowNotFound` / `remoteConnection`，记录为工具/窗口层 blocker。
- 2026-06-12 V2.64 validation：focused Rust/protocol checks、full service tests、focused/full Swift decode/store checks、service protocol fixture decode、`pnpm check:macos`、`pnpm check:privacy` 与 `git diff --check` 已通过；fixture macOS smoke 成功启动并捕获 `dist/SkillsCopilot.app` 窗口。真实本机验证中当前 bundle 进程可启动，但 System Events 在 activation 与 clean relaunch 后仍看到 0 个窗口，Computer Use 返回 `cgWindowNotFound`；该项记录为 V2.64 window/tool-layer blocker。真实本机截图未提交，因为 live UI 会暴露本地路径。
- 2026-06-12 V2.65 validation：focused Rust/protocol checks、full service tests、focused/full Swift model/store checks、service protocol fixture decode、`pnpm check:macos`、`pnpm check:privacy` 与 `git diff --check` 已通过；fixture macOS smoke 成功启动并捕获 `dist/SkillsCopilot.app` 窗口。真实本机验证中当前 bundle 进程可启动且 System Events 能看到 `SkillsCopilot` 进程，但 activation 后仍报告 0 windows，Computer Use 返回 `cgWindowNotFound`；该项记录为 V2.65 window/tool-layer blocker。真实本机截图未提交，因为 live UI 会暴露本地路径。
- 2026-06-12 V2.66 validation：focused Rust lifecycle/protocol checks、service protocol fixture decode、full service tests、focused/full Swift model/store checks、`pnpm check:macos`、`pnpm check:privacy`、`git diff --check` 与 fixture screenshot inspection 已通过；fixture smoke 成功启动并捕获 `dist/SkillsCopilot.app` 窗口。真实本机验证中当前 bundle 进程可启动且直接 capture helper 找到 app 窗口，但 System Events 仍报告 0 AX windows，Computer Use 对绝对 app path 返回 `cgWindowNotFound`；该项记录为 V2.66 window/tool-layer blocker。真实本机截图未提交，因为 live UI 会暴露本地路径。

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
| V2.65-V2.67 | Cockpit / lifecycle / guided cleanup | V2.65 已完成 Task-first Cockpit；V2.66 Skill Lifecycle Timeline complete；V2.67 planned guided cleanup flow |

## 它做什么

- **统一视图**：按 agent × scope 扫描、聚合、对比 skills。
- **跨 agent 对比**：同名/相似 skills 在 Claude/Codex/opencode/Pi/Hermes/OpenClaw 的状态、来源、风险、可写能力与差异支持只读对比。
- **配置管理**：启用 / 禁用、读写 agent 配置文件，支持原子写、快照和回滚。
- **冲突与权限**：检测同名 skill 冲突，展示权限声明和规则 findings。
- **Tool-global skill 池**：本地目录导入到 app-controlled staging，审计后 read-only preview，并可经确认安装到 Claude/Codex verified skill root。
- **Cleanup Queue**：把 open findings、完整性问题和 analysis insights 聚合成可处理队列，主要支持查看详情、跳转到现有安全动作入口、或获取建议草稿进行人工处理。
- **Skill 执行安全边界**：默认不真实执行脚本；任何未来执行请求都必须展示 cwd/env/network/files 预览并逐次确认。
- **AI-native 分析 gate**：规则引擎和 scanner 默认离线提供事实层；provider-backed explanation 只在用户完成 prompt preview/redaction/confirmation 后发送，输出保持 copy-only。V2.61 起，已确认发送的 AI 分析会保存 redacted prompt run metadata 与 copy-only draft output，用于重启后恢复展示；V2.62 起，Agent Session Skill Review 只保存 app-local redacted review metadata 且不发送 provider requests；V2.63 起，Local Skill Map 只派生本地 read-only map，不创建新的 source of truth 或默认持久化 artifact；V2.64 起，Provider Observability 只汇总 app-local redacted prompt/call metadata 并返回 cleanup/retention recommendations；V2.65 起，Task-first Cockpit 只聚合现有 local task/readiness/routing/session/provider/remediation evidence，不创建 hidden task state；V2.66 起，Skill Lifecycle Timeline 只从 existing local catalog/evidence/history metadata 派生生命周期行，不默认持久化 raw lifecycle artifacts。它们都不保存 raw transcript、raw prompt、raw response JSON、API key、credential、raw trace 或未脱敏本地路径，也不写 skill/config、不改 triage、不执行脚本、不发 telemetry。

## 它不做什么

- 不替代任何 agent 运行时。
- 不云端同步，不做账号系统。
- 不在默认路径真实执行 skill 自带脚本。
- 不触发后台自动分析；LLM 不会在未显式用户操作时发起 provider 请求。
- 不让 LLM 触发执行、写入或确认用户动作。
- 不在 Cleanup Queue 阶段新增自动清理、自动写入或自动执行链路。

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
| MVP 施工图 | [`docs/mvp-implementation-plan.md`](./docs/mvp-implementation-plan.md) |
| 路线图 | [`docs/roadmap.md`](./docs/roadmap.md) |

## 技术栈

| 层 | 技术 |
| --- | --- |
| macOS 产品壳 | SwiftUI + AppKit interop，位于 `apps/macos`。 |
| 内核 | Rust workspace crates：core / adapters / scanner / catalog / ai-core / commands / service。 |
| Service protocol | typed JSON / JSON-RPC stdio sidecar，位于 `crates/service`。 |
| 持久化 | SQLite catalog + JSON runtime state。 |
| LLM / AI Analysis | V2.41+ 已支持用户自配 OpenAI-compatible / Claude-compatible endpoint、Keychain-first API key、prompt preview/redaction/confirmation 和 provider-backed draft output；V2.61 起 provider-backed 分析 10 分钟等待并保存 redacted prompt run history；V2.62 起支持 `session.*` deterministic Agent Session Skill Review 的 app-local redacted metadata；V2.63 起支持 `knowledge.buildLocalSkillMap` deterministic/read-only local skill map；V2.64 起支持 `llm.providerObservability` read-only/app-local provider observability；V2.65 起支持 `task.buildCockpit` task-first cockpit；V2.66 支持 `skill.lifecycleTimeline` deterministic/read-only lifecycle rows。所有输出仍为 copy-only/read-only，不写 skill/config、不执行脚本、不保存 raw transcript/raw prompt/raw response JSON/secrets/unredacted paths。 |

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
```

### App 运行入口

| 命令 | 用途 |
| --- | --- |
| `./script/build_and_run.sh run` / `pnpm dev:macos` | 重新组装 `dist/SkillsCopilot.app`，并用真实本机环境启动，用于看实际效果。 |
| `./script/build_and_run.sh --verify` / `pnpm build:macos` | 重新组装 app，启动并确认进程存在。 |
| `pnpm smoke:macos-app` | 不打包 app，只检查并启动已有的 `dist/SkillsCopilot.app`。 |
| `pnpm smoke:macos-app -- --fixture-data --capture-window` | 使用临时 fixture HOME/app data/project roots 验证核心流程，不触碰真实用户配置。 |
| `pnpm capture:macos-window` | 用窗口 ID 截取完整 app 窗口；禁止整桌面截图。 |

### 组合检查

| 命令 | 覆盖内容 |
| --- | --- |
| `pnpm check:macos` | fmt / test / clippy / native list model / layout check / SwiftPM test / Swift build / Local App Launch Verify / Smoke App Run。 |
| `pnpm check:privacy` | 检查真实本机路径、用户目录、临时 app-data 路径、常见 token/key 形态和二进制证据文件中的敏感字符串。 |
| `pnpm benchmark:10k` | 生成 10k 个临时 Claude skills，跑 scan → catalog 基准并输出耗时与最大 RSS。 |
| `pnpm test:macos-list-model` | 编译真实 Swift list model 并验证 search / filter / sort 行为。 |
| `pnpm benchmark:macos-list-model` | 用 10k 条 synthetic native records 测量 Swift list model 搜索、过滤、排序性能。 |
| `pnpm verify:macos-ui-layout` | 静态检查原生 macOS shell 的关键布局约束。 |

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
