# AI 层：本地事实层 + AI-native 判断层

> 原则：**本地 deterministic 逻辑负责事实，用户显式配置的大模型负责复杂判断**。
>
> Scanner / rules / catalog 始终是事实来源；LLM/AI provider 是 AI agent skills 的核心分析增强，用于质量、任务可用性、routing 置信度、trace 分析、remediation 和治理总结。
>
> 当前实现边界（V2.55 baseline；V2.56 Remediation Planner 已实现）：
>
> - 已落地 disabled-by-default 的 service/UI gate 和 request prepare/estimate 能力。
> - 已落地用户显式配置的 OpenAI-compatible / Claude-compatible provider profile 基础：`llm.listProviderProfiles`、`llm.saveProviderProfile`、`llm.deleteProviderProfile`、`llm.testProviderConnection`、macOS Keychain-first API key storage、预算字段、disabled/unconfigured state，以及 test connection 的最小 redacted call metadata。
> - 用户主动触发 Analyze / Recommend / conflict explanation / draft frontmatter 前，可以展示 provider、model、token/cost 估算和不可用原因。
> - Analyze / Recommend / conflict explanation / draft frontmatter / skill analysis 可先生成 redacted prompt preview；只有用户显式确认后才可通过 `llm.confirmPromptAndSend` 发起 provider 请求并返回 copy-only draft output。
> - V2.43 已落地 `analysis.scoreSkillQuality`：基于 metadata、findings、conflicts、analysis、adapter diagnostics 生成 user-triggered/read-only deterministic local quality score；optional provider explanation 只走 V2.42 preview/redaction/confirmation。
> - V2.44 已落地 `task.checkReadiness`：用户输入真实任务后，基于 metadata、findings、conflicts、analysis、adapter diagnostics 与 V2.43 quality score 生成 read-only readiness score、候选 skill、gap/blocker、evidence references 与 safety flags；本地 readiness 不发起 provider 请求。
>
> V2.45（已完成）：
>
> - V2.45 在 V2.42-V2.44 基础上把 `task.checkReadiness` 输出升级为 `task.rankSkillRoutes` routing ranking：主候选 + 备选顺序、`confidence`、`match_reasons`、`ambiguity/collision warnings`、`likely wrong-pick`、`likely_miss`。
> - 当前已完成本地 deterministic ranking 与 native Analysis UI 集成；默认仅 read-only，不写 skill、不改 agent config、不执行脚本、不改 triage、不直接发送 provider 请求。
> - 每次真实 provider 调用前必须展示 prompt preview、redaction summary、token/cost estimate 和 network destination。
> - AI 输出默认 read-only，不直接写 skill、不改 agent config、不执行脚本、不改变 triage 或 policy 状态。
>
> V2.46（已完成）：
>
> - 本地 benchmark（任务集合）已落地：用户自定义 benchmark case（任务文本、预期 skill refs/names、可接受 agent / scope、成功标准）并本地持久化在 app-local `task-benchmarks.json`；执行过程 deterministic，基于 V2.44/V2.45 本地证据进行 expected/acceptable route match 评估。
> - 已实现 `task.listBenchmarks` / `task.saveBenchmark` / `task.deleteBenchmark` / `task.evaluateBenchmarks`；`task.evaluateBenchmarks` 默认不发起 provider 请求，不改 triage，不改 config，不改 snapshot，不执行脚本。
> - 可选 provider 辅助解释仅通过现有 V2.42 `llm.previewPrompt` + `llm.confirmPromptAndSend` 提供 copy-only 的展示草案，不参与主排序/回归判定。

> V2.47（已完成）：
>
> - 在 V2.46 基准集基础上做 routing regression；基线与回归结果保留在 app-local 数据，不读 credentials、不发 provider scoring 请求、不改 triage，不改 config，不改 snapshot，不执行脚本。
> - 已实现 `task.saveRoutingBaseline`（保存基线）与 `task.detectRoutingRegression`（回归对比）；baseline 保存为 app-local `task-routing-baseline.json`，检测输出 score/confidence delta、match-status 变化、top-route 变化、gap/blocker 增量、missing benchmark 与 safety flags。
> - 可选 provider 解释仍走 V2.42 `llm.previewPrompt` + `llm.confirmPromptAndSend`，仅 copy-only，不影响回归判定。

