# 技能管理界面 UI 优化方案

> 针对当前 AgentCopilot 跨 agent 技能浏览、详情和技能包管理界面的系统优化方案。
> 覆盖布局结构、视觉层级、信息密度、组件一致性与 macOS 原生体验。

## 0. 当前实现状态

2026-06-26 已按最新版 `AgentCopilot` UI 边界落地第一轮优化：

- 三栏宽度改由 `UIOptimizationPresentation` 统一管理：左栏 220/260/320，中栏 360/400/520。
- 左栏主导航和底部工具入口改为浅色选中态，保留主文字颜色，并以 3pt 品牌色竖线提示选中。
- 项目区域收敛为项目名 + 路径的单组信息，选择项目和更多操作保留在右侧菜单。
- 技能列表过滤器合并为自适应 toolbar：宽屏一行，窄屏自动分两行；搜索框保留 220px 最小宽度；批量入口移入 toolbar 图标按钮。
- 技能列表项压缩到 36-40pt，并为长技能名和路径提供 tooltip。
- 详情页 header 压缩为 48pt 标题区，状态 tag 与更多菜单同排；启用/禁用移入更多菜单，避免蓝色主按钮误导。
- definition、agents、diagnostic metadata 和 Skill Manager preview metadata 改为紧凑 key-value 行；definition、source、CWD、preview token 提供复制按钮。
- Detail tabs 增加 `Metadata`，raw catalog details 从 Overview 移入 Metadata；tab 选中态改为浅灰背景 + 下划线，不再使用饱和蓝底。
- 权限与脚本风险块改为橙色 warning 语义和左侧 warning strip。
- 当前 agent 为空但其他 agent 有技能时，空态会说明是当前 agent/root 无技能，不再误显示为搜索无匹配。

保留边界：

- Skill Manager 写操作仍保持 preview-first / explicit-confirm；没有新增隐藏 apply/write/script/provider 路径。
- 路径复制遵循当前 screenshot/privacy presentation，不新增绕过隐私模式的 raw path 展示。

验证记录：

- `pnpm check:macos` 已覆盖 Rust fmt/test/clippy、Swift test/build、文档治理、协议漂移、版本文档、fixture smoke 和 app-window 截图。
- 真实本机 Computer Use 已针对当前工作区 `dist/AgentCopilot.app` 验证 Codex 技能列表、详情 header、`Metadata` tab、copy affordance、warning 风险块和 Skill Manager preview metadata。
- Skill Manager 验证只执行 preview 操作，未触发 `Remove` / apply / install / update 写入。

2026-06-27 已按 Settings / Task Preflight / Skill Manager 范围落地第二轮优化：

- Settings 保留 toolbar tab，不把已迁出的 Agent Config 放回 Settings；四页改为统一 header、boundary pill 和 compact section 结构。
- AI Provider 设置拆分为 Connection、Limits、Credential Safety、Actions；服务页默认展示版本、协议和方法数健康摘要，路径细节收进 Advanced disclosure。
- Provider Observability 在无数据时使用单一空态卡，避免图表和历史区分散显示空结果。
- Task Preflight 保持 950px 双栏 sheet；左栏按 Agent scope、Task input、Result 排序，agent chip 固定宽度并提供 tooltip，右栏历史说明会回填输入、范围和结果。
- Provider 未配置或不可用时，Task Preflight 在输入区上方显示阻断提示，并禁用生成动作；只读边界说明固定保留在底部。
- Skill Manager 改为固定 Targets 摘要栏和 Search & Install、Installed & Updates、Local Library 三个 segmented workflows；移除/更新按名称操作收进 Installed 的 Advanced 区域。
- Skill Manager 外部 manager 不可用时禁用 search/install/remove/update，并展示修复说明；Local Library 仍按自身能力可用。
- Skill Manager 使用 surface-local error/message，关闭 sheet 会清理 workflow preview；安装名、移除/更新名、本地创建名分离，避免跨 workflow 串扰。
- 新增 Swift 模型、本地化和 store 测试覆盖 presentation 常量、workflow、独立输入状态、surface-local feedback、Provider/Preflight 空态；布局 verifier 增加 Settings、Preflight、Skill Manager 结构约束。

2026-06-27 审查后修复：

- Local Library 中的「预览安装」也会展示 mutation preview，避免预览卡片丢失。
- Skill Manager 写操作成功后统一清空 write previews，避免成功界面仍残留 Apply 按钮。
- 各 preview 动作开始时清空全部 write previews，防止多个过期的 preview 同时堆积。
- Skill Manager preview summary 改用后端返回的结构化 `source` / `skills` 字段，不再依赖命令行 token 顺序解析。
- Settings 服务页「Advanced」badge 图标从默认 `lock.shield` 改为 `gearshape`，语义更贴切。
- 技能列表 filter picker 宽度由固定值改为 `minWidth`，减少本地化截断风险。
- CompactMetadataGrid 改用 enumerated offset 作为 ForEach ID，避免重复 value 导致 SwiftUI 警告。

