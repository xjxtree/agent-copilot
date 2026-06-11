# 数据模型

> skills-copilot 内部所有数据围绕 `SkillInstance`（一份具体文件）+ `SkillDefinition`（按名字聚合的逻辑技能）+ `ConflictGroup`（同一 selected/current agent 的 runtime/name 冲突实例）三个核心类型。其它结构都是它们的视图或衍生。

## 1. 核心类型

### 1.1 `AgentId`

```rust
#[derive(Debug, Clone, Copy, Eq, PartialEq, Hash)]
pub enum AgentId {
    ClaudeCode,
    Codex,
    Pi,
    Hermes,
    Openclaw,
    Opencode,
}
```

> 当前 `AgentId` 不直接 `Serialize` / `Deserialize`，也没有 serde rename 属性。跨 crate / UI / catalog 边界通过 `AgentId::as_str()` 和 record DTO 手动映射为 kebab-case 字符串，避免给 `crates/core` 引入 serde 依赖。

> 只增不删。删除老 agent 通过 deprecate + adapter 关闭实现，不从 enum 里移除（避免历史 catalog 失去解读能力）。

### 1.2 `Scope`

```rust
#[non_exhaustive]  // 防止下游 match 时漏掉未来新增的 scope
pub enum Scope {
    ToolGlobal,        // 保留位：当前无 adapter 写入，为未来 import / 跨 agent 共享池预留
    AgentGlobal,       // ~/.xxx/
    AgentProject,      // <project>/.xxx/
}
```

### 1.3 `SkillInstance`

一份"具体文件"的内部表示。**每个 `(agent, scope, path)` 唯一对应一个 `SkillInstance`**。

```rust
pub struct SkillInstance {
    pub id: String,                       // 稳定 id：sha256("{agent}|{scope}|{path}")
    pub agent: AgentId,
    pub scope: Scope,
    pub project_root: Option<PathBuf>,    // 仅 AgentProject 时 Some
    pub path: PathBuf,                    // 绝对路径（canonical，用于 id 和 sweep）
    pub display_path: PathBuf,            // 用户可见路径（symlink 透明，用于 UI 展示）
    pub definition_id: String,            // → SkillDefinition.id

    pub name: String,                     // 来自 frontmatter
    pub display_name: String,             // name 不可用时回退到目录名
    pub description: String,
    pub version: Option<String>,

    pub state: SkillState,                // 见下
    pub enabled: bool,                    // 当前是否启用；Claude Code MVP 由 skillOverrides 推导

    pub frontmatter_raw: String,          // 原始 YAML 字符串
    pub body: String,                     // SKILL.md 正文

    pub scripts: Vec<SkillScript>,        // 该 skill 携带的可执行脚本
    pub permissions: PermissionRequest,   // frontmatter 声明的权限

    pub fingerprint: String,              // sha256(canonical content)
    pub mtime: i64,                       // 毫秒
    pub first_seen: i64,                  // 毫秒
    pub last_seen: i64,                   // 毫秒
}

pub enum SkillState {
    Loaded,       // 已加载
    Disabled,     // 显式禁用
    Shadowed,     // 被同名字高优先级实例覆盖，未实际生效
    Broken,       // 解析失败 / 缺 frontmatter / 缺必填字段
    Missing,      // catalog 里有但磁盘上没了（scan 后会清掉）
}
```

**id 规则**
- 当前代码使用 SHA-256：`id = sha256("{agent}|{scope}|{path}")`，scope 字符串是稳定的内部 key
- path 是绝对路径，归一化（resolve symlinks 后）
- id 一旦生成就**永不复用**：如果原文件被删，instance 进入 `Missing` 状态保留 N 天再清理
- 用户重命名 skill 目录 → 新 id，旧 id 走 `Missing` 流程

V2.27 口径补充：`definition` 维度参与去重解释（非存储主键变更）：

- 用于可解释显示与 cross-agent 对齐的 `skill_group_key` 采用 `(agent, scope, definition_id, path)`。
- 在 V2.28 冲突收口下，`skill_group_key` 的 cross-agent 关系继续作为 analysis 信息承载（如同名/同路径/enabled 不一致），不得直接转化为冲突组实例。
- `definition_id` 为 canonical name hash；定义与实例共享时可稳定解释“为何一份 physical file 在不同 agent 下重复显示”。
- 来自 opencode 的同名扫描条目要在 DTO 中携带 provenance 标签（`native` / `compatibility`）与 source root 说明。
- Pi `.md` 噪声继续排除：目录型 `SKILL.md` 外的直接 `.md`、root `SKILL.md`、`references/SKILL.md` 不进入 `SkillInstance` 列表。

### 1.4 `SkillDefinition`

按 `name` 聚合的逻辑技能。**跨 agent / 跨 scope 的同名 instance 都挂在同一个 `SkillDefinition` 下**。

```rust
pub struct SkillDefinition {
    pub id: String,                       // sha256(canonical_name)
    pub canonical_name: String,           // 来自 frontmatter name
    pub description: String,              // 取最详细的非空描述
    pub instances: Vec<String>,           // → SkillInstance.id
    pub active_instance: Option<String>,  // 当前实际生效的 instance.id
    pub has_multiple_instances: bool,     // > 1 instance（可能只是提示）
    pub has_conflict: bool,               // 存在 ContentDrift / PermissionMismatch / Shadowed 等需处理项
    pub fingerprint_set: Vec<String>,     // 每个 instance 的 fingerprint
}
```

