# skills-copilot Service Protocol

> Status: V2.31 Cleanup Queue is integrated; V2.32 Rule tuning / suppression is active. Hermes and OpenClaw read-only scanners, V2.18 cross-agent analysis, V2.19 health dashboard, V2.20 read-only AI skill analysis assist, V2.21 scan accuracy/dedupe alignment, V2.22 finding/conflict semantics, V2.23 Health Dashboard / Adapter Capability UX, V2.24 Skill Detail diagnostics, V2.25 Agent-config timeline, V2.26 Finding explainability, V2.27 Skill identity/provenance dedupe, V2.28 Conflict semantic closeout, V2.29 Finding triage persistence, V2.30 AI skill analysis workflow, and V2.31 Cleanup Queue are implemented or synchronized. V2.30 adds `llm.prepareSkillAnalysis` for user-triggered selected/batch read-only previews; it does not call providers by default, write files/config, create snapshots, execute scripts, save credentials, or mutate triage state. V2.31 adds `cleanup.listQueue` as a read-only aggregation method; it does not add write, execution, provider, credential, or snapshot methods.
>
> Integrated: V2.9 Tool-global import/export/install, V2.10 skill execution safety boundary, and 2026-06-10 real local Computer Use validation for the current mainline app. V2.11 added adapter capability status to the service protocol and macOS UI. V2.12 marks opencode writable through exact permission.skill deny/re-enable after snapshot/rollback, install, and fixture smoke validation pass; current opencode scan follows native plus official compatibility roots while install targets remain native roots.
>
> Product boundary: this protocol is the only supported boundary for the macOS native shell. Historical Tauri commands remain only in MVP documentation and git history.
>
> Project Context implementation and automated validation are complete. Future user-visible, UI, or service protocol changes must still rerun the real local Computer Use pass and keep any new blocker separate from implementation completion.

## Goals

- Keep product UI shells independent from Rust internals.
- Let the native macOS app call stable method names, payloads, errors, and fixture cases.
- Avoid committing the app to Tauri IPC, Swift-only bindings, or a long-running daemon too early.

## Runtime Shape

The first implementation is a short-lived stdio sidecar:

```json
{"id":"req-1","method":"catalog.listSkills","params":{}}
```

The sidecar returns one JSON object. `service.status` includes `protocol_version`; the current protocol version is `1`.

```json
{"id":"req-1","ok":true,"result":[]}
```

Failures keep stable machine-readable codes:

```json
{"id":"req-1","ok":false,"error":{"code":"unknown_method","message":"unknown method: x"}}
```

This stdio shape can later move behind a local socket without changing method payloads.

## Methods

