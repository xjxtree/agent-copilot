# AgentCopilot 全局 UI 统一优化方案

> 基于当前 9 张主界面截图，从「方便用户理解」「提升使用效率」「保持界面整洁美观」三个目标出发，制定本方案。
> 本方案只涉及 `apps/macos/Sources/SkillsCopilot` 内的 SwiftUI 表现层，**不影响后端服务、数据模型、持久化格式或服务协议**。
>
> **状态**：技能/会话/配置侧边栏、详情页、Settings、Task Preflight、Skill Manager 相关优化已落地，具体实现与验证记录见 `docs/ui-optimization-skills-manager.md`。

---

## 1. 全局现状诊断

### 1.1 已做得好的地方

- **技能列表页** 已经做了较大幅度的压缩：单列过滤器、紧凑列表行、详情 Header 单行化、Tab 使用图标 + 文字、选中态改为浅灰 + 左侧强调线。
- **Settings 各页** 统一了「标题 + 说明 + 边界 pill」的 header card 结构。
- **Provider Observability 空态** 已经收敛成单卡片，比分散的空结果更干净。

### 1.2 当前主要问题

| 问题 | 表现 | 影响 |
|---|---|---|
| 选中态不统一 | 技能列表用浅灰选中，会话列表仍用饱和蓝底 | 用户在不同页面切换时产生割裂感 |
| 过滤器/工具栏风格不一致 | 技能用 dropdown 一行化，会话用分段控件 + 大刷新按钮，配置又是另一套表单 | 学习成本高，视觉上嘈杂 |
| 灰色卡片滥用 | 详情页、配置页、Settings 大量堆叠灰底卡片，嵌套卡片造成「俄罗斯套娃」感 | 界面显脏，重点不突出 |
| 状态/徽章语义混乱 | 已启用绿标 + 禁用蓝按钮、会话 chip 全蓝框、配置「支持」pill 混在一起 | 用户难以判断状态与操作 |
| 操作按钮主次不分 | 「显示并编辑」配置用主蓝色、Skill Manager 建议项按钮分散 | 容易误触高风险操作 |
| 复制/操作图标常驻 | 每个消息、hash 旁边都常驻复制图标 | 列表显碎，干扰阅读 |
| 空态信息分散 | Task Preflight 历史空态仅一行文字 | 用户不知道下一步该做什么 |
| 路径/隐私展示不统一 | 有的路径可点击眼睛展开，有的直接展示，有的带复制按钮 | 截图安全和交互预期不一致 |

---

## 2. 全局设计目标

1. **一套视觉语言**：所有列表、表单、卡片、徽章、空态、按钮统一组件与语义。
2. **信息层级清晰**：标题 / 元数据 / 操作三层分离，不滥用背景色区分内容。
3. **密度适中**：在 macOS 桌面端保留足够信息量的同时，通过间距和字体层级透气。
4. **操作安全**：配置编辑、Provider 设置、Skill Manager 写入类操作使用 secondary/danger 样式，避免主蓝误导。
5. **后端零影响**：只改 SwiftUI View、Presentation 常量、本地化文案、颜色/字体常量；不改 Rust 服务、数据模型、协议。

---

## 3. 分模块优化方案

### 3.1 左侧边栏（Sidebar）

现状：技能/会话/配置三项样式基本一致，但选中态已在技能页改为浅灰，会话/配置列表仍用蓝色填充；项目区仍常驻眼睛图标。

优化：

- **统一选中态**：所有一级导航项统一使用浅灰背景 + 3pt 品牌色左侧强调线，文字保持主色，不再使用饱和蓝底。
- **数字徽章语义**：
  - 非零：启用 = 蓝色，问题/警告 = 橙色，冲突/禁用 = 红色/灰色
  - 零值：使用低对比灰色或隐藏
- **项目路径交互**：眼睛图标移除，改为 hover 显示完整路径 tooltip；右键菜单提供「在 Finder 中打开」。
- **底部工具入口**：「技能包管理」「任务 Preflight」加 8pt 分隔线，归到「工具」分组，文字大小与主导航一致。

### 3.2 列表页工具栏（Skills / Sessions / Config）

现状：技能已是一行化 dropdown toolbar；会话仍用分段控件 + 独立刷新按钮；配置页范围筛选用 dropdown，但与搜索/操作区没有对齐。

优化：

- **统一 toolbar 模式**：所有列表顶部使用「左侧筛选/排序 + 中间/右侧搜索 + 最右批量/操作」的一行布局。
- **范围选择控件**：
  - 二值范围（项目/全局）用 macOS 原生 `Picker(.segmented)`
  - 多值范围（全部 / Claude / Codex …）用 dropdown
- **排序控件**：名称、时间等排序把「升序/降序」合并为点击标题切换，减少一个控件。
- **搜索框**：统一最小宽度 220px，placeholder 明确。
- **刷新按钮**：不再使用大段文字按钮，统一为 toolbar 图标按钮 `arrow.clockwise`，hover 显示 tooltip。

