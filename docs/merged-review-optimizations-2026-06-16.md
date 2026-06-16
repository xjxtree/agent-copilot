# 合并 Review 优化点评估（2026-06-16）

来源：

- `CODE-REVIEW.md`
- `docs/project-review-2026-06-16.md`

Status:

- 两份来源 review 文件已完成合并评估并清理。
- 本文保留为 2026-06-16 review remediation 的唯一评估记录。
- 已完成项和剩余任务同步到 `docs/development-tasks.md`；release-risk 摘要同步到 `CHANGELOG.md`。

评估口径：

- 只收录经代码或项目文档现状验证后，确认有效或作为工程治理方向合理的优化点。
- 不把误判、过期判断、与当前项目边界冲突的建议纳入任务池。
- 本文是后续规划输入，不替代 `docs/development-tasks.md`、`docs/roadmap.md` 或 `CHANGELOG.md`。

## 总体结论

两份报告中有效问题高度集中在四类：

1. **模块边界与体积治理**：Rust/Swift/脚本仍存在超大文件，且当前 module-size gate 覆盖范围不足。
2. **数据与隐私安全**：Catalog 刷新缺少事务保护，LLM draft 持久化红线偏弱，部分审计写入路径缺少 containment 校验。
3. **进程与协议健壮性**：Swift stdio transport 的失败路径、超时、异常保护和测试覆盖仍可加强。
4. **文档与验证治理**：版本验证文档和专用 verifier 已开始膨胀，需要合并规则、保留机器门禁、压缩历史记录。

## 2026-06-16 Closeout

已完成：

- P0 五项均已落地：module-size gate 扩展、catalog refresh 事务、LLM draft output 强 redaction、Swift stdio timeout/error 测试、script audit path containment。
- P1 结构项已推进：service helper/test `include!` 改真实模块，`commands` 拆出 `script_execution.rs`，catalog schema/migration 拆到 `schema.rs`，adapter 共享 helper 拆到 `shared.rs`，Swift `ServiceClient` transport 与 `SkillStore` derived state 拆文件。
- P2 门禁项已推进：新增 `verify:js-syntax`，CI 新增 `cargo audit` job，文档边界写入 `development-tasks` / `CHANGELOG` / runbook。

继续跟踪：

- `crates/commands/src/lib.rs` 仍有 shrinking legacy budget，需继续分域拆到 `< 5k` 行。
- `SkillStore.swift`、`ServiceClient.swift`、catalog query/refresh/mapping、老版本 docs verifier、benchmark 趋势记录、公有 API doc gate 继续作为近期任务管理，不再另开重复 review 文档。

## P0：应优先修复

### 1. Module-size gate 覆盖范围不足

结论：**有效。**

当前 `scripts/verify-module-size.mjs` 主要通过硬编码文件和少量目录做检查，未覆盖多个已经明显超大的关键文件。例如：

- `crates/commands/src/lib.rs` 约 10k 行。
- `crates/catalog/src/lib.rs` 约 2.7k 行。
- `apps/macos/Sources/SkillsCopilot/Stores/SkillStore.swift` 约 3.2k 行。
- `scripts/smoke-macos-app.mjs` 约 1.2k 行。

建议：

- 将 module-size gate 改为目录遍历 + 显式例外清单。
- 覆盖 `crates/*/src/**/*.rs`、`apps/macos/Sources/**/*.swift`、`scripts/**/*.mjs`。
- 对当前遗留大文件设置递减阈值，而不是永久豁免。
- 将 Rust/Swift/脚本三类阈值分开，避免用同一标准套所有文件。

### 2. Catalog refresh 操作缺少事务保护

结论：**有效。**

`crates/catalog/src/lib.rs` 中刷新 finding、definition、conflict 等数据时存在 `DELETE` 后逐条 `INSERT` 的流程。如果中途失败，可能留下部分刷新状态。对本地 catalog 这类派生数据而言，损坏影响可以恢复，但仍会造成错误 UI、错误分析或后续扫描不稳定。

建议：

- 将 `refresh_rule_findings`、`refresh_definitions_and_conflicts` 等删除重建流程包入 SQLite transaction。
- 失败时整体回滚，避免中间态可见。
- 对 refresh 失败增加覆盖测试，验证旧数据不会被半清空。

### 3. LLM draft_output 持久化红线偏弱