> 当前 SQLite `skill_definition` 表不持久化 `instances` / `fingerprint_set`；它们由 `ai-core` 的 `DefinitionSummary` 在规则运行时计算，用于刷新定义和冲突结果。需要 UI 展示时通过 catalog record/query 组合。

### 1.5 `ConflictGroup`

记录该让用户看到的同一 selected/current agent 的 runtime/name 冲突分组。`NameCollision` 是 info 级提示；当 ≥ 2 个 instance 的 **fingerprint 不同** 时使用 `ContentDrift`，UI 必须提示"内容不一致"。

```rust
pub struct ConflictGroup {
    pub definition_id: String,
    pub reason: ConflictReason,
    pub instances: Vec<String>,           // instance.id 列表
    pub winner_id: Option<String>,        // 按优先级自动选出的胜者
}

pub enum ConflictReason {
    NameCollision,            // 同名，fingerprint 一致（无害，提示性）
    ContentDrift,             // 同名，fingerprint 不一致（必须提示）
    PermissionMismatch,       // 同一 instance 在不同 scope 的 permission 声明不同
    Shadowed,                 // 存在但被高优先级 instance 覆盖
}
```

> 当前 `ai-core` / catalog DTO 使用字符串 reason（如 `content-drift`、`name-collision`）和 `instance_ids` 字段暴露给 UI；`ConflictReason` enum 是核心模型语义说明，后续可以收敛成 typed record。Cross-agent duplicate/source-overlap 与 enabled-state mismatch 通过 `CrossAgentAnalysisRecord` 作为 analysis insights 表达，不作为 `ConflictGroup`。

- V2.28 closeout 补充：`app.stateSnapshot.health.conflict_count` 与 `catalog.listConflicts` 的实例语义必须一致，仅计入 `ConflictGroup`（selected/current agent runtime/name collision）；任何 cross-agent 分析口径（duplicate/source-overlap/enabled-mismatch）不得影响 health 冲突计数。

### 1.6 `PermissionRequest`

```rust
pub struct PermissionRequest {
    pub tools: Vec<String>,               // 允许调用的工具；Claude Code CLI 映射自 allowed-tools
    pub files: Vec<String>,               // 允许读写的路径 glob pattern
    pub network: NetworkAccess,           // None / ReadOnly / Full
    pub exec: bool,                       // 是否允许 fork 子进程
    pub requires_human: bool,             // 是否需要人工确认
}

pub enum NetworkAccess { None, ReadOnly, Full }
```

适配器把各 agent 异构的"权限字段"映射到这套统一形态。**没声明 = `tools/files` 为空、`network=None`、`exec=false`、`requires_human=true`**（最小权限 + 人工确认默认）。

### 1.7 `SkillScript`

```rust
pub struct SkillScript {
    pub name: String,
    pub path: PathBuf,                    // 相对 skill 根
    pub interpreter: Option<String>,      // 来自 shebang 或 frontmatter
    pub description: Option<String>,
    pub fingerprint: String,
}
```

`SkillScript` 是 metadata，不是运行队列。V2.10 的安全边界仍是 **默认不真实执行**：扫描、导入、导出、安装、LLM prepare 和详情读取只能展示脚本信息和规则 findings，不能由该结构触发进程。

### 1.9 V2.29 Finding triage persistence（completed）

- finding issue group 的持久 triage 状态以 app-local catalog/app data 为准，状态值为：
  - `Open`（默认）
  - `Reviewed`
  - `Ignored`
  - `Needs follow-up`
- 只在 app-local 持久层持久化，不写 agent config，不创建 skill-content snapshot 或 skill-toggle snapshot。
- 当 finding fingerprint 或受影响实例签名变化时，已有 triage 状态回退为 `Open`（重新复核）。
- 保持与现有口径一致：V2.22 finding/conflict 分离、V2.28 same-agent conflict 口径不变，cross-agent 仍留在 `Analysis`。不得与脚本执行、AI 回写、provider 调用或凭据持久化耦合。
- V2.30 AI 分析草稿（summary/risk/explanation/remediation）不引入新的持久化实体；该信息仅在协议返回中作为 display payload 存在，不能作为 catalog/app-data 或 triage 的持久字段写入。

### 1.10 `SkillExecutionAuditRecord`

V2.10 将 execution attempt 当成本地审计事实，而不是成功运行结果。当前安全边界只允许记录 non-success attempt status；真实 sandboxed runner 未实现前不得产生 `Completed` 执行记录。

```rust
pub struct SkillExecutionAuditRecord {
    pub id: String,
    pub instance_id: String,
    pub script_name: Option<String>,
    pub requester: ExecutionRequester,        // 当前只允许 User
    pub status: ExecutionAttemptStatus,       // Blocked | Cancelled | Failed
    pub confirmation_required: bool,
    pub confirmed: bool,
    pub command_preview: String,
    pub cwd_preview: PathBuf,
    pub env_preview: Vec<EnvPreviewEntry>,    // secret values redacted
    pub network_preview: NetworkAccess,
    pub files_preview: Vec<String>,
    pub reason: String,
    pub occurred_at: i64,
}

pub enum ExecutionRequester {
    User,
}

pub enum ExecutionAttemptStatus {
    Blocked,
    Cancelled,
    Failed,
}

```

