# 安全模型

> skills-copilot 触达的内容天然是“会跑的代码”：skill 自带脚本，被各 agent 加载后可能被执行。
>
> 默认策略：**deny by default、显式 opt-in、最小权限**。
>
> 本文件列出主要攻击面和对应缓解。

## 1. 信任分层

| 层 | 信任假设 | 默认权限 |
| --- | --- | --- |
| `skills-copilot` 内核（Rust） | 可信 | 全权限（自约束） |
| UI shell（macOS SwiftUI 产品壳） | 可信 | 只能调受控 service protocol；不能直接 FS |
| service protocol / IPC boundary | 可信边界但输入不可信 | 对所有请求做 schema、路径、权限和写操作二次校验 |
| catalog (SQLite) | 可信（本地） | 全权限 |
| 适配器 | 可信（受控代码） | 只能读自己负责的目录 |
| 规则引擎 | 可信 | 只读 snapshot，无 FS |
| LLM 输出 | **不可信** | 不进 IPC；只能进 UI 展示 |
| skill 文件（被管理对象） | **不可信** | 默认 Disabled + 不能通过 skills-copilot 执行 |
| execution attempt audit | 可信（本地记录） | 只能记录 blocked/cancelled/failure attempt metadata，不保存 secrets 或命令输出 |

> skill 是用户选择“启用”的对象。一旦启用，对应文件会进入 catalog，并允许对应 agent 加载。
>
> skills-copilot **不**在默认路径自行执行 skill 脚本。
>
> V2.7 LLM 本地辅助分析当前只实现 disabled-by-default gate 和 request prepare/estimate。V2.30 已实现的边界在此基础上要求：仅由用户显式触发的 `selected`/`batch` 场景返回本地 review preview，默认不发起 provider 网络请求；它不保存 credentials、不创建 provider client、不发起网络请求，也不把 LLM prompt/response/token/cost 写入 SQLite、项目目录或 logs。
>
> V2.41+ 将 AI 大模型介入提升为核心分析能力，但只能在用户显式配置 provider 并确认 prompt preview 后调用。Provider 支持方向是 OpenAI-compatible 与 Claude-compatible 接口标准；endpoint/API key/model 均由用户配置。API key 优先存入 Keychain；任何 fallback 必须显式 opt-in、权限检查，并且不得把 secret 写入 SQLite、项目目录、日志、报告、截图或 prompt artifacts。
>
> V2.10 skill execution safety 当前是 default-deny 边界：
>
> - 没有真实执行能力默认开启。
> - 任何未来执行请求都必须逐次人工确认。
> - 确认前必须展示 cwd/env/network/files preview。
> - blocked/cancelled/failure attempts 必须留下本地审计记录。
> - LLM 不能触发或确认执行。
>
> Privacy guardrail:
>
> - Repository docs, fixtures, screenshots, and evidence must not expose real local usernames, home paths, app-data paths, `/var/folders` temp paths, credentials, tokens, private keys, or proxy-managed credential placeholders.
> - Use placeholders such as `$HOME`, `<repo>`, `<worktree>`, `<project-root>`, `<app-data-dir>`, and `<redacted>`.
> - Run `pnpm check:privacy` before commit, push, or handoff.

## 2. 攻击面与缓解

### 2.1 路径穿越 / Symlink 逃逸

**风险**：恶意 skill 用 symlink 指到 `~/.ssh/` 或 `~/.aws/credentials`，让 adapter 解析时读到敏感内容。

**缓解**：
- 解析前 `canonicalize()`，与 `roots()` 返回的允许根比对；不在白名单内 → 拒绝 + 标 `Broken`
- symlink 解析的中间路径必须全部在白名单根内
- Scanner 只读路径边界：
- 每个内置 scan root 先 canonicalize。
- UserHome / Project root 的真实路径必须仍落在对应 home / project base 内。
- 显式 `Extra` root 视为用户 opt-in 的允许根。
- 每个 symlink target 和 `SKILL.md` 实际路径也 canonicalize。
- UserHome root 允许跟随仍在当前 user home 内的 symlink，以兼容用户本机 skill 目录复用。
- Project root 只允许项目 root 内 target。
- Extra root 只允许当前 canonical scan root 内 target。
- 已访问目录会去重，避免 symlink 目录循环导致重复扫描或 DoS。
- 配置文件写入时，**禁止**通过 symlink 路径写；Claude `settings.json` / `settings.local.json` 写入会校验目标等于当前 `AdapterContext` 推导出的配置路径，写前、rename 前、写后都要求 canonical parent 仍在允许 root 内
- 配置写入使用同目录唯一临时文件 + `create_new` + `rename`，并拒绝 symlink config file / config directory / lock file

