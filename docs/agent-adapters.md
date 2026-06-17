# Agent Adapters

> skills-copilot 支持的 6 个 agent 的适配要点。
>
> 当前版本线：V2.11 Adapter Capability Matrix、V2.12 opencode writable、V2.13 Pi read-only scanner/parser、V2.14 Hermes evidence-gate closeout、V2.15 OpenClaw evidence-gate closeout、V2.16 OpenClaw read-only scanner、V2.17 Hermes read-only scanner、V2.18 cross-agent analysis、V2.19 skill health dashboard、V2.20 read-only AI skill analysis assist、V2.21 扫描准确性/去重/agent 维度统计、V2.22 finding/conflict 语义、V2.23 Health Dashboard / Adapter Capability UX、V2.24 Detail 诊断口径、V2.25 Agent-config timeline、V2.26 Finding explainability、V2.27 Skill identity/provenance dedupe、V2.28 Conflict semantic closeout 均已完成。V2.29 Finding triage persistence、V2.30 read-only AI analysis workflow、V2.31 Cleanup Queue、V2.32 Rule tuning / suppression、V2.33 Safe batch actions、V2.34 Cross-agent comparison view、V2.35 Local report export、V2.36 Pi writable evidence harness、V2.37 Pi writable guarded slice、V2.38 Hermes external roots、V2.39 OpenClaw workspace 深化、V2.40 Adapter diagnostics 均已收口；V2.28 验收关键已收口：同 agent 的 runtime/name collision 进入 `Conflicts`；跨 agent duplicate/source overlap/enabled mismatch 进入 `Analysis`；health 冲突计数不包含 cross-agent analysis 分组。
>
> 扫描适配器实现 `AgentAdapter`。
>
> 配置变更适配器实现 `AgentConfigAdapter`。
>
> 上层 scanner / catalog / UI 不直接处理 agent 特有配置语义。
>
> V2.41-V2.93 的 provider/task/validation/module-splitting/Agent Copilot/Codex expanded root/opencode configured-root work is tracked in README, roadmap, development tasks, and verification checklists. V2.92 expands Codex read-only roots and V2.93 adds opencode configured local roots while preserving the writable capability matrix below.

## V2.40 Adapter diagnostics

为每个 agent，V2.40 提供统一的诊断字段（read-only 聚合）：

- `roots discovered` / `roots skipped` / `roots blocked`：扫描根发现、跳过、阻塞列表与原因；
- `config detected`：可见的可读/可写配置来源（用户级/项目级/兼容源）；
- `read-only` / `writable` 原因：来自能力矩阵 blocker/reason 与 scan 能力状态；
- `last scan activity`：每次扫描的最近一次摘要（状态、时间、计数、建议）。

这类字段不引入新的写行为，仅用于能力透明化与用户诊断判断。V2.40 已通过 focused Rust/Swift checks、`pnpm check:macos`、真实 app smoke launch/window id、`pnpm check:privacy` 与截图人工检查；Computer Use/AX/capture 的 `cgWindowNotFound` / 0 visible windows 仍作为工具/窗口 blocker 记录。

## 1. 统一接口

```rust
// crates/core/src/adapter.rs
pub trait AgentAdapter: Send + Sync {
    fn id(&self) -> AgentId;                          // 稳定 id
    fn display_name(&self) -> &'static str;          // 展示名
    fn roots(&self, ctx: &AdapterContext) -> Vec<AdapterRoot>; // 扫描根（全局/项目）
    fn parse(&self, path: &Path) -> Result<SkillInstance, AdapterError>;
    fn is_enabled(&self, instance: &SkillInstance) -> bool;
    fn config_paths(&self, ctx: &AdapterContext) -> Vec<PathBuf>; // 配置文件（用于配置层管理）
}

pub trait AgentConfigAdapter: Send + Sync {
    fn patch_enabled(
        &self,
        doc: &mut AgentConfigDocument,
        instance: &SkillInstance,
        on: bool,
    ) -> Result<(), AdapterError>;
}

pub struct AgentConfigDocument {
    pub path: PathBuf,
    pub format: ConfigFormat,                         // json / toml / markdown
    pub text: String,                                 // 原始文本，patch 后由 service 校验并写回
}

pub enum ConfigFormat { Json, Toml, Markdown }

pub struct AdapterContext {
    pub user_home: PathBuf,
    pub project_cwd: Option<PathBuf>,
    pub project_root: Option<PathBuf>,
    pub extra_roots: Vec<AdapterRoot>,
}

pub struct AdapterRoot {
    pub scope: Scope,                                 // agent-global / agent-project
    pub path: PathBuf,
    pub source: RootSource,                           // ~/.xxx  /  <project>/.xxx / 额外
}
```

