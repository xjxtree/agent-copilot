# skills-copilot

> 桌面 GUI：把分散在多个 AI agent（Claude Code / Codex / Pi / Hermes / OpenClaw / opencode）的 **skills** 统一管理、配置和审计。

## 当前状态

**当前阶段**：V2.11-V2.15 多 agent adapter 版本线已完成。P0 evidence 已把 OpenClaw 和 Hermes 推进为 read-only scanner candidate；Pi 进入 writable evidence harness candidate。

**近期主线**：先实现 OpenClaw/Hermes read-only scanner 的受限切片，再做 Pi writable evidence harness。OpenClaw/Hermes writable/install 与 Pi production writable 仍保持 blocked，直到 disposable rollback 证据通过。

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
- V2.14 Hermes evidence-gate closeout：没有 maintainer-confirmed spec，不实现 scanner/parser 或 writable adapter。
- V2.15 OpenClaw evidence-gate closeout：候选 roots/config 线索不足以作为 maintainer-confirmed spec，不实现 scanner/parser 或 writable adapter。
- 2026-06-09 真实本机 app Computer Use validation 已通过。

**当前产品 UI**：SwiftUI/AppKit macOS 原生壳 + Rust service protocol。

**旧 UI 状态**：旧 Tauri/React UI 与 Tauri IPC 壳已删除，不再是当前代码的一部分。

## Adapter 支持状态

| Agent | 当前状态 | 备注 |
| --- | --- | --- |
| Claude Code | 已支持 | 支持 scan、catalog、toggle、settings editor、snapshot rollback。 |
| Codex | 已支持已验证范围 | 支持 verified user/project roots、cwd→repo-root discovery、`catalog.scanAll`、agent filter、project context 归属和用户级 `config.toml` toggle。 |
| opencode | 已支持已验证范围 | 支持 native roots：`~/.config/opencode/skills` 和当前项目 `.opencode/skills`；支持 guarded writable toggle/install，写入 exact `permission.skill.<name> = "deny"` 并保留 snapshot/rollback。 |
| Pi | read-only | V2.13 已实现 Pi-native global/project scanner/parser；writable toggle/install 仍 blocked，等待 settings mutation/rollback 证据。 |
| Hermes | read-only candidate | P0 evidence 已确认 Hermes Agent 有 first-class skills 和 `~/.hermes/skills/**/SKILL.md`；project scan、writable toggle/install 仍 blocked。 |
| OpenClaw | read-only candidate | P0 evidence 已确认 OpenClaw `SKILL.md` roots、schema、precedence 和 `skills list --json`；writable toggle/install 仍 blocked。 |

## 近期版本规划

| 版本 | 目标 | 状态 |
| --- | --- | --- |
| V2.10 | Skill execution safety boundary / docs consistency | 已关闭 |
| V2.11 | Adapter Capability Matrix：服务协议和 macOS UI 展示六个 agent 的能力状态与 blocker | 已完成 |
| V2.12 | opencode writable evidence + guarded toggle/install | 已完成 |
| V2.13 | Pi read-only scanner/parser + writable blocker | 已完成 |
| V2.14 | Hermes maintainer-confirmed spec + adapter implementation scope | 已完成证据门 closeout；P0 evidence 后进入 read-only candidate |
| V2.15 | OpenClaw maintainer-confirmed spec + adapter implementation scope | 已完成证据门 closeout；P0 evidence 后进入 read-only candidate |

## 它做什么

- **统一视图**：按 agent × scope 扫描、聚合、对比 skills。
- **配置管理**：启用 / 禁用、读写 agent 配置文件，支持原子写、快照和回滚。
- **冲突与权限**：检测同名 skill 冲突，展示权限声明和规则 findings。
- **Tool-global skill 池**：本地目录导入到 app-controlled staging，审计后 read-only preview，并可经确认安装到 Claude/Codex verified skill root。
- **Skill 执行安全边界**：默认不真实执行脚本；任何未来执行请求都必须展示 cwd/env/network/files 预览并逐次确认。
- **AI 增强 gate**：规则引擎默认离线运行；LLM 目前只提供默认关闭的 prepare/estimate gate，不声明真实 provider/network/credential storage 已完成。

## 它不做什么

- 不替代任何 agent 运行时。
- 不云端同步，不做账号系统。
- 不在默认路径真实执行 skill 自带脚本。
- 不让 LLM 触发执行、写入或确认用户动作。

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
