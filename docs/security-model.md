# 安全模型

> skills-copilot 触达的内容天然是"会跑的代码"——skill 自带脚本、被各 agent 加载后会被执行。所以默认策略是 **deny by default、显式 opt-in、最小权限**。本文件把所有攻击面和对应缓解列清。

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

> skill 是用户选择"启用"的对象，所以一旦启用就把对应文件加进 catalog 并允许各 agent 加载。skills-copilot **不**在默认路径自行执行 skill 脚本。
>
> V2.7 LLM 本地辅助分析当前只实现 disabled-by-default gate 和 request prepare/estimate。它不保存 credentials、不创建 provider client、不发起网络请求、不把 LLM prompt/response/token/cost 写入 SQLite、项目目录或 logs。
>
> V2.10 skill execution safety 的当前边界是 default-deny：没有真实执行能力默认开启；任何未来执行请求都必须逐次人工确认，并先展示 cwd/env/network/files 预览；blocked/cancelled/failure attempts 必须留下本地审计记录；LLM 不能触发或确认执行。
>
> Privacy guardrail: repository docs, fixtures, screenshots, and release evidence must not expose real local usernames, home paths, app-data paths, `/var/folders` temp paths, credentials, tokens, private keys, or proxy-managed credential placeholders. Use placeholders such as `$HOME`, `<repo>`, `<worktree>`, `<project-root>`, `<app-data-dir>`, and `<redacted>`, and run `pnpm check:privacy` before commit, push, or handoff.

## 2. 攻击面与缓解

### 2.1 路径穿越 / Symlink 逃逸

**风险**：恶意 skill 用 symlink 指到 `~/.ssh/` 或 `~/.aws/credentials`，让 adapter 解析时读到敏感内容。

**缓解**：
- 解析前 `canonicalize()`，与 `roots()` 返回的允许根比对；不在白名单内 → 拒绝 + 标 `Broken`
- symlink 解析的中间路径必须全部在白名单根内
- Scanner 只读路径边界：每个内置 scan root 先 canonicalize，UserHome / Project root 的真实路径必须仍落在对应 home / project base 内；显式 `Extra` root 视为用户 opt-in 的允许根。每个 symlink target 和 `SKILL.md` 实际路径也 canonicalize；UserHome root 允许跟随仍在当前 user home 内的 symlink，以兼容用户本机 skill 目录复用；Project root 只允许项目 root 内 target；Extra root 只允许当前 canonical scan root 内 target。已访问目录会去重，避免 symlink 目录循环导致重复扫描或 DoS。
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
- 任何写操作前先 `config_snapshot` 落盘
- 原子写：写 `path.tmp` → `fsync` → `rename` 到 `path`
- 写完立即回读校验；不一致则从 snapshot 恢复
- 同一配置文件加文件锁（`fs4::FileExt::lock_exclusive()`，sentinel `.lock` 文件），并发写安全
- 提供"撤销"按钮（基于最近的 snapshot）

### 2.2.1 Repository evidence and privacy leakage

**风险**：validation docs, screenshots, fixtures, changelog entries, or historical commits can accidentally expose local usernames, absolute HOME paths, temporary app-data paths, proxy-managed credential placeholders, or realistic-looking test secrets.

**缓解**：
- Committed docs must use placeholders (`$HOME`, `<repo>`, `<worktree>`, `<project-root>`, `<app-data-dir>`, `<redacted>`) instead of real local paths or usernames.
- Committed screenshots must be app-window-only and must be manually inspected for visible paths, usernames, tokens, and credential placeholders before commit. Raw local captures stay out of git.
- `pnpm check:privacy` scans tracked text, tracked binary string metadata, and reachable history for local-path and secret-like patterns. It is required before commit, push, or release handoff and runs in CI with full history.
- Test fixtures may use explicit non-sensitive placeholders such as `fixture-redacted-value`; they must not use values that look like real tokens or local credentials.
- If privacy checks fail on reachable history, rewrite the affected unpushed or coordinated release branch history before pushing. Do not publish a branch that still contains the leaked blobs.

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

V2.4 把 opencode 作为第三个 adapter 接入 catalog，但没有 writable evidence 前只允许 read-only/native-root-only 行为。

**规则**

- Opencode 扫描根只允许 native roots：用户 `~/.config/opencode/skills` 和当前安全 `ProjectContext` 下的 `.opencode/skills`。
- Opencode 不扫描 `.agents/skills` 或 `.claude/skills` compatibility roots；这些目录分别归 Codex / Claude Code native adapter 管理，避免同一 skill 被重复归属或绕过各 adapter 的安全边界。
- Project boundary 与 V2.2 相同：project opencode root 必须 canonicalize 到当前 active project root 内；no-project 下只扫描 global opencode root，不扫描或重归属 project-local rows。
- `config.toggleSkill` 对 opencode 必须保持 read-only/unsupported。UI 应在调用 service 前禁用 opencode toggle 并显示 read-only adapter reason；直接 service 调用返回 unsupported/read-only error，且不得创建或修改任何 opencode config。
- Smoke fixture 只能使用临时 `HOME` 和临时 project roots 创建 opencode native roots；不得读取、创建或修改真实用户 opencode config。
- Writable opencode 行为（`permission.skill` exact patch、wildcard precedence、managed config、re-enable semantics）必须等 disposable local round-trip 或 maintainer spec 验证后才能进入实现。

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
- LLM 输出限定为 JSON schema，解析失败直接丢弃
- LLM 输出**永远不**进入 IPC 命令、不进入 catalog
- UI 渲染 LLM 文本时按纯文本处理（不解析 markdown 里的链接作为命令）
- 用户从 LLM 拿到的 `draft_frontmatter` 只是草稿展示/复制内容，不存在 Apply / Write；真实写入必须由用户进入正常编辑/保存路径，并经 Rust service 的格式校验、snapshot、原子写和回读验证

### 2.4.1 Skill execution safety boundary（V2.10）

**风险**：恶意 skill 把脚本、shebang、命令片段或 LLM 生成的建议伪装成可执行操作，诱导应用或用户在不清楚 cwd/env/network/files 范围时运行代码。

**缓解**：
- 默认不真实执行 skill 脚本；scan、detail、import、export、install、state snapshot 和 LLM prepare 都必须保持 non-execution。
- 任意未来执行入口必须只接受用户主动触发，逐次确认；不得复用上次确认，不得由 LLM、规则 finding、自动扫描、导入流程或安装流程触发。
- 确认前必须展示 command/interpreter preview、resolved cwd、env preview、network scope 和 files scope。env preview 必须 redacted secrets，files preview 不得读取 arbitrary file content。
- 未确认、权限不足、scope 不完整、未知 requester、LLM-originated action、sandbox unavailable、path/root 校验失败或运行失败，都必须写本地 audit record，状态只能是 `blocked`、`cancelled` 或 `failed`。
- 真实 sandbox runner 未实现前，不得产生 `Completed` execution record，不得保存 stdout/stderr，不得把执行输出写回 skill 文件、catalog frontmatter、LLM prompt/response 或配置文件。
- public release/signing/notarization/DMG 自动化不因该边界完成而变成当前能力；它们仍按 release checklist deferred。

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

每个写操作前落 `config_snapshot`（参见 [data-model.md §3](./data-model.md#3-sqlite-catalog-schema)）。UI 暴露：

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