### 1.11 V2.22 finding/conflict 语义对齐（完成口径）

- conflict 的定义收敛为 `ConflictGroup`：同一 selected/current agent 内的 runtime/name 冲突或 shadowing，不跨 agent。
- cross-agent duplicate / source overlap / enabled mismatch 仅作为 analysis group，不进入 `ConflictGroup`；health 冲突计数只消费 same-agent `ConflictGroup`，不消费 cross-agent analysis 计数。
- finding 默认展示采用去重后的问题组（issue key 级别）并保留受影响实例数与受影响条目数，避免同一问题在实例列表重复呈现。
- health 与 detail/list 统计口径共享同一可见实例定义：同一扫描上下文下，`ConflictGroup`（同 agent）计数与 analysis groups（跨 agent）计数可互斥解释。

### 1.12 V2.31 Cleanup Queue（已完成）

- V2.31 的 Cleanup Queue 不新增持久化表或列；它是现有持久化实体与视图的可复合输出。
- queue 项来自已有模型数据：`rule_finding` / triage 持久状态 / `catalog.analysis` / `app.stateSnapshot.health`；不新增独立的 queue state schema。
- queue 的动作状态不写入独立队列实体；任何状态回写仍由现有 V2.29 triage 持久化链路处理。
- 本阶段不得把清理队列设计为新的 data mutation actor；任何写入动作仍需走现有的受控 service method（toggle/save/rollback/scan），并受现有安全边界约束。

### 1.13 V2.32 Rule tuning / suppression（已完成）

- V2.32 的规则调优与抑制是本地 review 元数据，不属于 skill 内容或 agent 配置模型。
- 调优记录应保存在 app-local 持久层（catalog/app data），以实例级/规则级标识可追溯并可回滚。
- 记录需支持审计字段（谁在何时为何进行该变更）与可撤销状态，方便用户恢复原始 finding 行为。
- 该机制不创建快照，不触发脚本执行，不发起 provider 调用，不读写凭据，不改写 skill 文件或 agent config。

审计记录不得保存 secret env value、任意文件内容、LLM prompt/response，或未实现 runner 的 stdout/stderr。LLM 不能成为 `ExecutionRequester`，也不能代替用户确认。

### 1.14 V2.33 Safe batch actions（已完成）

- V2.33 的批量写作业围绕 `SkillInstance`（`instance_id`）与 `agent/root` 维度进行；每次预览应包含：
  - `requested_instance_ids`
  - `writable_targets`
  - `skipped_targets`（含 `skip_reason`）
  - `preview_plan`（预期变更与 snapshot/rollback 条件）
- read-only adapter 与不可写 root（Pi/Hermes/OpenClaw，及 capability 限制实例）必须进入 `skipped_targets`，并保留可解释跳过原因用于 UI 展示。
- 当前阶段不新增数据库 schema；批量预览/计划为执行前计算出的临时结果，不持久化到现有 catalog/app data 结构外。
- 批量写入仍不涉及 skill-content snapshot，不执行脚本，不写凭据/telemetry，不调用 AI provider。

### 1.15 V2.34 Cross-agent comparison view（已完成）

V2.34 对比面是派生视图，仍不引入新持久化实体。它复用 `SkillInstance` / `SkillDefinition` / `Catalog` 与 `CrossAgentAnalysisRecord`，通过只读 `CrossAgentComparisonRecord` service DTO 和 UI 层按以下维度表达：

- `comparison_key`：`canonical_name` 或配置化的相似性归一键（如同名/规范名归一名）
- `participants`：跨 agent 的 `instance_id` 参与集，保留 `agent / scope / path / state / root / provenance`
- `diff_axes`：状态差异、来源差异、risk 标记差异、可写能力差异
- `source`：opencode provenance 区分（`native` / `compatibility`）与其他 adapter 的来源标签
- `decision_context`：用于入口导航（detail/health/analysis）的稳定标识（如 `definition_id`、`finding_group_id`）

边界要求：

- 不新增 `skill_group`、`comparison`、`snapshot` 的 app-local schema。
- 不改变 `SkillInstance`/`ConflictGroup` 的持久主键定义；仅增加只读展示层映射。
- 对比视图只能读不写：任何写动作仍走现有已审计的 `config.toggleSkill` / `snapshot.*` / `skill.install` 服务路径。

## 2. 目录层级与项目根识别

`Scope::AgentProject` 需要知道"项目根"。识别规则（按顺序，命中即用）：

1. 如果请求显式传入 `ProjectContext.root_path`，它必须是 `current_cwd` 的祖先或同一路径，且必须通过 canonical safety check
2. 当前 `ProjectContext.current_cwd` 下是否有 `.git` / `.hg` / `.svn` / `package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod` → 是
3. 否则向上找最近的有这些标记之一的祖先目录
4. 找不到安全 root → 进入 no-project，不扫描 project-local roots，也不把结果退化归属到 `AgentGlobal`
5. Future：用户可在 `skills-copilot.toml` 里显式指定 `project_root`（当前尚未实现）

> **多项目根**：V2.2 仍以"当前有效 `ProjectContext` = 一个安全 root"为操作单位。最近项目列表可以记住多个 root，但一次 scan/toggle 只针对当前有效 root 和 agent-global roots。Monorepo 子项目归属必须保留在 `skill_instance.project_root`，不能在项目切换时重写成其它 root。