2026-06-08 复核记录：`crates/commands` 中产品文件写入面仅限 Claude config save/toggle/rollback，均走上述 config target 校验、锁、snapshot、原子写和回读验证。`scan_claude_to_catalog` 只通过 `Catalog` API 写本地 catalog 记录，不接受任意文件目标。`crates/scanner` 不写文件，但作为非配置路径读取面已收紧 canonical scan root 边界；`crates/adapters/fuzz` 只把 fuzz 输入写入 `tempfile` 管理的临时 `SKILL.md`。

### 2.1.1 Project context 边界

V2.2 Project Context Formalization 的安全目标是让 UI 可选择/记忆项目，同时不把"当前项目"变成任意文件系统授权。

**规则**

- `ProjectContext.current_cwd` 和 `ProjectContext.root_path` 必须 canonicalize；`current_cwd` 必须位于 `root_path` 内。
- Env launch 未显式传 `SKILLS_COPILOT_PROJECT_ROOT` 时，service 只能从 `SKILLS_COPILOT_PROJECT_CWD` 向上寻找受支持的 project marker；找不到安全 root 时进入 no-project，而不是把 `current_cwd` 当成任意 project root。
- Env override 优先级最高，但只用于测试、截图和开发者 launch。`SKILLS_COPILOT_PROJECT_CWD` / `SKILLS_COPILOT_PROJECT_ROOT` 产生的 context 不写入 `project-context.json`。
- `project-context.json` 只写在 app data 目录下，禁止写入用户项目目录，避免 project-local repo 被 skills-copilot 自动修改。
- no-project 下不扫描 project-local Claude/Codex roots，不创建 `AgentProject` catalog 归属，不重写旧项目 catalog 归属。
- 项目切换后，toggle 必须重新校验所选 `SkillInstance.project_root` 与当前有效 `ProjectContext.root_path`；旧 UI selection 或 stale catalog row 不能绕过边界。
- Codex 写入仍只允许用户 `config.toml` 的已验证 `[[skills.config]]` override。V2.2 不写 `<project>/.codex/config.toml`。
- V2.2 不扫描或写入 plugin/admin/system roots，包括 `/etc/codex/skills`、`$CODEX_HOME/skills`、插件分发目录或其它未验证的 adapter root。
- 项目记忆是本地 app state；不引入 cloud sync、账号、telemetry、匿名 crash report 或远端项目目录上传。

### 2.2 配置文件写入破坏

**风险**：toggle skill 时写坏 agent 配置文件，导致对应 agent 加载失败。

**缓解**：
- 写 agent 配置前先 `config_snapshot` 落盘；它是 agent config history，不是 skill 内容历史
- 原子写：写 `path.tmp` → `fsync` → `rename` 到 `path`
- 写完立即回读校验；不一致则从 snapshot 恢复
- 同一配置文件加文件锁（`fs4::FileExt::lock_exclusive()`，sentinel `.lock` 文件），并发写安全
- 提供 agent config rollback 入口（基于最近的 agent config snapshot）

### 2.2.1 Repository evidence and privacy leakage

**风险**：validation docs, screenshots, fixtures, changelog entries, or historical commits can accidentally expose local usernames, absolute HOME paths, temporary app-data paths, proxy-managed credential placeholders, or realistic-looking test secrets.

**缓解**：
- Committed docs must use placeholders (`$HOME`, `<repo>`, `<worktree>`, `<project-root>`, `<app-data-dir>`, `<redacted>`) instead of real local paths or usernames.
- Committed screenshots must be app-window-only and must be manually inspected for visible paths, usernames, tokens, and credential placeholders before commit. Raw local captures stay out of git.
- `pnpm check:privacy` scans tracked text, tracked binary string metadata, and reachable history for local-path and secret-like patterns. It is required before commit, push, or release handoff and runs in CI with full history.
- Test fixtures may use explicit non-sensitive placeholders such as `fixture-redacted-value`; they must not use values that look like real tokens or local credentials.
- If privacy checks fail on reachable history, rewrite the affected unpushed or coordinated release branch history before pushing. Do not publish a branch that still contains the leaked blobs.