2026-06-27 设计系统一致性追加优化：

- Task Preflight agent chip 选中态背景从饱和蓝改为 `selectedContentBackground` 浅灰，保留品牌色边框，与全局 sidebar 选中态统一。
- Task Preflight 历史记录选中态从饱和蓝底白字改为浅灰背景 + 左侧 3pt 品牌色强调线，文字恢复主/次色。
- Settings 页各类 banner（验证、成功、错误、保存/测试状态）增加左侧语义色带，强化提示层级并减少卡片堆砌感。
- Task Preflight Provider 未配置阻断提示、Skill Manager 外部 manager 不可用提示同样增加左侧橙色 warning strip，与全局 warning 块统一。
- ErrorBanner / SuccessBanner 统一增加左侧语义色带。

验证记录（修复后）：

- `pnpm check:macos` 全部通过。
- `pnpm check:privacy` 通过。

---

## 1. 整体布局

| 改动 | 现状 | 优化后 |
|---|---|---|
| 三栏最小宽度 | 中间栏被挤压，长名称截断 | 左栏 220px，中栏最小 360px，右栏自适应；分栏支持拖拽 |
| 顶部占用 | 过滤器占 4 行，列表区域被压缩 | 过滤器压缩到 1 行，列表顶部释放约 120px 纵向空间 |
| 右栏留白 | 诊断卡片内部空旷、上下留白不均 | 采用紧凑 key-value 网格，行高 28–32px |

---

## 2. 左侧边栏

### 2.1 选中态

- **改前**：高饱和蓝底白字。
- **改后**：macOS 原生风格，选中项背景使用 `NSColor.selectedContentBackground` 或 `#E6E6E6`，文字保持黑色，左侧加 3px 品牌色强调线。

### 2.2 项目区域

- **改前**：Claude 下拉 +「所选项目」+ 路径 + 眼睛图标，四层堆叠。
- **改后**：
  - 只保留项目名 `funnyaccount_system`，字体 13pt 加粗。
  - 路径 `$HOME/git/funnyaccount_system` 作为副标题（11pt，灰色），hover 时显示完整路径 tooltip。
  - 眼睛图标移除或改为「在 Finder 中打开」的右键菜单项。

### 2.3 数字徽章

- **改前**：启用 200 / 禁用 0 / 问题 291 / 冲突 0 四种颜色并列。
- **改后**：
  - 非零状态才高亮：`启用 200` 蓝色，`问题 291` 橙色。
  - 零状态（禁用 0、冲突 0）改用灰色 badge 或隐藏。

### 2.4 底部入口

- **改前**：「技能包管理」「任务 Preflight」风格不统一。
- **改后**：统一为 navigation item，上方加 8px 分隔线，并归为「工具」分组。

---

## 3. 中间技能列表

### 3.1 过滤器一行化

**改前**：

```
筛选  [全部 ▾]
范围  [全部范围 ▾]
排序  [名称 ▾]
方向  [升序 ▾]
```

**改后**：

```
[筛选 ▾]  [范围 ▾]      [排序 ▾ ▴]          [🔍 搜索技能名称、ID、来源…]    [批量]
```

- 排序和方向合并为一个控件：点击名称切换升序/降序。
- 搜索框右置，宽度 ≥ 220px。

### 3.2 列表项

- 移除左侧分区标题里重复的「筛选」二字。
- 长技能名 hover 显示完整 tooltip。
- 列表项高度从当前约 44px 调整到 **36–40px**，提升单屏信息量。

### 3.3 批量操作

- 「批量」按钮改为工具栏图标按钮（如 `square.and.pencil` 或 checklist icon），hover 显示「批量管理」tooltip。
- 或改为右键菜单入口，更符合 macOS 习惯。

---

## 4. 右侧详情面板（核心改动）

### 4.0 三栏顶部对齐规则

采用「统一 cap height 基线 + 右栏独立 header 区」的结合方案：

- **左栏项目名**：保持 13pt 加粗，作为 sidebar section header，不强行与右侧大标题顶边对齐。
- **中栏标题「Claude Code 技能」**：与右栏 `account-compound` 标题的 **cap height 对齐**，形成视觉节奏。
- **右栏标题区域**：使用固定高度 header（44–48px），内部垂直居中；标题、状态 tag、菜单按钮放在同一行。