## 2.5 `ProjectContext`

`ProjectContext` 是 UI/service 当前项目选择模型，不是 skill，也不是 agent 配置。

```rust
pub struct ProjectContext {
    pub id: String,                      // sha256(canonical root_path)
    pub name: String,                    // root basename 或用户传入的 name
    pub root_path: PathBuf,              // service 校验后的安全项目 root
    pub current_cwd: PathBuf,            // 用户选择或 env 注入的 cwd，必须位于 root_path 内
    pub last_used_at: i64,               // 毫秒
    pub is_active: bool,
    pub validation_error: Option<String>,
}

pub struct ProjectContextState {
    pub active: Option<ProjectContext>,
    pub recent: Vec<ProjectContext>,
}
```

`source` 不在每个 `ProjectContext` 上持久化；service 通过 `service.status.project_context.source` 暴露当前有效来源（`env` / `stored` / `none`）。

**归属规则**

- `SkillInstance.project_root` 只在 `scope = AgentProject` 时写入，值必须等于 scan 时有效 `ProjectContext.root_path` 或 adapter 明确发现的同一 canonical root。
- no-project scan 不写 `AgentProject` 实例，也不把旧项目实例改成 `AgentGlobal`。
- 项目切换只改变当前视图和之后 scan/toggle 的有效上下文；历史 catalog rows 通过自己的 `project_root` 保持归属。
- Toggle 目标必须从所选 `SkillInstance` 的 agent、scope、path 和当前有效 `ProjectContext` 重新校验，不能只相信 UI 传来的 path。

**持久化文件**

当前 V2.2 设计使用 app data 下的 JSON 文件，而不是 SQLite tenant/workspace migration：

`<app-data-dir>/project-context.json`

示例：

```json
{
  "schema_version": 1,
  "active": {
    "id": "6ab18f...",
    "name": "skills-copilot",
    "root_path": "<project-root>",
    "current_cwd": "<project-root>",
    "is_active": true,
    "validation_error": null,
    "last_used_at": 1780876800000
  },
  "recent": [
    {
      "id": "6ab18f...",
      "name": "skills-copilot",
      "root_path": "<project-root>",
      "current_cwd": "<project-root>",
      "is_active": true,
      "validation_error": null,
      "last_used_at": 1780876800000
    }
  ]
}
```

该文件只保存用户通过 UI 选择的项目上下文。`SKILLS_COPILOT_PROJECT_CWD` / `SKILLS_COPILOT_PROJECT_ROOT` 的 env override 可以产生有效 `ProjectContext`，但不能写入 `current` 或 `recent`。

## 3. SQLite Catalog Schema

```sql
-- 实例表
CREATE TABLE skill_instance (
    id              TEXT PRIMARY KEY,
    agent           TEXT NOT NULL,
    scope           TEXT NOT NULL,             -- 'tool-global' | 'agent-global' | 'agent-project'
    project_root    TEXT,
    path            TEXT NOT NULL,             -- canonical path
    display_path    TEXT,                      -- user-facing path; may preserve symlink path
    definition_id   TEXT NOT NULL,
    name            TEXT NOT NULL,
    description     TEXT NOT NULL,
    version         TEXT,
    state           TEXT NOT NULL,             -- 'loaded' | 'disabled' | 'shadowed' | 'broken' | 'missing'
    enabled         INTEGER NOT NULL,
    frontmatter     TEXT NOT NULL,             -- JSON; 当前写入 "{}"，标准化 frontmatter 持久化留到后续
    frontmatter_raw TEXT NOT NULL,
    body            TEXT NOT NULL,
    scripts         TEXT NOT NULL,             -- JSON
    permissions     TEXT NOT NULL,             -- JSON
    fingerprint     TEXT NOT NULL,
    mtime           INTEGER NOT NULL,
    first_seen      INTEGER NOT NULL,
    last_seen       INTEGER NOT NULL,
    UNIQUE (agent, scope, path)
);
CREATE INDEX idx_instance_definition ON skill_instance(definition_id);
CREATE INDEX idx_instance_agent      ON skill_instance(agent, scope);

-- 定义表（按 name 聚合）
CREATE TABLE skill_definition (
    id                TEXT PRIMARY KEY,
    canonical_name    TEXT NOT NULL UNIQUE,
    description       TEXT NOT NULL,
    active_instance   TEXT,
    has_multiple_instances INTEGER NOT NULL,
    has_conflict      INTEGER NOT NULL
);

-- 冲突分组
CREATE TABLE conflict_group (
    id           TEXT PRIMARY KEY,
    definition_id TEXT NOT NULL,
    reason       TEXT NOT NULL,
    winner_id    TEXT,
    FOREIGN KEY (definition_id) REFERENCES skill_definition(id)
);
CREATE TABLE conflict_group_member (
    group_id     TEXT NOT NULL,
    instance_id  TEXT NOT NULL,
    PRIMARY KEY (group_id, instance_id)
);

-- 变更历史（用于"谁在什么时候 toggle 了这个 skill"）
CREATE TABLE skill_event (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    instance_id TEXT NOT NULL,
    kind        TEXT NOT NULL,                -- 'toggle' | 'edit' | 'rescan' | 'broken'
    payload     TEXT NOT NULL,                -- JSON
    occurred_at INTEGER NOT NULL
);
CREATE INDEX idx_event_instance ON skill_event(instance_id, occurred_at);

-- 规则诊断结果
CREATE TABLE rule_finding (
    id            TEXT PRIMARY KEY,
    instance_id   TEXT,
    definition_id TEXT,
    rule_id       TEXT NOT NULL,
    severity      TEXT NOT NULL,              -- 'info' | 'warn' | 'error'
    message       TEXT NOT NULL,
    suggestion    TEXT,
    created_at    INTEGER NOT NULL
);
CREATE INDEX idx_rule_finding_instance   ON rule_finding(instance_id);
CREATE INDEX idx_rule_finding_definition ON rule_finding(definition_id);

-- 备份槽位（用于配置回滚）
CREATE TABLE config_snapshot (
    id          TEXT PRIMARY KEY,             -- uuid
    agent       TEXT NOT NULL,
    scope       TEXT NOT NULL,
    target      TEXT NOT NULL,                -- 配置文件绝对路径
    content     TEXT NOT NULL,
    reason      TEXT NOT NULL,                -- 'pre-toggle' | 'pre-config-edit'
    created_at  INTEGER NOT NULL
);
```