### 2.2.1.1 Pi writable evidence harness and guarded slice（V2.36-V2.37）

Pi settings mutation remains limited to the V2.37 guarded native toggle slice. V2.36 evidence harness passed in disposable roots only, and V2.37 uses that evidence for a minimal global/project/package toggle path. Broader Pi writes remain unsupported unless separate evidence confirms:

- global/project/package toggle mutation semantics
- rollback/恢复语义
- project trust gate (`pi config -l`) 与 untrusted/trusted 场景处理
- invalid JSON 与配置破损的保护性失败行为
- re-enable 规则（通过移除禁用 entry，而非写入正向 enable 字段）

超出 V2.37 native global/project/package 范围时，`config.toggleSkill` 等通道应返回 `read-only`/`unsupported` 风险提示，而非尝试直接写入 Pi settings 或 `.pi/settings.json`。

该证据项与 `V2.37` 受限 writable slice 已完成。该切片要求 preview→确认→snapshot/rollback，并限制为 minimal native global/project/package 作用域；不执行脚本，不自动 AI 写回，不保存 credentials，不开放任意兼容 roots。任何回退路径必须支持回滚，且 install 继续 blocked。

### 2.2.2 Codex config patch hardening（V2.3 implemented）

V2.3 的 Codex adapter hardening 不扩大写入范围；它只强化已验证的用户级 `~/.codex/config.toml` / `$CODEX_HOME/config.toml` patch 行为，并已通过 adapter/commands/smoke 回归覆盖。

**目标规则**

- Codex toggle 仍只写用户 config 的 `[[skills.config]]` override；不得写 `<project>/.codex/config.toml`。
- 写入目标必须 canonicalize 到已验证的 user config parent 内；拒绝 symlink config file、symlink config directory、symlink lock file 和 parent 逃逸。
- Disable 只归一化目标 absolute `SKILL.md` path 的 entries：删除所有目标 entries，再写一个 `enabled = false` entry。
- Re-enable 只删除目标 path 的 entries；不得写 `enabled = true` 来改变 Codex 默认发现语义。
- Patch 必须保留非目标内容，包括注释、未知 key、非目标 table、非目标 `[[skills.config]]` entry 和文件末尾换行。
- Malformed TOML、缺失/非 string `path`、非 bool `enabled`、不可写 config、重复冲突 entry、root 读取错误和 symlink/root rejection 必须变成稳定错误或 findings；不得静默重写整份 config。
- V2.3 仍不扫描或写入 `/etc/codex/skills`、`$CODEX_HOME/skills`、plugin-distributed skills、system skills 或其它未验证 adapter root。
- Project context 边界继续适用：当前项目只影响 Codex project skill 扫描归属；toggle 目标仍需匹配当前安全 project root 或 user root，且写入仍落在用户 config。

### 2.2.3 Opencode read-only boundary（V2.4 implemented）

V2.4 把 opencode 作为第三个 adapter 接入 catalog；当前实现按官方 OpenCode roots 扫描 native 和 `.claude` / `.agents` compatibility roots。Writable 行为仍限 V2.12 验证过的 managed `permission.skill` config override，file install 仍限 native opencode roots。

**规则**

- Opencode 扫描根允许官方 native roots 和 compatibility roots：用户/项目 `.opencode/skills`、`.claude/skills`、`.agents/skills`。
- Compatibility roots 是 scan-only 来源；同名或同文件重复由 cross-agent analysis 暴露，不通过隐藏 opencode-visible skill 来规避。
- Project boundary 与 V2.2 相同：project opencode root 必须 canonicalize 到当前 active project root 内；no-project 下只扫描 global opencode root，不扫描或重归属 project-local rows。
- `config.toggleSkill` 对 opencode 必须保持 read-only/unsupported。UI 应在调用 service 前禁用 opencode toggle 并显示 read-only adapter reason；直接 service 调用返回 unsupported/read-only error，且不得创建或修改任何 opencode config。
- Smoke fixture 只能使用临时 `HOME` 和临时 project roots 创建 opencode native/compatibility roots；不得读取、创建或修改真实用户 opencode config。
- Writable opencode 行为（`permission.skill` exact patch、wildcard precedence、managed config、re-enable semantics）必须等 disposable local round-trip 或 maintainer spec 验证后才能进入实现。

