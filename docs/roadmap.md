# 路线图

> 按 MVP → Product UI/UX Hardening → V1 Native macOS Pivot → macOS Native Productization → V2 Prep → V2 推进。每档都有"退出条件"，不达不升档。
>
> 进度判定口径：本文件中 0 / 1 / 1.5 / 2 / 2.5 的退出条件代表当前已完成阶段；V2、非 Claude adapter、发布安全 checklist 和 PR checklist 的未勾选项是后续阶段或模板项，不代表当前 MVP/V1 进度遗漏。
>
> 当前阶段：**V2.23 Health Dashboard / Adapter Capability UX 对齐（进行中）**；V2.22 finding/conflict 语义与验收同步作为前置约束仍在收口。V2.21 扫描准确性、去重边界、agent 维度统计已完成。Pi writable evidence、finding triage persistence 和 agent-config timeline 仍为后续候选跟进项。
>
> 近期主线：在 V2.22 口径收口后，优先完成 V2.23 侧栏健康卡片与 adapter 能力面板对齐：侧栏只看当前 selected/current agent，health 卡片做行动摘要；finding/conflict 与 issue group 口径统一；随后继续推进 Pi writable / triage 持久化 / agent-config timeline 等候选项。V2.16-V2.20 已完成 OpenClaw read-only scanner、Hermes read-only scanner、cross-agent skill analysis、skill health dashboard 和 read-only AI skill analysis assist。V2.21 负责扫描准确性、去重边界和 agent 维度统计口径同步；Pi writable 仍保持 evidence harness candidate，生产写入需等 rollback-safe evidence 通过。
>
> 已集成：macOS native baseline、refresh summary、V2 Prep safety gates、native SwiftPM test hardening、adapter evidence gates、首个 Codex adapter、V2.1-V2.20 各阶段能力、V2.9 Tool-global skill pool、V2.11 Adapter capability matrix、V2.16-V2.20 management/analysis line。V2.21 扫描准确性与去重口径已完成。后续候选变更仍需重新验证。
>
> V2.10 安全边界：默认不真实执行 skill 脚本；任何未来执行请求必须逐次人工确认，并先展示 cwd/env/network/files preview；blocked/cancelled/failure attempts 必须审计；LLM 不能触发执行。
>
> 真实本机 app 的 Computer Use 操作验证已在 2026-06-10 对当前 mainline app 通过，验证时显式选择当前 `dist/SkillsCopilot.app` bundle 以避开同 bundle id 的旧 worktree 注册路径。后续用户可见、UI 或 service protocol 变更仍需重跑，且不能用 smoke 截图替代。

## 0. 设计阶段（已完成）

**目标**：把模型、边界、扩展点对齐。

**产出**（已完成）
- ✅ `docs/architecture.md`
- ✅ `docs/agent-adapters.md`
- ✅ `docs/data-model.md`
- ✅ `docs/ai-layer.md`
- ✅ `docs/security-model.md`
- ✅ `docs/roadmap.md`（本文件）
- ✅ `docs/macos-native-plan.md`
- ✅ `docs/ai-agent-workflow.md`
- ✅ `AGENTS.md` 作为 Codex / Claude Code / Pi / opencode 等 coding agent 的共享指令入口；`CLAUDE.md` 仅保留 Claude Code 兼容层
- ✅ `README.md` 指向 docs

**退出条件**
- ✅ Claude Code spec 可实现；其它 agent 保持 TBD，不进入 MVP 实现范围
- ✅ MVP/早期 V1 曾使用 Web/Tauri 验证栈；当前产品 UI 主线已切到 native macOS，旧 Web/Tauri 代码已删除
- ✅ 当前产品栈已更新为 Rust 跨平台核心 + service protocol + macOS SwiftUI/AppKit 原生壳，详见 [`macos-native-plan.md`](./macos-native-plan.md)
- ✅ UI 交付标准已锁定：大版本/大功能先原型，完成后更新 UI 图，代码改动完成必须用 macOS Computer Use 启动并操作验证，详见 [`ui-delivery-standards.md`](./ui-delivery-standards.md)
- ✅ AI coding agent 入口已统一：共享规则写入根目录 [`../AGENTS.md`](../AGENTS.md)，详细工作流见 [`ai-agent-workflow.md`](./ai-agent-workflow.md)
- ✅ 仓库许可证 / CONTRIBUTING / issue 模板 / PR 模板就位

## 1. MVP — "能扫能看能 toggle"（已完成）

**当前状态（2026-06-08）**：Claude Code MVP 的核心闭环已实现。应用可扫描 Claude skills、写入 SQLite catalog、运行 4 条 MVP 规则、展示列表/详情/冲突/快照，支持 `skillOverrides` 启停和 snapshot rollback。V1 已追加 Claude `settings.json` 读写 command。原生 macOS 侧边栏已补 State 过滤和 Sort 控件，并有 `pnpm test:macos-list-model` / `pnpm benchmark:macos-list-model` 覆盖 Swift list model 行为和 10k 性能。原生用户可见主文案已迁到 `UIStrings` + Swift `Localizable.strings` 资源。`pnpm check:macos` 是当前本地质量门禁：Rust 当前为 30 passed + 1 ignored，`cargo clippy` 0 warning，native list model test、native layout check、SwiftPM macOS app build、Local App Launch Verify 和 Smoke App Run 通过。Smoke App Run 会检查 `dist/SkillsCopilot.app` 是否比 Swift/Rust/icon/build/资源输入更新，避免验证旧 app。GitHub Actions 主线已调整为 Rust fmt/test/clippy + native macOS list/layout/SwiftPM/bundle/smoke。旧 Web/Tauri UI 与 Tauri IPC 壳已删除；历史 Tauri command surface 只作为 service protocol 演进记录存在。

> 单平台：macOS 优先（贡献者最常在的环境），其它平台 buildable 但当前不定义分发产物。

### 1.1 范围

**功能**
- ✅ 启动应用，读取本地 SQLite catalog；用户可触发 Claude Code 全局目录扫描
- ✅ 支持 agent：**Claude Code**（其它 agent 在 V1/V2 补）
- ✅ Skills 列表视图（按 Definition 聚合 + 冲突标记 + 三视图导航：Skills / 冲突 / 快照）
- ✅ Skill 详情视图（frontmatter / body / scripts / 权限声明 / 诊断 findings）
- ✅ Toggle 启用 / 禁用（Claude Code MVP 通过 `skillOverrides`；原子写 + 快照）
- ✅ 文件监听：监听已存在的 Claude `.claude` 根目录，外部修改 `SKILL.md` / `settings.json` 后自动重扫并刷新 UI
- ✅ 内置规则最小集：`frontmatter.required-fields` / `name.collision` / `path.outside-workspace` / `fingerprint.changed`

**非功能**
- ✅ 全部 Rust 核心在测试覆盖下（`cargo test --workspace` 通过）
- ✅ Adapter / scanner / catalog / commands / rules 均有单元或集成测试覆盖
- ✅ CI：lint + test（macOS / Linux / Windows matrix）
- ✅ 10k scan → catalog benchmark：10k synthetic Claude skills，scan/catalog 2.439s（2026-06-04, macOS local）
- ✅ 内存基准：10k scan/catalog 最大 RSS 87.0MB（目标 ≤ 200MB）

### 1.2 不做

- LLM 任何能力（V1 再加）
- 多 agent 切换 UI（数据层可读，UI 只展示 Claude Code）
- 配置文件编辑 UI（只 toggle）
- 自动修复 / 自动 merge 冲突
- Linux / Windows 桌面产物（仅 buildable；等 macOS 原生产品壳稳定后再评估）
- Telemetry

### 1.3 退出条件

- [x] Claude Code 适配器完整实现；其它 agent 不凭猜测实现
- [x] Catalog 端到端：scan → 存 → 查 → `skillOverrides` toggle → 重扫
- [x] 任意写操作都有 snapshot，UI 可见 + 一键回滚
- [x] 关闭应用期间手动改 `skillOverrides`，重开/重扫后正确反映
- [x] README 写明"开发者怎么跑起来"
- [x] 至少一份 issue 模板 + CONTRIBUTING.md
- [x] 生产 `.app` 图标源修复：native app icon source 已迁到 `apps/macos/Sources/SkillsCopilot/Resources/AppIcon.icns`
- [x] macOS 生产 `.app` 手动 smoke：首屏、扫描、Skills / 冲突 / 快照视图可用
- [x] Smoke App Run 自动化：`pnpm smoke:macos-app -- --fixture-data --capture-window` 检查已有 `dist/SkillsCopilot.app` 的 freshness、bundle id、icon、packaged service sidecar、可见 app 窗口、窗口级截图，并用 fixture 验证 scan / Enable-Disable / Settings save / Snapshot Preview / Snapshot Rollback
- [x] CI matrix：GitHub Actions 覆盖 Rust fmt/test/clippy、native macOS list model、native layout、SwiftPM build、`dist/SkillsCopilot.app` build 和 bundle-only smoke；deprecated Web UI 不再作为产品 gate
- [x] 文件监听：应用运行期间外部修改 `SKILL.md` / `settings.json` 后，经 500ms debounce 自动重扫
- [x] macOS 系统日志噪音归因：`pnpm smoke:macos-app -- --fixture-data --check-logs` 过滤已知 AppKit/AppIntents/sandbox 噪音，未知 app error/fault 为 0
- [x] 10k skills 性能与内存基准：`pnpm benchmark:10k` 输出 scan/catalog 耗时和最大 RSS

**MVP 剩余硬化项**
- 暂无阻塞项；进入 V1 前先执行 1.5 Product UI/UX Hardening，把功能型 MVP 打磨成更可持续扩展的产品化操作台。

## 1.5 Product UI/UX Hardening — "更像一个产品"（已完成）

**目标**：在继续扩展多 agent、LLM 和配置编辑器前，先把当前功能型 MVP 打磨成稳定、清晰、可扩展的桌面产品体验。

**当前状态（2026-06-08）**：1.5 的产品化 UI/UX 硬化已落地并迁移到 native macOS 主线。旧 Tauri Web UI 已删除；其信息架构和交互经验作为历史记录保留在文档与 git history 中。原生 macOS shell 已具备三栏工作台、搜索、state 过滤、排序、Settings、快照预览和 rollback。scan / toggle / settings save / rollback 已有明确 loading、success、error 与 retry 状态反馈。详情 / 冲突 / 快照已补齐工作流空态、详情加载/错误态和小窗口布局保护。