### 3.3 技能详情页（Detail）

现状：Header 已单行化，但仍有绿色成功横幅占满顶部；「范围」「问题」等大图标卡片占用过多空间；「诊断概览」嵌套在深灰卡片里；复制按钮常驻。

优化：

- **全局反馈横幅**：绿/橙提示改为顶部 inline toast / snackbar，自动消失或提供关闭按钮，不占主内容区。
- **Header 区**：
  - 标题、状态 tag、更多菜单（⋯）保持同一行
  - hash / ID 使用 11pt SF Mono，右侧仅 hover 时显示复制按钮
  - 状态 tag 使用语义色：已启用 = 绿，禁用 = 灰/红
- **元数据区**：将「范围 / 问题 / Agents / Root / 类型 / 定义 / 来源」统一改为**两列 key-value 行**，标签列宽固定 82pt，行高 28–32pt，值列 hover 显示完整 tooltip。
- **诊断/用途概览**：
  - 用途描述不再单独放标题卡片，直接作为正文或左侧标签 + 右侧描述
  - 风险/权限块使用左侧黄色 warning strip + 白底
- **Tab 栏**：保持图标 + 文字，选中态使用下划线或浅灰底。原「详情区域」统一改名「元数据」。

### 3.4 会话页（Sessions）

现状：列表选中态为蓝色填充；顶部范围分段控件和刷新按钮堆叠；详情消息列表复制图标常驻，消息类型 chip 全蓝框；消息列表层级不明显。

优化：

- **列表选中态**：统一改为浅灰 + 左侧强调线。
- **工具栏**：改为与技能页一致的「范围 dropdown + 排序 + 搜索 + 刷新图标」一行布局。
- **会话列表项**：行高压缩到 40–44pt；标题 + 时间 + 路径摘要一行，hover 显示完整路径 tooltip。
- **详情区**：
  - 顶部统计 chip 使用语义色：用户 = 蓝色，Agent = 紫色/靛蓝，工具 = 橙色，技能 = 绿色
  - 消息列表按角色分组，使用小头像/图标区分 User / Agent / Tool
  - 复制按钮默认隐藏，hover 时显示
  - 长消息支持展开/折叠

### 3.5 配置页（Config）

现状：中间配置列表行高较大；详情 Header 的「支持」pill 和操作按钮布局松散；JSON 代码块无高亮；「显示并编辑」按钮使用主蓝色，容易误触；「重新加载」「保存」按钮与内容关系不明确。

优化：

- **配置列表项**：行高压缩，文件图标 + 文件名 + 路径摘要 + 状态 pill 同行；路径使用 PrivacyPathView。
- **详情 Header**：左侧 Agent 图标 + Agent 名称 + 配置文件路径；右侧只保留「当前生效 / 未生效」状态 pill，「支持」链接改为二级文字或移入菜单。
- **JSON 展示**：
  - 默认只读，使用等宽字体 + 基础语法高亮（key/string/number/bool）
  - 「显示并编辑」改为 secondary 或带警告图标的 danger 按钮，点击后进入编辑态并弹窗确认
  - 敏感值默认 `[REDACTED]`，编辑态仍用 password-style 输入
- **操作区**：将「重新加载」「保存」移到 Header 同一行右侧；保存按钮在编辑态才可用。

### 3.6 Skill Manager 弹窗

现状：Targets 区域 checkbox 过多；「流程」标签和 workflow 选择层级不够清晰；搜索字段布局略显随意；建议项是 plain text。

优化：

- **Targets 摘要栏**：顶部固定为一行：左侧「目标」+ 已选 agent 名称/图标 + All/None 切换；点击展开后显示完整 checkbox 网格。
- **Workflow 选择器**：去掉「流程」标签，使用 macOS 原生 `Picker(.segmented)` 或 toolbar 分段控件。
- **搜索区**：搜索框占主要宽度，作者/来源用较窄 secondary 输入框；Search 按钮右置，未输入时禁用。
- **建议项**：以 tag pill 形式展示，hover 显示完整信息，点击填入搜索框。
- **错误/反馈**：使用 surface-local banner，关闭弹窗后自动清理。

### 3.7 Task Preflight 弹窗

现状：Agent scope chips 截断显示且缺少图标；Provider 未配置提示只是一行橙色文字；历史区空态仅一行文字。

优化：

- **Agent scope chips**：固定宽度但显示 agent 图标 + 截断名，tooltip 显示完整名和技能数；选中态使用浅灰背景 + 品牌色边框。
- **Provider 未配置提示**：改为顶部 warning card，带「去设置」链接，并明确禁用「生成 Preflight」按钮。
- **任务输入区**：placeholder 更具体；输入框高度随内容自适应，最少 3 行。
- **历史区**：空态使用统一 empty-state 组件；有历史后按时间倒序，hover 显示摘要。