### 2.2.4 Hermes external roots（V2.38 completed）

V2.38 的 Hermes 口径已完成：`skills.external_dirs` 定义为 explicit external roots，不推断为 generic project roots；实现与安全边界继续保持 Hermes 只读扫描。Hermes writable/install 及写回路径（包含脚本执行、AI 自动写回、credentials 持久化、public distribution）均保持 blocked。

### 2.3 监听事件的拒绝服务

> MVP 曾在 Tauri 层监听 Claude Code 已存在的 `.claude` 根目录。当前 native macOS 路线下，监听属于 Rust service，而不是 UI shell。当前只响应 `SKILL.md`、`settings.json`、`settings.local.json` 变更；不存在的根不会被主动创建。

**风险**：用户在工作目录里大量 `git checkout` / `npm install`，触发百万级文件变更事件，catalog 写入风暴。

**缓解**：
- `notify` 事件走 debounce（MVP 默认 500ms）
- 监听 `~/.claude/skills/` 等**指定根**，**不**递归监听整个 `~/`
- 每次有效事件触发 Claude 全量重扫；10k synthetic skills 基准已覆盖 scan → catalog 耗时与最大 RSS，10k synthetic catalog 基准已覆盖 UI 列表搜索 / 过滤 / 排序响应，后续继续跟踪真实首屏 p95

### 2.4 恶意 skill 利用 LLM

**风险**：skill 的 body 包含提示词注入，诱骗 LLM 在 Analyze 时输出"删除 / 写入某个文件"。

**缓解**：
- V2.7 当前没有真实 provider 调用；prepare/estimate 只在本地计算请求预算和显示 disabled/unconfigured 状态
- V2.41+ 真实 provider 调用必须经过 prompt preview / redaction / token estimate；用户确认的是“将这些字段发往这个 endpoint”，不是确认任何写入或执行
- LLM 输出限定为 JSON schema，解析失败直接丢弃
- LLM 输出**永远不**进入 IPC 命令、不进入 catalog
- UI 渲染 LLM 文本时按纯文本处理（不解析 markdown 里的链接作为命令）
- 用户从 LLM 拿到的 `draft_frontmatter` 只是草稿展示/复制内容，不存在 Apply / Write；真实写入必须由用户进入正常编辑/保存路径，并经 Rust service 的格式校验、snapshot、原子写和回读验证
- AI task readiness、routing confidence、trace analysis、remediation planner、policy explanation 等都属于 judgment output；它们不能直接触发 toggle、install、rollback、script execution、triage mutation 或 policy mutation

### 2.4.1 Skill execution safety boundary（V2.10）

**风险**：恶意 skill 把脚本、shebang、命令片段或 LLM 生成的建议伪装成可执行操作，诱导应用或用户在不清楚 cwd/env/network/files 范围时运行代码。

**缓解**：
- 默认不真实执行 skill 脚本；scan、detail、import、export、install、state snapshot 和 LLM prepare 都必须保持 non-execution。
- 任意未来执行入口必须只接受用户主动触发，逐次确认；不得复用上次确认，不得由 LLM、规则 finding、自动扫描、导入流程或安装流程触发。
- 确认前必须展示 command/interpreter preview、resolved cwd、env preview、network scope 和 files scope。env preview 必须 redacted secrets，files preview 不得读取 arbitrary file content。
- 未确认、权限不足、scope 不完整、未知 requester、LLM-originated action、sandbox unavailable、path/root 校验失败或运行失败，都必须写本地 audit record，状态只能是 `blocked`、`cancelled` 或 `failed`。
- 真实 sandbox runner 未实现前，不得产生 `Completed` execution record，不得保存 stdout/stderr，不得把执行输出写回 skill 文件、catalog frontmatter、LLM prompt/response 或配置文件。
- public release/signing/notarization/DMG 自动化不因该边界完成而变成当前能力；它们仍按 release checklist deferred。

### 2.4.2 V2.30 AI skill analysis 边界（completed）