结论：**有效。**

`record_llm_prompt_run` 对 `task` / `error_message` 使用 `PromptRedactor::redact`，但 `draft_output` 使用的 redaction 逻辑更弱，主要面向少量 key/token/secret 类字段。它没有复用 roots/path/URL 等更强红线，也缺少高熵 token 识别。

建议：

- `draft_output` 持久化前复用强 redactor，至少覆盖 local path、URL secret、known roots 和常见 credential 形态。
- 增加高熵 token 或长随机片段检测。
- 为 draft output 增加专项测试：本地路径、URL token、API key-like 字符串、中文上下文混合文本。
- 如果无法保证强 redaction，则只保存摘要或 metadata，不保存完整 draft 文本。

### 4. Swift stdio transport 缺少 I/O 超时与失败路径测试

结论：**有效。**

`ServiceProcessRunner` 已支持 cancellation 和 stubborn process 终止，但当前 stdout/stderr 使用 `readDataToEndOfFile()`，stdin 写入和 JSON decode 失败路径仍缺少足够测试。异常、空输出、截断 JSON、非 envelope JSON、stderr-only exit 等情况需要稳定归类。

建议：

- 增加 per-call I/O timeout，区分 process timeout、stdout read timeout、decode failure。
- 包装 stdin write 失败，避免低层异常直接泄露到 UI 层。
- 为 malformed JSON、empty stdout、truncated output、non-envelope JSON、stderr-only failure 增加 Swift 测试。
- 将错误映射到已有 canonical service/client error 文案，保持 UI 可解释。

### 5. `record_blocked_script_execution` 审计路径缺少 containment 校验

结论：**有效。**

`crates/commands/src/lib.rs` 中该函数会创建并追加写入传入的 audit path，但未看到与其他写路径一致的 containment 校验。虽然该函数用于 blocked script audit，不执行脚本，但写文件路径仍应被限制在可信 app/workspace 数据目录内。

建议：

- 对 audit path 使用现有 containment helper 或新增明确的 app-data-only 校验。
- 禁止绝对任意路径写入。
- 增加路径穿越、symlink 或外部目录写入的拒绝测试。

## P1：重要结构性优化

### 1. 用真实模块替代 service helper `include!`

结论：**有效。**

`crates/service/src/lib.rs` 和 `crates/service/src/tests.rs` 使用多个 `include!` 拼接 helper/test 文件。虽然能降低单个文件行数，但语义上仍是同一模块，无法形成清晰边界，也会削弱可见性控制、ownership 和编译期结构反馈。

建议：

- 按 RPC 域拆真实模块：`catalog`、`config`、`task`、`knowledge`、`remediation`、`llm`、`support`。
- 让 dispatcher 保持薄层，只做 envelope、routing 和错误映射。
- 测试文件也按域拆为真实 `mod`，避免继续扩大 `include!`。

### 2. `crates/commands/src/lib.rs` 需要分域拆分

结论：**有效。**

该文件已经超过 10k 行，承担 adapter、scan、write guard、script audit、export、migration 等多类职责。它是当前最明显的 Rust god file。

建议：

- 优先拆出 `adapter_scan`、`write_guard`、`audit`、`export`、`config_paths`、`migration` 等模块。
- 保持 public API 兼容，先搬迁实现再调整接口。
- 为拆分后的模块设置 module-size gate，避免重新堆回单文件。

### 3. `SkillStore.swift` 需要从 god-object 拆为域 store

结论：**有效。**

`SkillStore.swift` 同时承担 catalog、task cockpit、knowledge、provider、remediation、validation、history 等状态和动作，`@Published` 与 async 方法数量都偏高。

建议：

- 按现有 UI/模型边界拆分：`CatalogStore`、`TaskCockpitStore`、`KnowledgeStore`、`RemediationStore`、`ProviderStore`、`ValidationStore`。
- 保留轻量 facade 给 SwiftUI 注入，避免一次性重写调用面。
- 每次拆分保持 behavior 不变，并用现有 Swift tests 锁定状态流。

### 4. `ServiceClient.swift` 需要按 RPC category 拆分

结论：**合理。**

文件体积约 2.5k 行，仍可维护，但随着 service protocol 增长，单文件会继续扩大。

建议：

