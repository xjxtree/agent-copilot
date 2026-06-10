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

### 1.8 `SkillExecutionAuditRecord`

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

### 1.9 V2.22 finding/conflict 语义对齐（完成口径）

- conflict 的定义收敛为 `ConflictGroup`：同一 selected/current agent 内的 runtime/name 冲突或 shadowing，不跨 agent。
- cross-agent duplicate / source overlap / enabled mismatch 仅作为 analysis group，不进入 `ConflictGroup`。
- finding 默认展示采用去重后的问题组（issue key 级别）并保留受影响实例数与受影响条目数，避免同一问题在实例列表重复呈现。
- health 与 detail/list 统计口径共享同一可见实例定义：同一扫描上下文下，`ConflictGroup`（同 agent）计数与 analysis groups（跨 agent）计数可互斥解释。
```

审计记录不得保存 secret env value、任意文件内容、LLM prompt/response，或未实现 runner 的 stdout/stderr。LLM 不能成为 `ExecutionRequester`，也不能代替用户确认。

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