`config_snapshot` 只表示 agent 配置文件历史，不表示单个 `SKILL.md` 内容历史。Enable/Disable 会先保存目标 agent config 的 snapshot，再在 `skill_event` 写一条 `toggle` activity，供 skill 信息页展示最近操作记录。

**当前迁移**
- `0001_initial.sql`：基础 catalog、conflict、event、finding、snapshot 表
- `0002_add_display_path.sql`：为旧库补 `display_path`
- `0003_add_rule_findings.sql`：幂等补丁；旧库若缺 `rule_finding` 则补齐，新库因 `0001` 已包含该表而无变化

> V2.2 Project Context Formalization 计划不新增 SQLite migration。只有当实现证明 `skill_instance.project_root` 与 `<app-data-dir>/project-context.json` 无法保证项目归属、切换和 no-project 行为时，才重新评估 SQLite tenant/workspace migration。

**保留策略**
- `skill_instance` 里 `state='missing'` 的记录保留 30 天再删
- `skill_event` 保留 90 天
- `config_snapshot` 可按 agent config history 列出和回滚；最近 50 份 LRU 淘汰策略不阻塞 MVP，留到后续配置编辑/存储维护阶段

## 4. 标识稳定性

- **id 不复用** —— 同一个 id 自始至终只代表同一份具体文件
- **重命名技能** = 删旧实例 + 加新实例，catalog 里两个 id 都短暂存在
- **fingerprint** = sha256(canonical frontmatter + body)，用于"内容是否变了"。任何写操作前算一次，写后算一次，不一致就拒绝并发写
- **config 路径**也作为 catalog 一部分：用户改 agent 配置路径时按"旧路径标记 missing + 新路径插入"处理。Claude Code MVP 的 toggle 写 `skillOverrides`。

## 5. 与外部世界的边界

- **导入**：当前支持从本地目录导入 skill 到 app-controlled `tool-global` staging，并运行规则审计；GitHub repo import 仍 deferred，不能 clone/network/write
- **导出**：导出 `settings.json` / `config.toml` 不在本模型范围，那是各 agent 配置层的职责；当前 Claude `settings.json` 读写通过 service protocol 的 `config.readClaudeSettings` / `config.saveClaudeSettings` 完成
- **执行**：当前模型不包含成功执行输出、session log 或 sandbox runtime。V2.10 只定义 blocked/cancelled/failure attempt 审计边界；真实执行模型必须先补安全模型、service protocol 和持久化策略
- **迁移**：catalog schema 升级走 `migrations/` 目录，每个 migration 一个 SQL 文件，编号顺序

## V2.35 Local report export (completed)

- Report payload (for local Markdown/JSON export):
  - `report_version`: versioned report schema
  - `generated_at`: timestamp
  - `agent_coverage_status`: per-agent coverage and read/write capability snapshot
  - `health_summary`: health counts, blockers, and conflict/analysis totals
  - `open_findings`: findings plus triage state and fingerprint provenance
  - `cleanup_queue`: queued items and review metadata
  - `cross_agent_comparison`: normalized cross-agent insight rows
- Export redaction policy:
  - Normalize/replace local paths, home paths, app-data roots, project roots, and project cwd with placeholders (`$HOME`, `<project-root>`, `<project-cwd>`, `<app-data-dir>`, `<redacted>`).
- Explicitly excluded from report data model: provider/AI outputs, credentials, signed package metadata, distribution targets, telemetry records, and script execution traces.
- Completed without adding persistent catalog schema; exports are generated from existing read models and written as redacted local artifacts.

## V2.41-V2.70 AI-native task governance models

The AI-native line introduces analysis models incrementally and evidence-first. V2.41 adds app-data provider profile metadata and Keychain credential references, but still has no persisted prompt, raw response, benchmark, trace, review session, policy, or governance-pack schema.

Model families:

- `ProviderProfile`（V2.41 completed）：provider type (`openai-compatible` / `claude-compatible`), base URL, model, headers/API version metadata, enabled state, budget settings, and credential storage reference。
- API keys must not be stored in SQLite. Credential storage is `keychain` in normal production path；fallback persistence（如 `~/.config/skills-copilot/llm.yaml`）只能在显式 opt-in 下允许，并且文档级别仅保留元数据与存储位置摘要，不允许保留 secret 本体。
- `ProviderCallMetadataMinimal`（V2.41-V2.42）：timestamp, provider type, model, destination host, action type, status/error, duration, token/cost, confirmation id, and redaction status. This is required before full observability and must not include API keys, raw prompts, raw responses, credentials, raw trace excerpts, or unredacted local paths.
- `PromptPreview`（V2.42）：ephemeral request preview with included/excluded fields, redaction summary, token/cost estimate, destination, and confirmation id. Raw prompt should not be persisted by default.
- `SkillQualityScore`（V2.43）：derived score from deterministic evidence plus optional AI explanation. Persist only if needed for cache/review; must include source evidence hash and stale invalidation.
- `TaskReadinessAssessment`（V2.44-V2.45）：task text/normalized intent, candidate skills, agent/scope availability, confidence, match reasons, ambiguity, gaps, and risk notes. Raw user task text may be sensitive; persistence requires explicit design and redaction.
- `TaskBenchmark`（V2.46）：user-defined local benchmark cases for repeatable readiness/routing checks。Benchmark definitions persist only in app data as `task-benchmarks.json` (not SQLite and not agent/project config) with `id`、`title`、task text、expected skill refs/names、acceptable agent/scope constraints、success criteria、created/updated metadata。`task.evaluateBenchmarks` uses V2.44/V2.45 local evidence（`metadata`/`findings`/`conflicts`/`analysis`/`adapter diagnostics`/`quality_score`/readiness/routing）for deterministic evaluation and returns expected/acceptable match status, top route, score/band, gap/blocker notes, evidence refs, and no-provider/no-write safety flags.
- `RoutingRegression`（V2.47 completed）：对 V2.46 `TaskBenchmark` 结果与 app-local `task-routing-baseline.json` 的比较记录。Baseline snapshot 包含 `generated_at`、`catalog_available`、`evaluated_count`、benchmark result snapshot、evidence refs 与 safety flags；检测结果包含 `status`、`summary`、`items`、score/confidence delta、expected-match 状态变化、top-route 变化、gap/blocker 增量、missing benchmark / new benchmark 信号、`baseline`、`current_evaluation` 与 no-provider/no-write safety flags。结果默认 app-local，不触发 provider 请求。可选 provider explanation 仍走 V2.42 流程（preview / redaction / confirm / copy-only）。
- `TraceImport`（V2.48 completed）

  用于本地行为轨迹/日志导入与判读的持久化记录，保存在 app-data 的 `trace-imports.json`。

  - `trace-imports.json`: `[{ id, title, source_kind, agent?, task?, expected_skill_refs, expected_skill_names, excerpt, excerpt_char_count, redaction_summary, content_hash, imported_at, analysis, safety_flags }]`
    - `raw_trace_persisted` 默认 `false`（默认不落盘原始 transcript/log 文本）。
    - `excerpt` 仅为可复查的脱敏片段，不包含 unredacted 路径、token、凭据、私有 URL、私有配置片段。
    - `redaction_summary` 记录 redaction status、redacted value count、redacted fields、placeholders，以及 raw trace/prompt/response/secret 持久化关闭状态。
  - `analysis`: `{ generated_by, catalog_available, outcome, reasons, detected_skills, evidence_refs }`
    - `outcome` 是 deterministic read-only 判读（`hit` / `miss` / `wrong_pick` / `ambiguous` / `unknown`）。
    - `detected_skills` 保存判读后的 skill id/name/agent/scope/evidence refs（与 catalog id 一致）。
  - `safety_flags`: 每条导入和评估输出都带有 `provider_request_sent`, `agent_config_mutated`, `skill_files_mutated`, `raw_prompt_persisted`, `raw_response_persisted`, `raw_trace_persisted`, `cloud_sync_performed`, `telemetry_emitted`，默认全 false。
  - 本模型不持久化 raw skill body、raw prompt/response、raw transcript/log，全量判读先基于 deterministic 本地证据。

- `RoutingAccuracy`（V2.49 completed）

  用于 routing 准确性看板的只读派生模型；不持久化新的 dashboard artifact，而是从 app-local benchmark、routing regression baseline/detection、redacted trace imports 和 catalog evidence 动态生成。

  - `routing.accuracyDashboard` response: `{ generated_by, catalog_available, filters, summary, agent_rows, history_rows, gap_issue_rows, recent_evidence_rows, blocker_notes, prompt_request, safety_flags }`。
  - `summary`: `{ trace_count, hit_count, miss_count, wrong_pick_count, ambiguous_count, unknown_count, benchmark_count, benchmark_matched_count, benchmark_gap_count, regression_count, missing_benchmark_count, accuracy_rate, known_outcome_rate, summary }`。
  - `agent_rows`: `[{ agent, trace_count, outcomes, accuracy_rate, benchmark_count, benchmark_matched_count, benchmark_gap_count, regression_count, recent_evidence_count, notes }]`。
  - `history_rows`: `[{ unix_day, trace_count, outcomes, accuracy_rate }]`。
  - `gap_issue_rows` and `recent_evidence_rows` cite local evidence refs from `trace.importLocal`, `task.evaluateBenchmarks`, and `task.detectRoutingRegression` without storing raw trace or raw prompts/responses.
  - 该模型不引入 provider 调用，仍依赖 app-local trace import + benchmark/quality/routing 的本地 evidence；optional provider explanation 仅能走 V2.42 preview/confirmation/copy-only。
