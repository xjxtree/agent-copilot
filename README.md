# skills-copilot

> 桌面 GUI：把分散在多个 AI agent（Claude Code / Codex / pi / hermes / openclaw / opencode）的 **skills** 统一管理、配置、审计。

**状态**：**V2.10 Skill execution safety boundary documented；下一编号版本为 V2.11 future desktop shell / local sharing planning；真实本机 Computer Use validation passed on 2026-06-09；V2.9 Tool-global import/export/install integrated**。Claude Code MVP、Product UI/UX Hardening、V1 原生 macOS 基线、macOS Native Productization、V2 Prep 安全门、refresh-summary UX、native test hardening、adapter evidence gates、首个 Codex adapter 实现切片、V2.1 Claude/Codex adapter experience、V2.2 project context、V2.3 adapter hardening、V2.4 opencode read-only adapter、V2.5 audit hardening、V2.6 release readiness docs、V2.7 LLM service/UI gate、V2.8 规则与权限治理、V2.9 Tool-global skill 池和 V2.10 skill execution safety docs/release consistency 均已集成。V2.10 的安全边界是：默认不真实执行 skill 脚本；任何未来执行请求都必须逐次人工确认，并先展示 cwd/env/network/files 预览；blocked/cancelled/failure attempts 必须留下本地审计记录；LLM 不能触发执行。V2.9 支持本地目录导入到 app-controlled tool-global staging、导入后规则审计、可复现 export bundle/manifest、manifest reimport 稳定性、tool-global read-only preview UI，以及经确认后安装到 Claude/Codex verified skill root；GitHub clone import、签名化公开分发和 opencode writable install 仍不做。真实本机 app 的 Computer Use 操作验证已在 2026-06-09 对当前 mainline app 通过：`pnpm check:macos` 通过，并在真实 HOME/app data/Claude/Codex/opencode 环境下操作 scan-all、findings filter、conflicts、snapshot preview、agent filter、project context set/clear、opencode read-only 和 V2.10 script safety preview；证据为 `docs/ui-artifacts/native-macos-shell/real-local-computer-use-2026-06-09.png`。当前产品 UI 方向已锁定为 SwiftUI/AppKit macOS 原生壳 + Rust service protocol。`apps/macos` 原生壳已接入扫描、列表、详情、规则 findings、冲突、快照、启停、Claude Settings 编辑、快照预览、回滚、scan-all、agent filter、project context、默认关闭的 LLM Assist prepare 面板，以及 V2.9 tool-global read-only preview/install affordance；旧 Tauri/React UI 与 Tauri IPC 壳已删除，不再是当前代码的一部分。

> 当前已完成的真实产品 adapter 是 **Claude Code**、**Codex** 和 read-only **opencode**。Codex 支持范围限于 verified user/project roots、cwd→repo-root project discovery、`catalog.scanAll`、agent filter、project context 下的扫描归属和用户级 `config.toml` toggle；V2.3 已强化 Codex config patch、状态表达和安全回归测试。V2.4 opencode 只扫描 native roots：`~/.config/opencode/skills` 和当前项目 `.opencode/skills`；不扫描 `.agents` / `.claude` compatibility roots，不提供 writable toggle。项目级 Codex config 写入、plugin/admin/system roots、Pi、Hermes、OpenClaw 仍未进入产品实现。

## 它做什么

- **统一视图**：按 agent × 作用域（工具全局 / agent 全局 / agent 项目级）扫描、聚合、对比 skills
- **配置管理**：启用 / 禁用、读写 `settings.json` / `config.toml` 等配置文件，支持原子写 + 快照回滚
- **冲突与权限**：同名 skill 跨 scope 冲突检测；最小权限声明、合规校验
- **Tool-global skill 池**（V2.9）：本地目录导入到 app-controlled staging 并审计；tool-global 记录 read-only preview；export bundle/manifest 可复现；安装到 Claude/Codex 前显示目标路径与风险，确认后走 verified write path
- **Skill 执行安全边界**（V2.10）：默认不真实执行脚本；执行前必须展示 cwd/env/network/files 预览并逐次确认；blocked/cancelled/failure attempts 必须审计；LLM 不能触发执行
- **AI 增强**（V2.7 gate）：规则引擎默认离线运行；当前只做默认关闭的 LLM gate 和 prepare/estimate，不做真实 provider/network/credential storage