- 分析路径默认 `read-only`，仅由用户显式触发；支持 `selected` / `batch` 范围。
- 分析默认处于 disabled-by-default 模式，优先本地 `prepare/preview`；当前不执行背景分析，不提供自动重算触发器。
- 默认路径不写文件、不写 agent-config，不建 skill-toggle / skill-content 快照，不执行 `script.execute`。
- V2.30 草稿输出仅作 `review` 与复制使用，不能直接 apply；不会持久化 triage 状态（`Open / Reviewed / Ignored / Needs follow-up`）。
- 当前阶段不读取或写入 LLM credentials；未来 provider 路径需显式 opt-in，并延续 V2.7 的 Keychain 优先边界。

### 2.4.3 V2.41-V2.70 AI-native provider boundary（planned）

**风险**：AI-native 分析会引入真实出站请求、用户配置的 endpoint/API key、prompt 内容、模型响应和成本/调用历史；如果边界不清晰，可能泄露本地路径、skill 内容、agent config、凭据或让 AI 输出绕过安全写入流程。

**缓解**

- Provider 配置只支持用户显式创建的 profile；默认 disabled/unconfigured。
- 支持 OpenAI-compatible 与 Claude-compatible 两类接口标准；不得暗中改写 endpoint 或把请求发往非用户确认的服务。
- API key 优先 Keychain；fallback 文件必须 `0600`，且默认不得保存 secret，除非用户明确选择。
- 每次 provider 请求必须展示：
  - provider/profile/model/base URL
  - prompt scope
  - included/excluded fields
  - redaction summary
  - token/cost estimate
  - 是否会发送 skill body、frontmatter、finding summary、trace excerpt 或 policy context
- Prompt preview 和 redaction 结果可以短暂显示；默认不持久化 raw prompt/response。
- V2.41-V2.42 必须先保存最小非敏感调用审计 metadata：timestamp、provider type、model、destination host、status/error、duration、token/cost、confirmation id、redaction status。保存 raw prompt/response 需要单独设计和明确用户 opt-in，且不得进入普通 report export。
- V2.69 provider observability 只能在上述最小 metadata 上做完整 UI、趋势、失败/限流分析、清理/保留策略和可选脱敏导出；不得把 observability 扩展成 secrets/raw prompt/raw response 存储。
- Imported trace/log 必须本地脱敏后再允许进入 provider prompt；默认不得发送 credentials、tokens、real home paths、temp paths、private URLs 或 raw config secrets。
- AI 输出永远是 untrusted suggestion；写入仍必须走已有 safe write path：preview-first、explicit confirm、snapshot、atomic write、readback verify、rollback。
- AI 不能成为 `ExecutionRequester`，不能创建 `Completed` execution record，不能确认脚本执行。

### 2.4.3.1 V2.43 AI quality score / V2.44 task readiness / V2.45-V2.70 routing planning

- V2.43 质量评分已实现为用户显式触发、默认只读的本地 deterministic scoring；本地默认不做周期性或后台评分。
- V2.44 任务可用性评估已实现为用户显式触发、默认只读的本地 deterministic readiness check；用户输入任务文本后，service 只使用本地 catalog/finding/conflict/analysis/adapter diagnostics/V2.43 quality evidence 生成 score、候选 skill、gap/blocker、evidence references 与 safety flags。
- 本地证据仍是事实来源：`metadata` / `findings` / `conflicts` / `analysis` / `adapter diagnostics` / V2.43 `quality_score`。
- Provider 辅助解释是 optional path，仍需经过：
  - prompt preview
  - redaction summary
  - `included` / `excluded` 字段展示
  - token/cost 估算
  - destination 预览
  - 用户显式确认。
- `task.checkReadiness` 本身不得发起 provider 请求、不得读取 credentials、不得持久化 raw prompt/response、不得写 agent config、不得创建 snapshot、不得改变 triage、不得执行脚本。
- provider 辅助输出仍为 copy/display-only，不直接触发 `config.toggleSkill` / `snapshot.*` / triage 变更 / script execution / new credentials write。V2.45+ routing confidence 仍是 planning。

### 2.4.3 Finding triage persistence 边界（V2.29）