> V2.48（已完成）：
>
> - `trace.importLocal`：用户粘贴 transcript/log raw text 后，服务端先做本地脱敏与 redaction summary，再持久化至 app-data `trace-imports.json` 的 trace import metadata、redacted excerpt 与 deterministic analysis（不落 raw trace）。
> - 返回是 deterministic local 判读：`analysis.outcome`（hit/miss/wrong_pick/ambiguous/unknown）、detected skills、reasons 与 evidence refs。
> - `trace.listImports`：查询历史导入的 app-local redacted metadata。
> - `trace.deleteImport`：删除本地 trace import 元数据；仍为 read-only 工作流边界，不改 triage、不写配置、不改 snapshot、不执行脚本。
> - 可选 provider 说明仍走 V2.42 preview/redaction/confirmation，纯 copy-only，不参与 deterministic 结果。

> V2.49（已完成）：
>
> - `routing.accuracyDashboard`：从 V2.46 benchmark、V2.47 routing regression evidence 与 V2.48 redacted trace imports 派生 summary、agent rows、history rows、gap/issue rows、recent evidence rows、prompt request metadata 与 safety flags。
> - Dashboard 生成是 user-triggered/read-only，本地指标不写 dashboard artifact、不落 raw trace、不发 provider 请求、不改 triage/config/snapshot/skill 文件、不读 credentials、不执行脚本。
> - 可选 provider 说明仍走 V2.42 preview/redaction/confirmation，copy-only，不改变 deterministic dashboard 结果。

> V2.50（已完成）：
>
> - `task.compareAgentReadiness`：同一任务横向比较 Claude/Codex/opencode/Pi/Hermes/OpenClaw 的本地候选可见性、readiness/routing score、quality 传播信号、enabled/scope/risk state、benchmark/regression/accuracy context、gap/blocker 与 evidence refs。
> - Cross-agent readiness 是 user-triggered/read-only，本地比较不写 comparison artifact、不发 provider 请求、不改 triage/config/snapshot/skill 文件、不读 credentials、不执行脚本。
> - 可选 provider 说明仍走 V2.42 preview/redaction/confirmation，copy-only，不改变 deterministic 推荐 agent 或 per-agent 排序。

> V2.51（已完成）：
>
> - `analysis.detectStaleDrift`：以 read-only、deterministic、本地 evidence-first 的方式检查 stale skills、fingerprint drift、scan/finding/source drift 与 readiness impact。
> - 已实现 service protocol 与 native Analysis UI：输出 summary、stale/drift rows、readiness impact rows、gap/blocker notes、evidence refs、prompt request metadata 与 safety flags。
> - 默认不写 skill / agent config / snapshot / triage，不执行脚本，不持久化 raw prompt/response/trace，也不默认发 provider 请求；可选 provider 说明仍必须走 V2.42 preview/redaction/confirmation 且保持 copy-only。

> V2.52（已完成）：
>
> - `knowledge.search` 是本地 only、read-only、user-triggered 的 search surface，围绕 existing catalog evidence 与 derived tags 做检索；search scope 聚焦 purpose、tools、keywords、rules、source、agent、risk、task fit、capability tags，并带入 quality/readiness/stale-drift context。
> - 已实现 service protocol 与 native Analysis UI：输出 summary、rows、facets、gap/blocker notes、evidence refs、prompt request metadata 与 safety flags。
> - 不默认 provider / network；不写 skill 文件、agent config、snapshot、triage 或 index artifact。未来若存在 provider 说明，仍必须走 V2.42 preview/redaction/confirmation 并保持 copy-only，不影响 deterministic search 结果。