## 它**不**做什么

- 不替代任何 agent 运行时
- 不云端同步、不做账号系统
- 不在默认路径真实执行 skill 自带脚本；V2.10 只锁定 default-deny、逐次确认、范围预览、审计和 LLM 隔离边界

## 文档导航

| 想看 | 路径 |
| --- | --- |
| 整体架构 | [`docs/architecture.md`](./docs/architecture.md) |
| macOS 原生产品壳计划 | [`docs/macos-native-plan.md`](./docs/macos-native-plan.md) |
| Service protocol | [`docs/service-protocol.md`](./docs/service-protocol.md) |
| AI agent 工作流与验证规则 | [`docs/ai-agent-workflow.md`](./docs/ai-agent-workflow.md) |
| UI 交付标准 | [`docs/ui-delivery-standards.md`](./docs/ui-delivery-standards.md) |
| macOS app 运行与检查规范 | [`docs/macos-app-runbook.md`](./docs/macos-app-runbook.md) |
| V2.6 手工 release checklist | [`docs/release-checklist.md`](./docs/release-checklist.md) |
| V2 adapter changelog / risk tracking | [`CHANGELOG.md`](./CHANGELOG.md) |
| V2 Prep 分发前 runbook | [`docs/distribution-runbook.md`](./docs/distribution-runbook.md) |
| Deprecated Web UI 删除记录 | [`docs/deprecated-web-ui-removal.md`](./docs/deprecated-web-ui-removal.md) |
| 6 个 agent 适配要点 | [`docs/agent-adapters.md`](./docs/agent-adapters.md) |
| 非 Claude adapter spec 工作单 | [`docs/agent-adapter-spec-worklists.md`](./docs/agent-adapter-spec-worklists.md) |
| Codex adapter spec 工作单 | [`docs/codex-adapter-spec.md`](./docs/codex-adapter-spec.md) |
| 统一数据模型 | [`docs/data-model.md`](./docs/data-model.md) |
| AI 层（规则 + LLM） | [`docs/ai-layer.md`](./docs/ai-layer.md) |
| 安全模型 | [`docs/security-model.md`](./docs/security-model.md) |
| 当前开发任务清单 | [`docs/development-tasks.md`](./docs/development-tasks.md) |
| MVP 施工图 | [`docs/mvp-implementation-plan.md`](./docs/mvp-implementation-plan.md) |
| 路线图（MVP → Product UI/UX Hardening → V1 Native macOS Pivot → macOS Native Productization → V2 Prep → V2） | [`docs/roadmap.md`](./docs/roadmap.md) |

## 技术栈

- macOS 产品壳：**SwiftUI + AppKit interop**（`apps/macos`，唯一维护的当前产品 UI，原生 Settings/Toolbar/menus、系统材质、Liquid Glass 适配）
- 内核：Rust（workspace crate：core / adapters / scanner / catalog / ai-core / commands / service）
- Service protocol：typed JSON / JSON-RPC 边界（`crates/service` stdio sidecar；macOS 原生壳和未来跨平台 UI 调同一 Rust service）
- 已删除旧 UI：Tauri + React + TypeScript + Vite 仅作为历史 MVP/V1 验证记录存在，不再有 `ui/` 或 `src-tauri/` 当前代码
- 持久化：SQLite（catalog）+ JSON（运行时状态）
- LLM：V2.7 可选辅助 gate；当前只定义 provider 偏好、gate 和 prepare/estimate 边界，Anthropic / OpenAI / DashScope / Ollama client 尚未作为完成能力声明

## 开发运行

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