### 3.8 Settings 窗口

现状：已经统一 header card，整体较好；AI Provider 表单标签较长，字段堆叠略显单调。

优化：

- **AI Provider 表单**：
  - 使用两列 label + input，长说明放在字段下方作为 caption
  - API key 输入框使用 secure field
  - 「测试连接」「保存」主次分明
- **Provider Observability**：保持现有单卡片空态；数据看板数字卡片统一使用图标 + 标签 + 数值，数值使用等宽字体。
- **语言 / 服务页**：保持现有结构，toggle 开关增加说明 caption；服务页 summary cards 与 Provider Observability 统一卡片样式。

---

## 4. 全局视觉规范（Design Token）

| 元素 | 规范 |
|---|---|
| 品牌蓝 | 仅用于主按钮、主链接、当前激活的 icon tint |
| 成功绿 | 已启用、成功提示 |
| 警告橙 | 问题、风险、只读提示 |
| 危险红 | 禁用、删除、高风险确认 |
| 中性灰 | 零值、未选中、次要说明 |
| 选中背景 | `NSColor.selectedContentBackground` 或 `#E6E6E6`，文字保持主色 |
| 强调线 | 3pt 品牌色竖线，用于 sidebar 选中 |
| 字体 | 正文 13pt，标题 15–16pt，元数据/hash 11pt SF Mono |
| 间距 | 8pt 基准：section 间距 16–20pt，卡片内边距 12–16pt |
| 圆角 | 卡片/按钮统一 7–8pt，输入框 5–6pt |
| 阴影 | 尽量不使用；需要层级时可用 1pt 浅灰边框 |
| 路径显示 | 统一走 `PrivacyPathView`：隐私模式占位 + hover tooltip + 可选复制 |

---

## 5. 建议新增/复用的统一组件

为减少重复实现，建议沉淀以下组件（可放入 `Views/DetailPresentationPrimitives.swift` 或新建 `DesignSystem/` 目录）：

1. `SidebarRowStyle` — 统一 sidebar 选中态、徽章、强调线。
2. `FilterToolbar` — 左侧 dropdown/segmented + 右侧搜索 + 操作图标。
3. `DetailHeaderCard` — 标题 + 状态 pill + 菜单按钮，固定 44–48pt 高度。
4. `CompactMetadataGrid` — 两列 key-value 行，支持复制、tooltip。
5. `StatusPill` — 统一成功/警告/危险/中性 badge。
6. `EmptyStateView` — 图标 + 标题 + 说明 + 可选操作。
7. `WarningStrip` — 左侧色带 warning/info block。
8. `PrivacyPathRow` — 路径显示 + 复制 + 隐私模式。
9. `MessageRow` — 会话消息统一组件，支持角色图标、时间、hover 操作。

---

## 6. 实施顺序

按「视觉收益大 → 影响面小 → 向后端依赖少」排序：

1. **Phase 1：基础 Design Token 与组件** — 统一颜色、字体、间距；实现通用组件。
2. **Phase 2：Sidebar 与列表选中态** — 统一所有列表的选中态、徽章、路径展示。
3. **Phase 3：工具栏统一** — 技能/会话/配置列表顶部 toolbar 统一。
4. **Phase 4：详情页降噪** — 技能详情、会话详情、配置详情统一 Header + 元数据网格。
5. **Phase 5：Sheet 优化** — Skill Manager、Task Preflight 统一 header、workflow 选择器、空态。
6. **Phase 6：Settings 细化** — AI Provider 表单、语言/服务页细节。
7. **Phase 7：交互完善** — tooltip、复制 hover、禁用确认、空态引导、加载骨架屏。

---

## 7. 验证方式

- 修改后运行 `pnpm check:macos`。
- 针对每个改动页面做真实本机 Computer Use 验证，确保：
  - 不触发后端写入（Skill Manager 只做 preview）
  - 配置编辑、Provider 设置等敏感操作有显式确认
  - 截图只捕获 app 窗口
- 新增/更新 Swift UI 测试覆盖相关 presentation 常量与空态逻辑。
- 运行 `pnpm check:privacy` 后再提交。

---

## 8. 底线约束

- **不改 Rust 服务层**：所有数据获取、过滤、排序逻辑仍由现有 `SkillStore` / service protocol 提供。
- **不改数据模型**：不新增持久化字段、不改 JSON schema、不改 agent 配置格式。
- **不改协议**：`docs/service-protocol.md`、fixtures、协议漂移校验无需调整。
- **不新增隐藏写入路径**：配置编辑、Provider 保存、Skill Manager 安装/移除仍需显式确认。
- **不重建 Tauri/React UI**：所有改动只在 `apps/macos/Sources/SkillsCopilot` 内。