> V2.53（已完成）：
>
> - `knowledge.groupSimilarSkills` 是本地 only、read-only、user-triggered 的 grouping surface；它只围绕 existing catalog evidence、V2.52 derived tags、source/name/tool/rule/capability/risk overlaps 与 quality/readiness/stale-drift context 做 grouping，不引入默认 provider/network。
> - 已实现 service protocol 与 native Analysis UI：把 similar / confusable skills 区分为 coverage redundancy 与 routing ambiguity 两类解释，并输出 summary、groups、members、gap/blocker notes、evidence refs、prompt request metadata 与 safety flags。
> - 该版本仍不写 skill 文件、agent config、group artifact、snapshot、triage 或 raw trace；如果未来存在 provider 说明，仍必须走 V2.42 preview/redaction/confirmation 并保持 copy-only，不影响 deterministic grouping 结果。

> V2.54（已完成）：
>
> - `knowledge.buildCapabilityTaxonomy` 是本地 only、read-only、user-triggered 的 capability taxonomy surface；它只围绕 existing catalog evidence、V2.52 derived tags、V2.53 similar groups、agent/workspace/source/tool/rule/risk/capability signals、quality 与 stale-drift context 构建 capability-domain 视图。
> - 已实现 service protocol 与 native Analysis UI：输出 summary、domains、coverage rows、representative skills、gap/blocker notes、evidence refs、prompt request metadata 与 safety flags，并显式区分 coverage redundancy 与 routing ambiguity。
> - 该版本仍不写 skill 文件、agent config、taxonomy artifact、snapshot、triage 或 raw trace；不默认 provider / network；可选 provider 说明仍必须走 V2.42 preview/redaction/confirmation 且保持 copy-only，不影响 deterministic taxonomy 结果。

> V2.55（已完成）：
>
> - `workspace.checkReadiness` 是 workspace readiness 的入口，围绕 current workspace 的 catalog、V2.54 taxonomy、task readiness/routing、cross-agent readiness、stale/drift、findings/conflicts/analysis、adapter diagnostics 与 source provenance 做 local-only、user-triggered、deterministic、read-only by default 的评估。
> - 已实现 service protocol 与 native Analysis UI：输出 summary、checklist/readiness rows、agent rows、capability rows、gap/blocker notes、evidence refs、prompt request metadata 与 safety flags。
> - 该版本仍不发 provider 请求、不写 skill/config/snapshot/triage/readiness artifact、不执行脚本、不读 credentials、不持久化 raw prompt/response/trace，也不做 cloud sync 或 telemetry；任何可选 provider 说明仍受 V2.42 preview/redaction/confirmation 约束并保持 copy-only，且不能改变 deterministic readiness 结果。

> V2.56（已实现）：
>
> - `remediation.plan` 是 remediation planner 的只读入口，围绕 findings、cleanup queue、stale/drift、similar grouping、capability taxonomy、workspace readiness、optional task readiness/routing、conflicts、analysis、adapter diagnostics 与 source provenance，把本地 evidence 转成 prioritized remediation plan items。
> - 已实现 Rust service/protocol：输出 summary、plan_items、priority_rows、gap/blocker notes、evidence refs、prompt request metadata 与 safety flags；native UI、draft/impact/history surfaces 仍是后续工作。
> - 该方法不发 provider 请求、不写 skill/config/snapshot/triage/remediation artifact、不执行脚本、不读 credentials、不持久化 raw prompt/response/trace，也不做 cloud sync 或 telemetry；optional provider explanation 仍必须走 V2.42 preview/redaction/confirmation 且保持 copy-only，不能改变 deterministic plan。

## 1. 双层分工