当前阶段只有一个 app bundle 路径：`dist/SkillsCopilot.app`。
`./script/build_and_run.sh run` / `pnpm dev:macos` 是 **Local App Run**：重新组装 `dist/SkillsCopilot.app`，再用本机真实 HOME / 默认 app data / 真实 Claude 配置启动，用于看实际效果。
`./script/build_and_run.sh --verify` / `pnpm build:macos` 是 **Local App Launch Verify**：重新组装 `dist/SkillsCopilot.app`，启动并确认进程存在。
`pnpm capture:macos-window` 会用窗口 ID 截取完整 app 窗口到 UI artifact；禁止整桌面截图。
`pnpm smoke:macos-app` 是 **Smoke App Run**：不打包 app，只检查并启动已有的 `dist/SkillsCopilot.app`；默认会检查该 bundle 是否比 Swift/Rust/icon/build 脚本输入更新，发现旧 app 会失败。
`--fixture-data` 会注入临时 Claude、Codex 和 opencode fixture skills 与 app data，并通过打包进 `.app` 的 Rust service sidecar 验证 scan、Enable/Disable、Settings save、Snapshot Preview 和 Snapshot Rollback，不触碰真实用户配置。V2.4 opencode smoke fixture 只使用临时 `~/.config/opencode/skills` 和项目 `.opencode/skills`，并在 service 集成 opencode 后断言 toggle 被 read-only 拒绝。
`--capture-window` 会调用窗口 ID 截图脚本，只截取完整 APP 窗口；禁止整桌面截图。
CI 主线使用 Rust + native macOS product gate：Rust fmt/test/clippy、native list model、native layout、SwiftPM test/build、`dist/SkillsCopilot.app` build 和 bundle-only smoke。旧 Web/Tauri UI 已删除，不再有 Web UI gate。
`pnpm check:macos` 是当前阶段的组合质量检查：fmt / test / clippy / native list model test / native layout check / SwiftPM test / Swift build / Local App Launch Verify / Smoke App Run。它会先重新组装 `dist/SkillsCopilot.app`，再跑 Smoke App Run，因此是开发后验证最新代码的推荐入口。
`pnpm check:privacy` 是提交/推送前隐私检查：阻止真实本机路径、用户目录、临时 app-data 路径、常见 token/key 形态，以及二进制证据文件里的敏感字符串。新截图仍必须人工目检，因为自动检查不做 OCR。
`pnpm benchmark:10k` 会生成 10k 个临时 Claude skills，跑 scan → catalog 基准并输出耗时与最大 RSS。
`pnpm test:macos-list-model` 会编译真实 Swift list model 源码并验证 search / filter / sort 行为。
`pnpm benchmark:macos-list-model` 会用 10k 条 synthetic native records 测量 Swift list model 搜索、过滤、排序性能。
`pnpm verify:macos-ui-layout` 会静态检查原生 macOS shell 的关键布局约束。

## 贡献

仓库目前 **V2.10 Skill execution safety boundary documented**，且 **V2.9 Tool-global import/export/install integrated**；V2 编号内剩余明确小版本是 **V2.11 future desktop shell and local sharing planning**，具体任务见 [`docs/development-tasks.md`](./docs/development-tasks.md)。当前 mainline 的真实本机 Computer Use 验证已在 2026-06-09 通过；后续用户可见、UI 或 service protocol 变更仍需重跑。欢迎：

1. 继续扩展后续变更的真实本机 app Computer Use 验证：project context、scan-all、adapter filter、findings filtering/grouping、V2.8 七条新规则、opencode read-only toggle、script safety preview 和窗口级截图
2. 提 issue 指出文档或 MVP 行为里的疑点 / 缺漏
3. 推进 V2.11 future desktop shell / local sharing planning
4. 推进跨版本 backlog：release gate 梳理、真实 execution sandbox 设计、Pi disposable local round-trip、opencode writable evidence、Hermes / OpenClaw maintainer spec
5. 改进 Claude Code MVP/V1/native macOS 基线的测试、文档和 service protocol
6. 改进 native macOS 验证资产；不要重新引入旧 `ui/` / `src-tauri` 产品壳

AI coding agents should use [`AGENTS.md`](./AGENTS.md) as the shared instruction entrypoint. Claude Code uses [`CLAUDE.md`](./CLAUDE.md), which imports the shared rules and only adds Claude-specific behavior.

详细贡献流程见 [`CONTRIBUTING.md`](./CONTRIBUTING.md)。

## 许可证

MIT — 详见 [`LICENSE`](./LICENSE)。