- `CrossAgentTaskReadiness`（V2.50 completed）

  用于同一任务跨 Claude/Codex/opencode/Pi/Hermes/OpenClaw 的只读 readiness 比较；默认 read-only、deterministic、本地 evidence-first。该模型是 `task.compareAgentReadiness` 的派生 response，不持久化新的 comparison artifact。

  - `task.compareAgentReadiness` response: `{ generated_by, catalog_available, filters, summary, agent_rows, recommended_agent, gap_issue_rows, evidence_references, prompt_request, safety_flags }`。
  - `summary`: `{ agent_count, candidate_count, ready_agent_count, partial_agent_count, blocked_agent_count, gap_issue_count, recommended_agent, summary }`。
  - `agent_rows`: `[{ rank, agent, display_name, comparison_score, readiness_score, readiness_band, routing_confidence_score, routing_confidence_band, candidate_count, best_candidate, enabled_scope_risk_state, blocker_count, gap_count, reasons, blocker_notes, gap_notes, routing_accuracy_context, benchmark_context, evidence_refs }]`。
  - `best_candidate`: `{ instance_id, definition_id, skill_name, scope, enabled, state, readiness_score, readiness_band, routing_confidence_score, routing_confidence_band, quality_score }`。
  - `enabled_scope_risk_state`: `{ enabled, scope, state, risk_level, risk_summary, writable_status, adapter_status }`。
  - `routing_accuracy_context`: `{ trace_count, accuracy_rate, benchmark_count, benchmark_gap_count, regression_count, recent_evidence_count, notes }`；`benchmark_context`: `{ evaluated_count, matched_count, gap_count, regression_count, notes }`。
  - 数据来源：`TaskReadinessAssessment`, `TaskBenchmark`, `RoutingRegression`, `TraceImport`, `RoutingAccuracy`，以及 existing `SkillQualityScore`。
  - 与现有模型一致：默认不持久化 raw trace/raw prompt/raw response/raw skill body；可选 provider 辅助仍走 V2.42 preview/redaction/confirmation/copy-only。
- `StaleDriftAssessment`（V2.51 completed）

  用于 `analysis.detectStaleDrift` 的只读 stale/drift 派生 response；默认 read-only、deterministic、本地 evidence-first，不持久化新的 stale/drift artifact。

  - `analysis.detectStaleDrift` response: `{ generated_by, catalog_available, filters, summary, stale_drift_rows, readiness_impact_rows, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`。
  - `filters`: `{ agent, candidate_instance_ids, limit, stale_days }`。
  - `summary`: `{ scanned_skill_count, returned_row_count, stale_count, drift_count, high_risk_count, medium_risk_count, low_risk_count, missing_history_count, summary }`。
  - `stale_drift_rows`: `[{ rank, instance_id, definition_id, skill_name, agent, scope, enabled, state, stale_drift_score, stale_drift_band, drift_signals, readiness_impact, reasons, gap_notes, evidence_refs, safety_flags }]`。
  - `drift_signals`: `{ fingerprint_drift, finding_drift, source_drift, modified_age_days, stale_by_mtime, missing_mtime, missing_previous_scan, related_finding_count, related_conflict_count, related_analysis_count }`。
  - `readiness_impact_rows`: `[{ instance_id, skill_name, agent, impact_level, stale_drift_score, notes, evidence_refs }]`。
  - 数据来源：catalog fingerprint / `mtime` / state, `RuleFindingRecord`, same-agent conflicts, cross-agent analysis groups, source/root provenance, adapter diagnostics, and derived readiness impact notes。Previous-scan drift is only asserted when existing local evidence exists（例如 `fingerprint.changed` finding、conflict、analysis group）；missing timestamp/history is surfaced as gap evidence rather than live file I/O。
  - 与现有模型一致：默认不持久化 raw trace/raw prompt/raw response/raw skill body；可选 provider 辅助仍走 V2.42 preview/redaction/confirmation/copy-only，且不得改变 deterministic stale/drift 结果。
- `KnowledgeSearchResult` / `KnowledgeIndex`（V2.52 completed）：local-only, read-only search view over existing catalog evidence and derived tags; it does not persist an index artifact.
  - `knowledge.search` response: `{ generated_by, catalog_available, filters, summary, rows, facets, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`。
  - `rows`: `[{ rank, instance_id, definition_id, skill_name, agent, scope, enabled, state, source, purpose_snippet, description_snippet, matched_fields, match_reasons, keywords, tools, rules, capability_tags, risk_tags, quality_context, readiness_context, stale_drift_context, evidence_refs, safety_flags }]`。
  - `facets`: grouped counts for agents, scopes, states, enabled values, risks, tools, and keywords.