| 能力 | 由谁负责 | 何时触发 |
| --- | --- | --- |
| 路径/格式/frontmatter 校验 | 规则 | 每次 scan / save |
| 权限声明合规（缺字段、越权） | 规则 | scan 后台 + 用户 toggle 前 |
| 冲突检测 / 优先级计算 | 规则 | 实时 |
| 备份 / 回滚 | 规则 | 任何写操作前 |
| skill 描述语义分析（"这个 skill 到底是干嘛的"） | LLM / AI provider | 用户主动点 Analyze |
| 任务可用性判断（"这个任务哪个 agent/skill 能做"） | LLM + 本地证据 | 用户输入任务并确认分析 |
| routing 置信度和错选/漏选解释 | LLM + 本地证据 | 用户主动运行 task readiness / benchmark |
| trace/log 中实际选 skill 的准确性判断 | LLM + 本地证据 | 用户导入 trace 并确认分析；LLM 说明仅作 optional provider 辅助，主判读为 deterministic local 结果 |
| 修复建议 / review session / governance report | LLM + 本地证据 | 用户主动生成 |
| 改写 frontmatter / 生成草稿 | LLM | 用户主动进入编辑模式；草稿仍不可直接 apply |

> **关键约束**：LLM **永远不直接执行** toggle、edit、delete 等写操作。所有"看起来 LLM 在做"的动作，最终都是"LLM 给提案 → 用户在 UI shell 确认 → Rust service / 规则引擎执行"。
>
> V2.7 的 draft frontmatter 更严格：当前只允许作为草稿展示或复制，不提供 Apply / Write。真实写入仍必须由用户进入已有的正常编辑/保存路径，并经 Rust service 的校验、snapshot 和原子写流程。

## 1.1 Provider 标准（V2.41+）

V2.41 起优先支持两类接口标准，而不是绑定单一厂商：

| Provider type | 必填配置 | 说明 |
| --- | --- | --- |
| OpenAI-compatible | `base_url`、`api_key`、`model` | 兼容 OpenAI、企业代理、LiteLLM、vLLM、Ollama/OpenAI-compatible gateway 等。 |
| Claude-compatible | `base_url`、`api_key`、`model`、API version/header | 兼容 Anthropic Claude 和 Claude-compatible gateway。 |

Provider 配置原则：

- endpoint/API key/model 由用户自己配置。
- key 不写 SQLite、project directory、logs、prompt artifacts、response artifacts、report exports 或 screenshots。
- provider call 只在用户发起具体动作后发生；V2.41 支持显式 Test Connection，V2.42 起分析请求必须经过 prompt preview/redaction confirmation。
- provider request/response 默认不持久化；V2.42 confirmed send 只保存最小 redacted call metadata（status、duration、error、token/cost、redaction status、confirmation id、destination host），用于审计每次真实请求；V2.69 再在此基础上做完整 observability UI、统计、清理和导出策略。
- provider 不得成为写入者、执行者或确认者。

## 1.2 V2.41-V2.70 AI-native 能力线

