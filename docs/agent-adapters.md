# Agent Adapters

> skills-copilot 支持的 6 个 agent 的适配要点。
>
> 当前版本线：V2.11 Adapter Capability Matrix、V2.12 opencode writable、V2.13 Pi read-only scanner/parser、V2.14 Hermes evidence-gate closeout、V2.15 OpenClaw evidence-gate closeout、V2.16 OpenClaw read-only scanner、V2.17 Hermes read-only scanner、V2.18 cross-agent analysis、V2.19 skill health dashboard、V2.20 read-only AI skill analysis assist 已完成；V2.21 扫描准确性、去重与 agent 维度统计同步已完成；V2.22 finding/conflict 语义与验收同步进行中。
>
> 扫描适配器实现 `AgentAdapter`。
>
> 配置变更适配器实现 `AgentConfigAdapter`。
>
> 上层 scanner / catalog / UI 不直接处理 agent 特有配置语义。

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

该矩阵通过 `service.status.adapter_capabilities` 和 `adapter.listCapabilities` 暴露给 macOS UI。UI 必须根据该矩阵显示 scan/toggle/install 能力和 blocker，不应仅根据 agent 名称推断可写能力。

当前能力状态：

| Agent | 状态 | Scan | Toggle / writable |
| --- | --- | --- | --- |
| Claude Code | `verified` | 支持 | 支持，走 settings snapshot/lock/atomic write/read-back/rescan |
| Codex | `verified` | 支持 | 支持用户 `config.toml` override；项目 `.codex/config.toml` 仍 blocked |
| opencode | `verified` | 支持 native roots 与官方 `.claude` / `.agents` compatibility roots | 支持 guarded writable：exact `permission.skill` deny/re-enable、snapshot/rollback；tool-global install 仍限 native roots |
| Pi | `read-only` | 支持 Pi-native roots | writable harness candidate；production writes blocked |
| Hermes | `read-only` | 支持 active/profile Hermes home | generic project scan、toggle、install、writable blocked；`skills.external_dirs` 未来按 explicit external roots 处理 |
| OpenClaw | `read-only` | 支持 read-only filesystem scan | project scope 仅限 confirmed OpenClaw home workspace roots；toggle、install、writable blocked |

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
| 状态 | **V2 first implementation complete** |
| Spec 工作单 | [`docs/codex-adapter-spec.md`](./codex-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#codex) |
| 已核实边界 | Codex 可使用 `AGENTS.md` 作为项目指令入口；这不等同于已核实 skills adapter 的目录、配置 schema 或启停语义 |
| Skill 格式 | 目录 + 必需 `SKILL.md`；frontmatter 中 `name` 和 `description` 必填 |
| 首版 read-only roots | 官方并经本地 `codex-cli 0.137.0` 验证：user `$HOME/.agents/skills`；repo 从 adapter context `project_cwd` 到 `project_root` 的 `.agents/skills` |
| 首版 blocked/deferred roots | 不扫描 `/etc/codex/skills`、plugin-distributed/system bundled skills 或本地观测到的 `$CODEX_HOME/skills`，除非另有产品决策；这些 root 不进入 V2 首个实现切片 |
| 配置文件 | 用户级 `~/.codex/config.toml` / `$CODEX_HOME/config.toml` 已验证可用 `[[skills.config]]` 按绝对 `SKILL.md` path 禁用；skill 文件夹 path 在本地验证中未禁用 |
| 启用控制 | 用户 config 中用绝对 `SKILL.md` path 写 `enabled = false`；re-enable 删除同 path entries |
| Fixture | 最小 evidence fixtures 位于 `fixtures/codex/` |
| 行动项 | 后续恢复真实本机 Computer Use 操作验证；项目级 toggle、plugin/admin/system roots、`$CODEX_HOME/skills` 兼容 root 未定前不要写对应能力 |

Codex 当前实现边界：

- 第一版可读 verified roots，并只写用户 Codex config。
- 项目级写入启停仍 blocked。
- adapter core、commands/service、cwd→repo-root discovery 和 macOS UI scan-all 已集成。
- 缺少 `name` 或 `description` 应作为 malformed/broken skill 处理，不应让整次 scan 失败。
- 可选 `scripts/`、`references/`、`assets/`、`agents/openai.yaml` 只保留/展示为原始资源，不推导权限。
- Disable 前必须先归一化同 path entries。
- 不要写 `<repo>/.codex/config.toml`。
- 不要删除 skill 文件。
- 不要添加 `enabled = true` 作为 re-enable。
- Re-enable 是删除同一绝对 `SKILL.md` path 的所有 `[[skills.config]]` entries。

### 2.3 pi coding agent

| 项 | 值 |
| --- | --- |
| AgentId | `pi` |
| 状态 | **Read-only implemented; writable harness candidate** —— P0 evidence 已确认 Pi-native 和 package filter mutation 语义，但 production writes 仍需 harness 验证 |
| Spec 工作单 | [`docs/pi-adapter-spec.md`](./pi-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#pi-coding-agent) |
| 本地观测 | 2026-06-08 本机 `pi --version` 为 `0.78.1`；`~/.pi/agent/skills/` 和 `~/.pi/agent/settings.json` 存在；未读取或修改真实 settings 内容 |
| Skill roots | 官方 Pi docs：全局 `~/.pi/agent/skills/`、`~/.agents/skills/`；项目 `.pi/skills/`、从 `cwd`/父级到 repo root 的 `.agents/skills/`；settings/package 也可添加 skill paths |
| Skill 格式 | Skills Copilot 当前只 catalog 目录型 `SKILL.md`；Pi-native root `.md` 可能被 Pi agent 识别，但真实本机验证显示会混入大量普通资源文档，暂不展示；frontmatter `name`/`description` 必填 |
| 配置文件 | 全局 `~/.pi/agent/settings.json`；项目 `.pi/settings.json`；project settings override/merge global settings |
| 启用控制 | `pi config` 是官方资源启停界面；settings/package filters 支持排除资源。但 direct local skill toggle 的 exact JSON mutation、re-enable、project trust 行为未验证 |
| Fixture | 最小 evidence fixtures 位于 `fixtures/pi/` |
| 行动项 | 先做 disposable `agentDir`/fixture project round-trip；按 V2.21 定义明确 `.agents/skills` 与 global/project root 关系；先补扫描准确性口径与去重约束，再考虑 write adapter，写入 adapter 继续 blocked |

> 目前只允许基于该 spec 做 read-only scanner/parser 设计；不要写可修改 Pi settings 的 adapter，直到 `pi config` 的 exact JSON mutation 和回滚语义完成本地验证。

### 2.4 hermes

| 项 | 值 |
| --- | --- |
| AgentId | `hermes` |
| 状态 | **V2.17 read-only scanner implemented / writable blocked** |
| Spec 工作单 | [`docs/hermes-adapter-spec.md`](./hermes-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#hermes) |
| Evidence fixture | `fixtures/hermes/` 只保存 service evidence 样例，不是 parser contract |
| 只读范围 | 只扫描 active Hermes home 的 `skills/**/SKILL.md`；不做 generic project scan；`skills.external_dirs` 未来按 explicit external roots 处理；不把 cron jobs 映射为 `SkillInstance` |
| 写入范围 | 禁止写 Hermes 配置；individual skill disable schema 和 rollback-safe writes 未验证 |
| 行动项 | ① 保持 scoped read-only scanner；② 继续确认 profile/external_dirs 语义；③ 确认 individual skill disable/re-enable schema |

Hermes P0 evidence 已确认它是 Nous Research Hermes Agent，且有 first-class skills 和 active Hermes home `skills/**/SKILL.md`。

第一版只做 read-only scanner；project discovery、toggle、install 和 writable 继续 blocked。

### 2.5 openclaw

| 项 | 值 |
| --- | --- |
| AgentId | `openclaw` |
| 状态 | **Read-only scanner candidate after P0 evidence / writable blocked** |
| Spec 工作单 | [`docs/openclaw-adapter-spec.md`](./openclaw-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#openclaw) |
| Candidate roots | `<workspace>/skills`、`<workspace>/.agents/skills`、`~/.agents/skills`、`~/.openclaw/skills`、bundled skills、`skills.load.extraDirs`；第一版只做 filesystem scan |
| Config evidence | plugin docs 使用 `openclaw config file` 定位 `openclaw.json`，并 patch `.plugins.entries[*].enabled` / `.plugins.allow`；这只证明 plugin 配置线索，不证明 skill toggle |
| Evidence fixture | `fixtures/openclaw/` 保存 read-only evidence 样例和 redacted plugin config 样例，不是 writable toggle contract |
| 行动项 | ① 保持 filesystem-only read-only scan；② 继续确认技能启停语义、权限模型和 rollback-safe 配置写入路径；③ 不调用 OpenClaw CLI |

OpenClaw P0 evidence 已确认官方 `SKILL.md` roots、frontmatter schema、loading order、precedence、`skills list --json` 和 config override 语义。Project-like scope 只按 OpenClaw workspace 处理：`<workspace>/skills` 和 `<workspace>/.agents/skills`；不把任意 repo root 推断为 OpenClaw project。

V2.16 第一版只做 read-only filesystem scanner；toggle/install/writable 继续 blocked，直到 disposable config mutation 证明 credential-safe rollback。

### 2.6 opencode

| 项 | 值 |
| --- | --- |
| AgentId | `opencode` |
| 状态 | **Verified guarded writable with compatibility scanning** —— scanner 覆盖 opencode native roots 与官方 `.claude` / `.agents` compatibility roots；V2.12 已实现 exact `permission.skill` deny/re-enable、snapshot/rollback，native-root install 仍为唯一 install target |
| Spec 工作单 | [`docs/opencode-adapter-spec.md`](./opencode-adapter-spec.md) |
| 统一工作单 | [`docs/agent-adapter-spec-worklists.md`](./agent-adapter-spec-worklists.md#opencode) |
| 本地观测 | 2026-06-08 本机 `opencode --version` 为 `1.16.2`；`~/.config/opencode/skills/` 和 `~/.config/opencode/opencode.json` 存在；未读取或修改真实 config 内容 |
| Skill roots | 扫描 `~/.config/opencode/skills`、项目 `.opencode/skills`、`~/.claude/skills`、项目 `.claude/skills`、`~/.agents/skills`、项目 `.agents/skills` |
| Skill 格式 | 每个 skill 一个目录加 `SKILL.md`；frontmatter `name`/`description` 必填；`name` 必须匹配目录名；unknown fields ignored |
| 配置文件 | 全局 `~/.config/opencode/opencode.json`；项目根 `opencode.json`；`.opencode` 目录；`OPENCODE_CONFIG` / `OPENCODE_CONFIG_DIR`；managed config 只读 |
| 启用控制 | `permission.skill` 支持 `allow` / `deny` / `ask`；V2.12 只写 exact `permission.skill.<name> = "deny"`，re-enable 只移除同名 exact deny，不改 wildcard rules |
| Fixture | parser/scan contract fixtures 位于 `fixtures/opencode/` |
| 行动项 | 兼容 roots 已纳入 opencode 扫描；按 V2.21 扫描准确性与 path 去重口径保留重复来源；继续用 cross-agent analysis 暴露与 Claude/Codex 的重复关系，install 仍只写 native opencode roots |

opencode roots 口径：

- 当前实现扫描用户 native root：`~/.config/opencode/skills/<name>/SKILL.md`。
- 当前实现扫描项目 native root：`.opencode/skills/<name>/SKILL.md`。
- 当前实现按官方文档扫描 `.claude/skills` 和 `.agents/skills` compatibility roots；这些记录归属 opencode 视图，同时由 cross-agent analysis 表达与 Claude/Codex 的重复和冲突。
- 项目 discovery 从 cwd 向上到 Git worktree。

### 3.5 扫描准确性与去重统计（V2.21 完成）

- 扫描结果必须先 canonicalize path 与 root，再做去重，避免同一目录在软链接、别名路径、项目上行扫描中重复入库。
- 去重策略原则：`id = hash(agent, scope, path)` 保留 adapter 内同物理源的唯一实例；不同 agent 的同名或同物理文件保留可见但不混淆为同一运行时状态。
- 统计口径要求：跨 agent 的重复（同名、同路径、enabled mismatch）由 `catalog.analysis` 的 group 视图承载；`app.stateSnapshot.health` 提供 per-agent 汇总并保留实例维度计数，UI 过滤不改变总量定义。
- 交叉验证要求：`catalog.scanAll.result.activity.agent_summaries`、`catalog.analysis`、`app.stateSnapshot.health` 对同一扫描上下文应可对齐（无新增或遗漏的可见实例）。
- V2.22 进行时：冲突（conflict）与 cross-agent 重复需清晰分离，前者仅用于同一 selected/current agent runtime/name collision。

## 3. 跨 agent 公共问题

> 当前 6 个 agent 的 adapter **都不写** `Scope::ToolGlobal`（参见 [data-model.md §1.2](./data-model.md#12-scope)）。该 scope 保留为未来 import / 共享池扩展位，MVP / V1 都不会出现 ToolGlobal 实例。

### 3.1 路径冲突

同一物理文件可能被多个 agent 识别为 skill（例如 symlink）。catalog 用 `id = hash(agent, scope, path)` 去重，跨 agent 仅作为 analysis group 观察；同-agent runtime/name 冲突仍由冲突分组展示（参见 [data-model.md](./data-model.md)）。

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