| Method | Mutates local state | Current client use | Result |
| --- | --- | --- | --- |
| `app.version` | No | Native macOS About / compatibility checks | app version and protocol version |
| `app.stateSnapshot` | No | Native macOS launch/read flow | status plus current skills, findings, conflicts, cross-agent analysis, skill health summary, and compatibility snapshot payload |
| `service.status` | No | Diagnostics, adapter gating, and smoke tests | protocol version, app version, app data dir, catalog path, user home, supported methods, adapter capabilities, refresh capability state, and LLM gate status |
| `adapter.listCapabilities` | No | Native macOS agent selector/status gating | adapter capability matrix for scan, project scan, config toggle, config snapshot, install, writable state, and current blockers |
| `llm.status` | No | Native macOS LLM affordance gating | disabled-by-default LLM status: enabled/configured/provider/model/reason/token limit/budget/credential persistence policy |
| `llm.prepareAction` | No | Native macOS user-triggered LLM preflight | user-triggered selected/batch preflight, optional provider/model/token/cost estimate, confirmation requirement, prompt scope, privacy notes, deterministic read-only review preview, and write-back guard for a requested LLM action |
| `llm.prepareSkillAnalysis` | No | Native macOS user-triggered selected/batch skill analysis preview | deterministic local read-only summary/risk/cleanup draft, included/missing skill counts, token estimate, and safety flags with write-back/script/credential storage disabled |
| `script.previewExecution` | No | Native macOS script safety preview | command/cwd/env/network/files previews, risks, and confirmation requirement |
| `script.execute` | No | Native macOS script execution intent (default-deny path) | blocked/cancelled/failed attempt audit with redacted preview metadata; no real execution while runner is deferred |
| `project.getContext` | No | Native macOS project selector/read flow | `{ active: ProjectContext|null, recent: ProjectContext[] }` |
| `project.setContext` | Yes, writes app state | Native macOS project selector | validates and stores `{ root_path, current_cwd?, name? }`, then returns project context state |
| `project.clearContext` | Yes, writes app state | Native macOS project selector | clears active context, keeps recent contexts |
| `project.validateContext` | No | Native macOS project selector preflight | validates `{ root_path, current_cwd?, name? }` and returns a `ProjectContext` with `validation_error` set on failure |
| `catalog.listSkills` | No | Native macOS launch/read flow | `SkillRecord[]` |
| `catalog.getSkill` | No | Native macOS Overview detail / single skill detail workbench | `SkillDetailRecord` for `{ "instance_id": "..." }` |
| `catalog.analysis` | No | Native macOS analysis/read flow（read-only/offline） | `CrossAgentAnalysisRecord` grouping duplicate names, canonical-name overlap, shared source paths, enabled-state mismatches, broken/missing rows, and supported precedence/shadowing explanations |
| `catalog.listFindings` | No | Native macOS Findings segment（问题分组，issue groups） | `RuleFindingRecord[]` |
| `catalog.listConflicts` | No | Native macOS Conflicts segment（仅当前 selected/current agent） | `ConflictGroupRecord[]` |
| `catalog.importSkill` | Yes, writes app-controlled staging/catalog only | V2.9 tool-global import | imported read-only `SkillRecord`, staging path, filtered findings, and audit summary |
| `catalog.scanAll` | Yes, refreshes catalog | Native macOS toolbar Scan action | scanned count, refreshed `SkillRecord[]`, and refresh activity summary for supported adapters |
| `catalog.scanClaude` | Yes, refreshes catalog | Compatibility / Claude-only diagnostics | scanned count, refreshed `SkillRecord[]`, and refresh activity summary |
| `skill.exportBundle` | Yes, writes app-controlled export files | V2.9 local tool-global/staging export | manifest path, bundle path, fingerprint, and reproducible metadata |
| `skill.install` | Yes, after confirmation | V2.9 install/copy from tool-global to target agent | preview or completed install record with target path, files, risks, confirmation, and optional snapshot id for future config-backed installs |
| `skill.listEvents` | No | Native macOS skill detail Recent Activity | recent local `skill_event` records for `{ "instance_id": "...", "limit"?: 12 }` |
| `config.toggleSkill` | Yes, writes agent config | Native macOS Enable / Disable action | updated `SkillRecord` |
| `config.readClaudeSettings` | No | Native macOS Settings editor load action | `ConfigDocumentRecord` |
| `config.saveClaudeSettings` | Yes, writes Claude settings and rescans | Native macOS Settings editor Save action | saved `ConfigDocumentRecord` |
| `snapshot.list` | No | Compatibility / diagnostics | global `ConfigSnapshotRecord[]` (app-level, not skill-content snapshots) |
| `snapshot.listAgentConfig` | No | Native macOS Agent Config History（仅 toggle/config history） | agent-config `ConfigSnapshotRecord[]` filtered by `{ "agent": "...", "scope"?: "agent-global" }` |
| `snapshot.previewRollback` | No | Native macOS Agent Config History preview action | snapshot, current content, read error, changed flag, and diff payload for UI review |
| `snapshot.rollback` | Yes, writes agent config snapshot content and rescans | Native macOS Agent Config History rollback action | rescanned skill count after confirmation-driven restore |

`catalog.scanAll` is the native UI scan path.

It currently scans:

- Claude Code
- Codex
- opencode (verified writable through managed permission overrides; scans native plus official compatibility roots)
- Pi (read-only native roots)
- OpenClaw (read-only filesystem roots)
- Hermes (read-only active/profile home skills)

It resolves the effective `ProjectContext` before adapter scanning.

## V2.24 Skill Detail 诊断工作台（完成）

V2.24 将 `catalog.getSkill` 与 detail 视图收敛为单 skill 诊断工作台，不新增 method：

- **Detail 定义**：Detail 为单个 skill 的诊断工作台，负责展示该 skill 的定义、finding、conflict、analysis 及 history 信息。
- **Findings 定义**：`catalog.listFindings` 口径为 issue groups，与 health 计数与筛选口径对齐。
- **Conflicts 定义**：`catalog.listConflicts` 仅返回 selected/current agent 的 runtime/name collision，保持 current-agent scope。
- **Analysis 定义**：`catalog.analysis` 为 read-only/offline 的 cross-agent 分析洞察，不触发写入、不调用外部服务。
- **History 定义**：`snapshot.list` / `snapshot.listAgentConfig` / `skill.listEvents` 在 V2.24 口径下仅用于 toggle/config 相关历史；不新增 skill-content snapshot。
- **边界限制**：本阶段不新增 skill-content snapshot，不新增脚本执行或写入路径，detail 仅消费可读数据并发起已存在的受控 toggle/save/rollback 动作。

该 section 是当前完成口径；未来 detail 相关 UI/protocol 变更必须继续遵守该边界。

## V2.25 Agent-config timeline（完成）

V2.25 聚焦 agent-config snapshot timeline 收敛，仍不新增 protocol method：

- **scope 定义**：`snapshot.listAgentConfig` 仅返回 agent-config 层面的快照历史（toggle/config）与可选 scope；不承担 skill-content 快照、skill-toggle 快照或 content snapshot 的历史职责。
- **按 agent 分片**：时间线按单个 agent 维持独立事件序列；UI 可以按 `agent` 过滤，但不得将多 agent 条目合并为 selected skill 的 detail history。
- **rollback 前置流程**：`snapshot.previewRollback` 先行返回当前内容、目标快照与 diff，供用户确认是否进行回滚；未经过 preview 的回滚不算通过口径验收。
- **二次确认**：`snapshot.rollback` 在 preview 核验后仍需用户二次确认，且与现有 `confirmed=true` 机制互斥表达，避免单击误操作即立即回滚。
- **只读边界**：本阶段不做 skill-content snapshot，不做 skill-toggle snapshot，不把 detail 的 finding/conflict 历史与 agent-config timeline 混在一个视图中。