| Version | AI role | 本地事实来源 |
| --- | --- | --- |
| V2.41-V2.42（实现） | Provider config、prompt preview/redaction/confirmed send 与最小审计 metadata | service status、settings、Keychain/fallback permission checks、confirmation id、redaction status |
| V2.43（实现） | Deterministic skill quality score plus optional preview-confirmed provider explanation | metadata、findings、conflicts、analysis、adapter diagnostics |
| V2.44（实现） | Deterministic task readiness plus optional preview-confirmed provider explanation | task text、metadata、findings、conflicts、analysis、adapter diagnostics、quality score |
| V2.45（实现） | Routing confidence（ranking + risk + ambiguity） | task text、readiness candidates、metadata、findings、conflicts、analysis、adapter diagnostics、quality score |
| V2.46（实现） | Task benchmark set | app-local `task-benchmarks.json`、expected/acceptable route match、local evidence-first + optional AI 说明 |
| V2.47（实现） | Routing regression detection | 基于 V2.46 benchmark 结果的 app-local baseline 对比（`task.saveRoutingBaseline` + `task.detectRoutingRegression`）；local evidence-first + optional AI 说明 |
| V2.48（实现） | Agent behavior trace import（`trace.importLocal`/`trace.listImports`/`trace.deleteImport`） | trace 文本先 redacted 后存元数据与可复查摘要；deterministic local 判读 hit/miss/wrong-pick/ambiguity；不落 raw trace；可选 provider 说明走 V2.42 |
| V2.49（实现） | Routing accuracy dashboard（`routing.accuracyDashboard`） | V2.46 benchmark results + V2.47 regression evidence + V2.48 redacted trace imports；local evidence-first + optional AI 说明 |
| V2.50（实现） | cross-agent task readiness（`task.compareAgentReadiness`） | 同一任务横向比较 Claude/Codex/opencode/Pi/Hermes/OpenClaw 的 skill 可见性、质量、路由置信度与 gap；输入来自 `task.checkReadiness` / `task.rankSkillRoutes` / benchmark / regression / trace import / accuracy evidence；read-only，本地 evidence-first，provider 仅在 V2.42 preview-confirmed copy-only |
| V2.51（实现） | stale/drift detection（`analysis.detectStaleDrift`） | fingerprints、mtime、finding/conflict/analysis drift、source/root provenance、readiness impact、local evidence-first、optional V2.42 copy-only provider explanation |
| V2.52（实现） | knowledge index / `knowledge.search` | existing catalog evidence、derived tags、quality/readiness/stale-drift context、local-only read-only search |
| V2.53（实现） | similar grouping / `knowledge.groupSimilarSkills` | existing catalog evidence、V2.52 tags、source/name/tool/rule/capability/risk overlaps、quality/readiness/stale-drift context、local-only deterministic grouping |
| V2.54（实现） | capability taxonomy / `knowledge.buildCapabilityTaxonomy` | existing catalog evidence、V2.52 tags、V2.53 similar groups、quality/stale-drift context、agent/workspace coverage、local-only deterministic taxonomy |
| V2.55（实现） | workspace readiness（`workspace.checkReadiness`） | catalog、taxonomy、task readiness/routing、cross-agent readiness、stale/drift、adapter diagnostics、findings/conflicts/analysis；local-only deterministic readiness |
| V2.56（实现） | remediation planner（`remediation.plan`） | findings、cleanup queue、stale/drift、similar groups、taxonomy、workspace readiness、task readiness/routing、adapter diagnostics；local-only deterministic read-only plan |
| V2.57（实现） | preview drafts（`remediation.previewDrafts`） | user-triggered local-only deterministic copy/edit-ready drafts for frontmatter、description、permissions、dependency、policy；no direct apply/write path；provider wording still follows V2.42 preview/redaction/confirmation |
| V2.58（实现） | impact preview / `remediation.previewImpact` | User-triggered, local-only, deterministic impact preview before enable/disable/edit/remediation actions; previews impacted tasks、agents、skills、risk deltas、snapshot/rollback plan、writable capability/filtering/blockers、evidence refs; no apply/write/snapshot mutation/triage/script/credential/cloud/telemetry/default-provider side effects; any provider wording stays V2.42 gated copy-only |
| V2.59-V2.60（future） | batch review、history | future work; remains constrained by findings、triage、policy、snapshots and the writable capability matrix |
| V2.61-V2.70 | review session、governance report、policy packs、skill map、full provider observability、safe write planning | local reports, policy profiles, V2.41-V2.42 call metadata, evidence gates |

V2.57 的 preview drafts 只生成可复制/可编辑的草稿建议，不提供直接 apply/write；任何 provider wording 都必须经过 V2.42 的 prompt preview / redaction / confirmation，并继续作为 copy-only 输出。

## 2. 规则引擎

### 2.1 Rule trait

```rust
pub trait Rule: Send + Sync {
    fn id(&self) -> &'static str;            // "no-empty-tools" 等稳定 id
    fn applies_to(&self, inst: &SkillInstance) -> bool;
    fn check(&self, inst: &SkillInstance, ctx: &RuleContext) -> Vec<Finding>;
}

pub struct Finding {
    pub rule_id: String,
    pub severity: Severity,                   // Info / Warn / Error
    pub message: String,                      // 用户可见，可本地化
    pub suggestion: Option<String>,           // 修复建议（同样可本地化）
}

pub enum Severity { Info, Warn, Error }
```