```
左栏顶部              中栏顶部                  右栏顶部
┌────────────┐       ┌────────────┐           ┌────────────────────────┐
│ funnyaccount│       │ Claude Code │           │ account-compound  [已启 │
│ _system 13pt│       │ 技能 16pt   │           │ 用 ▼]              [⋯] │
└────────────┘       └────────────┘           └────────────────────────┘
        ↑ 三者 cap height 对齐，下方留白自适应
```

### 4.1 Header 区域

**改前**：

- 大标题 `account-compound`
- 下方大段 hash
- 右上角「已启用」绿标 + 蓝色「禁用」按钮

**改后**：

```
┌────────────────────────────────────────────────────────┐
│ account-compound                      [已启用 ▼]  [⋯]  │  ← 44–48px header，垂直居中
├────────────────────────────────────────────────────────┤
│ 10d4d8e3ff58…def5244be1   [复制]                       │
│ 已安装本技能的 Agents: Claude Code                     │
```

- 状态 tag 和「禁用/更多」操作移到标题右侧同一行。
- hash 改为 **11pt 等宽字 + 复制图标**，作为二级信息。
- 「禁用」按钮改为标题栏右侧的 **⋯ 菜单 → 禁用**。
- 若必须保留独立按钮，禁用按钮改为灰色/红色描边样式，禁用后才显示「启用」蓝色按钮。

### 4.2 Tab 栏

- **改前**：五个 tab 图标不统一，选中态为圆角蓝底。
- **改后**：
  - 统一所有 tab 都带图标。
  - 顺序和命名：
    - 概览（`chart.pie`）
    - 问题项（`exclamationmark.triangle`）
    - 历史（`clock`）
    - 智能分析（`sparkles`）
    - 元数据（`info.circle`）← 原「详情区域」改名
  - 选中态使用下划线或浅灰底，不再用饱和蓝底。

### 4.3 诊断概览

- **改前**：6 个卡片分两行，留白大、对齐不齐。
- **改后**：改为 **两列 key-value 列表**：

```
Agent      Claude Code
范围       项目
Root       Claude Code 原生 root
类型       原生
定义       10d4d8e3…def5244be1  [复制]
来源       $HOME/git/…/SKILL.md  [复制]
```

- 行高 30px，标签列宽 80px，等宽显示。
- 来源路径单行显示，hover tooltip 显示完整路径，右侧加复制按钮。
- 「定义」中的 hash 若与顶部 ID 重复，可考虑隐藏或折叠。

### 4.4 用途概览

- **改前**：「用途概览」标题 + 大段描述各占一行。
- **改后**：
  - 标题与描述合并为一段：`用途：Document a recently solved problem…`
  - 或标题放在左列，描述放在右列，与下方网格对齐。

### 4.5 权限与脚本风险

- **改前**：灰底 + 浅字，像禁用态。
- **改后**：
  - 背景改为白色/透明。
  - 顶部加一条黄色 warning strip 或左侧黄色竖条。
  - 文案改为更明确的行动提示：

    > ⚠️ 权限未声明  
    > 该技能未声明所需权限。运行前请检查 SKILL.md 中的权限说明。

  - 提供操作按钮：「查看来源」「运行前确认」。

---

## 5. 色彩与字体规范

| 元素 | 改前 | 改后 |
|---|---|---|
| 品牌蓝使用 | 按钮、选中态、tag、icon 全蓝 | 仅主按钮/链接使用 |
| 状态色 | 绿标 + 蓝按钮并置 | 启用=绿色，禁用=灰色/红色，问题=橙色，冲突=红色 |
| 选中态 | 饱和蓝底 | 浅灰底 + 左侧强调线 |
| 次要文字 | 灰度不够淡 | 使用 `secondaryLabelColor` / `#6E6E6E` |
| 等宽信息 | 正文字体显示 hash | 11pt 等宽字体（SF Mono） |

---

## 6. 交互细节

| 改动点 | 具体方案 |
|---|---|
| 数字可点击 | 「问题 1」点击后自动切换到「问题项」tab；「启用 200」点击后过滤列表显示已启用技能 |
| 路径可复制 | 来源路径 hover 显示完整路径 tooltip，旁边提供复制按钮 |
| 禁用确认 | 点击禁用弹出确认对话框，或采用 undo toast |
| 空状态 | 列表为空时显示「暂无技能」+ 安装指引；无问题时「问题项」tab 显示空状态插图 |
| 加载态 | 列表和详情切换时显示骨架屏，避免白屏 |

---

## 7. 建议实施顺序

1. **右栏详情面板重构**（视觉收益最大）
2. **过滤器一行化**（释放列表空间）
3. **左栏选中态与 badge 治理**（原生体验提升）
4. **色彩规范落地**（整体质感提升）
5. **交互细节补齐**（tooltip、复制、确认、空状态）