该 section 是当前完成口径；当前实现仍以现有 method 与现有 payload 执行，未来 rollback 相关 UI/service 变更仍需重新验证。

## V2.26 Finding explainability（完成）

本阶段要求现有 `catalog.listFindings` 与 `app.stateSnapshot.health` 产生可解释、可追溯、可 drill-down 的 finding issue group：

- `catalog.listFindings` 仍为 read-only。
- 一个 finding group 必须暴露下列解释元数据：
  - `finding_group_id`：用于 Health/Detail/Detail drill-down 的稳定分组 ID。
  - `rule_id` + `rule_source`：规则来源（rule 集、扫描器、版本）。
  - `trigger`：`trigger_reason` 与 `trigger_message`，说明为什么当前上下文出现该 finding。
  - `affected_instances`：受影响 `instance_id[]` 列表。
  - `scan_entries`：至少一个扫描证据 tuple（`agent`、`scope`、`definition_id`、`path`、`root`）。
  - `severity`：error/warn/info。
  - `risk_subset`：是否属于 health 风险子集（例如 `is_risky`、`risk_reason`、`risk_kind`）。
  - `next_action`：建议的下一步动作（例如 open detail、open health card、refresh scan）。
- `app.stateSnapshot.health` 的 finding 计数与 `catalog.listFindings` 的 issue group 数必须同口径。
- Health 卡片到 Detail 的 drill-down 必须按 `{ finding_group_id, rule_id, severity, affected_instance_ids, scan_entries }` 回到同一可见实例集，不新增协议口径也不改变 payload。
- 本阶段不新增 protocol method；仅通过现有查询字段与 payload 展示字段增强解释性。
- 所有解释信息必须保持既有边界：`script.execute` 不在本阶段执行；no automatic writes；`llm.prepareAction` 仍是 read-only preview；不读取/保存 credentials。

示意返回片段：

```json
{
  "finding_group_id": "fg::permission.unknown::claude-code::abc123",
  "rule_id": "permissions.unknown",
  "rule_source": "core.rules@V2.26",
  "trigger_reason": "missing-explicit-permission",
  "trigger_message": "Permission block not declared as explicit grant/deny pair.",
  "severity": "warning",
  "affected_instances": ["instance-001", "instance-009"],
  "scan_entries": [
    { "agent": "claude-code", "scope": "agent-global", "definition_id": "def-abc", "path": "/repo/skills/A/SKILL.md", "root": "/repo/skills" }
  ],
  "risk_subset": { "is_risky": true, "risk_kind": "permission", "risk_reason": "Missing permissions field requires safe default handling." },
  "next_action": "open_skill_detail"
}
```

## V2.27 Skill identity/provenance dedupe（完成）

- Identity for dedupe/provenance is documented as `(agent, scope, definition_id, path)`. `definition_id` uses canonical skill name identity, `path` is canonicalized absolute path, and `scope` keeps project vs global visibility explicit.
- Analysis payloads and scan activity summaries should preserve a stable provenance label for each visible row; opencode entries must be distinguishable as `native` vs `compatibility` roots in scan entries, catalogs, and UI drill-down.
- Pi scans remain directory-rooted; only directory `SKILL.md` instances are cataloged. Standalone `.md` files at `pi-root/SKILL.md`、`*.md` direct files、以及 `references/SKILL.md` 噪声应被过滤，避免伪阳性。
- Conflict semantics unchanged from V2.22: cross-agent duplicate names、source-overlap、enabled-state mismatch remain analysis groups; `catalog.listConflicts` keeps selected-agent runtime/name collision only.

## V2.29 Finding triage persistence（completed）

- Finding triage state is persisted only in app-local catalog/app data and exposed on existing finding list/detail payload flows.
- 每个 finding issue group 采用 `Open / Reviewed / Ignored / Needs follow-up`，初始缺省为 Open。
- 复查规则：finding fingerprint 或受影响实例集合（instance signature）变化时，已持久化 triage 状态应回到 Open，用于重新提示。
- 本阶段禁止任何 agent-config 持久化路径参与 triage 存储；不得产生 skill-toggle snapshot 或 skill-content snapshot；不得将 triage 改动与脚本执行、provider 调用、AI 回写、凭据写入耦合。

## V2.30 AI skill analysis workflow（completed）

- Scope: AI analysis must be user-triggered, `selected` or `batch` scoped, and never background/scheduled.
- `llm.prepareSkillAnalysis` returns a deterministic local-only review preview by default, including:
  - risk summary
  - finding/risk explanation
  - cleanup/suggestion draft
- Drafts are `copy-only`; no action path consumes these drafts directly as write/apply operations.
- Provider networking is out of default scope for this phase (`llm.prepareAction` remains read-only unless explicit opt-in and explicit provider path is implemented later).
- No files are written by analysis action; no `agent-config` writes, no `snapshot` writes, no skill-content/skill-toggle snapshot generation, and no script execution.
- Analysis call result must not mutate finding triage state, and must not create credentials side effects.

## V2.31 Cleanup Queue（completed）