- `SimilarityGroup` / `SimilarityGroupMember`（V2.53 completed）：local-only, read-only grouping view over existing catalog evidence and derived tags; it does not persist a grouping artifact.
  - `knowledge.groupSimilarSkills` response: `{ generated_by, catalog_available, filters, summary, groups, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`。
  - `filters`: `{ agent, limit, min_score, candidate_instance_ids, include_singletons }`。
  - `summary`: `{ indexed_skill_count, candidate_skill_count, matched_group_count, returned_group_count, duplicate_group_count, confusable_group_count, coverage_redundancy_group_count, routing_ambiguity_count, summary }`。
  - `groups`: `[{ group_id, rank, group_type, similarity_score, ambiguity_risk, coverage_redundancy, routing_ambiguity, canonical_name, canonical_key, title, summary, why_grouped, shared_terms, shared_tools, shared_rules, shared_capability_tags, shared_risk_tags, shared_source_signals, members, evidence_refs, safety_flags }]`。
  - `members`: `[{ instance_id, definition_id, skill_name, agent, scope, enabled, state, source, quality_context, readiness_context, stale_drift_context, match_reasons, similarity_reasons, evidence_refs }]`。
  - grouping signals: source/name/tool/rule/capability/risk overlap, quality/readiness/stale-drift context, and same/similar/confusable routing patterns. The output is explanatory and read-only; it distinguishes coverage redundancy from routing ambiguity and does not create new skill or agent state.
- `CapabilityTaxonomy`（V2.54 completed）：derived read-only taxonomy produced by `knowledge.buildCapabilityTaxonomy` from existing catalog evidence, V2.52 tags, V2.53 similar groups, quality/stale-drift context, findings/conflicts/analysis, adapter diagnostics, source provenance, and agent/workspace coverage.
  - `summary`: `{ indexed_skill_count, candidate_skill_count, domain_count, returned_domain_count, total_representative_skill_count, agent_count, workspace_count, duplicate_or_redundant_domain_count, routing_ambiguity_domain_count, gap_count, summary }`。
  - `domains`: `[{ domain_id, rank, domain_key, domain_name, coverage_level, coverage_score, skill_count, enabled_skill_count, disabled_skill_count, agent_count, workspace_count, agents, workspaces, duplicate_or_redundant_count, routing_ambiguity_count, representative_skills, capability_tags, risk_tags, tools, rules, keywords, gap_notes, blocker_notes, evidence_refs, safety_flags }]`。
  - `coverage_rows`: per-domain coverage summaries including gaps, redundancy, routing ambiguity, agent counts, and evidence refs.
  - Safety boundary: no provider request, no taxonomy artifact persistence, no skill/config/snapshot/triage/script/credential mutation, no raw prompt/response/trace persistence, no cloud sync, and no telemetry.
- `WorkspaceReadiness`（V2.55 completed）：derived read-only workspace readiness view over existing catalog / taxonomy / task readiness / routing / cross-agent readiness / stale-drift evidence. The entry point is `workspace.checkReadiness`; local, user-triggered, deterministic, and read-only by default. Response shape: `{ generated_by, catalog_available, filters, summary, readiness_rows, checklist_rows, agent_rows, capability_rows, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`, with row fields for agent/workspace/scope/risk/readiness signals and no persisted readiness artifact.
- `RemediationPlan` / `RemediationPlanItem`（V2.56 completed）：local-only deterministic read-only plan over findings, gaps, routing ambiguity, and drift. Response shape: `{ generated_by, catalog_available, filters, summary, plan_items, priority_rows, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`; plan items are prioritized remediation items with issue type, affected skills/agents, next step, confidence, and writable-path requirement notes. No persisted artifact by default.
- `PreviewDraft` / `PreviewDraftItem`（V2.57 completed）：local-only, user-triggered draft suggestions for frontmatter, description, permissions, dependency, and policy. Response shape: `{ generated_by, catalog_available, filters, summary, draft_items, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`; draft items are copy/edit-ready suggestions with current/proposed text, rationale, confidence, copy label, edit guidance, evidence refs, no apply/write path, no persisted raw prompt/response/trace by default, and any provider wording remains V2.42 gated copy-only.
- `ImpactPreview` / `ImpactPreviewItem`（V2.58 completed）：local-only, user-triggered deterministic impact preview before enable/disable/edit/remediation actions. Response shape: `{ generated_by, catalog_available, filters, summary, impact_rows, task_impact_rows, agent_impact_rows, skill_impact_rows, risk_delta_rows, snapshot_rollback_rows, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`; preview items describe impacted tasks, agents, skills, writable capability matches, filtered/blocked write paths, snapshot/rollback planning, risk deltas, and evidence refs. It does not apply actions, write skill files, mutate agent config, create/rollback snapshots, mutate triage, execute scripts, read credentials, persist raw prompt/response/trace, sync cloud, emit telemetry, or send default provider traffic. Any provider wording remains V2.42 gated copy-only.
- `ReviewSession` / `RemediationHistory`（V2.59-V2.61 future）：local review state, actions considered, decisions, reopened issues, impact notes, and summary. AI suggestions remain untrusted and cannot directly mutate skill files or agent config.
- `PolicyPack` / `PolicyProfile` / `ComplianceReport`（V2.63-V2.66）：local policy schema, import/export metadata, profile bindings, deterministic evidence, and optional AI explanation.
- `ProviderObservabilityView`（V2.69）：derived UI/reporting layer over `ProviderCallMetadataMinimal`, adding call history, cost trends, provider errors, rate limits, availability, cleanup/retention controls, and optional redacted export. Do not persist API keys, raw prompts, raw responses, credentials, or local paths by default.

Cross-cutting constraints:

- Every persisted AI-derived record must include enough deterministic evidence identifiers to know when it is stale.
- AI output is explanation/suggestion data; it must not become an execution requester, config writer, snapshot actor, or hidden policy mutation.
- Local report exports may include AI summaries only after redaction and only when they do not contain credentials, raw prompts, raw responses, or unredacted paths.