- Finding triage 持久化只发生在 app-local catalog/app data 层，目标是降低重复噪音并提示用户复核；不参与 agent 配置写入，也不改写 skill 内容。
- triage 状态值限定为 `Open` / `Reviewed` / `Ignored` / `Needs follow-up`。
- finding fingerprint 或受影响实例变化时，状态必须回退为 `Open`，防止旧结论静默覆盖新风险。
- triage 操作不能触发脚本执行，不得进行 AI 写回，不得发起 provider 调用，不得写入或读取凭据，也不应触发任何 agent config 快照/回写流程（包括 skill-toggle 或 skill-content snapshot）。

### 2.4.4 Cleanup Queue 边界（V2.31）

- V2.31 将 open findings、完整性问题与 cross-agent analysis insights 汇总成 review queue，只用于 UI 列表化与导航，不定义新的执行动作。
- queue 默认 read-only：允许过滤/排序/跳转到 detail、health、analysis 等已存在的安全通道；不得在 queue 层直接触发写入、安装、脚本执行或 provider。
- queue 不新增持久化实体；其持久状态只复用 V2.29 的 finding triage 状态（Open / Reviewed / Ignored / Needs follow-up），并保持与现有 health/list/detail 口径一致。
- queue 阶段不得增加 credential 持久化、agent-config 写入、snapshot 写入、AI write-back 或 skill-content/safety toggle snapshot 等新路径；建议动作仅可指向现有 guard 流程（toggle/save/rollback）或只读查看路径。

### 2.4.5 Rule tuning / suppression（V2.32）

- 规则调优与 suppression 仅作为本地 review 风险控制，默认不写文件，仅改写 app-local metadata。
- 变更必须可审计且可撤销，并需记录谁/何时/为何进行的上下文信息。
- 该路径不应改写 skill 文件、不改写 agent config、也不创建任何 snapshot。
- 不能触发脚本执行，不可发起 provider 调用，不得读取/写入 LLM credentials。
- 不应产生额外 telemetry、cloud 同步或 release automation 的 side effects。

### 2.4.6 V2.33 Safe batch actions（已完成）

- V2.33 批量 enable/disable 为 preview-first：必须先返回受影响项、跳过项、snapshot/rollback 计划，再由用户二次确认后执行。
- 仅对 verified writable agent/roots 执行；Pi/Hermes/OpenClaw、blocked、或能力不满足项归入跳过集合并给出具体跳过原因。
- 执行仍通过现有 config 写安全链路逐项落盘，不新增 skill-content 写入口径，不触发 `script.execute`，不发起 provider 调用，不写入 credentials，不引入 telemetry。

### 2.5 LLM 凭据泄露

**风险**：用户配的 API key 落到 git 仓库或同步盘。

**缓解**：
- V2.7 当前不保存 credentials，也不读取真实 API key。
- 后续 macOS 凭据存储必须优先使用 Keychain；Linux / Windows 后续分别使用 libsecret / Windows Credential Manager。
- fallback 只允许 `~/.config/skills-copilot/llm.yaml`，创建和读取前必须检查权限为 `0600`；权限不符时拒绝使用。
- 凭据不得写入 SQLite、项目目录、logs、crash report、prompt、request/response artifact 或 smoke fixture。
- fallback 写文件时检测路径是否在同步目录下（iCloud / Dropbox 等），命中则警告并要求用户确认或改用 Keychain。
- 设置页提供"清空所有凭据"按钮；清除操作只触达 OS keyring 或 fallback 文件。

### 2.6 SQL 注入

**风险**：catalog 里有不可信数据，SQL 拼接导致注入。

**缓解**：
- 全部用 `rusqlite` 参数化查询；禁止字符串拼 SQL
- 任何 `pragma` 在迁移时只允许白名单条目
- 写文件路径前用 `Path::canonicalize` 二次校验

### 2.7 IPC / service protocol 滥用

**风险**：UI 端被误调用或传入畸形 payload，伪造 service method。