- Scope: The cleanup queue is an app-local review surface composed from existing read-only protocol payloads and exposed through `cleanup.listQueue`; no new write, execute, provider, credential, or snapshot protocol method is introduced.
- Composition source:
  - open findings from `catalog.listFindings` (issue groups with triage state),
  - integrity-related issue indicators from existing health/finding diagnostics,
  - cross-agent analysis from `catalog.analysis`.
- Behavioral boundary:
  - queue is read-only by default (list/filter/search/ordering);
  - queue entries are actionable only through existing safe action surfaces (open detail, apply existing filters, `catalog.scanAll`/refresh, existing toggle/rollback path, etc.);
  - queue itself does not trigger scans, config writes, installs, script execution, provider calls, credential writes, snapshot creation, or other automatic remediation actions.
- Data model boundary: no new persistence entity is introduced for queue rows. Existing V2.29 triage persistence state is reused, and queue render state can be recomputed on each relevant read request.

## V2.18 Cross-Agent Analysis Payload


`catalog.analysis` and `app.stateSnapshot.analysis` return the same read-only, computed-on-demand payload. The service derives it from visible catalog rows after applying the effective project context; it does not read agent config, write files, execute scripts, call agent CLIs, or infer unsupported adapter roots.

V2.22 对齐说明：该 API 仅用于 **cross-agent** 分析洞察（duplicate name、canonical overlap、source path overlap、enabled mismatch、malformed、precedence）。同-agent 的 runtime/name 冲突不在此聚合；同-agent 冲突只在 `catalog.listConflicts` 中体现。

This API is read-only by contract: `mutated` behavior is always false even though the payload does not carry a `mutated` flag. It must not trigger writes, config changes, installs, CLI actions, script execution, or unsupported-root inference.

```json
{
  "summary": {
    "total_groups": 3,
    "duplicate_name_groups": 1,
    "canonical_name_groups": 1,
    "path_overlap_groups": 0,
    "enabled_mismatch_groups": 1,
    "malformed_groups": 0,
    "precedence_groups": 1,
    "affected_skill_count": 4
  },
  "groups": [
    {
      "id": "analysis:duplicate_name:abc123",
      "kind": "duplicate_name",
      "severity": "warning",
      "title": "Duplicate skill name 'review-diff' appears in 2 records.",
      "canonical_name": "review-diff",
      "explanation": "Multiple visible skills use the same name. Agents load independently, so this is not automatically a runtime conflict across agents, but users may see ambiguous skills in the catalog.",
      "instance_ids": ["claude-id", "codex-id"],
      "agents": ["claude-code", "codex"],
      "scopes": ["agent-global"],
      "paths": ["/path/to/SKILL.md"]
    }
  ]
}
```

Analysis group kinds:

- `duplicate_name`: same visible skill name after case-insensitive comparison.
- `canonical_name_overlap`: different visible names normalize to the same canonical slug.
- `source_path_overlap`: the same physical `SKILL.md` path is represented by multiple catalog rows.
- `enabled_state_mismatch`: related skills have mixed `enabled` values or loaded/disabled/shadowed/broken/missing states.
- `malformed_or_broken`: visible rows are `broken` or `missing`.
- `precedence_shadowing`: same-agent same-canonical-name rows where project/global precedence or existing `shadowed` state can be explained from adapter evidence.

Precedence notes are intentionally conservative. The service may choose a `winner_id` only inside one agent's visible rows, preferring loaded/enabled project-scoped rows over agent-global rows. Cross-agent duplicate names never imply shared runtime precedence because each agent loads its own roots independently.

## V2.19 Skill Health Summary Payload

`app.stateSnapshot.health` returns an additive, read-only summary derived from the same visible catalog rows, findings, conflicts, and cross-agent analysis groups. It does not write agent configs, import skills, execute scripts, call provider APIs, or infer unsupported roots.

The summary includes total/enabled/disabled counts, broken/missing/malformed counts, finding counts by severity, conflict counts, risky script and permission counts, cross-agent analysis group counts, and per-agent summaries for native dashboard and read-only triage filters. Per-agent finding and risk counts are instance-scoped by `instance_id`; definition-only findings are not expanded across same-name skills. Per-agent conflict counts only include conflicts where at least two instances from that same agent participate; cross-agent duplicate names, source overlap, or enabled-state mismatch remain in `catalog.analysis`, not in a selected agent's skill conflict detail. V2.29 开始支持 finding 状态持久化为 app-local triage（reviewed / ignored / needs follow-up）。该持久化只用于 issue-group 层面的 triage，不写入 agent config，不创建 skill-toggle 或 skill-content snapshot，不触发脚本执行、AI 回写或凭据持久化。finding fingerprint 或受影响实例集合变化时，triage 自动回退到 Open。

健康口径（health）与 detail/list 过滤必须使用同一实例可见性定义；`finding_count` 与 issue group 口径一致，`conflict_count` 不从 cross-agent duplicate/source overlap 口径叠加，且应可与 `catalog.analysis` 分组数量在同一扫描上下文下对齐。V2.23 要求这些数字用于 sidebar 行动摘要卡片，而非重复统计表。

Example shape:

```json
{
  "total_count": 12,
  "enabled_count": 8,
  "disabled_count": 4,
  "broken_count": 1,
  "missing_count": 1,
  "malformed_count": 2,
  "finding_count": 5,
  "conflict_count": 2,
  "risky_script_count": 1,
  "risky_permission_count": 2,
  "findings_by_severity": { "error_count": 1, "warning_count": 3, "info_count": 1 },
  "analysis_groups": { "total_count": 3, "duplicate_name_count": 1, "precedence_count": 1 },
  "agent_summaries": [
    { "agent": "codex", "total_count": 3, "finding_count": 1, "conflict_count": 1 }
  ]
}
```

## V2.23 Health / Adapter Capability Alignment（完成口径）

V2.23 已完成当前文档与验收口径：

- `catalog.listConflicts` 与 Health conflict 卡片共享口径：仅 current selected/current agent 的 runtime/name collision。
- `app.stateSnapshot.health` 与 `finding` 过滤一致：`finding_count` 与问题分组（issue group）默认口径一致；不得与 `catalog.analysis` 的 cross-agent 组重复叠加。
- sidebar 仅展示 current selected/current agent 的卡片，不以 `catalog.analysis` 或全量 analysis 数字填充侧栏。
- `adapter.listCapabilities` / `service.status.adapter_capabilities` 必须显示每项能力 `scan` / `config_toggle` / `install` / `writable` 的显式 supported、状态、原因，并清晰标注 read-only 与 blocked。
- Detail 口径补充：Findings 映射 issue groups，Conflicts 仅 selected/current agent；Analysis read-only/offline；History 限 toggle/config event（history 仅 agent-config 轨迹，不做 skill-content snapshot）。

上述要求不引入新 method；请仅通过现有 payload 的可解释字段驱动 UI。

## Adapter Capability Payload

`adapter.listCapabilities` and `service.status.adapter_capabilities` expose the same additive protocol v1 matrix:

```json
{
  "agent": "opencode",
  "display_name": "opencode",
  "status": "verified",
  "scan": { "supported": true, "status": "verified" },
  "project_scan": { "supported": true, "status": "verified" },
  "config_toggle": {
    "supported": true,
    "status": "verified-exact-skill-deny",
    "reason": "V2.12 writes exact permission.skill.<name> = deny and re-enables by removing that exact deny without changing wildcard rules."
  },
  "config_snapshot": {
    "supported": true,
    "status": "verified",
    "reason": "opencode global/project opencode.json writes use snapshot, atomic write, verify, and rollback."
  },
  "install": {
    "supported": true,
    "status": "verified",
    "reason": "Tool-global skills can be installed to native opencode user/project skill roots after confirmation; compatibility roots are scanned but not install targets."
  },
  "writable": {
    "supported": true,
    "status": "verified",
    "reason": "Writable support uses managed exact skill permission overrides; file installs stay limited to native opencode roots."
  },
  "blockers": [
    "Scan official opencode compatibility roots as read-only sources; keep custom skills.paths and skills.urls deferred."
  ]
}
```

Current matrix（V2.23 对齐口径）:

| Agent | Top-level status | Scan | Toggle | Install | Writable | Read-only/Blocked |
| --- | --- | --- | --- | --- | --- | --- |
| Claude Code | `verified` | Supported | Supported（verified settings writes） | Supported（tool-global install to verified target） | Supported | `none` |
| Codex | `verified` | Supported | Supported（user `config.toml` only） | Supported（tool-global install to user/project roots） | Supported（用户级 settings patch） | `project-local` blocked |
| opencode | `verified` | Supported（native + official compatibility roots） | Supported（managed exact `permission.skill` deny/re-enable） | Supported（native-root install target） | Supported（managed permission overrides） | `custom skills.paths/urls` blocked |
| Pi | `read-only` | Supported（Pi-native roots） | Blocked（evidence harness pending） | Blocked | Blocked | `read-only` |
| Hermes | `read-only` | Supported（active/profile Hermes home skills） | Blocked | Blocked | Blocked | `read-only; generic project scan and writes blocked` |
| OpenClaw | `read-only` | Supported（documented filesystem roots） | Blocked | Blocked | Blocked | `read-only; workspace-scoped project roots only` |

Native UI must use this matrix for affordance gating and explanations. It must not infer write support only from an agent name.

The following APIs remain intentionally Claude-specific compatibility/config-editor APIs:

- `catalog.scanClaude`
- `config.readClaudeSettings`
- `config.saveClaudeSettings`

Protocol v1 keeps execution methods in default-deny mode.

Execution boundary:

- `script.previewExecution` and `script.execute` are preflight / intent methods only.
- No real process execution occurs while the local sandbox runner is deferred.
- Unknown execution-like method names must return the normal `unknown_method` error.
- Unknown execution-like methods must not spawn a process, open a network connection, read undeclared files, or write an execution log.

## V2.9 Tool-global Import Payload

`catalog.importSkill` imports a local directory containing `SKILL.md` into the app-controlled tool-global staging area. It does not write agent config. Imported records use `agent = "tool-global"` and `scope = "tool-global"` so adapter scans do not confuse staged content with Claude/Codex/opencode roots.

```json
{
  "source_path": "/tmp/source-skill"
}
```

The result returns the read-only staged record plus audit data:

```json
{
  "imported": { "id": "tool-id", "agent": "tool-global", "scope": "tool-global" },
  "instance_id": "tool-id",
  "source_path": "/tmp/source-skill",
  "staging_path": "/tmp/app-data/tool-global/skills/demo/SKILL.md",
  "findings": [],
  "audit": {
    "status": "completed",
    "read_only_preview": true,
    "finding_count": 0,
    "error_count": 0,
    "warn_count": 0,
    "info_count": 0,
    "conflict_count": 0
  }
}
```

GitHub repo import is explicitly deferred in V2.9. Passing `github_url` returns a stable unsupported error and performs no clone/network/write.

## V2.9 Local Export Bundle Payload

`skill.exportBundle` creates a local directory bundle. It does not sign, zip, publish, or install the skill into any agent. The bundle contains:

- `manifest.json`
- `skill/SKILL.md`

The request accepts exactly one source:

```json
{
  "instance_id": "catalog-skill-instance-id",
  "output_dir": "/tmp/skills-copilot-exports"
}
```

or:

```json
{
  "source_path": "/tmp/skills-copilot-staging/demo/SKILL.md",
  "output_dir": "/tmp/skills-copilot-exports"
}
```

`source_path` may point at a skill directory or at `SKILL.md`. If `output_dir` is omitted, the service writes under `<app-data-dir>/exports`.

The result returns local paths plus stable metadata:

```json
{
  "manifest_path": "/tmp/skills-copilot-exports/demo/manifest.json",
  "bundle_path": "/tmp/skills-copilot-exports/demo",
  "fingerprint": "sha256-content-fingerprint",
  "metadata": {
    "name": "demo",
    "description": "Fixture skill",
    "skill_path": "skill/SKILL.md",
    "source_agent": "skills-copilot",
    "source_scope": "tool-global",
    "version": "2.9.0"
  }
}
```

`manifest.json` is reproducible JSON with `manifest_version`, `bundle_format`, `metadata`, `fingerprint`, and `permissions`. Reproducible fields must use bundle-relative paths only; absolute paths are limited to service response fields such as `manifest_path` and `bundle_path`. Reimport validation recomputes the fingerprint from `skill/SKILL.md` and preserves manifest metadata when content matches.

## V2.9 Tool-global Install Payload

`skill.install` copies an existing `tool-global` catalog record into a target agent root. Preview and install use the same method. Preview is non-mutating:

```json
{
  "instance_id": "tool-id",
  "target_agent": "claude-code",
  "target_scope": "agent-global",
  "confirmed": false
}
```

Confirmed install requires the same target fields with `confirmed = true`. The result includes source/target paths, copied files, risk notes, confirmation metadata, `wrote`, and a `snapshot_id` field for protocol compatibility. Current direct skill-file installs do not create config snapshots.

```json
{
  "source_instance_id": "tool-id",
  "source_path": "/tmp/app-data/tool-global/skills/demo/SKILL.md",
  "target_agent": "claude-code",
  "target_scope": "agent-global",
  "target_path": "$HOME/.claude/skills/demo/SKILL.md",
  "wrote": false,
  "files": [{ "source": "/tmp/app-data/tool-global/skills/demo/SKILL.md", "target": "$HOME/.claude/skills/demo/SKILL.md", "kind": "skill", "will_write": true, "target_exists": false }],
  "risks": ["Will write into the claude-code agent-global skill root through the verified install path."],
  "confirmation": { "required": true, "confirmed": false, "message": "Confirm install to copy this tool-global skill into the selected agent root.", "fields": ["source_instance_id", "source_path", "target_agent", "target_scope", "target_path", "files", "risks"] },
  "snapshot_id": null
}
```

Rules:

- Tool-global records are read-only previews in list/detail surfaces; `config.toggleSkill` must not be used for them.
- `confirmed=false` is non-mutating and must not copy skill content, write agent config, or modify catalog state.
- `confirmed=true` must require target agent/scope/path confirmation and routes through the target adapter's verified write path.
- Claude/Codex writable installs use verified target paths, locked/atomic writes, read-back verification, and target-adapter rescan. They do not create skill-content snapshots.
- Opencode remains read-only; install attempts return a stable unsupported/read-only error.
- `tool.previewInstall` is not part of the current service-supported method list; native clients may keep it only as a compatibility fallback after `skill.install` returns `unknown_method`.

## V2.10 Skill Execution Safety Boundary

V2.10 defines the safe boundary for script execution without adding a real script runner. The default state is non-execution: catalog/detail surfaces may show `SkillScript` metadata and rule findings, but the service must not execute skill scripts as part of scan, import, export, install, LLM prepare, state snapshot, or detail loading.

Any future execution path must be a user-initiated request with a fresh confirmation. A preflight must show at least:

- selected `skill_instance_id` and script/command label
- command/interpreter preview without secret expansion
- resolved cwd
- environment preview, with secrets redacted and implicit inherited env called out
- network scope
- readable/writable file scope
- confirmation state and the user-visible reason execution is blocked or allowed