- 拆出 request builder、response envelope、process runner、domain client extension。
- 按 service 方法域组织调用，不改变协议 payload。
- 保留统一 decode/error mapping 层，避免每个 domain 重复处理错误。

### 5. `crates/catalog/src/lib.rs` 需要拆分 schema/query/mutation/migration

结论：**合理。**

文件尚未达到最危险规模，但 migration、schema、query、refresh mutation、model mapping 混在单文件中，已经影响局部修改的风险判断。

建议：

- 拆为 `schema`、`migrations`、`queries`、`refresh`、`mapping`。
- migration 不再依赖 `"duplicate column"` 字符串判断，优先用 schema inspection。
- 对 corrupt JSON fallback 分类处理：可恢复字段保留 warning，关键字段失败应返回明确错误或 degraded status。

### 6. Adapter helper 重复

结论：**有效。**

多个 adapter 模块重复实现 frontmatter 拆分、stable path id、required/optional string、skill name validation 等逻辑。

建议：

- 提取共享 parser/name validation helper。
- 保留 agent-specific 差异在 adapter 层，公共 YAML/frontmatter/字段校验集中测试。
- 防止不同 adapter 对同类坏输入产生不一致诊断。

### 7. DetailView 和相关 Swift view 可继续按 section 拆分

结论：**合理。**

V2.83 已拆出部分 overview helper，但 Detail surface 仍可继续按 Task Cockpit、Skill Map、Guided Cleanup、Provider Observability、Review 等 section 拆 view 文件。

建议：

- 先拆纯 presentation view，不移动 service/store 逻辑。
- 抽取共享 evidence/privacy/collapsible row 组件，减少 UI 复制。
- 每次拆分跑 `swift test` 与 native UI layout verifier。

### 8. 大型脚本需要模块化

结论：**合理。**

`scripts/smoke-macos-app.mjs` 和 `scripts/verify-native-ui-layout.mjs` 已经承载过多职责。继续堆叠会让验证逻辑本身变成维护风险。

建议：

- 将 capture、bundle resolution、AX/window targeting、fixture smoke、artifact verification 拆为 helper modules。
- 保持 CLI entrypoint 不变。
- 给 helper 增加小型 unit-style 测试或 fixture input/output 测试。

### 9. CI 应增加 Rust dependency/security gate

结论：**合理。**

项目已有 `audit:rust` 脚本，但 CI 当前未强制执行 `cargo audit`。对于本地安全工具类产品，依赖安全检查应进入常规门禁。

建议：

- 在 CI 增加 `cargo audit`，可先设为独立 job。
- 增加 `cargo machete` 或等价 unused dependency 检查；初期可以作为报告型 gate，清理后再设为强制。
- 对 Node 依赖保持轻量 review，不需要引入过重流程。

### 10. CI bundle-only smoke 不能替代真实 GUI 证据

结论：**有效，但需按当前边界处理。**

CI 中 `pnpm smoke:macos-app -- --bundle-only` 只能证明 bundle/package 层健康，不能证明真实窗口、AX、截图、Computer Use 路径全部可用。项目已有文档说明 real-local evidence 和 canonical blocker，这一点不应被误读为 CI 已完全覆盖 GUI。

建议：

- 保持 CI bundle-only 作为基础门禁。
- 在 release candidate 或指定维护版本上使用 self-hosted macOS/unlocked session 执行真实 GUI smoke。
- 文档明确区分 CI smoke、fixture smoke、real-local Computer Use evidence 的证明力。

## P2：治理与可维护性优化

### 1. 合并 per-version checklist 与 verifier

结论：**有效。**

`docs/` 下存在大量 v2 verification checklist，`scripts/` 下也存在多份 `verify-v2-*-validation-docs.mjs`。这类文件在版本密集推进时有价值，但长期保留会制造重复信息和维护负担。

建议：

- 将已关闭版本的验证事实沉淀到 `docs/verification-history.md` 或同类历史文档。
- 将仍有机器价值的规则合并进通用 verifier。
- 删除或归档只剩文字检查价值的 per-version verifier。
- 新版本只新增必要任务文档，避免一版一份长期脚本。

### 2. Refactor-only 工作不应继续制造完整版本仪式

结论：**合理。**

模块拆分、文件搬迁、测试整理这类维护工作如果都以完整 feature version 记录，会扩大 roadmap、changelog、checklist、verifier 的写作和维护成本。