**缓解**：
- JSON-RPC / typed JSON service method 必须有稳定 schema、参数上限、错误码和 request/response fixture
- macOS SwiftUI shell 只能调用同一 Rust service facade，写操作校验不能只放在 UI shell
- 写类 command 必须二次确认（前端 button + 后端 sanity check）
- 写配置类 service method 可以传配置文本，但后端必须先做格式校验、snapshot、原子写和回读验证；配置文本不得被解释为 shell/系统命令
- sidecar / local socket 只监听本机进程可达范围；如使用 socket，必须使用随机 per-launch token 或 OS 级权限约束，禁止开放到局域网
- 旧 Tauri/Web shell 已删除；当前产品 UI 是 SwiftUI/AppKit 原生壳，不依赖 Web CSP。

### 2.8 供应链

**风险**：依赖被投毒，编译出的二进制里藏后门。

**缓解**：
- 依赖锁文件（`Cargo.lock` + `pnpm-lock.yaml`）随仓库提交
- 本地发布前入口：`pnpm audit:rust` 跑 `cargo audit`，`pnpm audit:node` 跑 `pnpm audit --audit-level high`，`pnpm run audit` 串行执行两者
- CI 跑 `cargo audit` / `pnpm audit`（进入公开分发前接入）
- future distribution binary 由 maintainer 本机构建，签名上传
- 不引入大依赖：评估每个新 crate 的下载量、维护活跃度、是否已被广泛使用

### 2.4.7 V2.34 Cross-agent comparison view（已完成）

风险：comparison 可见性叠加多个 agent 信息时，容易误解为可执行权限变化。

缓解：

- comparison 视图仅做 read-only 说明；不触发新的写路径，不发起 `catalog.scanAll` 之外扫描，不执行脚本、provider 请求、credential I/O、快照创建。
- 对比字段仅来自现有读模型（`catalog.analysis`、`app.stateSnapshot.analysis`、adapter capability），并保留 `Cross-agent` 与 `selected-agent conflict` 的口径隔离。
- comparison 面只提供决策导航（Detail、Health、findings/filter、scan、现有 confirm flow）；禁止直接挂接 apply/toggle/install/rollback 动作。
- 对比输出不新增审计记录；不改变 triage/snapshot/agent-config 持久化边界。

## 3. 权限系统

### 3.1 应用自身（向 OS 申请）

| 权限 | macOS | Linux | Windows | 用途 |
| --- | --- | --- | --- | --- |
| 读 `~/` | User-Selected File (NSOpenPanel) / scoped app data roots | `~/.local/share` 默认 | Documents / UserProfile | 扫描 |
| 写 `~/` | 同上；SwiftUI shell 仍必须经 Rust service 写入 | 同上 | 同上 | toggle / edit |
| 网络出站 | 用户首次启用 LLM 时同意 | 同 | 同 | LLM 调用 |

> 第一次启动不弹任何权限框；只在用户实际触发需要权限的操作时再申请（lazy consent）。
>
> V2.7 当前 prepare/estimate 不需要网络权限，也不得用网络探测 provider 可达性。后续真实 provider 调用必须继续保持默认关闭、用户主动触发，并在调用前展示 provider、model、token/cost 预算。

### 3.2 skill 的权限声明（被记录在 catalog）

| 字段 | 含义 | 默认值 |
| --- | --- | --- |
| `tools` | skill 允许调用的工具列表 | `[]` |
| `files` | 允许读写的路径 glob | `[]` |
| `network` | 网络访问级别 | `None` |
| `exec` | 是否 fork 子进程 | `false` |
| `requires_human` | 执行前是否需要人工确认 | `true`（默认最严） |

> `requires_human: true` 是默认。skill 想默认绕过人工确认，必须 frontmatter 显式 `requires_human: false`，且 UI 显示一个明显提示。

## 4. 配置回滚