**1.5 本地基线（2026-06-04, macOS local）**
- 10k scan → catalog：2.142s，最大 RSS 86.6MB（`pnpm benchmark:10k`）。
- 10k native Swift list model：搜索 / 过滤 / 排序 p95 最高 31.14ms（`pnpm benchmark:macos-list-model`）。
- Native macOS layout guard：11 项静态检查通过（`pnpm verify:macos-ui-layout`）。
- Smoke App Run：`pnpm smoke:macos-app -- --fixture-data --capture-window` 覆盖已有 `dist/SkillsCopilot.app` 的 scan、toggle、Settings save、Snapshot Preview、Snapshot Rollback，不触碰真实用户配置。

**UI 方向决策**
- 1.5 的 Tauri Web UI 是历史验证稿，当前代码已删除。
- 当前唯一维护的产品 UI 是 SwiftUI/AppKit macOS 原生壳。
- 原生壳应继承 1.5 已验证的信息架构：sidebar / content list / inspector-detail / toolbar / settings。
- Liquid Glass 只通过系统组件和少量功能 surface 使用；旧 CSS glass tokens 仅作视觉参考。

### 1.5.1 范围

**信息架构**
- Skills / 冲突 / 快照 / 详情保持为一屏内高频工作区，但重构为 macOS 式三栏工作台：sidebar 负责导航，content list 负责扫描和定位，inspector/detail 负责判断和处理。
- 明确全局状态区：扫描中、自动监听中、上次扫描时间、catalog 条目数、错误和警告不互相抢占。
- 为空目录、无冲突、无快照、扫描失败、权限不足等状态设计可恢复的空态和错误态。

**交互与效率**
- Skills 列表补齐搜索、过滤、排序、行选择、长路径压缩展示、状态 chip、sticky header 和小窗口下的可读布局。
- Toggle、rollback、scan 等写操作统一使用处理中、成功、失败、可重试状态，避免按钮点击后无反馈。
- 快照 rollback 前提供变更预览；冲突视图提供实例对比、winner 标记入口和原因标签，但不自动合并。
- 支持基础键盘流：列表上下选择、Enter 打开详情、Esc 返回/关闭面板、Tab 顺序可预测。

**视觉与组件**
- 原生 macOS shell 使用 `ContentView` / `SidebarView` / `DetailView` / `SettingsView` / `SkillStore` 等 SwiftUI 和 store 边界。
- 建立轻量 design tokens：macOS material、颜色、间距、hairline border、focus ring、状态 chip、表格密度、按钮层级；避免每个视图各自定义一套样式。
- 建立 Liquid Glass 风格约束：只在 toolbar、sidebar、inspector、浮层或关键操作组使用 glass surface；不使用大面积低对比 blur，不用纯装饰性的 tint。
- 详情面板、冲突对比、快照预览使用一致的信息块结构，降低后续 Settings / Analyze / Recommend 面板接入成本。
- 明确 macOS 小窗口最小体验：核心操作不重叠、不横向溢出，文本在按钮、表格、详情区内可读。

**质量保障**
- 增加 UI 单元/集成测试覆盖列表过滤、详情切换、冲突/快照空态和关键写操作状态。
- 扩展 smoke 脚本覆盖主导航、搜索/过滤、详情打开、冲突和快照视图可见性。
- 记录首屏 p95、10k catalog 下搜索/过滤响应、扫描期间 UI 可操作性，作为进入 V1 前的体验基线。

### 1.5.2 不做

- 不新增多 agent 适配器。
- 不接入 LLM provider。
- 不实现配置文件编辑器。
- 不自动修复或自动 merge 冲突。
- 不引入云端同步、账号、telemetry。
- 不重新引入 deprecated Web UI；历史 Web 产物只作为文档和 git history 中的信息架构参考。
- 不为了视觉效果牺牲信息密度、对比度、键盘可达性或跨平台 buildability。

### 1.5.3 退出条件

- [x] 原生 macOS shell 视图和 store 边界清晰，后续 V1 面板可继续复用。
- [x] Skills 列表具备搜索、过滤、排序和稳定选中态。
- [x] macOS-native inspired 三栏布局落地：sidebar / content list / inspector/detail 层级清晰。
- [x] 轻量 Liquid Glass design tokens 落地，并覆盖 toolbar、sidebar、inspector、按钮、输入框、状态 chip。
- [x] 10k catalog 下搜索、过滤、排序有可接受的响应基线。
- [x] 扫描、自动刷新、toggle、rollback 均有明确 loading / success / error / retry 反馈。
- [x] 详情、冲突、快照三个工作流都有空态、错误态和小窗口布局验证。
- [x] rollback 前有可读的快照差异预览；冲突视图能对比实例并表达冲突原因。
- [x] macOS `.app` smoke 覆盖主导航、详情打开、搜索/过滤、冲突和快照视图；深度 UI 断言要求调用终端具备 macOS Accessibility 权限。
- [x] 首屏 p95 采样机制、10k 搜索/过滤响应、scan 中内存和 UI 可操作性有本地基线记录；本轮首屏 p95 需在授权终端补采样。

## 2. V1 Native macOS Pivot — "协议先行 + 原生壳开工"（已完成基线）

**当前状态（2026-06-08）**：V1 已启动，且路线已调整。早期 V1 的 Web/Tauri 验证壳已被删除，所有产品 UI 能力转向 SwiftUI/AppKit macOS 原生壳。`crates/service` 已提供 protocol v1 typed JSON stdio 方法与 contract fixtures，`apps/macos` 已提供 SwiftUI 原生壳，并通过 macOS Computer Use 验证扫描、列表、详情、findings、conflicts、snapshots、启停、Claude Settings 编辑、快照预览和回滚流。

### 2.1 范围

- Service protocol：把当前 Tauri commands 抽成 Rust service facade，提供 protocol v1 typed JSON request-response fixture，让 macOS 原生壳和未来跨平台 UI 共享同一能力边界。当前主要方法：`service.status`、`catalog.listSkills`、`catalog.getSkill`、`catalog.listFindings`、`catalog.listConflicts`、`catalog.scanAll`、`catalog.scanClaude`、`config.toggleSkill`、`config.readClaudeSettings`、`config.saveClaudeSettings`、`snapshot.list`、`snapshot.previewRollback`、`snapshot.rollback`。
- Native macOS app scaffold：`apps/macos/`，使用 SwiftUI + AppKit interop。
- Native MVP parity：扫描、列表、详情、冲突、快照、启停、Claude settings 编辑器在 macOS 原生壳可用。
- UI delivery standard：为 native shell 建立首批 `docs/ui-artifacts/` 原型、完成截图和验证记录。
- Removed UI guardrail：不要重新引入 `ui/` / Tauri Web UI；旧能力只保留历史记录。
- Codex adapter、LLM 端到端、Recommend、冲突合并等能力仍在 V1/V2 范围内，但新产品 UI 只落到 native macOS shell。

### 2.2 退出条件

- [x] Rust service protocol 初版完成：`service.status.protocol_version = 1`，当前 native UI-facing service methods 有对应 request/response fixture；Tauri commands 仅作为历史 MVP 记录
- [x] `apps/macos/` 原生 app scaffold 可构建、可启动
- [x] 原生 macOS shell 完成 MVP 核心只读流：扫描、列表、详情、findings、conflicts、snapshots
- [x] 原生 macOS shell 完成 MVP 核心写流：toggle、Claude settings editor、snapshot preview、rollback
- [x] 首批 UI 原型、完成截图和验证记录落到 `docs/ui-artifacts/`
- [x] 本轮代码改动已用 macOS Computer Use 启动 app 并操作验证；后续每次代码改动仍需持续记录
- [x] i18n 切换无重载丢失
- [x] Claude `settings.json` 配置编辑 MVP：JSON 校验、snapshot、原子写、写后 rescan
- [x] V1 `AnalyzeView` 空壳和 LLM provider preference/settings 底座已接入，且不会在未配置时调用模型；这不是 provider client、网络调用或 credential storage 完成声明

## 2.5 macOS Native Productization — "功能对齐 + 删除旧 UI"（已完成）

**目标**：在短期半年只考虑 macOS 桌面版的前提下，把当前验证壳里的产品能力迁移到 SwiftUI/AppKit 原生体验，完成 parity 后删除旧 Web UI 层，同时保留 Rust 核心与 service protocol 边界。

**技术路线**
- 核心：继续使用 Rust workspace crates，不重写 scanner/catalog/adapters/rules/snapshot/config write。
- 协议：SwiftUI 壳只通过 service protocol 调 Rust service；不直接依赖 Tauri IPC，也不直接链接 scanner/catalog internals。
- UI：SwiftUI + 少量 AppKit interop，优先 `NavigationSplitView`、`Toolbar`、Settings scene、menus、inspector、native table/list。
- Liquid Glass：优先系统组件和系统 material；自定义 glass 只用于 toolbar group、floating inspector、popover、command bar 等功能 surface，并支持 reduced transparency / reduced motion。
- Deprecated Tauri Web UI：parity 已达成，旧 `ui/` / `src-tauri/` 已删除。

### 2.5.1 范围

- 扩展 macOS 原生 app scaffold（当前 `apps/macos/`）。
- 实现主工作台：source list / skill list / inspector-detail 三栏。
- 接入只读 catalog：scan 后列表、详情、findings、conflicts、snapshots。
- 接入写操作：scan、toggle、Claude settings editor、snapshot preview、rollback。
- 接入 Settings：语言、provider preferences、未来 keychain-backed credentials 入口。
- 接入菜单和快捷键：scan、refresh、search focus、snapshot、settings、help。
- 建立 native UI smoke / snapshot / accessibility 检查清单。
- 建立 macOS app runbook：明确 Local App Run / Smoke App Run、`dist/SkillsCopilot.app` 更新时间、窗口截图和 fixture 验证规则。
- 迁移或替换仍有价值的旧 UI 验证资产：fixtures、benchmarks、smoke scripts、完成截图。
- 删除旧 UI 层：`ui/`、web-only layout checks、obsolete package scripts、Tauri web glue 已完成。

### 2.5.2 不做

- 不重写 Rust core。
- 不重新引入 Web/Tauri 验证壳。
- 不规划 Windows/Linux shell 或全平台 UI 适配。
- 不为了 Liquid Glass 牺牲信息密度、对比度、键盘可达性、可访问性或旧 macOS fallback。
- 不引入 cloud sync、telemetry 或默认联网。

### 2.5.3 退出条件

- [x] SwiftUI shell 可完成 MVP/V1 核心工作流：扫描、列表、详情、冲突、快照、启停、Claude settings 编辑。
- [x] service protocol contract fixtures and decode tests pass for native UI-facing methods.
- [x] macOS native UI 支持首批菜单、快捷键、Settings、搜索和快照视图入口。
- [x] Liquid Glass / material surface 使用系统 material，主内容 surface 已通过 reduced transparency fallback 和 reduced motion transaction 检查。
- [x] Deprecated Web UI 的关键 smoke / service fixture / 完成截图资产已迁移或替换；web-only benchmark/layout 脚本已被 native list model benchmark 和 native layout check 替换，CI 不再把 Web UI 当产品 gate（清单见 [`deprecated-web-ui-removal.md`](./deprecated-web-ui-removal.md)）。
- [x] `ui/` 和 obsolete Tauri UI glue 已删除；workspace membership、Tauri 依赖和 `*:web-deprecated` 脚本已移除。
- [x] 当前阶段 app 运行规范完成：Local App Run / Local App Launch Verify / Smoke App Run / macOS Check 均记录在 [`macos-app-runbook.md`](./macos-app-runbook.md)。