Audit records for execution attempts are required even when no process is spawned. Current V2.10-safe statuses are `blocked`, `cancelled`, and `failed`; a `completed` status must not be emitted until a real sandboxed runner exists. Audit records must include request time, requester kind, selected skill/script identity, confirmation state, cwd/env/network/files preview, status, reason/error code, and enough UI context to explain the decision. They must not include secret env values, arbitrary file content, stdout/stderr from untrusted commands, provider prompts, or LLM output.

LLM actions cannot cross into execution. `llm.prepareAction` remains a read-only estimate/preflight method and cannot call any execution method, set `confirmed=true`, synthesize a user confirmation, or turn model output into a command.

## LLM Gate Payload

V2.7 exposes only a local, disabled, no-provider LLM gate. The service does not implement a real provider, does not read credentials, does not write credentials to SQLite or project directories, and does not perform network I/O.

`service.status.llm` and `llm.status` return:

```json
{
  "enabled": false,
  "configured": false,
  "provider": null,
  "model": null,
  "reason": "LLM actions are disabled by default; no local provider is configured.",
  "single_request_token_limit": 8000,
  "monthly_budget_usd": 0.0,
  "credentials_storage": "none",
  "credential_persistence_allowed": false
}
```

`llm.prepareAction` accepts:

```json
{
  "kind": "analyze",
  "skill_instance_id": "skill-instance-id",
  "user_intent": "Explain the security posture of this skill."
}
```

Supported `kind` values are `analyze`, `recommend`, `explain_conflict`, and `draft_frontmatter`. `analyze` and `draft_frontmatter` require an existing catalog `skill_instance_id`; the service reads only the selected catalog record to estimate prompt tokens from name, description, frontmatter, and body, but does not return paths, body text, credentials, or arbitrary file content. `recommend` estimates from explicit `user_intent`. `explain_conflict` estimates from current conflict and finding summaries.

The result is a preflight only: `allowed` is currently `false`, `requires_confirmation` is `true`, `write_back_allowed` is always `false`, and `draft_requires_user_copy` is always `true`. The response includes provider/model placeholders, estimated input/output/total tokens, estimated cost, prompt scope labels, privacy notes, and a deterministic `review_preview` suitable for UI display.

V2.20 adds `review_preview` as an offline/read-only assist payload. It may summarize selected skill purpose, risk signals, rule finding explanations, and cross-agent fit from already cataloged metadata. It is generated by the Rust service, not a provider; `provider_request_sent`, `write_actions_available`, and `execution_actions_available` are always `false`. The preview must not return skill source paths, raw skill body, raw frontmatter, credentials, provider prompts, provider responses, Apply/Write/Execute affordances, or imports/config changes.

## Project Context Payload

`ProjectContext` is the UI/service description of the active project selection:

```json
{
  "id": "sha256(root_path)",
  "name": "skills-copilot",
  "root_path": "<project-root>",
  "current_cwd": "<project-root>/apps/macos",
  "last_used_at": 1780876800000,
  "is_active": true,
  "validation_error": null
}
```

Rules:

- `ProjectContextState` is `{ active: ProjectContext|null, recent: ProjectContext[] }`.
- `source` is reported in `service.status.project_context.source`, not on each `ProjectContext`; current values are `env`, `stored`, or `none`.
- In no-project mode, `active` is `null` and `recent` remains the persisted recent-project list.
- `project.setContext` accepts `root_path`, optional `current_cwd`, and optional `name`. The service canonicalizes both paths, defaults `current_cwd` to `root_path`, verifies that `current_cwd` is inside `root_path`, and rejects unsafe or unreadable paths with stable error codes.
- `project.clearContext` clears only the persisted current project selection. It must not delete catalog rows, config snapshots, or skill files.
- `project.getContext` returns only persisted app state (`active` and `recent`). `service.status.project_context` reports the effective context after env override precedence is applied.

Persistence file:

`<app-data-dir>/project-context.json`

The file stores the current user-selected project and recent project list. It is app state, not agent config, and must not be written inside a user project repository.

`ProjectContext` fields are `id`, `name`, `root_path`, `current_cwd`, `last_used_at`, `is_active`, and `validation_error`. `ProjectContextState` fields are `active` and `recent`.

## Environment Overrides

| Variable | Purpose |
| --- | --- |
| `SKILLS_COPILOT_APP_DATA_DIR` | Override the catalog directory; useful for tests and screenshots. |
| `SKILLS_COPILOT_HOME` | Override the user home used by adapters. |
| `SKILLS_COPILOT_PROJECT_CWD` | Optional current project working directory for adapters such as Codex that walk project skills upward from cwd. |
| `SKILLS_COPILOT_PROJECT_ROOT` | Optional project safety root. If omitted while `SKILLS_COPILOT_PROJECT_CWD` is set, the service infers the nearest ancestor with a supported project marker, or uses no-project if a safe root cannot be established. |
| `SKILLS_COPILOT_CLAUDE_EXTRA_ROOTS` | Path-list of extra Claude skill roots for fixture runs. |
| `SKILLS_COPILOT_SERVICE_PATH` | Override the sidecar binary path for local app debugging. |
| `CODEX_HOME` | Optional Codex user config home. It is honored only when it is safe for the active user context; otherwise `~/.codex/config.toml` is used. |

Default macOS catalog path is:

`~/Library/Application Support/dev.skills-copilot.native/catalog.sqlite`

Project context is persisted separately at:

