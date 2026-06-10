# skills-copilot

> 桌面 GUI：把分散在多个 AI agent（Claude Code / Codex / Pi / Hermes / OpenClaw / opencode）的 **skills** 统一管理、配置和审计。

## 当前状态

**当前阶段**：V2.34 Cross-agent comparison view 已完成并通过真实本机 App Analysis 验证，V2.35 Local report export 已启动。V2.33 的验收口径为：对 verified writable agent/roots 提供批量 enable/disable preview-first 工作流，必须展示受影响技能、不可写跳过项及原因、snapshot/rollback 计划，并在 Apply 前要求显式确认且确认 preview id 仍匹配当前 preview；Pi/Hermes/OpenClaw 继续 read-only。V2.34 对同名/相似 skills 只做跨 agent 只读对比（state/source/risk/capability/diff），不新增写入、执行、AI provider、credential 或快照路径。继续围绕 skills 管理、检查、分析和配置审计推进。

**近期主线**：继续围绕 skills 管理、检查、分析和配置审计打磨体验。短期不做全平台 UI 适配、正式签名 release、notarization、DMG/ZIP 或 public distribution。OpenClaw/Hermes writable/install 与 Pi production writable 仍保持 blocked，直到 disposable rollback 证据通过。V2.35 本地报告导出保持脱敏、本地、用户触发，不作为 public distribution 或自动同步入口。

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
- V2.18-V2.34：cross-agent analysis、skill health dashboard、read-only AI skill analysis、scan accuracy/dedupe、finding/conflict 语义、Health/Adapter Capability UX、Detail 诊断口径、Agent-config timeline、Finding explainability、skill identity/provenance dedupe、conflict semantic closeout、finding triage persistence、AI skill analysis workflow、Cleanup Queue、Rule tuning / suppression、Safe batch actions、Cross-agent comparison view 已收口；V2.35 Local report export 正在进行。
- 2026-06-10 真实本机 app Computer Use validation 已通过；后续 UI/service/protocol 变更仍需重跑。

**当前产品 UI**：SwiftUI/AppKit macOS 原生壳 + Rust service protocol。

**旧 UI 状态**：旧 Tauri/React UI 与 Tauri IPC 壳已删除，不再是当前代码的一部分。

## Adapter 支持状态

| Agent | 当前状态 | 备注 |
| --- | --- | --- |
| Claude Code | 已支持 | 支持 scan、catalog、toggle、settings editor、snapshot rollback。 |
| Codex | 已支持已验证范围 | 支持 verified user/project roots、cwd→repo-root discovery、`catalog.scanAll`、agent filter、project context 归属和用户级 `config.toml` toggle。 |
| opencode | 已支持已验证范围 | 支持 native roots：`~/.config/opencode/skills` 和当前项目 `.opencode/skills`；支持 guarded writable toggle/install，写入 exact `permission.skill.<name> = "deny"` 并保留 snapshot/rollback。 |
| Pi | read-only | V2.13 已实现 Pi-native global/project scanner/parser；writable toggle/install 仍 blocked，等待 settings mutation/rollback 证据。 |
| Hermes | read-only | V2.17 已实现 active/profile Hermes home `skills/**/SKILL.md` 只读扫描；不做 generic project scan；显式 `skills.external_dirs` 另行设计为 external roots；writable toggle/install 仍 blocked。 |
| OpenClaw | read-only | V2.16 已实现文档化 filesystem roots 只读扫描；project scope 仅限 OpenClaw workspace roots，不按任意 repo root 推断；writable toggle/install 仍 blocked。 |

## 近期版本规划