## 3. V2 Prep — "发布前硬化 + 证据门"（已完成）

**目标**：在扩展多 agent 和生态能力前，先把 native macOS baseline 的真实使用、发布前安全、分发准备和 adapter 证据门补稳。

**当前状态（2026-06-08）**：V2 Prep 已完成。V2 Prep 完成时，Codex 已具备进入首个 adapter 实现切片的证据和写入策略；随后 §4.0 首个 Codex adapter 实现切片已集成到主分支。Pi / opencode 只具备 read-only 规划证据且 writable blocked；Hermes / OpenClaw 仍 blocked。

**范围**
- 事件与刷新体验：scan progress、watcher event、自动刷新状态、失败恢复和用户可见日志。
  - 2026-06-08 Refresh experience 切片：`service.status.refresh`、`catalog.scanClaude.result.activity` 和后续 `catalog.scanAll.result.activity` 提供 protocol v1 additive refresh metadata；native sidebar 已显示 scan/reload/write 后的刷新状态、watcher manual 状态、最近 refresh log 和失败 retry 入口。当前 stdio sidecar 只提供完成态 summary，不伪装 streaming progress 或后台 watcher event stream；真正实时 watcher/event stream 进入 V2 后续设计。
- 发布前安全门：`cargo audit` / `pnpm audit`、写路径 canonicalize 二次校验、frontmatter/parser fuzz target。
  - 2026-06-08 安全门切片：已增加 `pnpm audit:rust` / `pnpm audit:node` / `pnpm run audit` 本地入口；`pnpm run audit` 本地通过，RustSec 和 pnpm 均未报告 high/critical。
  - 2026-06-08 安全门切片：Claude config write/toggle/rollback 已补写路径校验，要求 snapshot rollback 目标等于当前 context 的 Claude config path，并拒绝 symlink config dir/file/lock file。
  - 2026-06-08 安全门切片：scanner 非配置路径读取面已收紧为内置 root 真实路径必须仍在对应 home / project base 内；UserHome root 允许跟随仍在当前 user home 内的 symlink，Project root 只允许项目 root 内 target，Extra root 只允许当前 canonical scan root 内 target，并对已访问目录去重，降低 symlink 循环 DoS 风险。本切片复核 `crates/commands` / `crates/scanner` / `crates/adapters/fuzz` 后，未发现除 Claude config 外的产品任意 FS 写入面。
  - 2026-06-08 安全门切片：已为 adapter frontmatter parser 建立最小 `cargo-fuzz` scaffold，`cargo fuzz list` 能发现 `frontmatter_parser`；修复半安装 nightly 后，用显式 CLT libc++ include 完成 `cargo fuzz run frontmatter_parser -- -runs=256`，结果 `Done 256 runs in 0 second(s)`。可复现命令见 [`security-model.md`](./security-model.md#6-安全-checklist未来发布前)。
- 非 Claude adapter 证据收集：Codex / Pi / Hermes / OpenClaw / opencode 的目录布局、配置 schema、启停语义和最小 fixture。
  - 2026-06-08 Codex evidence 切片：官方 docs + 本地 `codex-cli 0.137.0` disposable HOME/CODEX_HOME 验证已确认 user/project `.agents/skills` read-only roots、`SKILL.md` 格式、用户级 `$CODEX_HOME/config.toml` / `~/.codex/config.toml` 写入禁用/恢复语义。第一版 Codex adapter 决策为 user-config writable；项目级 `.codex/config.toml` toggle、plugin/admin roots、`$CODEX_HOME/skills` compatibility root 仍不进入首版能力。
  - 2026-06-08 Pi / opencode evidence 切片：官方资料足够规划 read-only scanner/parser，但 writable adapter 仍 blocked，需 disposable local round-trip 和重复 root 策略。
  - 2026-06-08 Hermes / OpenClaw evidence 切片：已记录本地线索和 fixtures；2026-06-10 P0 evidence 进一步确认二者可进入 read-only scanner candidate，writable/install 继续 blocked。
- Native test hardening：把适合长期维护的 Swift list/model 行为沉淀为 SwiftPM test target。
  - 2026-06-08 Native test hardening 切片：SwiftPM `SkillsCopilotTests` 已补 `SkillStore` model 行为，覆盖 reload 后选中稳定性、缺失选中回退、空 catalog 友好模型、service error/loading 复位，以及 toggle 写操作 in-flight / success refresh 状态；`swift test --package-path apps/macos` 本地通过。

**退出条件**
- [x] scan / watcher / refresh 关键路径有用户可见 summary 状态、错误和恢复验证；实时 watcher/event stream 明确 defer 到 V2 后续设计。
- [x] 发布前安全 checklist 中 high/critical audit、canonicalize 和 fuzz 有明确结果或决策。
- [x] 至少一个非 Claude adapter 完成 spec 证据清单；当前 Codex 已完成 writable adapter 切片，opencode 已从 read-only native-root adapter 扩展到 official compatibility-root scan + guarded writes，当前 mainline 真实本机 UI 操作验证已在 2026-06-10 补跑通过。Pi / Hermes / OpenClaw 仍不得按猜测实现。
- [x] SwiftPM test target 覆盖核心 native view model/list model 行为，Node 脚本保留为集成/布局辅助。

## 4. V2 — "全 agent + 生态"

**当前 V2 状态（2026-06-10）**：Codex adapter 首个实现切片、V2.1 Claude/Codex adapter experience、V2.2 project context、V2.3 adapter hardening、V2.4 opencode read-only adapter、V2.5 audit hardening、V2.6 manual readiness docs、V2.7 LLM local assist gate、V2.8 rules/permissions governance implementation、V2.9 Tool-global skill pool、V2.10 skill execution safety docs/release consistency、V2.11-V2.20 adapter/management/analysis line 已完成 closeout，且当前 mainline app 的真实本机 Computer Use 操作验证已在 2026-06-10 通过。产品重心保持在 skills 的管理、检查、分析和配置审计；真实 sandbox runner、GitHub clone import、script-file install 已从活动 backlog 删除。可执行任务清单见 [`development-tasks.md`](./development-tasks.md)。V2.10 已完成安全边界文档同步：default-deny，不真实执行；blocked/cancelled/failure attempt audit；LLM 不可触发执行。当前产品方向不规划 successful execution output log。V2.8 已完成 LLM status protocol compatibility、permissions roundtrip for V2.8 rules、explicit severity ordering、findings filtering/grouping UI、`app.stateSnapshot` refresh optimization，以及七条新本地规则：`frontmatter.tools-not-empty`、`permissions.network-declared`、`permissions.exec-needs-human`、`name.canonical-case`、`script.no-shebang`、`body.too-long`、`dependency.unknown`。Codex adapter core、commands/service、cwd→repo-root project discovery、macOS UI scan-all、agent filter、restart note、project context、config patch hardening、状态表达、安全回归、opencode native + compatibility root 扫描、guarded opencode permission writes、scanner/config/snapshot/service/UI/docs audit hardening、adapter changelog tracking、默认关闭的 LLM service/UI gate 和 request prepare/estimate 均已落地。

**V2 剩余开发判定**
- 近期主线：Comprehensive Agent Adapter Support，优先补齐 Pi、opencode writable、Hermes、OpenClaw。
- 跨版本 backlog：不改变 V2.1-V2.10 closeout 状态，按 [`development-tasks.md`](./development-tasks.md) 的优先级单独推进。
- 验证口径：代码/UI/协议变更继续跑 `pnpm check:macos`；用户可见、UI 或 service protocol 变更继续重跑真实本机 Computer Use。若未来 macOS/AX 无法解析窗口，必须重新记录 blocker，不能用 smoke 截图替代。

### 4.0 首个实现切片：Codex adapter

**目标**：把 Codex skills 作为第二个真实 adapter 接入 catalog 和 macOS UI，同时保持所有写入经 service/commands 统一 snapshot、锁、原子写和回读验证。

**实现状态**

| 工作项 | 当前状态 |
| --- | --- |
| Codex adapter evidence | 已完成：见 [`codex-adapter-spec.md`](./codex-adapter-spec.md) 与 [`agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#codex) |
| Adapter core | 已集成：`crates/adapters/src/codex/` + `CodexAdapter` 注册 |
| Commands / service scan-all and toggle integration | 已集成：`catalog.scanAll` 扫描 Claude Code、Codex、guarded writable opencode 和 read-only Pi；Codex toggle 写用户 `config.toml`；opencode toggle/install 走 V2.12 exact `permission.skill` 与 snapshot/rollback；Pi writes remain blocked |
| macOS UI agent visibility / scan-all flow | 已集成：toolbar/menu/store 使用 scan-all，fixture tests 覆盖 `codex` agent record |
| Docs | 已更新；首轮 Computer Use 真实操作验证当时豁免，当前 mainline 已在 2026-06-09 后补通过 |

**范围**
- 新增 `crates/adapters/src/codex/`，实现 read-only scanning for verified roots：user `$HOME/.agents/skills`，以及从 adapter context `project_cwd` 向上到 `project_root` 的 `.agents/skills`。
- 解析 Codex `SKILL.md` frontmatter：`name` / `description` 必填；保留 raw frontmatter 和 body；不要从 `agents/openai.yaml` 猜测权限字段。
- 增加 Codex fixtures/parser/commands tests：global、project、malformed、conflict、disabled/re-enabled、duplicate config entries。
- 实现 user-config writable toggle：只 patch `$CODEX_HOME/config.toml` / `~/.codex/config.toml` 的 `[[skills.config]]`，disable 写绝对 `SKILL.md` path + `enabled = false`，enable 删除该 path 的所有 entries。
- 接入 catalog/service contract：list/get/findings/conflicts/snapshot 对多 agent 数据仍稳定；UI 显示 agent 为 `codex`，但不把 plugin/admin/system skills 暴露为首版范围。
- 验证：`cargo test --workspace`、focused adapter/commands tests、service fixtures、`pnpm check:macos` 已通过；当前 mainline 已在 2026-06-09 后补真实 macOS Computer Use 操作验证。

**不做**
- 不写 `<repo>/.codex/config.toml`。
- 不扫描 `/etc/codex/skills`、plugin-distributed skills 或 `$CODEX_HOME/skills`，除非另有产品决策。
- 不从 `agents/openai.yaml`、未知 frontmatter 字段或 Codex plugin metadata 推导权限、依赖或启停状态。
- 本切片不实现 Pi / opencode / Hermes / OpenClaw adapter。

**退出条件**
- [x] Codex global/project skills 能进入 catalog，并与 Claude Code skills 共存。
- [x] Codex nested cwd→repo-root project walking 通过 `AdapterContext.project_cwd` 完成。
- [x] Codex disable/re-enable user-config round trip 有 snapshot、原子写、回读验证和 rescan。
- [x] Malformed Codex skills 被标记为 broken，不导致 scan 失败。
- [x] macOS UI 能清楚区分 `claude-code` 与 `codex` agent，并保留 refresh/log/error 状态。
- [x] `pnpm check:macos` 通过。
- [x] Real local app Computer Use validation 首轮切片未执行；当前 mainline 已于 2026-06-09 后补通过，后续代码改动仍需重跑。

### 4.1 V2.1 Claude/Codex Adapter Experience

**目标**：先把 Claude/Codex 两个 writable-capable adapter 体验打稳，再继续扩大 adapter 数量。

**状态（2026-06-09）**：实现已集成，自动验证已通过，并已完成当前 mainline 真实本机 Computer Use 补验。`catalog.scanAll` 已提供 per-agent refresh summary，native macOS UI 已补 agent filter / grouped list / Codex restart note，SwiftPM 和 native list model tests 已覆盖核心行为。`pnpm check:macos` 通过；真实 app 从 `<repo>/dist/SkillsCopilot.app` 启动，Computer Use 操作验证覆盖 scan-all、All/Claude Code/Codex/opencode agent filter、Codex/Claude/opencode 可见性、opencode read-only 状态、project context set/clear、findings/conflicts/snapshot preview 和 script safety preview-only。真实 Codex/Claude toggle 写入未在本轮触发，避免改动开发者真实配置；写路径仍由 fixture smoke 和服务测试覆盖。

**范围**
- UI 应补齐 agent 维度过滤/分组：`All` / `Claude Code` / `Codex`。过滤只影响可见列表、计数和空态，不应改变 catalog 数据或触发写入。
- 列表、详情和 refresh log 应清楚展示 skill 来源、扫描 root、扫描数量和失败 root；用户应能分辨同名 Claude Code / Codex skill 的来源。
- `catalog.scanAll` 的用户可见 summary 应分别表达 Claude Code 与 Codex 的扫描结果，包括成功数量、broken/missing/error root 和最近一次 scan 时间。
- Codex toggle 后应补用户提示：Codex runtime 可能需要 restart 才能读取用户级 `config.toml` 变更。提示不得暗示 Codex 会 live reload，也不得要求重启 Skills Copilot 才能完成写入。
- Claude Code toggle、Claude Settings 编辑、snapshot preview / rollback 仍应保持 V1/V2.0 行为，不因 Codex support 回归。
- 真实本机 app Computer Use 操作验证应在集成后恢复执行，覆盖 scan-all、agent filter、Codex 可见性、Claude Code 回归、Codex toggle restart note 和窗口级截图。
- 不新增第三个 adapter，不扩大 Codex root 范围，不写 project-local Codex config。

**Coordinator validation checklist**
- [x] Run `pnpm check:macos` from a clean-enough working tree and record the exact command result.
- [x] Run `pnpm dev:macos` to launch the real local app against the developer's real local `HOME`, default app data, real Claude config, and current Codex config.
- [x] In the real app, run Scan / scan-all and confirm the UI calls the multi-adapter path rather than Claude-only scan; 2026-06-09 visible summary: `341 scanned, 341 in catalog, 866 findings, 170 conflicts`.
- [x] Exercise the agent filter for `All`, `Claude Code`, `Codex`, and `opencode`; 2026-06-09 real local counts were 341 / 154 / 171 / 16 visible rows and selected detail updated correctly.
- [x] Confirm at least one Codex skill is visible when local Codex fixture or real Codex roots exist; 2026-06-09 real local Codex filter showed 171 visible rows.
- [x] Confirm a Claude Code skill is still visible; 2026-06-09 real local Claude Code filter showed 154 visible rows. Real config toggle write was not re-exercised in this pass to avoid mutating live user config.
- [ ] Toggle a writable Codex skill and confirm the post-write UI includes a restart note for Codex runtime config reload; keep this open until a disposable real Codex config or explicit user-approved live-config write pass is used.
- [ ] After the Codex toggle, restart or reopen the relevant Codex runtime only if needed for local confirmation; record whether restart was required or skipped.
- [x] Capture the completed UI evidence with the app-window-only capture script; 2026-06-09 evidence: `docs/ui-artifacts/native-macos-shell/completed.png` and `docs/ui-artifacts/native-macos-shell/real-local-computer-use-2026-06-09.png`.
- [x] Update `docs/ui-artifacts/native-macos-shell/completed.png` and verification notes after the real app validation completed.

**退出条件**
- [x] 用户能在 UI 中按 agent 过滤并确认每条 skill 来源。
- [x] `catalog.scanAll` 的用户可见 summary 能区分 Claude Code / Codex 结果。
- [x] Codex toggle 的 restart 提示明确且不误导为 live reload。
- [x] Claude Code scan/list/detail/toggle/settings/snapshot flows 没有因 Codex UI 收敛回归。
- [x] `pnpm check:macos` + real local app Computer Use validation passed on 2026-06-09; window-level evidence recorded at `docs/ui-artifacts/native-macos-shell/real-local-computer-use-2026-06-09.png`.

### 4.2 Project context 正式化

**状态**：implementation integrated; current mainline real local validation passed later。2026-06-08 已集成 ProjectContext service/UI/catalog/smoke/docs，实现和自动化验证通过；该里程碑 closeout 时真实本机 app 进程可启动，但 macOS/AX 会话无法解析 SkillsCopilot 窗口。当前 mainline app 后续已在 2026-06-09 操作 project context set/clear 并通过真实本机 Computer Use 验证。

**目标**：把当前 env-driven project context 变成产品可理解、可复用的项目选择/记忆能力。

**范围**
- 明确 app 如何设置 `SKILLS_COPILOT_PROJECT_CWD` / `SKILLS_COPILOT_PROJECT_ROOT`。
- 支持用户选择/记忆项目目录，并在 scan-all 时传入 service。
- 定义多 project / monorepo catalog 归属和切换规则。
- 防止 Claude / Codex project skills 被错误归入其它项目。
- 定义 `ProjectContext` 模型、service 方法、持久化文件、env override 优先级、无项目行为和安全边界。

**ProjectContext contract**
- `ProjectContext` 是 UI/service 之间的当前项目描述，包含 `id`、`name`、`root_path`、`current_cwd`、`last_used_at`、`is_active` 和 `validation_error`；有效来源通过 `service.status.project_context.source` 暴露为 `env` / `stored` / `none`。
- `current_cwd` 是用户当前选择或环境注入的工作目录；`root_path` 是 service 校验后的安全项目根。`current_cwd` 必须位于 `root_path` 内；UI 设置项目时显式传 `root_path`，env launch 可由 service 从 `SKILLS_COPILOT_PROJECT_CWD` 向上推导 root。
- 持久化文件为 app data 下的 `project-context.json`，只保存最近一次用户选择的安全项目上下文和最近项目列表。环境变量注入的上下文不写入该文件。
- 优先级：`SKILLS_COPILOT_PROJECT_CWD` / `SKILLS_COPILOT_PROJECT_ROOT` env override 最高；其次是 `project-context.json` 的 active 项目（包括本次 UI 显式选择写入的项目）；最后是 no-project。
- no-project 下 UI 必须显示未选择项目，`catalog.scanAll` 不扫描 project-local Claude/Codex roots，不把发现结果归入某个旧项目；用户级 Claude/Codex roots 仍可扫描。
- 多 project / monorepo 切换时，catalog 记录必须保留 `project_root` 归属；当前项目视图只能展示当前 root 相关 project skills 和 agent-global skills，toggle 目标必须来自当前上下文可写范围。

**Service protocol additions**
- `project.getContext`：读取持久化项目上下文，返回 `{ active, recent }`。
- `project.setContext`：传入用户选择的 `root_path`、可选 `current_cwd` 和可选 `name`，由 service canonicalize、校验安全边界、推导 name、写 `project-context.json`，然后返回 `{ active, recent }`。
- `project.clearContext`：清除持久化当前项目，进入 no-project；不得删除 catalog 里属于其它项目的历史记录。
- `project.validateContext`：校验 `{ root_path, current_cwd?, name? }`，返回带 `validation_error` 的 `ProjectContext` 供 UI 预检/修复。
- `catalog.scanAll` 在 V2.2 之后必须使用当前有效 `ProjectContext`，通过 `service.status.project_context` 区分 env、stored 与 none。

**Non-goals**
- 不新增第三个 adapter。
- 不写 project-local Codex config；Codex toggle 仍只写用户 `config.toml`。
- 不扫描或写入 plugin/admin/system roots，包括 `/etc/codex/skills`、`$CODEX_HOME/skills` 或插件分发目录。
- 不引入 cloud sync、账号、telemetry、匿名 crash report 或远端项目记忆。
- 不做 SQLite tenant / workspace migration，除非实现中证明仅靠 `project_root` 和 `project-context.json` 无法保证归属。

**退出条件**
- [x] UI 能显示当前项目上下文，并允许切换/清除。
- [x] Codex cwd→repo-root scanning 在 fixture/stored project context 下可复现；当前 mainline app 于 2026-06-09 完成真实本机 project context 操作验证。
- [x] 多 project 切换不会污染 catalog 状态或 toggle 目标。
- [x] V2.2 文档、service fixtures、实现和 UI 文案没有互相矛盾的 complete/passed claims。
- [x] 真实本机 UI 操作验证已在 2026-06-09 通过并记录窗口级证据：`docs/ui-artifacts/native-macos-shell/real-local-computer-use-2026-06-09.png`。

**Coordinator validation checklist**
- [x] Run `cargo test --workspace` and record the exact result: passed on 2026-06-08.
- [x] Run `cargo clippy --workspace --all-targets --all-features` and record the exact result: passed on 2026-06-08 with `-D warnings`.
- [x] Run `swift test --package-path apps/macos` and record the exact result: passed on 2026-06-08.
- [x] Run `pnpm check:macos` and record the exact result: passed on 2026-06-08, including fixture app-window screenshot capture.
- [x] Run a smoke project context scenario using fixture data: start no-project, set a project cwd, scan-all, switch/clear project, and confirm catalog ownership and toggle targets do not leak across contexts.
- [x] Run the real local app with `pnpm dev:macos` or `./script/build_and_run.sh run` against the developer's real local `HOME`, default app data, real Claude config, and current Codex config: `pnpm dev:macos` / `open -n dist/SkillsCopilot.app` launched the real bundle process on 2026-06-08.
- [x] When the macOS session is unlocked and Computer Use/AX can see a SkillsCopilot window, operate the real app to set/switch/clear project context, run scan-all, verify Codex cwd→repo-root behavior, and capture only app-window evidence. Completed on 2026-06-09 against `<repo>/dist/SkillsCopilot.app`.
- [x] At V2.2 closeout, if Computer Use/AX could not see the real app window, the blocker was recorded explicitly: process launched, but `script/capture_app_window.sh dist/real-local-v2.2-window.png` reported no visible window, System Events reported 0 SkillsCopilot windows, and Computer Use `get_app_state` returned `remoteConnection`. Current mainline real local validation was completed later on 2026-06-09.

### 4.3 Adapter hardening

**状态**：implementation integrated; current mainline real local validation passed later。2026-06-08 已集成 Codex config patch hardening、root/security regressions、状态表达、smoke 覆盖和文档同步，并通过自动化验证；该里程碑 closeout 时真实本机 app Computer Use 操作验证因 macOS/AX 窗口不可见而阻塞。当前 mainline app 后续已在 2026-06-09 通过真实本机验证。

**目标**：把 Codex 首版实现从“可用”推进到“耐用”。

**范围**
- 强化 Codex `config.toml` patch：保留非目标内容、重复 entries 归一化、异常配置给出清晰错误。
- 细化 symlink、duplicate skill、broken skill、missing root 的 UI/refresh 表达。
- 增加 Codex config / root 安全回归测试。
- 继续不扫描 `/etc/codex/skills`、plugin/system skills 或 `$CODEX_HOME/skills`，除非另有产品决策。

**Task checklist**
- [x] Codex config patch hardening：disable 时只归一化目标 absolute `SKILL.md` path 的 `[[skills.config]]` entries；re-enable 时删除所有目标 entries；保留注释、非目标 table、非目标 skill override、未知 config key 和文件末尾换行。
- [x] 异常 config 行为：非 string `path`、缺失 `path`、重复/冲突 entry 和不可写 config path 返回错误或保持非目标内容；不得静默覆盖整份 config。
- [x] State expression：扫描/refresh summary、列表/详情和 toggle 反馈区分 enabled、disabled、broken、missing、shadowed/unknown 和 skipped-root/root-error；Codex restart note 只在 user config 写入成功后出现。
- [x] Security regressions：覆盖 project context 边界、Codex user config path canonicalization、拒绝 project-local `.codex/config.toml` 写入、拒绝 plugin/admin/system roots、拒绝 unsafe `CODEX_HOME`、以及 stale catalog selection 不能越过当前 project root toggle。
- [x] Initial docs sync：README、AGENTS、roadmap、Codex adapter spec、adapter worklists 和 security model 对 V2.3 scope/status 使用同一口径；V2.2 real Computer Use validation blocker 保持显式。

**Validation checklist**
- [x] Focused Codex adapter/config tests cover comment preservation, non-target preservation, duplicate normalization, malformed config errors, disabled/re-enabled round trip, and malformed target block handling.
- [x] Focused service/commands tests cover snapshot, atomic write, read-back verification, rescan behavior, safe/unsafe `CODEX_HOME`, and current-project write boundaries.
- [x] Security regression tests prove no writes to `<project>/.codex/config.toml`, plugin/system roots, unsafe `CODEX_HOME`, or paths outside the validated user config parent.
- [x] UI/store and smoke coverage prove status labels and refresh summaries remain distinguishable for disabled/broken/missing/root-error cases.
- [x] Run `cargo test --workspace` and focused adapter/commands tests after implementation changes: passed on 2026-06-08.
- [x] Run `pnpm check:macos` after implementation/UI changes: passed on 2026-06-08, including fixture app-window screenshot and Codex config hardening smoke.
- [x] Real local app validation remains required for code/UI changes: on 2026-06-09 Computer Use operated project context, scan-all, agent filters, read-only states, snapshot preview, and captured only the app window. Real Codex live-config toggle/restart note remains separately open until a disposable or explicitly approved live-config write pass.
- [x] Documentation-only sync pass validation: run stale-status `rg` scan and `git diff --check`.

**退出条件**
- [x] Codex config patch 覆盖注释/非目标配置/重复 entries/异常配置测试。
- [x] broken/disabled/missing/root-error 状态在 UI 中可区分。
- [x] security regressions 覆盖 Codex user config path、project context、root allowlist 和 project-local/plugin/admin/system write rejection。
- [x] README / AGENTS / roadmap / adapter specs / security model 状态一致，不再残留 V2.1 active-phase 文案；V2.2/V2.3 real Computer Use blocker 仍清楚可见。
- [x] 真实本机 UI 操作验证已在 2026-06-09 通过并记录窗口级证据：`docs/ui-artifacts/native-macos-shell/real-local-computer-use-2026-06-09.png`。

### 4.4 V2.4 opencode read-only implementation

**目标**：把 opencode 作为第三个 adapter 接入 catalog，但没有 writable 证据前只做 read-only。

**状态**：complete / automated validation passed；current mainline real local Computer Use validation passed on 2026-06-09。fixture smoke 截图仍不能替代后续候选变更的真实本机验证。

**范围**
- 当前实现扫描 opencode native roots 与官方 `.agents/skills` / `.claude/skills` compatibility roots；重复关系交给 cross-agent analysis 展示。
- 解析 opencode `SKILL.md` frontmatter：`name` / `description` 必填，`name` 必须匹配目录；缺失或不匹配应作为 broken/malformed 记录，不让整次 scan 失败。
- 接入 `catalog.scanAll`、project context 和 agent filter/status；read-only rows 的 toggle 必须被 UI/service 明确拒绝。
- Smoke fixture 使用临时 HOME/project 创建 opencode native/compatibility roots，并在 service 支持 opencode 时断言 no-project global 可见、project context 下 project skill 可见、guarded toggle path 符合 capability matrix。
- Writable opencode toggle 继续 blocked；`permission.skill` 的 exact patch / re-enable / wildcard precedence / managed config 行为未完成 disposable round-trip 前不得实现。

**退出条件**
- [x] opencode read-only scanner/parser 与 Claude Code / Codex 共存，不产生 compatibility-root 重复污染。
- [x] `catalog.scanAll` 在 no-project 下展示 global opencode，在 active project context 下展示 project opencode。
- [x] UI/service 对 opencode toggle 展示并返回 read-only/unsupported 原因，不创建或修改 opencode config。
- [x] Smoke coverage 使用临时 opencode roots，且不触碰真实用户 config。
- [x] Coordinator final validation 后同步 README / AGENTS / roadmap / runbook 状态为 complete。

### 4.5 V2.5 Audit Hardening

**目标**：把本轮文档审查暴露的 stale/status drift 和 audit blind spots 收敛成实现前 checklist，优先强化边界隔离、fixture typing、UI 防误操作和文档同步。

**状态**：complete / automated validation passed；current mainline real local Computer Use validation passed on 2026-06-09。2026-06-08 已集成 scanner/parser、commands/security、service/smoke、macOS UI 和 docs/status hardening；后续候选变更仍需重跑真实本机验证。

**Task checklist**
- [x] Scanner override isolation：复核 `SKILLS_COPILOT_*_EXTRA_ROOTS`、fixture roots、project context env override 和 adapter native roots 的隔离，确保测试/截图 override 不会进入真实用户 config 或跨 adapter 扫描边界。
- [x] Codex TOML hardening：继续覆盖 duplicate/invalid `[[skills.config]]`、comment preservation、unknown key preservation、path canonicalization、non-target preservation、malformed TOML error 和 re-enable deletion semantics。
- [x] Snapshot / permissions audit：确认所有写路径在 snapshot、file lock、atomic write、read-back verify、rollback failure handling 和 permission/root checks 上保持一致；新增写路径必须先补 threat model。
- [x] Read / preview validation：强化 `snapshot.previewRollback`、config read、skill detail read 和 project context validation 的 read-only error surface，避免 preview/read flow 暗中写入或吞掉 path/root 错误。
- [x] Service fixture typing：让 request/response fixtures 覆盖 supported adapter `agent_summaries`、opencode read-only rejection、project context payloads、snapshot preview error fields 和 stable error codes；fixture decode tests 必须防 schema drift。
- [x] UI selection / busy / read-only states：验证 scan/filter/project switch 后 stale selection 被清理或重新校验；busy write 状态阻止重复写；read-only/broken/missing/shadowed/opencode rows 不调用写 API 并显示明确原因。
- [x] Docs sync gate：README、AGENTS、architecture、service protocol、security model、runbook、native plan、UI artifacts 和 roadmap 使用同一状态口径；保留 stale wording `rg` 和 `git diff --check` 作为 docs-only closeout gate。

**退出条件**
- [x] Focused tests cover each audit item above, or the item has an explicit deferred rationale.
- [x] `pnpm check:macos` passes after implementation changes.
- [x] Real local Computer Use validation blocker remains explicit until the macOS/AX session can resolve the app window.
- [x] Docs closeout proves no stale V2.1/V2.2/V2.4 status wording remains in maintained milestone docs.

### 4.6 Release readiness（非公开发布自动化）

**目标**：继续准备本地交付纪律，不引入正式发布打包流程。

**状态**：complete / docs-only readiness。2026-06-08 已新增手工 readiness checklist 和 V2 adapter changelog tracking。

**范围**
- 版本号策略、changelog 模板、手工 release checklist。
- `pnpm check:macos` 继续作为本地质量门禁。

**退出条件**
- [x] 手工 release checklist 可执行，且不声称已有正式分发自动化（见 [`release-checklist.md`](./release-checklist.md)）。
- [x] changelog 能追踪 V2 adapter 行为变化和风险（见 [`../CHANGELOG.md`](../CHANGELOG.md)）。

### 4.7 LLM 本地辅助分析

**目标**：把 `docs/ai-layer.md` 中已定义的 Analyze / Recommend / conflict explanation / draft frontmatter 能力纳入明确路线，同时保持默认离线和用户显式启用。

**状态**：complete / disabled-by-default service and UI gate。V2.7 的实现边界是 request prepare/estimate：用户主动触发前显示 provider、model、token/cost 估算和 unavailable reason；不实现真实 provider client、网络调用或 credential storage。主分支 closeout 已完成，`pnpm check:macos` 通过；当前 mainline app 后续已在 2026-06-09 通过真实本机窗口级 Computer Use 操作验证，并确认 LLM controls 仍默认关闭。

**范围**
- Provider credentials UX：本阶段不保存 credentials；未来 macOS Keychain 优先，退路 `~/.config/skills-copilot/llm.yaml` 必须检查 `0600` 权限。
- Analyze：本阶段只准备/估算请求；未来用户主动触发后，对单个 skill 做摘要、风险说明和可读性分析。
- Recommend：本阶段只准备/估算请求；未来基于当前 catalog 和用户显式输入推荐已有 skill，不主动联网或读取未授权内容。
- Conflict explanation：本阶段只准备/估算请求；未来解释 name collision、shadowing、fingerprint changed 等发现。
- Draft frontmatter：本阶段只允许草稿展示/复制，不存在 Apply / Write；所有真实写入仍需用户进入正常编辑/保存路径并走 Rust service。
- Token/cost budget：单次和月度上限，默认关闭；本阶段只做本地估算和 gate 状态展示。

**实现 checklist**
- [x] service 状态明确 LLM disabled-by-default，且未配置 provider 时不会创建 client 或发起网络请求。
- [x] Analyze / Recommend / conflict explanation / draft frontmatter action 必须由用户主动触发 prepare/estimate。
- [x] prepare/estimate 响应包含 provider、model、预估 token、预估 cost、budget 状态和 disabled/unconfigured reason。
- [x] Provider credentials UI 不保存真实 API key；后续保存能力必须 Keychain 优先，fallback 文件强制 `0600`。
- [x] 凭据、prompt、response、token/cost 估算不得写 SQLite、项目目录或 logs。
- [x] Draft frontmatter UI 只有展示/复制，不提供 Apply / Write。
- [x] stale wording 检查不能出现 provider/client/network/key storage 已落地之类的误导声明。

**退出条件**
- [x] LLM 默认关闭，未配置 provider 时 UI 不触发任何网络调用。
- [x] 所有 LLM action 都是用户主动触发，并显示 provider/model/token/cost 预估。
- [x] LLM 输出不能直接进入写操作；草稿只展示/复制，真实写入必须经正常编辑/保存路径和 Rust service。
- [x] 凭据不写入 SQLite、项目目录或日志。

### 4.8 规则与权限治理

**目标**：把规则引擎从 MVP 4 条规则扩展成可维护的本地治理层，优先覆盖权限、依赖、脚本和内容质量。

**状态**：complete / automated validation passed；current mainline real local Computer Use validation passed on 2026-06-09。五项 remediation 已完成集成并通过 focused validation、docs stale-claim 检查和主线 `pnpm check:macos`；七条新规则已完成：`frontmatter.tools-not-empty`、`permissions.network-declared`、`permissions.exec-needs-human`、`name.canonical-case`、`script.no-shebang`、`body.too-long`、`dependency.unknown`。

**范围**
- 已完成新规则：`frontmatter.tools-not-empty`、`permissions.network-declared`、`permissions.exec-needs-human`、`name.canonical-case`、`script.no-shebang`、`body.too-long`、`dependency.unknown`。
- 为不同 agent 的权限字段建立 read-only normalization，未验证字段只保留 raw，不推导权限。
- UI 增加 rules/finding filtering、severity grouping 和 remediation suggestion。
- 对 high-risk script / network / exec 声明保持本地规则判断，不调用 LLM。
- Remediation target：LLM status protocol compatibility，兼容 V2.7/V2.8 status payload，缺字段时必须 unknown-safe，不得推断 provider/client/network 已经落地。
- Remediation target：permissions roundtrip for V2.8 rules，fixture 和 read-back 必须覆盖 raw、normalized、unknown 字段不丢失。
- Remediation target：explicit severity ordering，规则输出、排序、分组和 UI 文案必须使用同一稳定顺序。
- Remediation target：findings filtering/grouping UI，按 severity / rule / agent 过滤和分组时保持计数、空状态、详情选择一致。
- Remediation target：`app.stateSnapshot` refresh optimization，只有状态快照变化才触发昂贵刷新，但 scan/filter/project-context/adapter-state 改变后不得复用 stale findings 或 stale permissions。

**退出条件**
- [x] 七条新规则有单元测试和 fixture 覆盖：`frontmatter.tools-not-empty`、`permissions.network-declared`、`permissions.exec-needs-human`、`name.canonical-case`、`script.no-shebang`、`body.too-long`、`dependency.unknown`。
- [x] UI 能按 severity / rule 筛选 findings，并按 severity 分组；agent 维度仍通过左侧 agent filter 覆盖。
- [x] 权限字段未验证时显示 unknown，不误报为 safe 或 unsafe。
- [x] LLM status protocol compatibility 有 fixture/contract 覆盖，V2.7 gate 边界仍不声称 real provider/client/network/credential storage。
- [x] Permissions roundtrip 覆盖 normalized 字段 read-back；更深 raw/unknown permission normalization 仍随新规则扩展推进。
- [x] Severity ordering 在 service、UI grouping 和 docs 中一致。
- [x] `app.stateSnapshot` refresh optimization 有 stale-selection/stale-findings 防回归覆盖。
- [x] Current mainline real local Computer Use validation passed on 2026-06-09; fixture smoke screenshots remain insufficient for future candidates.

**V2.8 final integration validation completed**
- `cargo test -p skills-copilot-catalog`
- `swift test --package-path apps/macos`
- `pnpm verify:macos-ui-layout`
- `pnpm check:macos`
- stale wording `rg`
- `git diff --check`
- The current mainline app later passed real local Computer Use validation on 2026-06-09; future candidates still need a fresh real local pass.

**Release / V2.10 closeout**：V2.9 Tool-global skill 池与导入导出已集成；V2.10 已把 Skill execution safety 边界同步到 roadmap / README / AGENTS / security model / service protocol / data model / macOS runbook / release checklist。2026-06-09 真实本机 Computer Use pass 已验证当前 mainline app：`pnpm check:macos` 通过，真实本机 app window 可解析，实际操作覆盖 scan-all、findings severity filter、conflicts、snapshot preview、Codex/opencode agent filter、project context set/clear、opencode read-only、LLM disabled controls 和 script safety preview；窗口级证据为 `docs/ui-artifacts/native-macos-shell/real-local-computer-use-2026-06-09.png`。后续继续推进 Pi disposable local round-trip、opencode writable evidence、Hermes / OpenClaw read-only scanner，并在未来候选变更后重跑真实本机验证。

### 4.9 Tool-global skill 池与导入导出

**目标**：把 `Scope::ToolGlobal` 从数据模型保留位推进为产品能力，用于本地导入、共享池和跨 agent 复用，但不绕过各 agent 的真实配置语义。

**状态（2026-06-09）**：complete / automated validation passed。已完成 tool-global catalog/staging 基座、本地目录 import + audit、可复现 export bundle/manifest、manifest reimport 稳定性、Claude/Codex verified install flow、native macOS read-only preview/confirmation UI 和 service protocol fixtures；主线 `pnpm check:macos` 已通过。GitHub clone import 和 script file install 已从活动 backlog 删除；opencode writable install 转入 adapter 主线。

**范围**
- Skill 导入：从本地目录或 GitHub repo 导入到 tool-global staging area，并运行规则审计。
- Skill 导出：生成可复现 bundle/manifest。
- 定义 tool-global 与 agent-global / agent-project 的优先级、冲突展示和复制/安装到具体 agent 的流程。
- 所有导入内容默认 read-only preview；安装到 agent 前需要用户确认目标和写入路径。

**退出条件**
- [x] Tool-global records 能进入 catalog 且不被 adapter scan 混淆。
- [x] Import 只写 app-controlled staging area，不写 agent config。
- [x] Export manifest 可被重新导入并保持 fingerprint/metadata 稳定。
- [x] 安装到 agent 时仍走对应 adapter 的 verified write path。

### 4.10 Skill 执行与脚本安全

**目标**：为未来“执行 skill 脚本”建立独立安全边界。当前产品默认不真实执行；本阶段完成的是安全 contract、preview/audit 要求和 release/docs consistency，不是可运行脚本 sandbox。

**状态（2026-06-09）**：V2.10 safety boundary documented / release consistency complete。`script.previewExecution` 与 `script.execute` 为默认拒绝执行边界内的预检/意图方法，当前阶段仅产出 blocked/cancelled/failed 审计；scan、import、export、install、LLM prepare、state snapshot 和 detail loading 都不得触发执行。真实 runner、sandbox、stdout/stderr capture、成功执行记录和公开发布自动化仍 deferred。

**范围**
- 定义默认不执行的边界，以及未来执行前必须逐次确认的规则。
- 定义 cwd/env/network/files preview、命令/interpreter preview、风险提示和 secret redaction 要求。
- 定义 blocked/cancelled/failure attempt audit record；当前产品方向不规划 successful execution output log。
- 与 LLM 严格隔离：LLM 不得触发执行、不得代替用户确认、只能生成展示/复制用建议。

**退出条件**
- [x] 默认禁止真实执行脚本；协议 v1 不暴露 runner method。
- [x] 未来执行必须用户逐次确认，并显示 cwd/env/network/files 范围。
- [x] security model 记录 default-deny、preview、audit、LLM separation 和 public release deferral。
- [x] blocked/cancelled/failure attempts 有审计记录 contract；真实 runner 未实现前不得产生 `completed` execution record。
- [x] 真实 sandbox runner 不进入当前产品规划；V2.10 只保留 default-deny 安全边界和审计一致性。

### 4.11 V2.11 Adapter Capability Matrix

**目标**：把六个 agent 的当前能力状态变成服务协议和 macOS UI 的一等信息，避免 UI 或后续 agent 仅凭名称猜测 scan/toggle/install 支持。

**状态（2026-06-09）**：completed。V2.11 service/UI 切片已集成并通过 `pnpm check:macos`：`adapter.listCapabilities` 和 `service.status.adapter_capabilities` 暴露 Claude Code、Codex、opencode、Pi、Hermes、OpenClaw 的 scan、project scan、config toggle、config snapshot、install、writable 状态与 blocker；macOS 侧边栏显示所选 agent 的能力和阻塞原因。

**范围**
- 服务协议暴露 adapter capability matrix。
- macOS agent selector 覆盖 Claude Code、Codex、opencode、Pi、Hermes、OpenClaw，但不恢复 `All` 选项。
- UI 以能力矩阵显示 scan/toggle/install 状态和 blocker。
- V2.11 本身只展示能力矩阵，不实现 opencode/Pi/Hermes/OpenClaw 的新写入语义。
- 后续 V2.12 已完成 opencode writable；V2.13 已完成 Pi read-only scanner/parser。

**退出条件**
- [x] `adapter.listCapabilities` 和 `service.status.adapter_capabilities` 有 contract fixtures。
- [x] macOS UI 能展示六个 agent 的能力状态、只读/blocked 原因和当前 agent skill 列表。
- [x] opencode toggle/install 仍被服务端稳定拒绝，且 UI 显示 read-only blocker。
- [x] `pnpm check:macos` 通过。
- [x] 当轮因会话锁屏跳过真实交互 Computer Use validation；当前 mainline 已在 2026-06-10 用当前 `dist/SkillsCopilot.app` 完成真实 Computer Use 补验。

### 4.12 V2.12 opencode writable support

**目标**：在 disposable local evidence 证明安全前提后，才允许 opencode 从 read-only 进入 guarded writable。

**状态（2026-06-09）**：completed。`permission.skill.<name> = "deny"` exact patch、re-enable、agent-config snapshot/rollback、tool-global install 到 native opencode roots、UI/service capability gating 和 fixture smoke 已通过 `pnpm check:macos`。

**范围**
- 用临时 HOME / `XDG_CONFIG_HOME` / `OPENCODE_CONFIG_DIR` / fixture project 验证 `permission.skill` 写入语义。
- 确认 exact patch、re-enable、wildcard precedence、managed config ownership、rollback-safe write path。
- 证据充分后实现 guarded toggle/install；证据不足则保持 blocker。

**退出条件**
- [x] Disposable evidence 使用临时 HOME / `XDG_CONFIG_HOME` / `OPENCODE_CONFIG_DIR` / fixture project，不读取不修改真实 opencode config。
- [x] 完成 exact patch、re-enable、wildcard precedence、managed config ownership、rollback-safe write path 的本地 round-trip 验证。
- [x] Toggle 前后的 catalog snapshot、agent-config snapshot、skill activity 符合预期，可回放恢复。
- [x] 仅在上述代码实现与验证通过后，UI 和 service 才将 opencode 标记 writable 并开放 guarded toggle/install；否则 `blocked` 原因保持可见且不得移除。
- [x] `pnpm check:macos` 通过；当轮真实交互 Computer Use 因会话锁屏跳过，当前 mainline 已在 2026-06-10 完成真实 Computer Use 补验。

### 4.13 V2.13 Pi adapter support

**目标**：先实现证据充分的 Pi-native read-only scanner/parser，并保留 Pi writable blocker，直到 settings mutation / rollback 语义完成 disposable round-trip。

**状态（2026-06-10）**：completed with local-noise hardening。V2.13 已实现 Pi-native `~/.pi/agent/skills` 与项目 `.pi/skills` scanner/parser，当前只 catalog 目录型 `SKILL.md`；Pi-native root `.md` 在真实本机验证中会混入大量普通资源文档，暂不展示。`pnpm check:macos` 通过。Pi toggle/install/snapshot writes 仍 blocked。

**退出条件**
- [x] Pi scan roots、project precedence、malformed behavior 有 fixture。
- [x] macOS UI 支持 Pi filter、status、findings、activity 和 read-only capability blocker。
- [x] `pnpm check:macos` 通过；当轮真实交互 Computer Use 因会话锁屏跳过，当前 mainline 已在 2026-06-10 完成真实 Computer Use 补验。
- [ ] Pi settings schema 和 enable/disable 语义完成 disposable 验证；该项保留为后续 writable follow-up，不阻塞 V2.13 read-only closeout。

### 4.14 V2.14 Hermes adapter support

**目标**：先拿到 maintainer-confirmed spec，再决定 Hermes 是否映射为 SkillInstance 以及可写范围。

**状态（2026-06-10）**：V2.17 read-only scanner implemented / writable still blocked。P0 evidence 确认 Hermes Agent 有 first-class skills 和 active Hermes home `skills/**/SKILL.md`；第一版只实现 scoped read-only scanner，不做 generic project scan、toggle、install 或 writable。`skills.external_dirs` 未来只按 explicit external roots 评估，不自动映射为 project roots。

**退出条件**
- [x] P0 evidence 确认 Hermes skill-like unit 和 active Hermes home skill root。
- [x] `adapter.listCapabilities` / `service.status.adapter_capabilities` 展示 Hermes supported read-only scan。
- [x] Hermes scoped read-only scanner 实现并通过 focused fixture validation。
- [x] Hermes install/toggle/writable 保持 blocked。
- [x] `pnpm check:macos` 通过；当轮真实交互 Computer Use 因会话锁屏跳过，当前 mainline 已在 2026-06-10 完成真实 Computer Use 补验。

### 4.15 V2.15 OpenClaw adapter support

**目标**：先拿到 maintainer-confirmed spec，再决定 OpenClaw scan/toggle/install 范围。

**状态（2026-06-10）**：V2.16 read-only scanner implemented / writable still blocked。P0 evidence 确认 OpenClaw `SKILL.md` roots、schema、loading order、precedence 和 JSON list capability；第一版只实现 scoped filesystem read-only scanner，不调用 OpenClaw CLI，不做 toggle/install/writable。Project-like scope 只限 confirmed OpenClaw workspace roots `<workspace>/skills` 和 `<workspace>/.agents/skills`，不按任意 repo root 推断。

**退出条件**
- [x] P0 evidence 确认 OpenClaw read-only scanner 所需基础 roots/schema/precedence。
- [x] `adapter.listCapabilities` / `service.status.adapter_capabilities` 展示 OpenClaw read-only candidate，scan 仍 disabled until implementation.
- [x] OpenClaw scoped read-only scanner 实现并通过 focused fixture validation。
- [x] OpenClaw install/toggle/writable 保持 blocked。
- [x] `pnpm check:macos` 通过；当轮真实交互 Computer Use 因会话锁屏跳过，当前 mainline 已在 2026-06-10 完成真实 Computer Use 补验。

### 4.16 V2.16 OpenClaw read-only scanner

**目标**：把 OpenClaw 已确认的 skill roots 纳入 catalog，只做管理和分析，不做执行、CLI 调用、install 或 writable toggle。

**范围**
- 仅做文件系统扫描；普通 catalog 扫描不调用 OpenClaw CLI、不写文件、不得触发 install/网关重启/安全扫描命令。
- 扫描 documented `SKILL.md` directories。
- Global/shared roots 包括 `~/.openclaw/skills`、`~/.agents/skills`、bundled skills 和配置化 extra dirs。
- Project-like scope 只限 confirmed OpenClaw workspace roots：`<workspace>/skills` 和 `<workspace>/.agents/skills`。
- 不推断任意 repo root，不发明 `.openclaw/skills` project root。

**退出条件**
- [x] OpenClaw read-only fixtures 覆盖 documented roots、missing-name fallback、missing description 和 workspace scope。
- [x] OpenClaw 扫描只依赖文件系统，不调用 `openclaw` CLI，且不写入任何 OpenClaw 配置。
- [x] `catalog.scanAll` 能展示 OpenClaw skills，并在 capability matrix 中把 scan 从 disabled candidate 更新为 supported read-only。
- [x] UI 能按 OpenClaw 过滤，并通过统一 detail/source/scope 与 capability matrix 展示 read-only / blocked writable reason；若本机无 OpenClaw roots，显示 missing/empty 状态。
- [x] `pnpm check:macos` 通过；当前 mainline 已在 2026-06-10 完成真实本机 app validation，验证时显式选择当前 `dist/SkillsCopilot.app` bundle。

### 4.17 V2.17 Hermes read-only scanner

**目标**：把 active/profile Hermes home 的 first-class skills 纳入 catalog，只做只读管理和分析。

**范围**
- 扫描 active/profile Hermes home `skills/**/SKILL.md`。
- 不做 generic project scan。
- `skills.external_dirs` 先保留为 future explicit external roots，不自动映射为 project roots。
- 不读取 `.env`、`auth.json`、logs、cron job content。
- 不做 Hermes CLI 调用。
- 不把 cron jobs 映射为 `SkillInstance`。
- 不做 install、toggle、writable。

**退出条件**
- [x] Hermes read-only fixtures 覆盖 nested skills、malformed metadata、ignored secret/log/cron paths。
- [x] `catalog.scanAll` 能展示 Hermes skills，并在 capability matrix 中把 scan 从 disabled candidate 更新为 supported read-only。
- [x] UI 能按 Hermes 过滤，并通过统一 detail/source/scope 与 capability matrix 展示 active home / read-only / blocked writable reason；若本机无 Hermes roots，显示 missing/empty 状态。
- [x] `pnpm check:macos` 通过；当前 mainline 已在 2026-06-10 完成真实本机 app validation，验证时显式选择当前 `dist/SkillsCopilot.app` bundle。

### 4.18 V2.18 Cross-agent skill analysis

**状态（2026-06-10）**：completed service/protocol slice。`catalog.analysis` 和 `app.stateSnapshot.analysis` 已输出只读 cross-agent analysis payload；深度 UI 视图和 dashboard 入口留到 V2.19。

**目标**：让用户看清多个 agent 之间的重复、冲突、shadowing、precedence 和 source overlap。

**范围**
- Cross-agent duplicate name analysis。
- Same path / same content / same canonical name grouping。
- Agent-specific precedence and shadowing explanation where evidence exists。
- Disabled/enabled mismatch grouping。
- Malformed/broken skills grouped by agent/source。
- 不根据未验证 adapter 规则推导 unsupported roots。

**退出条件**
- [x] Service protocol 输出 cross-agent analysis summary 和 per-group detail。
- [x] `app.stateSnapshot` 包含 cross-agent analysis payload。
- [x] Tests 覆盖 duplicate、canonical overlap、source overlap、enabled mismatch、malformed 和 same-agent precedence/shadowing。
- [x] UI 通过 V2.19 health dashboard / Risk / Triage filters 暴露 duplicate/conflict/overlap analysis groups；更深的专用 analysis view 可作为后续增强，不阻塞 V2.18 closeout。
- [x] Detail/assist flow 通过 V2.20 read-only review preview 展示 cross-agent fit；默认详情页常驻 badge/section 可作为后续增强，不阻塞 V2.18 closeout。

### 4.19 V2.19 Skill health dashboard and triage UX

**状态（2026-06-10）**：completed read-only dashboard slice。`app.stateSnapshot.health` 已提供 health summary；macOS sidebar 已增加 health dashboard card、Risk / Triage 快捷过滤。当前详情页和 agent health 的 finding 计数按具体 `instance_id` 归属，agent conflict 只统计同一 agent 内至少两个 instance 参与的冲突；跨 agent 同名/路径重叠/状态不一致保留在 cross-agent analysis，不混入所选 agent 的 skill conflict。Reviewed/ignored 持久化 triage state 不在本切片内，仍作为后续 finding triage persistence 处理。

**目标**：把 app 的入口从长列表升级为“需要关注什么”的管理面板。

**范围**
- Agent/project health cards：total、enabled、disabled、findings、conflicts、malformed、risky scripts/permissions。
- Read-only triage filters：Risk、Needs Triage。
- Findings grouping / reviewed / ignored persistence 仍为后续 finding triage persistence，不写 agent config、不隐藏 unresolved high-risk findings。

**退出条件**
- [x] Sidebar dashboard 能直接进入 Risk / Triage 高价值过滤视图。
- [x] Health summary 不影响 adapter config、不隐藏未审计风险。
- [x] Dashboard 在侧边栏中随布局自适应；更深主面板视图留到后续 UX 切片。
- [x] `pnpm check:macos` 通过；当轮真实本机 Computer Use 因会话锁屏按本轮要求可忽略，当前 mainline 已在 2026-06-10 完成真实 Computer Use 补验。

### 4.20 V2.20 Read-only AI skill analysis assist

**状态（2026-06-10）**：completed offline/read-only preview slice。`llm.prepareAction` 已返回 deterministic `review_preview`，用于展示 skill purpose、risk、finding explanations 和 cross-agent fit；不创建 provider client、不联网、不保存 credentials、不写 skill/config/snapshot/prompt artifacts、不提供 Apply/Write/Execute。

**目标**：在 V2.7 disabled-by-default LLM gate 基础上，增加只读 AI 辅助分析能力，帮助用户理解 skill 作用、风险和修复方向。

**范围**
- 默认关闭，用户显式启用。
- Skill purpose summary、risk summary、finding explanation、cross-agent fit analysis。
- 只生成建议和解释，不自动写入 skill、config、snapshot 或 prompt/response artifacts。
- 不执行 scripts，不触发 imports/install/toggle。
- 不保存 credentials；如未来实现 provider，凭证优先 Keychain，fallback 必须 `0600` 且隐私检查覆盖。
- LLM output 始终 untrusted，只能作为 review aid。

**退出条件**
- [x] Service protocol 明确 prepare/estimate/review result 边界。
- [x] UI 明确显示 disabled/offline/unavailable reason、token/cost estimate 和隐私提示。
- [x] AI review 对单 skill 生成只读 offline preview；catalog/finding group 级别可在后续扩展。
- [x] 无 Apply/Write/Execute 路径，隐私检查和 fixture 测试覆盖。

### Removed from active planning: desktop shell expansion and local sharing

Full-platform UI adaptation, Windows/Linux shell work, local team sharing, signing, notarization, DMG/ZIP, and public distribution are not active roadmap items. The active roadmap remains focused on the macOS app and skills management, inspection, analysis, and configuration audit.

### 4.21 V2.21 扫描准确性、去重与 agent 维度统计（完成）

**目标**

- 统一扫描口径，明确可扫描根、扫描顺序、扫描范围边界，减少重复遍历和不一致计数。
- 明确去重口径：同一物理路径在 `catalog` 侧只保留一条实例；同名 skill 的跨 agent 重复不通过去重压制，而是由 cross-agent 分析入口统一说明。
- 统一 agent 维度统计基准：`catalog.scanAll.result.activity`、`catalog.analysis`、`app.stateSnapshot.health` 使用一致的计数含义与过滤条件，避免 UI 与协议对同一批次出现不同结论。

**范围**

- 对照 `docs/agent-adapters.md`、`docs/pi-adapter-spec.md`、`docs/opencode-adapter-spec.md`，补齐 V2.21 的“扫描准确性、去重、agent 统计”文档口径。
- 明确 fixture 场景中去重与重复来源（path overlap / duplicate name / precedence shadow）对诊断和计数的影响。
- 已完成 scanner 与 catalog 侧实现：根路径 canonicalization 后跳过重复 root，扫描结果按 `agent/scope/path` 去重；Pi 只接受 `<pi-root>/<skill-name>/SKILL.md`，过滤 direct `.md`、root `SKILL.md` 和 nested `references/SKILL.md` 噪声；same-agent 同名不同路径继续保留用于 conflict/analysis。

**退出条件**

- 文档口径更新包含：扫描根确定性、duplicate/path-overlap 的可复现解释、agent 维度统计定义。
- V2.21 口径下的 `catalog.analysis`、`app.stateSnapshot.health`、agent 过滤统计由同一定义驱动，能够交叉解释。
- 下一版本（如 finding triage persistence）可直接复用该口径，不额外定义新的重复规则。

**验证**

- `cargo test -p skills-copilot-scanner` 通过，覆盖 root canonicalization、Pi 噪声过滤、opencode compatibility roots、Hermes/OpenClaw documented roots。
- `cargo test -p skills-copilot-catalog` 通过，覆盖 catalog 输出层 historical noise filter 与 same-agent same-name preservation。
- same-agent 同名不同路径不在 scanner/catalog 静默吞并，继续作为 conflict/analysis 输入。

### 4.22 V2.22 finding/conflict 语义与验收同步（进行中）

**目标**

- 统一 `conflict` 定义：同一 selected/current agent 内的 runtime/name collision（同名、同 agent 的覆盖/竞争关系）。
- 将 cross-agent 重复与重叠（duplicate name、source overlap、enabled mismatch）作为 analysis insight，不纳入 `conflict` 计数语义。
- finding 视图默认按问题组去重展示，保留受影响实例数与受影响条目数，避免实例级重复刷屏。
- 对齐 health 与 detail/list 过滤统计：同一扫描可见实例集下的冲突 / finding / 风险计数定义一致。

**范围**

- 更新 `docs/roadmap.md`、`docs/development-tasks.md`、`docs/service-protocol.md`、`docs/data-model.md`、`docs/agent-adapters.md` 与 AGENTS 的冲突与统计口径定义。
- 明确 `catalog.listConflicts` 只返回 selected/current agent 内的 runtime/name collision，`catalog.analysis` 负责 cross-agent duplicate/source overlap。
- 统一 `catalog.scanAll.result.activity.agent_summaries`、`catalog.analysis`、`app.stateSnapshot.health` 与 finding 过滤统计口径。

**退出条件（不提前宣称完成）**

- V2.22 文档口径同步完成，且定义不再将 cross-agent duplicate/source overlap 错误归入 conflict。
- finding UI 默认聚合展示问题组并保留受影响实例/条目计数字段（或相应 UI 展示项）。
- health 与 detail/list 的冲突、finding、风险过滤能在同一扫描上下文下互相解释。
- 未确认代码验证结果前，不将该版本状态更新为 closed。

**验证项（代码侧待补充）**

- `catalog.listConflicts` 只报告同一 agent runtime/name 冲突；`catalog.analysis` 只报告 cross-agent duplicate/source overlap 类问题。
- `app.stateSnapshot.health` 与 finding/detail/list 过滤采用统一实例计数定义。
- find/list 页面默认显示去重后的 issue group，并显示受影响实例和条目数。

### 4.23 V2.23 Health Dashboard / Adapter Capability UX 口径对齐（进行中）

**目标**

- 统一侧栏健康区行为：仅展示当前 `selected/current agent` 的健康摘要与风险优先级，不展示重复的全量或 cross-agent 统计表。
- 把 Health 卡片定义为可行动摘要：每张卡片都对应可见操作入口（复检、跳转、修复入口）与影响范围说明。
- 使 finding、issue group、conflict 数字与详情一致：`finding_count` 与 issue group 口径一致；`conflict_count` 与当前 agent runtime/name 冲突一致，不混入 cross-agent duplicate/source overlap。
- 让 `adapter.listCapabilities` 与 `service.status.adapter_capabilities` 的 UI 表达明确 `scan / toggle / install / read-only / blocked` 状态，并与 `app.stateSnapshot.health` 与筛选上下文一致。

**范围**

- 在 `service-protocol`、`agent-adapters` 与 `ui-delivery-standards` 中同步能力矩阵可读文本与状态枚举：read-only 与 blocked 必须有独立原因。
- 明确侧栏过滤策略：切换 agent 时仅替换 selected agent 的健康卡片与能力状态；列表总量与分析组口径不在侧栏重复渲染。
- 对 `catalog.scanAll.result.activity`、`catalog.analysis`、`app.stateSnapshot.health`、`catalog.listConflicts`/`catalog.listFindings` 增加同一扫描上下文对齐检查清单；不一致时侧边显示可重扫提醒。

**退出条件（暂不宣称完成）**

- [ ] 健康卡片定义（行动摘要）与冲突/finding 数字与 issue group 口径在 roadmap / service-protocol / adapter docs / ui 标准中一致。
- [ ] sidebar 在 agent 切换时仅呈现当前 selected/current agent 的 health 卡片与 capability 摘要；不以全量 cross-agent 表格替代。
- [ ] capability matrix 显式覆盖 scan / toggle / install / writable / blocked，并保留可解释的 blocker reason。
- [ ] 未有代码验证结果前，该阶段不标记为 done/closed。

## 5. 风险与未决项

| 项 | 风险 | 缓解 |
| --- | --- | --- |
| Codex skills spec 仍在演化 | adapter 频繁 breaking | doc 里维护 spec 版本号；spec 一变先升 catalog schema |
| Pi / Hermes / OpenClaw 的真实写入语义未知 | 适配器猜错 | adapter capability matrix 必须展示 blocker；opencode writable 已在 V2.12 限定为 managed `permission.skill` writes 和 native install targets；Pi production writable、Hermes writable/install、OpenClaw writable/install 未完成 disposable rollback evidence 前继续 blocked |
| Codex evidence 被误读成完整运行时支持 | 用户或 agent 误以为所有 Codex roots / project config / plugin skills 均已支持 | roadmap / AGENTS / adapter docs 明确：当前只实现 verified user/project roots + user-config writable；project config、plugin/admin/system roots 仍待后续决策 |
| 贡献者门槛（Rust） | 社区贡献慢 | doc 写明"轻量贡献（rule / UI）只需 TS / Rust 单语言"；提供 good first issue |
| LLM 成本失控 | 用户被烧钱 | 月度上限 + 单次上限 + 默认 LLM 关闭 |
| UI shell 被重新绑到框架专属 IPC | 破坏跨平台 UI 复用 | 所有产品 UI 只走 service protocol；不重新引入 Tauri IPC |
| SwiftUI 原生壳与 Web 壳能力漂移 | 迁移期两套 UI 行为不一致 | service protocol contract tests + shared fixtures + macOS app runbook；旧 UI 只作为参考，最终删除 |
| Liquid Glass 过度使用 | 可读性、性能、可访问性下降 | 只在功能 surface 使用，主内容保持稳定对比；检查 reduced transparency / reduced motion |
| 未实际启动 app 验证代码改动 | 文档/测试通过但真实 UI 断裂 | 每个代码改动任务完成前必须用 macOS Computer Use 启动 app 并操作相关功能；阻塞时记录原因 |

## 6. 度量指标

每档结束时跑：

- 启动到首屏时长（p50 / p95）
- 内存占用（idle / scan 中 / 写入中）
- catalog 写入 p95 时延
- 10k skills 下的 scan → catalog 耗时与搜索响应
- LLM 调用 p95 时延 + token 估算误差
- 0 day 内 0 高危 CVE（`cargo audit` / `pnpm audit`）