### 2.2 内置规则清单（MVP）

| rule id | 含义 |
| --- | --- |
| `frontmatter.required-fields` | 必填 `name` / `description` 缺失 → Error |
| `path.outside-workspace` | 路径在项目外但 scope 标为 project → Error |
| `name.collision` | 跨 agent/scope 同名 → Info，自动归入冲突分组 |
| `fingerprint.changed` | 重扫发现 fingerprint 变化 → Info |

当前实现：

- `frontmatter.required-fields`、`path.outside-workspace`、`fingerprint.changed` 是 `Rule` trait 实现。
- `name.collision` 由 `append_name_collision_results()` 在同一次 MVP 规则入口中聚合同名实例、刷新 definition / conflict，并产出 info finding。
- 每条 MVP 规则都有单元测试或命令层集成测试。
- 规则结果写入 `rule_finding`，同名实例同步刷新 `skill_definition` / `conflict_group`。

后续候选规则（V1/V2）：`frontmatter.tools-not-empty`、`permissions.network-declared`、`permissions.exec-needs-human`、`name.canonical-case`、`script.no-shebang`、`body.too-long`、`body.too-short`、`dependency.unknown`。

### 2.3 RuleContext

规则运行所需的最小上下文：

```rust
pub struct RuleContext {
    pub previous_fingerprints: HashMap<String, String>,
}
```

规则 **不允许** 通过 ctx 触发任何写操作。任何"自动修"都通过 `Finding::suggestion` 字段，UI 拿到后转成按钮，用户点才执行。更丰富的上下文字段（用户偏好、definition 快照等）留到 V1。

### 2.4 MVP 入口：`evaluate_mvp_rules()`

MVP 不用动态 rule registry。`crates/ai-core` 导出一个入口函数：

```rust
pub fn evaluate_mvp_rules(
    instances: &[SkillInstance],
    ctx: &RuleContext,
) -> RuleReport
```

`RuleReport` 包含本次运行产出的所有 `Finding` 和 `ConflictGroup`，由 commands 层写入 catalog 的 `rule_finding` / `skill_definition` / `conflict_group` 表。

4 条 MVP 规则各自有单元测试：`required_fields_reports_missing_description`、`name_collision_creates_conflict_and_findings`、`path_outside_workspace_flags_project_skill`、`fingerprint_changed_compares_previous_scan`。

## 3. LLM 层

### 3.0 V2.7 当前边界

V2.7 不把 LLM provider 接入产品运行时。当前阶段的 LLM 本地辅助分析只包含：

- 默认关闭的 Settings / service 状态门禁。
- 用户主动触发 Analyze / Recommend / conflict explanation / draft frontmatter 前的 prepare/estimate。
- UI 明示 provider、model、预估 input/output token、预估 cost、budget 状态和 disabled/unconfigured 原因。
- 失败时只显示本地错误状态；不会静默重试、不会切换 provider、不会联网。

当前阶段明确不做：

- 不创建 Anthropic / OpenAI / DashScope / Ollama client。
- 不发起任何 LLM provider 网络请求。
- 不读取、保存或迁移 API key。
- 不把 LLM request/response、prompt、token 或凭据写入 SQLite、项目目录或 logs。
- 不提供草稿 Apply / Write 按钮。

下面的 provider trait、凭据和 prompt 章节是目标架构与安全约束；只有在后续实现 provider/network/credential storage 时才可标记为完成能力。

### 3.1 Provider trait

```rust
#[async_trait]
pub trait LlmProvider: Send + Sync {
    fn id(&self) -> &'static str;            // 'anthropic' | 'openai' | 'dashscope' | 'ollama' | …
    fn display_name(&self) -> &'static str;
    async fn complete(&self, req: LlmRequest) -> Result<LlmResponse, LlmError>;
}

pub struct LlmRequest {
    pub system: String,                       // 来自 skills-copilot 的固定 system prompt
    pub user: String,                         // 经过"内容过滤"的输入
    pub model: Option<String>,                // 用户可指定
    pub max_tokens: u32,
    pub temperature: f32,
    pub attachments: Vec<Attachment>,         // 允许附带：frontmatter / body / 单个 script
}
```