`~/Library/Application Support/dev.skills-copilot.native/project-context.json`

## Project Context Precedence

Effective context is resolved in this order:

1. `SKILLS_COPILOT_PROJECT_CWD` plus optional `SKILLS_COPILOT_PROJECT_ROOT`.
2. The active context stored in `<app-data-dir>/project-context.json`, including a project selected during the current UI session through `project.setContext`.
3. No-project.

Env overrides are for tests, screenshots, and developer launches. They are never persisted back to `project-context.json`, and the UI must show that env is controlling the active context.

No-project behavior:

- `catalog.scanAll` still scans supported agent-global roots.
- Project-local Claude and Codex roots are skipped.
- Catalog rows from previously scanned projects remain owned by their recorded `project_root`; they must not be reassigned to no-project or to the next selected project.
- Toggle writes are limited to agent-global writable targets unless the selected row belongs to the effective project context and that adapter has a documented writable path.

## Compatibility Rules

- UI shells must not import `scanner`, `catalog`, or `commands` directly.
- Additive result fields are allowed; removing fields requires a protocol version bump.
- `protocol_version = 1` covers the current stdio request/response envelope and the native UI-facing method payloads listed above.
- Error `code` values are stable and localizable by UI shells.
- `service.status.refresh` describes current refresh capabilities. In the stdio sidecar, scan progress is summary-only and native watcher events are reported as manual refresh state rather than a live event stream.
- `service.status.project_context` is an additive summary of the effective project context source (`env`, `stored`, or `none`), active context, recent count, and validation error if present.
- `service.status.adapter_capabilities` is an additive matrix for native UI gating. Missing fields should be treated as no additional capability evidence, not as permission to write.
- `service.status.llm` mirrors `llm.status` so UI shells can disable LLM affordances on launch without opening provider config or credential files.
- `llm.prepareAction` is read-only preflight. It must never execute a provider, perform network I/O, write model output, write credentials/config/snapshot/prompt artifacts, create a catalog when none exists, or return selected skill paths/body text in the response.
- Skill/script execution is default-denied in protocol v1. No supported method may execute a skill script indirectly, and no future execution method may be exposed without the V2.10 confirmation, preview, audit, and LLM-separation rules above.
- `catalog.importSkill` writes only the app-controlled tool-global staging area and catalog records; it must never write agent config.
- `skill.exportBundle` writes only local bundle/export files. It does not sign, zip, publish, install, or modify agent config.
- `skill.install` is preview-only unless `confirmed=true`. Confirmed installs must use the adapter verified target path, snapshot/audit, locking, read-back verification, and rescan behavior described in the V2.9 install payload.
- `tool.previewInstall`, when used by older clients as a compatibility fallback, is read-only preflight. It must not copy/import/export/write files.
- `app.stateSnapshot` opens the current catalog and returns its already-known local state. It does not scan adapter roots, watch files, refresh UI state, or write user config.
- `catalog.scanAll.result.activity` and `catalog.scanClaude.result.activity` are additive protocol v1 summaries for user-visible refresh feedback. They include operation, status, start/finish timestamps, scanned/catalog/finding/conflict/snapshot counts, considered roots, log entries, and recovery suggestions. `catalog.scanAll.result.activity.agent_summaries` is an additive summary for supported adapters; each entry includes agent id, display label, status, scanned/catalog/broken counts, roots considered/scanned/skipped, and agent-scoped recovery suggestions when no roots were scanned. They are not streaming progress feeds.
- Project context validation canonicalizes `root_path` and `current_cwd`, defaults `current_cwd` to `root_path`, requires both paths to be readable directories, and rejects `current_cwd` outside `root_path` after canonicalization, including symlink escapes.
- `project.setContext` writes schema version 1 app state atomically to `project-context.json`. `project.clearContext` removes the active context and retains the recent list.
- Adapter context priority is env override first (`SKILLS_COPILOT_PROJECT_CWD` / `SKILLS_COPILOT_PROJECT_ROOT`), then stored active project context, then no project context.
- `config.toggleSkill` snapshots the target agent config, takes a file lock, writes atomically, verifies read-back content, rolls back on verification failure, records a local `skill_event`, and refreshes catalog state. Claude Code writes `.claude/settings*.json`; Codex writes only the user `config.toml` `[[skills.config]]` override and never project `.codex/config.toml`. Opencode writes only exact `permission.skill.<name> = "deny"` rules in verified `opencode.json` config targets; compatibility-root files are scanned but never modified by toggle.
- `config.saveClaudeSettings` validates JSON, snapshots the target config, takes a file lock, writes atomically, verifies read-back content, rolls back on verification failure, and rescans before returning.
- `snapshot.listAgentConfig` is the product UI path for rollback history. It returns config snapshots by agent/scope and must not be treated as skill content history.
- `snapshot.rollback` writes the stored agent config snapshot content through the locked write path and rescans before returning the refreshed count.
- Future write methods must document snapshot, lock, verification, rollback, and rescan behavior before being exposed in native UI.

## Contract Fixtures

Shared request/response examples live in [`../fixtures/service-protocol`](../fixtures/service-protocol). The service crate has a fixture decoding test so schema drift is caught during `cargo test --workspace`.