服务层还暴露统一能力矩阵：

```rust
pub struct AdapterCapabilityRecord {
    pub agent: &'static str,
    pub display_name: &'static str,
    pub status: &'static str,                         // verified / read-only / planned / blocked
    pub scan: AdapterFeatureCapability,
    pub project_scan: AdapterFeatureCapability,
    pub config_toggle: AdapterFeatureCapability,
    pub config_snapshot: AdapterFeatureCapability,
    pub install: AdapterFeatureCapability,
    pub writable: AdapterFeatureCapability,
    pub blockers: Vec<&'static str>,
}

pub struct AdapterFeatureCapability {
    pub supported: bool,
    pub status: &'static str,
    pub reason: Option<&'static str>,
}
```

该矩阵通过 `service.status.adapter_capabilities` 和 `adapter.listCapabilities` 暴露给 macOS UI。UI 必须根据该矩阵显示 scan/toggle/install 能力和 blocker，不应仅根据 agent 名称推断可写能力；侧栏健康摘要也应使用 current selected/current agent 过滤后的能力与计数视图。

当前能力状态：

| Agent | 状态 | Scan | Toggle | Install | Writable | Blocker |
| --- | --- | --- | --- | --- | --- | --- |
| Claude Code | `verified` | 支持（settings、project roots） | 支持（verified） | 支持（tool-global install） | 支持（verified） | `project-local` settings 与非 verified 目标 blocked |
| Codex | `verified` | 支持（native user/project roots + read-only `$CODEX_HOME/skills`、plugin marketplace、`/etc/codex/skills` diagnostics） | 支持（仅用户 `config.toml`，且仅 native `.agents/skills` 实例） | 支持（tool-global install to native roots） | 支持（native-root allowlist） | 项目级 `.codex/config.toml`、plugin/admin/system/compat roots writable blocked |
| opencode | `verified` | 支持 native roots + 官方 `.claude` / `.agents` compatibility roots + configured local `skills.paths` roots | 支持（exact `permission.skill` deny/re-enable） | 支持（native-root 安装） | 支持（managed permission overrides） | `skills.urls` metadata-only/no-fetch；configured/compat roots 不作为 install/write target |
| Pi | `guarded` | 支持 Pi-native roots | 支持 guarded native toggle（仅 global/project/package，基于证据） | blocked | limited | V2.37 已实现 preview/snapshot/rollback 与 disabled-state rescan；install、兼容 root 写入、脚本执行、AI 自动写回、credentials 仍 blocked |
| Hermes | `read-only` | 支持 active/profile Hermes home | blocked（read-only 扫描） | blocked | blocked | 外部目录仅按 `skills.external_dirs` 显式 external roots 处理；generic project scan / toggle / install / writable blocked |
| OpenClaw | `read-only` | 支持文档化 filesystem roots | blocked（read-only scan only） | blocked | blocked | project scope 仅 workspace，toggle/install/writable blocked |