建议：

- 用户可见能力进入 roadmap/changelog。
- 内部维护任务进入 `docs/development-tasks.md`。
- Refactor-only closeout 只记录变更摘要、验证命令、安全边界，不再新增大段版本叙事。

### 3. CHANGELOG、roadmap、development-tasks 边界应继续收紧

结论：**合理。**

当前项目已经开始区分人类文档与 agent 文档，但版本信息仍容易在多个文件重复出现。

建议：

- `CHANGELOG.md`：只记录已完成、用户或开发者需要知道的变更，保持倒序。
- `docs/roadmap.md`：记录方向、里程碑和未完成规划，不承载已完成版本流水账。
- `docs/development-tasks.md`：记录当前和近期可执行任务，按状态维护。
- `AGENTS.md` / `CLAUDE.md`：只保留 agent 需要的边界、命令、当前状态和禁止事项，避免复制完整历史。

### 4. Public crate API 文档可补强

结论：**合理。**

Rust crate 中公开 API 的 doc comment 覆盖偏低。当前项目主要是 app/internal crates，因此不是高危问题，但对长期维护和 agent 上下文读取有帮助。

建议：

- 对 public structs/enums/functions 增加简短 doc comment。
- 在 CI 或本地 gate 中增加 `cargo doc --no-deps`，先作为健康检查。
- 不追求文档覆盖率数字，优先补协议、catalog、adapter、command write guard 等稳定边界。

### 5. Benchmark 与性能治理需要从“脚本存在”升级为“趋势记录”

结论：**部分有效。**

报告中“没有自动 benchmark”的说法不完全正确，项目已有 benchmark 相关脚本。但目前更合理的问题是缺少趋势记录和阈值治理。

建议：

- 保留现有 benchmark scripts。
- 为关键场景记录基准输出：large catalog scan、task readiness、routing、knowledge search、macOS list model。
- 对 clone/string 优化先做 profile，不把全局 `clone()` 数量当成直接问题。

### 6. JS verifier/smoke 脚本可增加 lint 或类型约束

结论：**合理。**

验证脚本数量和体积增长后，纯运行时发现错误的成本会上升。

建议：

- 增加轻量 ESLint 或 `node --check` 覆盖所有 `.mjs`。
- 对通用 helper 使用 JSDoc typedef，避免引入过重 TypeScript 迁移。
- 优先保护 validation blocker、privacy、gate parity、native UI verifier 等高价值脚本。

### 7. Dependency review 应周期化

结论：**合理。**

项目依赖量不大，但作为本地工具和 agent-facing 应用，依赖新增、未使用依赖和安全公告需要可见。

建议：

- CI 加 `cargo audit`。
- 周期性跑 unused dependency 检查。
- 对新增依赖要求在 PR/任务说明中解释用途和替代方案。

## 未纳入任务池的点

以下报告观点经核对后不作为有效优化点收录：

- **“CI 未跑 gate parity”**：不准确。CI 已运行 `pnpm verify:gate-parity`。
- **“Swift 测试几乎没有 test 方法”**：不准确。项目使用自定义 runner 风格，不以 XCTest `func test*` 数量衡量。
- **“Tauri/ui/src 引用都应清理”**：大多是历史边界或禁止重建说明，不应机械删除。只需避免 current-state 文档继续引用过时架构。
- **“没有统一 ServiceError”**：不准确。service crate 已有 `ServiceError`，可继续改善错误分类，但不是从零缺失。
- **“必须改 async/tokio service”**：不纳入。当前短生命周期 stdio 模型是明确边界，除非后续 roadmap 改为 daemon/socket 架构。
- **“增加 release workflow / signed release / DMG / notarization”**：与当前项目边界冲突。AGENTS 明确不引入 public distribution、signing、notarization、DMG/ZIP。
- **“统一 config 格式”**：不作为当前优化。项目需要读取多 agent 既有配置，不能为了统一格式破坏兼容性。
- **“全局 clone/String 数量就是性能问题”**：证据不足。应以 profile 和 benchmark 趋势确认热点。
- **“CHANGELOG 过长应截断”**：不直接采纳。更合理做法是保持倒序、减少未来重复记录；历史是否归档需单独决策。
- **“大量测试 unwrap/panic 必须清理”**：作为低优先级测试卫生即可，不作为当前主要工程风险。