每个 agent 配置写操作前落 `config_snapshot`（参见 [data-model.md §3](./data-model.md#3-sqlite-catalog-schema)）。UI 暴露：

- **当前快照**：列出最近快照
- **内容预览**：显示目标配置文件与快照内容
- **一键回滚**：选快照 → 写回 + 触发重扫

MVP 不要求 unified diff 预览和自动淘汰最近 50 份策略；这两项留到 V1/V2 的配置编辑体验与存储维护里处理。

## 5. 隐私 / 数据收集

> 本节是"无 cloud / 无 telemetry / 无崩溃报告"约束的唯一定义点。其它文档（architecture / ai-layer / AGENTS.md / CLAUDE.md）只引用本节，不重复展开。

- **不**上传任何 catalog 内容、文件内容、用户行为
- 当前 V2.7 prepare/estimate 阶段没有 LLM 出站流量；后续唯一允许的出站流量是用户主动启用 LLM 后，对所选 provider 的 API 调用
- "匿名崩溃报告" **首版不实现**；未来要做也必须默认关闭 + opt-in

## 6. 安全 checklist（未来发布前）

> 这些未勾选项是进入公开分发、签名、公证或更大版本发布前的安全门禁；当前阶段尚未做 public release，因此不计入 MVP/V1 完成度。
>
> 2026-06-08 本地抽查：`pnpm run audit` 通过；`cargo audit` 扫描 `Cargo.lock` 后未报告 high/critical，`pnpm audit --audit-level high` 返回 No known vulnerabilities found。
> 同日已建立并运行最小 frontmatter parser fuzz scaffold：`crates/adapters/fuzz/fuzz_targets/frontmatter_parser.rs`。`cargo fuzz list` 能发现 `frontmatter_parser`。本机默认 `cargo` / `rustc` 来自 Homebrew stable，不能直接编译 `-Zsanitizer`；rustup nightly 也曾处于半安装状态。通过 `PATH="$HOME/.cargo/bin:$PATH" rustup toolchain install nightly --profile minimal` 修复 nightly 后，`libfuzzer-sys` 仍需要显式 CLT libc++ include。已成功命令：`SDKROOT=$(xcrun --show-sdk-path); PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=nightly CXX=clang++ CXXFLAGS="-isysroot $SDKROOT -I$SDKROOT/usr/include/c++/v1" cargo fuzz run frontmatter_parser -- -runs=256`，结果 `Done 256 runs in 0 second(s)`。

- [x] `cargo audit` 无 high/critical（入口：`pnpm audit:rust`；2026-06-08 本地通过）
- [x] `pnpm audit` 无 high/critical（入口：`pnpm audit:node`；2026-06-08 本地通过）
- [x] 旧 Web/Tauri UI 攻击面已删除；native macOS 壳通过 SwiftUI/AppKit + Rust service protocol 限制攻击面
- [x] 写路径都用 canonicalize 二次校验（Claude config write/toggle/rollback 已补；scanner 非配置读取面已收紧为按 root source 限定 canonical target base；本切片未发现其它产品任意 FS 写入面）
- [x] 写操作都有 snapshot（Claude Code toggle）
- [x] 关键模块有 fuzz 测试（adapter frontmatter parser scaffold 已建；2026-06-08 本地 `frontmatter_parser` 完成 256 runs；后续发布前可扩展 seed corpus 和更长 runs）
- [ ] future distribution binary 签名

## V2.35 Local report export privacy scope

- Local report export runs on demand and remains local.
- Exported Markdown/JSON artifacts must redact sensitive path information before write:
  - `$HOME`
  - `<project-root>`
  - `<project-cwd>`
  - `<app-data-dir>`
  - `<redacted>` (any non-recoverable or local-only paths)
- V2.35 reports must not include credentials, provider tokens, raw config secrets, or script output.
- V2.35 does not introduce telemetry, cloud sync, remote upload, public distribution, or signed package export.
- V2.35 does not trigger provider calls, credential persistence, or automatic write-back into agent configuration.
- V2.35 privacy verification passed on 2026-06-10 with `pnpm check:privacy` plus a generated report path-redaction check.

## V2.39 OpenClaw scope security note (completed)

- OpenClaw deepening in V2.39 is read-only and workspace-scoped.
- Confirmed roots: `<workspace>/skills` and `<workspace>/.agents/skills` only; no arbitrary repo inference.
- No credential writes/reads, no script execution, no AI-auto write paths, and no public distribution changes are introduced in this milestone.
- These constraints reflect the completed V2.39 implementation boundary.

## 8. Appendix: V2.40 Adapter diagnostics boundary

V2.40 keeps diagnostics strictly read-only. The adapter-diagnostic fields (discovered/skipped/blocked roots, detected config source, read-only/writable reason, last scan activity) are for visibility and audit only.

Implementation note for review:

- No additional credentials are required to render this diagnostic information.
- No script execution, no auto-write paths, and no AI-backed write-back are introduced in this milestone.
- Any future extension must preserve these constraints and pass existing privacy redaction requirements when exporting reports.