> **实现要求**：所有适配器**无状态**。
>
> `AgentAdapter` 只负责：
>
> - 给出扫描根。
> - 解析 skill 路径。
> - 读取启用状态。
>
> `AgentConfigAdapter` 只负责对内存中的 `AgentConfigDocument` 打 agent-specific patch。
>
> 实际原子写、snapshot、锁与回滚由 commands/service 层统一执行。这样 listen-then-rescan 循环里，适配器不需要持有锁。

## 2. 各 agent 适配要点

### 2.1 Claude Code

> Spec status: verified against official Claude Code skills docs on 2026-06-03. See [`mvp-implementation-plan.md §2`](./mvp-implementation-plan.md#2-verified-claude-code-skill-facts).

| 项 | 值 |
| --- | --- |
| AgentId | `claude-code` |
| 全局 skills 目录 | `~/.claude/skills/<skill-name>/SKILL.md` |
| 项目级 skills 目录 | `<project>/.claude/skills/<skill-name>/SKILL.md`；Claude Code 还会从启动目录的父级到 repo root、以及工作到的嵌套目录按需发现 `.claude/skills/` |
| 额外目录 | `--add-dir` / `/add-dir` 指向的目录里若有 `.claude/skills/`，skills 会被加载；`permissions.additionalDirectories` 只授予文件访问，不加载 skills |
| 配置文件 | 用户级 `~/.claude/settings.json`；项目本地 `<project>/.claude/settings.local.json`；项目共享 `<project>/.claude/settings.json` 只读展示，MVP 不写共享配置 |
| 启用控制 | CLI skills 默认按文件系统发现并视为 `skillOverrides` 的 `"on"`；MVP toggle 在 `"off"` 与 inherited/default 之间切换，详见 [`mvp-implementation-plan.md §3`](./mvp-implementation-plan.md#3-mvp-toggle-semantics) |
| Frontmatter 解析 | YAML，`---` 分隔；`description` 官方推荐但字段整体可选；`name` 是展示标签，普通 personal/project skill 的命令名来自目录名 |
| 权限字段 | Claude Code CLI 支持 `allowed-tools` frontmatter；SDK 使用主查询参数控制工具权限，不能把 CLI 字段当成 SDK 权限 |
| 备注 | 单个 skill 是目录（含 `SKILL.md` + 可选 `scripts/`、`references/`）。扫描时按目录走，不要把每个文件当 skill。 |

### 2.2 Codex / OpenAI Agents

| 项 | 值 |
| --- | --- |
| AgentId | `codex` |
| 状态 | **V2.92 expanded roots complete** |
| Spec 工作单 | [`docs/codex-adapter-spec.md`](./codex-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#codex) |
| 已核实边界 | Codex 可使用 `AGENTS.md` 作为项目指令入口；这不等同于已核实 skills adapter 的目录、配置 schema 或启停语义 |
| Skill 格式 | 目录 + 必需 `SKILL.md`；frontmatter 中 `name` 和 `description` 必填 |
| Read-only roots | Native user `$HOME/.agents/skills` 和项目 `.agents/skills`；V2.92 还扫描/诊断 `$CODEX_HOME/skills`、local plugin marketplace skills、`/etc/codex/skills`（存在时） |
| Writable roots | 仅 native user/project `.agents/skills` 实例可通过用户 `config.toml` override toggle；`$CODEX_HOME/skills`、plugin/admin/system roots 只读 |
| 配置文件 | 用户级 `~/.codex/config.toml` / `$CODEX_HOME/config.toml` 已验证可用 `[[skills.config]]` 按绝对 `SKILL.md` path 禁用；skill 文件夹 path 在本地验证中未禁用 |
| 启用控制 | 用户 config 中用绝对 `SKILL.md` path 写 `enabled = false`；re-enable 删除同 path entries |
| Fixture | 最小 evidence fixtures 位于 `fixtures/codex/` |
| 行动项 | 后续若要启用项目级 toggle、plugin/admin/system/compat root 写入，必须重新走 evidence gate、snapshot/rollback 和 disposable fixture 验证 |

Codex 当前实现边界：

- 第一版可读 verified roots，并只写用户 Codex config。
- V2.92 额外扫描 `$CODEX_HOME/skills`、local plugin marketplace roots、`/etc/codex/skills`，但这些 root 只读。
- 项目级 `.codex/config.toml` 写入启停仍 blocked。
- adapter core、commands/service、cwd→repo-root discovery 和 macOS UI scan-all 已集成。
- 缺少 `name` 或 `description` 应作为 malformed/broken skill 处理，不应让整次 scan 失败。
- 可选 `scripts/`、`references/`、`assets/`、`agents/openai.yaml` 只保留/展示为原始资源，不推导权限。
- Disable 前必须先归一化同 path entries。
- 不要写 `<repo>/.codex/config.toml`。
- 不要写 `$CODEX_HOME/skills`、`/etc/codex/skills`、plugin marketplace roots 或 system roots。
- 不要删除 skill 文件。
- 不要添加 `enabled = true` 作为 re-enable。
- Re-enable 是删除同一绝对 `SKILL.md` path 的所有 `[[skills.config]]` entries。

### 2.3 pi coding agent

| 项 | 值 |
| --- | --- |
| AgentId | `pi` |
| 状态 | **Read-only implemented; guarded toggle complete** —— P0 evidence 证据已完成：global/project/package toggle、rollback、trust gate、invalid JSON/config、re-enable；V2.37 最小写入切片已完成，Pi install 与兼容根写入仍 blocked |
| Spec 工作单 | [`docs/pi-adapter-spec.md`](./pi-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#pi-coding-agent) |
| 本地观测 | 2026-06-08 本机 `pi --version` 为 `0.78.1`；`~/.pi/agent/skills/` 和 `~/.pi/agent/settings.json` 存在；未读取或修改真实 settings 内容 |
| Skill roots | 官方 Pi docs：全局 `~/.pi/agent/skills/`、`~/.agents/skills/`；项目 `.pi/skills/`、从 `cwd`/父级到 repo root 的 `.agents/skills/`；settings/package 也可添加 skill paths。V2.37 writable 切片只走 native/global-project-package 最小写入，不对 `.agents/skills` 等兼容根提供可写能力。 |
| Skill 格式 | Skills Copilot 当前只 catalog 目录型 `SKILL.md`；Pi-native root `.md` 可能被 Pi agent 识别，但真实本机验证显示会混入大量普通资源文档，暂不展示；frontmatter `name`/`description` 必填 |
| 配置文件 | 全局 Pi settings 与项目 `.pi/settings.json`；project settings override/merge global settings。V2.37 产品写入只使用服务验证后的 global/project settings target，不写兼容 roots。 |
| 启用控制 | V2.37 guarded toggle 支持 local disabled-skill collection（`skills.disabled` / `disabledSkills`）的 disable/re-enable；project/package toggle 需要 trusted project settings；install 仍 blocked。 |
| Fixture | 最小 evidence fixtures 位于 `fixtures/pi/` |
| 行动项 | 保持 V2.37 切片严格限制为 global/project/package minimal toggle 且无 install、无脚本执行、无 AI 自动写回、无凭据持久化、无任意兼容根写入；任何 Pi install、兼容根写入或更广 package mutation 都必须重新走 evidence gate。 |

> V2.37 只允许基于已验证证据写 Pi guarded native toggle；不要扩展到 Pi install、兼容 root 写入或未验证 package mutation，直到 exact mutation 和回滚语义另行完成本地验证。

### 2.3.1 Pi `.md` 去噪与可解释性边界（V2.27）

- Pi 扫描仅保留目录型 skill（`<root>/<skill-name>/SKILL.md`）与项目同构路径；不以 `.md` 文件作为 skill 实例。
- 过滤 `~/.pi/agent/skills/SKILL.md`、`.pi/skills/SKILL.md`、`references/SKILL.md`、或其他资源目录中的 direct `.md` 以减少伪阳性。
- 与其它 agent 的重名/共享路径关系由 cross-agent analysis 表达，不进入 `catalog.listConflicts`，并且不计入 health 冲突计数。

### 2.4 hermes

| 项 | 值 |
| --- | --- |
| AgentId | `hermes` |
| 状态 | **V2.17 read-only scanner implemented / writable blocked** |
| Spec 工作单 | [`docs/hermes-adapter-spec.md`](./hermes-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#hermes) |
| Evidence fixture | `fixtures/hermes/` 只保存 service evidence 样例，不是 parser contract |
| 只读范围 | 扫描 active Hermes home 的 `skills/**/SKILL.md` 和 V2.38 explicit `skills.external_dirs`；不做 generic project scan；不把 cron jobs 映射为 `SkillInstance` |
| 写入范围 | 禁止写 Hermes 配置；individual skill disable schema 和 rollback-safe writes 未验证 |
| 行动项 | ① 保持 scoped read-only scanner；② `skills.external_dirs` 在实现中只作为 explicit external roots，不推断为 project scope；③ 继续确认 individual skill disable/re-enable schema |

Hermes P0 evidence 已确认它是 Nous Research Hermes Agent，且有 first-class skills 和 active Hermes home `skills/**/SKILL.md`。

第一版只做 read-only scanner；project discovery、toggle、install 和 writable 继续 blocked。

### 2.5 openclaw

| 项 | 值 |
| --- | --- |
| AgentId | `openclaw` |
| 状态 | **Read-only scanner implemented / writable blocked** |
| Spec 工作单 | [`docs/openclaw-adapter-spec.md`](./openclaw-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#openclaw) |
| Candidate roots | `<workspace>/skills`、`<workspace>/.agents/skills`、`~/.agents/skills`、`~/.openclaw/skills`、bundled skills、`skills.load.extraDirs`；第一版只做 filesystem scan |
| Config evidence | plugin docs 使用 `openclaw config file` 定位 `openclaw.json`，并 patch `.plugins.entries[*].enabled` / `.plugins.allow`；这只证明 plugin 配置线索，不证明 skill toggle |
| Evidence fixture | `fixtures/openclaw/` 保存 read-only evidence 样例和 redacted plugin config 样例，不是 writable toggle contract |
| 行动项 | ① 保持 filesystem-only read-only scan；② 继续确认技能启停语义、权限模型和 rollback-safe 配置写入路径；③ 不调用 OpenClaw CLI |

OpenClaw P0 evidence 已确认官方 `SKILL.md` roots、frontmatter schema、loading order、precedence、`skills list --json` 和 config override 语义。Project-like scope 只按 OpenClaw workspace 处理：`<workspace>/skills` 和 `<workspace>/.agents/skills`；不把任意 repo root 推断为 OpenClaw project。

V2.16 第一版只做 read-only filesystem scanner；toggle/install/writable 继续 blocked，直到 disposable config mutation 证明 credential-safe rollback。

### 2.6 opencode
### 2.6.1 opencode provenance 口径（V2.27）

- 在 catalog 和 analysis 视图中，opencode 条目需展示 provenance label：`native`（`~/.config/opencode/skills`、`project/.opencode/skills`）、`compatibility`（`~/.claude/skills`、`~/.agents/skills` 等官方兼容目录）与 `configured`（JSON/JSONC `skills.paths` configured local roots）。
- 身份口径由 `(agent, scope, definition_id, path)` 决定；跨 root 的同名条目作为可解释重叠，保留于 Analysis，不直接变更 conflict 口径。
- `id` 规则仍以实例主键为准，provenance 仅用于用户可解释展示与分析分组。


| 项 | 值 |
| --- | --- |
| AgentId | `opencode` |
| 状态 | **Verified guarded writable with compatibility/configured scanning** —— scanner 覆盖 opencode native roots、官方 `.claude` / `.agents` compatibility roots，以及 V2.93 configured local `skills.paths` roots；V2.12 已实现 exact `permission.skill` deny/re-enable、snapshot/rollback，native-root install 仍为唯一 install target |
| Spec 工作单 | [`docs/opencode-adapter-spec.md`](./opencode-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#opencode) |
| 本地观测 | 2026-06-08 本机 `opencode --version` 为 `1.16.2`；`~/.config/opencode/skills/` 和 `~/.config/opencode/opencode.json` 存在；未读取或修改真实 config 内容 |
| Skill roots | 扫描 `~/.config/opencode/skills`、项目 `.opencode/skills`（native）、`~/.claude/skills` / `.claude/skills` / `~/.agents/skills` / `.agents/skills`（compatibility），以及 readable global/project JSON/JSONC config 中的 local `skills.paths`（configured） |
| Skill 格式 | 每个 skill 一个目录加 `SKILL.md`；frontmatter `name`/`description` 必填；`name` 必须匹配目录名；unknown fields ignored |
| 配置文件 | 全局 `~/.config/opencode/opencode.json` / `opencode.jsonc`；项目根 `opencode.json` / `opencode.jsonc`；`.opencode` 目录；`OPENCODE_CONFIG` / `OPENCODE_CONFIG_DIR` / `OPENCODE_CONFIG_CONTENT`；managed config 只读 |
| 启用控制 | `permission.skill` 支持 `allow` / `deny` / `ask`；V2.12 只写 exact `permission.skill.<name> = "deny"`，re-enable 只移除同名 exact deny，不改 wildcard rules |
| Fixture | parser/scan contract fixtures 位于 `fixtures/opencode/` |
| 行动项 | 兼容 roots 与 configured local `skills.paths` roots 已纳入 opencode 扫描；按 V2.21 扫描准确性与 path 去重口径保留重复来源；继续用 cross-agent analysis 暴露与 Claude/Codex 的重复关系，install 仍只写 native opencode roots；`skills.urls` 继续 metadata-only/no-fetch |

opencode roots 口径：

- 当前实现扫描用户 native root：`~/.config/opencode/skills/<name>/SKILL.md`。
- 当前实现扫描项目 native root：`.opencode/skills/<name>/SKILL.md`。
- 当前实现按官方文档扫描 `.claude/skills` 和 `.agents/skills` compatibility roots；这些记录归属 opencode 视图，同时由 cross-agent analysis 表达与 Claude/Codex 的重复和冲突。
- 当前实现以 `RootSource::Configured` 扫描 readable JSON/JSONC `skills.paths` local roots；它们只读，不作为 install/write target。
- 当前实现不抓取 `skills.urls`；URL entries 只作为 metadata/no-fetch boundary 记录到能力说明与 blockers。
- 项目 discovery 从 cwd 向上到 Git worktree。

### 3.5 扫描准确性与去重统计（V2.21 完成）

- 扫描结果必须先 canonicalize path 与 root，再做去重，避免同一目录在软链接、别名路径、项目上行扫描中重复入库。
- 去重策略原则：`id = hash(agent, scope, path)` 保留 adapter 内同物理源的唯一实例；不同 agent 的同名或同物理文件保留可见但不混淆为同一运行时状态。
- 统计口径要求：跨 agent 的重复（同名、同路径、enabled mismatch）由 `catalog.analysis` 的 group 视图承载；`app.stateSnapshot.health` 提供 per-agent 汇总并保留实例维度计数，UI 过滤不改变总量定义；`app.stateSnapshot.health.conflict_count` 只统计 selected/current agent 的 same-agent runtime/name 冲突，不叠加 cross-agent 分析计数。
- 交叉验证要求：`catalog.scanAll.result.activity.agent_summaries`、`catalog.analysis`、`app.stateSnapshot.health` 对同一扫描上下文应可对齐（无新增或遗漏的可见实例）。
- V2.22 已完成：冲突（conflict）与 cross-agent 重复需清晰分离，前者仅用于同一 selected/current agent runtime/name collision；后者由 `catalog.analysis` / Analysis UI 承载。

## 3. 跨 agent 公共问题

> 当前 6 个 agent 的 adapter **都不写** `Scope::ToolGlobal`（参见 [data-model.md §1.2](./data-model.md#12-scope)）。该 scope 保留为未来 import / 共享池扩展位，MVP / V1 都不会出现 ToolGlobal 实例。

### 3.1 路径冲突

同一物理文件可能被多个 agent 识别为 skill（例如 symlink）。catalog 用 `id = hash(agent, scope, path)` 去重，跨 agent 仅作为 analysis group 观察；同-agent runtime/name 冲突仍由冲突分组展示（参见 [data-model.md](./data-model.md)）。V2.27 追加 provenance 标注：同一物理路径在不同 provenance source 下的重复展示，仍走 Analysis 而不影响 conflict 计数。

### 3.2 启用优先级（当同一名字出现在多 scope）

默认顺序（当前固定；Future 可被项目内 `skills-copilot.toml` 覆盖，但该配置文件尚未实现）：

1. `agent-project`（项目本地最高，覆盖一切）
2. `agent-global`
3. `tool-global`（未来跨 agent 共享池，最低优先；MVP / V1 不会由 adapter 产生）
4. 同 scope 内多份 → 取文件 mtime 最新；并列则取 path 字典序最小，UI 高亮提示。

### 3.3 Frontmatter 兼容性

不同 agent 的 frontmatter 字段差异：
- `name` / `description` —— 通用
- `version` —— 多数支持
- `tools` / `permissions` —— 命名不同；Claude Code CLI 的工具字段已核实，Codex 的权限 / dependency 映射仍未核实，不要从猜测字段推导权限
- `requires` / `dependencies` —— 暂未广泛使用，留作扩展点

适配器在解析时把异构字段统一映射到 [`SkillInstance`](./data-model.md#1-skillinstance) 的标准化字段。原始 frontmatter 同时保留在 `frontmatter_raw` 里，便于将来调试。

### 3.4 配置文件读写

写 `settings.json` / `config.toml` 时**必须**：
- 读出原文件 → 在内存中合并 → 原子写（写 `.tmp` → rename）→ 失败时回滚原文件
- 任何"toggle"操作都不应删除原 skill 文件，只动 agent 的配置/可见性开关
- 写完后**立即**触发对应目录的重扫（不依赖 notify 兜底）

Claude Code MVP 的 toggle 写 `skillOverrides`：项目 skill 写 `<project>/.claude/settings.local.json`，个人 skill 写 `~/.claude/settings.json`。它仍然走同一套 snapshot、锁、原子写、回读校验和回滚路径。

## 4. 新增 agent 的 checklist

> 这是非 Claude adapter 的准入模板。未勾选表示该 agent 尚未进入实现范围，不代表当前 Claude MVP/V1 漏项。

要把新 agent 加进 skills-copilot，至少提供：

- [ ] 该 agent 的官方文档链接（skills 规范）
- [ ] 一份最小可复现的样例：1 个全局 skill + 1 个项目级 skill + 1 份配置文件
- [ ] 配置文件 schema（字段含义、类型、版本）
- [ ] 启用/禁用的真实语义（"黑名单"还是"白名单"还是"全开"）
- [ ] 任何破坏性差异（例如：禁用的 skill 还会被加载吗？）

填齐后再写 `crates/adapters/src/<id>/` 与对应 fixture 测试。

非 Claude adapter 的详细证据清单维护在 [`agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md)。

## OpenClaw scope note (V2.39, completed)

- OpenClaw support is workspace-scoped and read-only.
- Confirmed roots: `<workspace>/skills` and `<workspace>/.agents/skills`.
- Do not infer arbitrary repository/project roots for OpenClaw scanning.
- OpenClaw writable/install features remain blocked; no script execution, AI auto-write, credential persistence, or public distribution for this milestone.
- This section reflects the completed V2.39 implementation and validation boundary.