### 3.2 provider 目标实现（未来）

- `anthropic` —— 目标默认 `claude-sonnet-4`；用户可改其它 Claude 模型
- `openai` —— 目标默认 `gpt-5`
- `dashscope`（阿里云百炼）—— 目标默认 `qwen-plus`
- `ollama` —— 目标默认 `llama3.1`；用户可改本地模型（完全离线）

新增 provider 是加一个文件 + 注册，不需要改 trait。

V2.7 当前代码不应声称上述 provider 已接入；只允许把它们作为用户选择偏好和估算展示的候选值，且在未实现 provider client 时保持 disabled/unconfigured。

### 3.3 凭据

V2.7 当前阶段**不保存 credentials**，也不读取真实 API key。后续实现凭据存储时必须满足：

- 凭据**只**存在本机。
- macOS 优先使用 Keychain；Linux / Windows 后续分别使用 libsecret / Windows Credential Manager。
- 退路配置文件只允许 `~/.config/skills-copilot/llm.yaml`，创建和每次读取前都必须检查权限为 `0600`；权限不符时拒绝使用并提示用户修复。
- **不得**上传、不得缓存到 SQLite、不得写入项目目录、不得写入 logs。
- 设置页可清除全部凭据；清除操作必须只触达 OS keyring 或上述 fallback 文件。

### 3.4 Prompt 边界

LLM 看到的输入有严格过滤：

| 输入 | 是否进 prompt |
| --- | --- |
| 用户当前选中的 skill 的 `name` / `description` / `body` | ✅ |
| 该 skill 的 `frontmatter`（标准化后） | ✅ |
| 单个 `script` 文件（用户主动 attach） | ✅（带长度上限，默认 8KB） |
| 其它 skills 的内容 | ❌（除非用户显式 attach） |
| 用户文件系统任意路径 | ❌（LLM 没有 FS 访问） |
| 任何凭据 / token | ❌（强制脱敏） |

LLM 输出端：
- 限定为 JSON（`{ summary, recommendations, draft_frontmatter? }`）
- 解析失败时降级为"显示原文 + 标红提示"
- 不允许 LLM 输出"执行命令"类指令；如果它写了，只在 UI 里展示，不进 IPC
- `draft_frontmatter` 只是草稿展示/复制内容，不存在 Apply / Write；真实写入必须走用户主动编辑和 Rust service 保存路径

### 3.5 Token 预算

UI 默认不主动调用 LLM（避免无意识烧钱）。V2.7 当前只做本地 token/cost prepare/estimate；后续真实 LLM 调用也必须走"用户主动触发 + 显示 provider/model/token/cost 预估 + 确认"流程。设置页里可设：
- 单次上限（默认 4K output）
- 月度上限（默认 $5，纯客户端累计估算）
- 关闭 LLM（默认就是关闭）

## 4. 离线优先行为

- 启动时**不**尝试连接任何 LLM
- "扫描 / 校验 / 启停"全在本地 Rust 内核完成
- "Analyze" 按钮在 LLM 关闭时变灰并显示原因；native macOS UI 应从同一 service state 获取 provider 状态
- LLM 调用失败时降级为"显示错误"——**不**静默重试、不切换到默认 provider
- V2.7 prepare/estimate 不得尝试探测 provider 可达性或验证 API key

## 5. 可观测性

- 规则运行结果直接展示在 skill 行的"诊断"折叠区
- 未来真实 LLM 调用：仅记录非敏感元数据 (provider, model, token_in, token_out, duration, success)，可导出 JSON
- V2.7 当前 prepare/estimate 不记录 prompt、response、API key 或 credential path；不得把 token/cost 估算写入 SQLite、项目目录或 logs
- 数据收集 / 隐私约束集中定义在 [security-model.md §5](./security-model.md#5-隐私--数据收集)