| 版本 | 目标 | 状态 |
| --- | --- | --- |
| V2.31 | Cleanup Queue（默认 read-only 列表 + 现有安全动作入口） | 已完成 |
| V2.32 | Rule tuning / suppression（本地 rule override / suppression，可审计可撤销） | 已完成：仅 app-local 元数据，默认不改写 skill 文件/agent config，不新增快照，且无脚本执行/AI provider/凭据/telemetry 路径 |
| V2.33 | Safe batch actions（verified writable agents 的 preview-first 批量 enable/disable） | 已完成：Apply 前必须显式确认，且确认 preview id 必须仍匹配当前 preview |
| V2.34 | Cross-agent comparison view（跨 agent 同名/相似 skill 差异对比） | 已完成：Analysis 中只读展示，不新增写入/执行/provider/credential/snapshot 路径 |
| V2.35 | Local report export（脱敏 Markdown/JSON 本地审计报告） | 进行中 |
| V2.30 | AI skill analysis workflow（selected/batch read-only 预览，默认禁用，非凭证/非写入） | Completed |
| V2.29 | Finding triage persistence（Open / Reviewed / Ignored / Needs follow-up；仅 app-local） | Completed |
| V2.28 | Conflict semantic closeout（验收：Conflicts=当前 agent runtime/name collision；Analysis=cross-agent duplicate/source overlap/enabled mismatch；health conflict_count 不含 cross-agent analysis） | 已完成 |
| V2.27 | Skill identity/provenance dedupe | 已完成 |
| V2.26 | Finding explainability | 已完成 |
| V2.10 | Skill execution safety boundary / docs consistency | 已关闭 |
| V2.11 | Adapter Capability Matrix：服务协议和 macOS UI 展示六个 agent 的能力状态与 blocker | 已完成 |
| V2.12 | opencode writable evidence + guarded toggle/install | 已完成 |
| V2.13 | Pi read-only scanner/parser + writable blocker | 已完成 |
| V2.14 | Hermes maintainer-confirmed spec + adapter implementation scope | 已完成证据门 closeout；read-only scanner 后续已在 V2.17 实现 |
| V2.15 | OpenClaw maintainer-confirmed spec + adapter implementation scope | 已完成证据门 closeout；read-only scanner 后续已在 V2.16 实现 |

## 它做什么

- **统一视图**：按 agent × scope 扫描、聚合、对比 skills。
- **跨 agent 对比**：同名/相似 skills 在 Claude/Codex/opencode/Pi/Hermes/OpenClaw 的状态、来源、风险、可写能力与差异支持只读对比。
- **配置管理**：启用 / 禁用、读写 agent 配置文件，支持原子写、快照和回滚。
- **冲突与权限**：检测同名 skill 冲突，展示权限声明和规则 findings。
- **Tool-global skill 池**：本地目录导入到 app-controlled staging，审计后 read-only preview，并可经确认安装到 Claude/Codex verified skill root。
- **Cleanup Queue**：把 open findings、完整性问题和 analysis insights 聚合成可处理队列，主要支持查看详情、跳转到现有安全动作入口、或获取建议草稿进行人工处理。
- **Skill 执行安全边界**：默认不真实执行脚本；任何未来执行请求都必须展示 cwd/env/network/files 预览并逐次确认。
- **AI 增强 gate**：规则引擎默认离线运行；LLM 目前只提供默认关闭的 prepare/estimate gate，不声明真实 provider/network/credential storage 已完成。

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
| MVP 施工图 | [`docs/mvp-implementation-plan.md`](./docs/mvp-implementation-plan.md) |
| 路线图 | [`docs/roadmap.md`](./docs/roadmap.md) |

## 技术栈

| 层 | 技术 |
| --- | --- |
| macOS 产品壳 | SwiftUI + AppKit interop，位于 `apps/macos`。 |
| 内核 | Rust workspace crates：core / adapters / scanner / catalog / ai-core / commands / service。 |
| Service protocol | typed JSON / JSON-RPC stdio sidecar，位于 `crates/service`。 |
| 持久化 | SQLite catalog + JSON runtime state。 |
| LLM | V2.7 optional assist gate；当前只有 provider preference、gate 和 prepare/estimate 边界。 |

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
