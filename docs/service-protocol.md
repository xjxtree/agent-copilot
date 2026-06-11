# skills-copilot Service Protocol

> Status: V2.36 Pi writable evidence harness, V2.37 Pi writable guarded slice, V2.38 Hermes external roots, V2.39 OpenClaw workspace deepening, V2.40 Adapter diagnostics, V2.41 AI Provider Foundation, V2.42 Prompt Preview / Redaction, and V2.43-V2.56 task-centered analysis surfaces are integrated at the Rust service/protocol layer. V2.38 models `skills.external_dirs` as explicit read-only external roots, not generic project roots, and Hermes writable/install remains blocked. V2.39 limits OpenClaw project scope to confirmed workspace roots, not arbitrary repo roots, and OpenClaw writable/install remains blocked. Hermes and OpenClaw read-only scanners, V2.18 cross-agent analysis, V2.19 health dashboard, V2.20 read-only AI skill analysis assist, V2.21 scan accuracy/dedupe alignment, V2.22 finding/conflict semantics, V2.23 Health Dashboard / Adapter Capability UX, V2.24 Skill Detail diagnostics, V2.25 Agent-config timeline, V2.26 Finding explainability, V2.27 Skill identity/provenance dedupe, V2.28 Conflict semantic closeout, V2.29 Finding triage persistence, V2.30 AI skill analysis workflow, V2.31 Cleanup Queue, V2.32 Rule tuning / suppression, V2.33 Safe batch actions, V2.34 Cross-agent comparison view, V2.35 Local report export, V2.36 Pi writable evidence harness, V2.37 Pi guarded toggle, V2.38 Hermes external roots, V2.39 OpenClaw workspace deepening, V2.40 Adapter diagnostics, V2.41 provider profiles, V2.42 prompt confirmation, V2.50 cross-agent readiness, V2.51 stale/drift detection, V2.52 local knowledge search, V2.53 similar grouping, V2.54 capability taxonomy, V2.55 workspace readiness, and V2.56 remediation planning are implemented or synchronized. V2.33 adds `batch.previewSkillToggles` and `batch.applySkillToggles` for preview-first verified writable toggles with explicit confirmation and matching preview id before apply; V2.34 adds read-only `comparison.listCrossAgent`; V2.35 adds user-triggered local/redacted `report.exportLocal`; V2.36 adds evidence-only `evidence.piWritableHarness`; V2.37 adds a guarded minimal Pi native toggle slice (global/project/package), and Pi install stays blocked; V2.40 adds read-only `adapter.listDiagnostics` plus `service.status.adapter_diagnostics` / `app.stateSnapshot.status.adapter_diagnostics`; V2.51 adds read-only `analysis.detectStaleDrift` over local catalog evidence; V2.52 adds read-only `knowledge.search` over local catalog evidence and derived tags; V2.53 adds read-only `knowledge.groupSimilarSkills` over local similarity evidence; V2.54 adds read-only `knowledge.buildCapabilityTaxonomy`; V2.55 adds read-only `workspace.checkReadiness`; V2.56 adds read-only `remediation.plan`.

> V2.43 `analysis.scoreSkillQuality` is integrated and validated as a read-only deterministic quality score. Closeout evidence includes focused checks, `pnpm check:macos`, real local app validation, fixture screenshot inspection, and `pnpm check:privacy`.

## V2.36 Pi writable evidence harness（完成）

- V2.36 阶段为 evidence-only：只新增 evidence-only `evidence.piWritableHarness`，不会直接写真实 `pi` settings。V2.37 已基于该证据启用 guarded `config.toggleSkill` Pi native global/project/package 最小切片。
- 核心证据路径要求包含：
  - global/project/package toggle 变更语义（含 `pi config` 与 package filters）
  - rollback（可重放回滚）
  - trust gate（trusted / untrusted 项目上下文）
  - invalid JSON/config 损坏输入时的失败回退
  - re-enable 行为
- 上述证据已通过，V2.37 的 guarded writable slice 已实现；V2.37 保持 preview/snapshot/rollback/disabled-state rescan 边界，Pi install 继续 blocked。该阶段写路径**仅限 native global/project/package**，不支持 install、脚本执行、AI 自动写回、credentials 持久化，并且不放开任意兼容 roots。该阶段已通过 `pnpm check:macos`、真实 app smoke/window capture、direct CG/AX window evidence、bundled `service.status` Pi capability check、`pnpm check:privacy`；Computer Use 工具返回 `cgWindowNotFound`，作为后续复验 blocker 保留。
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
| `config.toggleSkill` | Yes, writes agent config | Native macOS Enable / Disable action; batch apply must stay preview-confirmed and call this per-skills path. Pi write scope for V2.37 is limited to native/global/project/package with no compatibility-root writes; Hermes remains read-only until explicit write evidence is in scope | updated `SkillRecord` |
| `config.readClaudeSettings` | No | Native macOS Settings editor load action | `ConfigDocumentRecord` |
| `config.saveClaudeSettings` | Yes, writes Claude settings and rescans | Native macOS Settings editor Save action | saved `ConfigDocumentRecord` |
| `snapshot.list` | No | Compatibility / diagnostics | global `ConfigSnapshotRecord[]` (app-level, not skill-content snapshots) |
| `snapshot.listAgentConfig` | No | Native macOS Agent Config History（仅 toggle/config history） | agent-config `ConfigSnapshotRecord[]` filtered by `{ "agent": "...", "scope"?: "agent-global" }` |
| `snapshot.previewRollback` | No | Native macOS Agent Config History preview action | snapshot, current content, read error, changed flag, and diff payload for UI review |
| `snapshot.rollback` | Yes, writes agent config snapshot content and rescans | Native macOS Agent Config History rollback action | rescanned skill count after confirmation-driven restore |
| `trace.importLocal` | Yes, writes app-data metadata | Integrated (V2.48) | Import pasted/local trace text with optional task/agent/expected refs, local redaction + deterministic trace import outcome |
| `trace.listImports` | No | Integrated (V2.48) | List local trace import metadata records without raw trace content |
| `trace.deleteImport` | Yes, updates app-data metadata | Integrated (V2.48) | Delete one local trace import record by id |
| `routing.accuracyDashboard` | No | Integrated (V2.49) | Read-only dashboard aggregating benchmark, regression, and redacted trace evidence into routing accuracy metrics |
| `task.compareAgentReadiness` | No | Integrated (V2.50) | Compare readiness/routing/readiness confidence across Claude/Codex/opencode/Pi/Hermes/OpenClaw for the same task |
| `analysis.detectStaleDrift` | No | Integrated (V2.51) | Detect stale skills and drift across fingerprints, finding/conflict/source provenance, mtime staleness, and readiness impact using local evidence only |
| `knowledge.search` | No | Integrated (V2.52) | Local-only read-only search over existing catalog evidence and derived tags; query/agent/limit/optional filters; no default provider/network |
| `knowledge.groupSimilarSkills` | No | Integrated (V2.53) | Local-only deterministic similar-grouping over existing catalog evidence, V2.52 tags, and source/name/tool/rule/capability/risk overlaps; inputs `agent`, `limit`, optional `min_score`, optional candidate ids, optional singleton inclusion |
| `knowledge.buildCapabilityTaxonomy` | No | Integrated (V2.54) | Local-only deterministic capability taxonomy over existing catalog evidence, V2.52 tags, similar groups, findings/conflicts/analysis, and adapter/source provenance |
| `workspace.checkReadiness` | No | Integrated (V2.55) | Local-only deterministic workspace readiness over taxonomy, task readiness/routing, cross-agent readiness, stale/drift, findings/conflicts/analysis, adapter diagnostics, and source provenance |
| `remediation.plan` | No | Integrated (V2.56) | Local-only deterministic remediation plan over findings, gaps, ambiguity, drift, readiness, taxonomy, workspace, and adapter evidence; no default provider/network/write path |

`catalog.scanAll` is the native UI scan path.

It currently scans:

- Claude Code
- Codex
- opencode (verified writable through managed permission overrides; scans native plus official compatibility roots)
- Pi (read-only native roots)
- OpenClaw (read-only filesystem roots)
- Hermes (read-only active/profile home skills; V2.38 models `skills.external_dirs` as explicit external roots only, not generic project roots)

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

## V2.32 Rule tuning / suppression（completed）

- Scope: rule severity overrides and suppressions are app-local review metadata only, persisted in catalog/app-data style state.
- Mutations must be explicit, auditable, and reversible (reason + actor + timestamp), and should not mutate skill files or agent config.
- This path must not create or consume any new snapshot entity for rule tuning records.
- Rule-tuning actions must not execute scripts, call LLM providers, perform network I/O, or read/write credentials.
- Data exposure for existing UI/protocol read flows should remain through existing payloads (`catalog.listFindings`, `app.stateSnapshot.health`, `catalog.getSkill`) without adding new write-heavy method dependencies.

## V2.33 Safe batch actions（已完成）

目标：在已验证可写 adapter 的基础上补齐安全批量 enable/disable 预览流程，且保持 read-only agent 的行为隔离。

- 批量预览只处理 `agent/roots` 在 adapter matrix 显式 `writable` 且当前 session 验证为 verified 的候选项；`Pi`、`Hermes`、`OpenClaw` 及配置受阻实例进入 `skipped` 集合并返回明确 `skip_reason`。
- 预览输出应至少包含：
  - `requested_instance_ids`
  - `included_instance_ids`（可写）
  - `skipped_instance_ids` 与 `skipped_reason`
- 每次预览必须包含该次批量变更的 `snapshot_plan` 与 `rollback_plan`（按 agent / scope 维度），并明确列出执行顺序。
- 应用路径必须是“预览先行 + 显式确认 + 当前确认 preview id 匹配 + 逐项执行”；任何变更必须生成对应 agent-config 快照以便回滚。
- 本阶段不新增 skill-content 写入路径，不触发脚本执行，不发起 provider 调用，不读写 credentials，不引入 telemetry。

## V2.34 Cross-agent comparison view（已完成）

V2.34 主要交付是“只读对比”体验，而不是新写链路。对比视图新增只读 method `comparison.listCrossAgent`，并继续复用现有 `catalog.analysis`/`app.stateSnapshot.analysis` 的语义边界；UI 优先使用 service payload，不可用时只能退回本地 catalog-only 只读对比：

- 同名/相似 skill 在 Claude/Codex/opencode/Pi/Hermes/OpenClaw 间的可见实例对齐（`definition_id`/`instance_id`）
- `state`（enabled/disabled/shadowed/broken/missing）、`source provenance`（canonical name / path / scope / root）
- `risk`（finding/risky script / risky permission）与分析级别解释
- 可写能力对比（adapter capability + 根级可写能力）
- 差异摘要（仅供决策）：谁启用、谁不可写、谁来源于 native / compatibility

边界要求：

- 比较接口保持 read-only：不得新增 `catalog`/`snapshot`/`config` 的 mutate path。
- 不在 comparison 入口发起 `catalog.scanAll` 之外的新扫描；依赖已完成 scan/activity 的现有上下文快照。
- 不新增 skill 内容读写、脚本执行、provider 调用、凭据读取/持久化、snapshot 创建路径。
- 不在 comparison 面直接提供 apply/rollback/enable/disable；只读入口必须回到现有受控动作（`catalog.scanAll`、`config.toggleSkill`、`snapshot.previewRollback`、`snapshot.rollback`）的 preview-confirm 流程。

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
| Pi | `guarded` | Supported（Pi-native roots） | Supported（V2.37 guarded native global/project/package） | Blocked | Limited | `install and compatibility-root writes blocked` |
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

## V2.41-V2.50 AI Provider Foundation, Prompt Safety, Quality, Readiness, Routing Confidence, Task Benchmarks, Routing Regression, Trace Import, Routing Accuracy, And Cross-agent Readiness

Current implementation status after V2.55:

- Implemented: disabled-by-default `llm.status`, `llm.prepareAction`, `llm.prepareSkillAnalysis`, provider/model DTOs, token/cost estimates, deterministic `review_preview`, and native read-only preview UI.
- Implemented in V2.41: `llm.listProviderProfiles`, `llm.saveProviderProfile`, `llm.deleteProviderProfile`, and `llm.testProviderConnection`; OpenAI-compatible and Claude-compatible provider profile metadata; macOS Keychain-first API key storage; explicit Test Connection network path; budget fields; and minimal redacted test-call metadata under app data.
- Implemented in V2.42: `llm.previewPrompt` and `llm.confirmPromptAndSend`; provider-backed Analyze/Recommend/conflict/draft/skill-analysis requests now require redacted prompt preview, included/excluded field display, token/cost estimate, destination preview, explicit confirmation, and minimal redacted call metadata.
- Implemented in V2.43: `analysis.scoreSkillQuality`; local scoring is deterministic, user-triggered, read-only, and based on catalog/finding/conflict/analysis/adapter diagnostic evidence. Optional provider explanation uses V2.42 prompt preview/redaction/confirmation and remains copy-only.
- Implemented in V2.44: `task.checkReadiness`; local readiness is deterministic, user-triggered, read-only, and based on task text plus catalog/finding/conflict/analysis/adapter diagnostic evidence and V2.43 quality scoring. Optional provider explanation uses V2.42 prompt preview/redaction/confirmation and remains copy-only.
- Implemented in V2.45: `task.rankSkillRoutes`; local routing confidence is deterministic, user-triggered, read-only, and based on task text plus catalog/finding/conflict/analysis/adapter diagnostic evidence, V2.43 quality scoring, and V2.44 readiness signals. Optional provider explanation uses V2.42 prompt preview/redaction/confirmation and remains copy-only.
- Implemented in V2.46: `task.listBenchmarks`, `task.saveBenchmark`, `task.deleteBenchmark`, and `task.evaluateBenchmarks`; benchmark definitions persist app-locally in `task-benchmarks.json`, and evaluation reuses V2.44 readiness + V2.45 routing evidence. Optional provider explanation remains preview/redaction/confirmation-gated and copy-only.
- Implemented in V2.47: `task.saveRoutingBaseline` and `task.detectRoutingRegression`; baseline snapshots persist app-locally in `task-routing-baseline.json`, and detection compares saved baseline vs current V2.46 benchmark evaluation with score/confidence/status/top-route/gap/blocker/missing-benchmark signals. Optional provider explanation remains preview/redaction/confirmation-gated and copy-only.
- Implemented in V2.48: `trace.importLocal`, `trace.listImports`, and `trace.deleteImport`; trace imports persist app-locally in `trace-imports.json` as redacted metadata/excerpts plus deterministic local `analysis`. Raw trace content is never stored by default. Optional provider explanation remains preview/redaction/confirmation-gated and copy-only.
- Implemented in V2.49: `routing.accuracyDashboard`; dashboard output is derived read-only from V2.46 benchmark evaluation, V2.47 routing regression evidence, and V2.48 redacted trace imports. It returns summary metrics, per-agent rows, history rows, gap/issue rows, recent evidence rows, blocker notes, prompt request metadata, and safety flags without writing a dashboard artifact or sending provider traffic.
- Implemented in V2.50: `task.compareAgentReadiness`; cross-agent task readiness output is derived read-only from V2.44 readiness, V2.45 routing, V2.46 benchmark evaluation, V2.47 routing regression evidence, V2.48 redacted trace imports, V2.49 routing accuracy, and V2.43 quality signals. It returns summary, per-agent rows, optional recommended agent, gap/issue rows, evidence references, prompt request metadata, and safety flags without writing a comparison artifact or sending provider traffic.
- Implemented in V2.51: `analysis.detectStaleDrift`; stale/drift output is derived read-only from catalog fingerprints, mtime, findings, same-agent conflicts, cross-agent analysis, source/root provenance, and adapter diagnostics. It returns summary counts, stale/drift rows, readiness impact rows, gap/blocker notes, evidence references, prompt request metadata, and safety flags without writing a stale/drift artifact or sending provider traffic.
- Implemented in V2.52: `knowledge.search`; local knowledge search output is derived read-only from catalog evidence, derived tags, source/root provenance, quality/readiness/stale-drift context, and facets. It returns rows, facets, gap/blocker notes, evidence references, prompt request metadata, and safety flags without writing an index artifact or sending provider traffic.
- Implemented in V2.53: `knowledge.groupSimilarSkills`; similar grouping output is derived read-only from catalog evidence, V2.52 tags, source/name/tool/rule/capability/risk overlaps, and quality/readiness/stale-drift context. It returns groups, members, gap/blocker notes, evidence references, prompt request metadata, and safety flags without writing a grouping artifact or sending provider traffic.
- Implemented in V2.54: `knowledge.buildCapabilityTaxonomy`; capability taxonomy output is derived read-only from catalog evidence, V2.52 knowledge tags, V2.53 similar groups, quality/stale-drift context, findings, conflicts, analysis, adapter diagnostics, source provenance, and agent/workspace coverage. It returns summary counts, domain rows, coverage rows, gap/blocker notes, evidence references, prompt request metadata, and safety flags without writing a taxonomy artifact or sending provider traffic.
- Implemented in V2.55: `workspace.checkReadiness`; workspace readiness output is derived read-only from catalog evidence, V2.54 taxonomy, task readiness/routing, cross-agent readiness, stale/drift, findings, conflicts, analysis, adapter diagnostics, and source provenance. It returns summary counts, checklist/readiness rows, agent rows, capability rows, gap/blocker notes, evidence references, prompt request metadata, and safety flags without writing a readiness artifact or sending provider traffic.
- Implemented in V2.56: `remediation.plan`; remediation plan output is derived read-only from findings, cleanup queue, stale/drift, similar grouping, taxonomy, workspace readiness, optional task readiness/routing, conflicts, analysis, adapter diagnostics, and source provenance. It returns summary counts, prioritized plan items, priority rows, gap/blocker notes, evidence references, prompt request metadata, and safety flags without writing a remediation artifact or sending provider traffic.
- Implemented in V2.57: `remediation.previewDrafts`; fix preview draft output is derived read-only from local findings, skill metadata/frontmatter/body snippets, remediation plan signals, conflicts, analysis, rules, adapter diagnostics, writable capability context, and source provenance. It returns summary counts, copy/edit-ready draft items, gap/blocker notes, evidence references, prompt request metadata, and safety flags without writing a draft artifact, applying changes, or sending provider traffic.

V2.58 planning starts from the completed V2.57 protocol surface below; preview drafts stay local-only and copy-only by default, and the next surface is a deterministic impact preview before any enable/disable/edit/remediation action.

| Version | Protocol surface | Boundary |
| --- | --- | --- |
| V2.41 | `llm.listProviderProfiles`, `llm.saveProviderProfile`, `llm.deleteProviderProfile`, `llm.testProviderConnection` | Completed foundation: user-configured OpenAI-compatible / Claude-compatible profiles; Keychain-first; explicit test connection only; no automatic analysis; minimal redacted test-call metadata |
| V2.42 | `llm.previewPrompt`, `llm.confirmPromptAndSend` | Completed. Redaction summary, included/excluded fields, token/cost estimate, destination preview, explicit confirmation before request; confirmed calls record minimal audit metadata |
| V2.43 | `analysis.scoreSkillQuality` | Integrated. Deterministic local quality score from catalog/findings/conflicts/analysis/adapter diagnostics; optional provider explanation stays gated by V2.42 prompt preview/redaction/confirmation |
| V2.44 | `task.checkReadiness` | Integrated. Task input to local agent/skill readiness candidate evaluation with score/band, candidate skills, gap/blocker notes, evidence references, prompt request metadata, and no-write/no-provider safety flags |
| V2.45 | `task.rankSkillRoutes` | Integrated. Candidate ranking（主候选 + 备选）、`confidence`、`match_reasons`、ambiguity/collision risk、wrong-pick 和 miss 风险输出 |
| V2.46 | `task.listBenchmarks`, `task.saveBenchmark`, `task.deleteBenchmark`, `task.evaluateBenchmarks` | Integrated. App-local benchmark definition CRUD + deterministic local readiness/routing evaluation; no provider/write/script/config/snapshot/triage/credential side effects |
| V2.47 | `task.saveRoutingBaseline`, `task.detectRoutingRegression` | Integrated. Saves benchmark baseline snapshots in app-local storage and compares latest benchmark outputs against the saved baseline to emit local regression signals; no provider/write/script/config/snapshot/triage/credential side effects |
| V2.48 | `trace.importLocal`, `trace.listImports`, `trace.deleteImport` | Integrated. App-local trace import/list/delete; pasted/local trace is redacted before persistence; no raw transcript/log persistence |
| V2.49 | `routing.accuracyDashboard` | Integrated. Read-only dashboard over benchmark/regression/redacted trace imports; no raw trace persistence and no provider/write/script/config/snapshot/triage/credential side effects |
| V2.50 | `task.compareAgentReadiness` | Integrated. Cross-agent task readiness comparison over local readiness/routing/benchmark/regression/trace/accuracy evidence; no comparison artifact persistence and no provider/write/script/config/snapshot/triage/credential side effects |
| V2.51 | `analysis.detectStaleDrift` | Integrated. Read-only stale/drift detection over catalog fingerprint/mtime/finding/conflict/analysis/adapter evidence; no artifact persistence and no provider/write/script/config/snapshot/triage/credential side effects |
| V2.52 | `knowledge.search` | Integrated. Local-only read-only search over existing catalog evidence and derived tags; rows include purpose snippets, tools/keywords/rules, source provenance, risk/capability tags, quality/readiness/stale-drift context, facets, evidence refs, and no-write/no-provider safety flags |
| V2.53 | `knowledge.groupSimilarSkills` | Integrated. Local-only deterministic grouping over existing catalog evidence, V2.52 tags, source/name/tool/rule/capability/risk overlaps, and quality/readiness/stale-drift context; distinguishes coverage redundancy from routing ambiguity with no provider/write/script/config/snapshot/triage/credential side effects |
| V2.54 | `knowledge.buildCapabilityTaxonomy` | Integrated. Local-only deterministic capability-domain taxonomy over existing catalog evidence, V2.52 tags, V2.53 similar groups, quality/stale-drift context, and agent/workspace coverage; no provider/write/script/config/snapshot/triage/credential side effects |
| V2.55 | `workspace.checkReadiness` | Integrated. Local-only deterministic workspace readiness over catalog/taxonomy/readiness/routing/cross-agent/stale-drift/adapter evidence; returns summary, checklist/readiness rows, agent rows, capability rows, gap/blocker notes, evidence refs, prompt request metadata, and safety flags with no provider/write/script/config/snapshot/triage/credential side effects |
| V2.56 | `remediation.plan` | Integrated. Local-only deterministic remediation planner over findings/gaps/ambiguity/drift/readiness/taxonomy/workspace evidence; returns prioritized read-only guidance with no provider/write/script/config/snapshot/triage/credential side effects |
| V2.57 | `remediation.previewDrafts` | Integrated. User-triggered, local-only/deterministic-by-default draft suggestions for frontmatter, description, permissions, dependency, and policy; returns summary, `draft_items`, gap/blocker notes, evidence refs, prompt request metadata, and safety flags; copy/edit-ready only, with no direct apply/write path. Any provider wording must still go through V2.42 prompt preview/redaction/confirmation and remain copy-only |
| V2.58 | `remediation.previewImpact` | Integrated. Local-only deterministic impact preview over impacted tasks, agents, skills, risk deltas, snapshot/rollback plan, writable capability/filtering/blockers, and evidence refs before enable/disable/edit/remediation actions; returns summary, impact rows, task/agent/skill rows, risk delta rows, snapshot/rollback rows, evidence refs, prompt metadata, and safety flags with no apply/write/snapshot mutation/triage/script/credential/cloud/telemetry/default-provider side effects. Provider wording stays V2.42 gated copy-only |
| V2.59-V2.60 | `(planned) remediation.batchReview`, `(planned) remediation.history` | Future batch review/history work; remains local review only unless the user enters an existing safe write flow |
| V2.61-V2.68 | `(planned) reviewSession.*`, `(planned) policyPack.*`, `(planned) governance.exportPack` | Local review/policy/governance records and redacted exports |
| V2.69 | `(planned) llm.listProviderCallMetadata`, `(planned) llm.summarizeProviderUsage`, `(planned) llm.clearProviderCallMetadata`, `(planned) llm.exportProviderUsage` | Full observability UX over V2.41-V2.42 metadata: call history, cost trends, failures, rate limits, availability, cleanup/retention; no secrets/raw prompt/response by default |
| V2.70 | `(planned) writeEvidence.planExpansion` | Evidence-only safe-write planning; no new writes without verified rollback-safe agent/root support |

## V2.52 Local Knowledge Index（completed）

`knowledge.search` is the integrated local-only, read-only search surface over existing catalog evidence and derived tags.

- Input shape: `{ query, agent?, limit?, filters? }`
  - `query`: free-text search string.
  - `agent`: optional agent scope or preference.
  - `limit`: optional max rows returned.
  - `filters`: optional narrowing by purpose, tools, keywords, rules, source, risk, task fit, and capability tags.
- Corpus and behavior:
  - search reads existing catalog evidence and derived metadata only.
  - it does not write skill files, agent config, snapshots, triage, or index artifacts.
  - it does not default to provider or network.
  - optional provider explanation, if ever added later, must still follow V2.42 preview/redaction/confirmation and remain copy-only.
- Output shape: `{ generated_by, catalog_available, filters, summary, rows, facets, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`
  - `summary`: `{ indexed_skill_count, matched_row_count, returned_row_count, enabled_count, disabled_count, high_risk_count, stale_or_drift_count, summary }`
  - `rows`: `[{ rank, instance_id, definition_id, skill_name, agent, scope, enabled, state, source, purpose_snippet, description_snippet, matched_fields, match_reasons, keywords, tools, rules, capability_tags, risk_tags, quality_context, readiness_context, stale_drift_context, evidence_refs, safety_flags }]`
  - `facets`: grouped counts for agents, scopes, states, enabled values, risks, tools, and keywords.
  - `gap_notes` / `blocker_notes`: local evidence caveats and blockers; no index artifact is created.
- Safety boundary: user-triggered, deterministic, local-only, read-only, no default provider/network, no writes to skill files/agent config/index artifacts/snapshots/triage/scripts/credentials/raw prompt/raw response/cloud sync/telemetry.
- V2.55 workspace readiness is completed around `workspace.checkReadiness` and must not be inferred from V2.52 alone; V2.56 remediation planning is available as a separate read-only local planner. V2.53 similar grouping and V2.54 taxonomy are completed as separate read-only local slices.

## V2.53 Similar Skill Grouping（completed）

`knowledge.groupSimilarSkills` is the integrated local-only, read-only, deterministic grouping surface for same/similar/confusable skills.

- Input shape: `{ agent, limit, min_score?, candidate_instance_ids?, include_singletons? }`
  - `agent`: optional agent scope or preference.
  - `limit`: optional max group/member rows returned.
  - `min_score`: optional minimum similarity score threshold.
  - `candidate_instance_ids`: optional narrowed candidate set.
  - `include_singletons`: optional flag to surface isolated skills as singleton groups.
- Grouping signals:
  - existing catalog evidence and derived tags from V2.52
  - source/name/tool/rule/capability/risk overlap
  - quality/readiness/stale-drift context
  - same/similar/confusable routing patterns
- Output shape: `{ generated_by, catalog_available, filters, summary, groups, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`
  - `summary`: `{ indexed_skill_count, candidate_skill_count, matched_group_count, returned_group_count, duplicate_group_count, confusable_group_count, coverage_redundancy_group_count, routing_ambiguity_count, summary }`
  - `groups`: `[{ group_id, rank, group_type, similarity_score, ambiguity_risk, coverage_redundancy, routing_ambiguity, canonical_name, canonical_key, title, summary, why_grouped, shared_terms, shared_tools, shared_rules, shared_capability_tags, shared_risk_tags, shared_source_signals, members, evidence_refs, safety_flags }]`
  - `members`: `[{ instance_id, definition_id, skill_name, agent, scope, enabled, state, source, quality_context, readiness_context, stale_drift_context, match_reasons, similarity_reasons, evidence_refs }]`
  - `group_type`: duplicate, similar, confusable, source-overlap, or coverage-redundancy style values.
- Safety boundary: user-triggered, deterministic, local-only, read-only, no default provider/network, no writes to skill files/agent config/group artifacts/snapshots/triage/scripts/credentials/raw prompt/raw response/raw trace/cloud sync/telemetry.
- If a provider explanation ever appears later, it must still follow V2.42 preview/redaction/confirmation and remain copy-only.
- V2.55 workspace readiness is completed around `workspace.checkReadiness` and must not be inferred from V2.53 alone; V2.56 remediation planning is available as a separate read-only local planner. V2.54 capability taxonomy is completed as a separate read-only local taxonomy slice.

## V2.54 Capability Taxonomy（completed）

`knowledge.buildCapabilityTaxonomy` is the integrated local-only, read-only, deterministic taxonomy surface for grouping visible skills into capability domains.

- Input shape: `{ agent?, limit?, include_single_skill_domains?, candidate_instance_ids? }`
  - `agent`: optional agent scope or preference.
  - `limit`: optional max domain rows returned.
  - `include_single_skill_domains`: optional flag to keep one-skill domains in the taxonomy.
  - `candidate_instance_ids`: optional narrowed candidate set.
- Taxonomy signals:
  - existing catalog evidence and derived tags from V2.52
  - V2.53 similar group redundancy / routing ambiguity signals
  - quality and stale/drift context
  - findings, conflicts, cross-agent analysis, adapter diagnostics, source provenance, agent, workspace, tools, rules, keywords, and risk tags
- Output shape: `{ generated_by, catalog_available, filters, summary, domains, coverage_rows, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`
  - `summary`: `{ indexed_skill_count, candidate_skill_count, domain_count, returned_domain_count, total_representative_skill_count, agent_count, workspace_count, duplicate_or_redundant_domain_count, routing_ambiguity_domain_count, gap_count, summary }`
  - `domains`: `[{ domain_id, rank, domain_key, domain_name, coverage_level, coverage_score, skill_count, enabled_skill_count, disabled_skill_count, agent_count, workspace_count, agents, workspaces, duplicate_or_redundant_count, routing_ambiguity_count, representative_skills, capability_tags, risk_tags, tools, rules, keywords, gap_notes, blocker_notes, evidence_refs, safety_flags }]`
  - `coverage_rows`: per-domain coverage summary with agent/workspace counts, gaps, redundancy, routing ambiguity, and evidence refs.
  - `representative_skills`: skill rows with instance/definition ids, name, agent, scope, enabled/state, source, quality/stale context, similar group refs, match reasons, and evidence refs.
- Safety boundary: user-triggered, deterministic, local-only, read-only, no default provider/network, no writes to skill files/agent config/taxonomy artifacts/snapshots/triage/scripts/credentials/raw prompt/raw response/raw trace/cloud sync/telemetry.
- Optional provider explanation remains V2.42 preview/redaction/confirmation-gated and copy-only; `knowledge.buildCapabilityTaxonomy` itself never sends provider traffic.

## V2.55 Workspace Readiness（completed）

`workspace.checkReadiness` is the integrated local-only, read-only, deterministic workspace readiness surface for checking whether the current workspace has usable, scoped, and risk-controlled skills across agents and capabilities.

- Input shape: `{ agent?, task? / task_text?, workspace_path? / project_root?, expected_capabilities?, limit?, candidate_instance_ids? }`
  - `agent`: optional agent scope or preference.
  - `task` / `task_text`: optional expected work description used to reuse task readiness/routing evidence.
  - `workspace_path` / `project_root`: optional workspace context for project-scoped evidence.
  - `expected_capabilities`: optional capability labels that should be represented in readiness rows.
  - `limit`: optional max row count.
  - `candidate_instance_ids`: optional narrowed candidate set.
- Output shape: `{ generated_by, catalog_available, filters, summary, readiness_rows, checklist_rows, agent_rows, capability_rows, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`
  - `summary`: workspace/project availability, visible/enabled skill counts, agent/domain/capability counts, ready/partial/blocked counts, gap/blocker counts, and summary copy.
  - `readiness_rows` / `checklist_rows`: checklist-style rows with category/status/score/title/detail/agent/capability/evidence refs.
  - `agent_rows`: per-agent readiness score/state, visible/enabled/project skill counts, gap/blocker counts, notes, and evidence refs.
  - `capability_rows`: per-capability readiness score/state, agent coverage, representative skills, gap/blocker notes, and evidence refs.
- Evidence signals: existing catalog evidence, V2.54 taxonomy, V2.44/V2.45 task readiness/routing, V2.50 cross-agent readiness, V2.51 stale/drift, findings, conflicts, cross-agent analysis, adapter diagnostics, source/root provenance, agent scope/state, and risk tags.
- Safety boundary: user-triggered, deterministic, local-only, read-only, no default provider/network, no writes to skill files/agent config/readiness artifacts/snapshots/triage/scripts/credentials/raw prompt/raw response/raw trace/cloud sync/telemetry.
- Optional provider explanation remains V2.42 preview/redaction/confirmation-gated and copy-only; `workspace.checkReadiness` itself never sends provider traffic.

## V2.56 AI Remediation Planner（completed）

`remediation.plan` is the integrated local-only, read-only, deterministic service surface for converting existing local evidence into a prioritized remediation plan.

- Input shape: `{ agent?, task? / task_text?, workspace_path? / project_root?, focus? / focus_areas?, limit?, candidate_instance_ids?, include_deferred? }`
  - `agent`: optional agent scope or preference.
  - `task` / `task_text`: optional task context used to reuse readiness/routing ambiguity evidence.
  - `workspace_path` / `project_root`: optional workspace context for workspace readiness and project-scoped evidence.
  - `focus` / `focus_areas`: optional categories such as finding, gap, ambiguity, drift, readiness, or policy.
  - `limit`: optional max item count; invalid zero limits are rejected before opening or creating catalog/app data.
  - `candidate_instance_ids`: optional narrowed candidate set.
  - `include_deferred`: optional flag to include lower-priority/deferred items.
- Output shape: `{ generated_by, catalog_available, filters, summary, plan_items, priority_rows, gap_notes, blocker_notes, evidence_references, prompt_request, safety_flags }`
  - `summary`: candidate and returned item counts, critical/high counts, deferred count, gap/blocker counts, and summary copy.
  - `plan_items`: prioritized items with stable id, rank, priority/severity, category, title, summary/detail, affected agent/skill/capability/task refs, affected instance ids, read-only safe next action, prerequisites, blockers, evidence refs, and explicit side-effect flags.
  - `priority_rows`: category/priority rollups for UI sorting and review.
- Evidence signals: findings, cleanup queue, stale/drift, similar grouping, capability taxonomy, workspace readiness, optional task readiness/routing, conflicts, cross-agent analysis, adapter diagnostics, source/root provenance, enabled/scope/state, and risk tags.
- Safety boundary: user-triggered, deterministic, local-only, read-only, no default provider/network, no writes to skill files/agent config/remediation artifacts/snapshots/triage/scripts/credentials/raw prompt/raw response/raw trace/cloud sync/telemetry.
- Optional provider explanation remains V2.42 preview/redaction/confirmation-gated and copy-only; `remediation.plan` itself never sends provider traffic.

V2.41 additive status/profile surface:

- `service.status` / `app.stateSnapshot.status` include `llm.provider_profile_count`, `llm.default_profile_id`, `llm.profiles_path`, `llm.call_metadata_path`, `llm.raw_prompt_persistence_allowed=false`, and `llm.raw_response_persistence_allowed=false`.
- `llm.listProviderProfiles` returns profile metadata, `default_profile_id`, `credential_storage=keychain`, `credential_persistence_allowed`, and `raw_secrets_returned=false`.
- `llm.saveProviderProfile` writes provider metadata under app data and stores the submitted API key in Keychain when available. It returns `raw_secret_returned=false`.
- `llm.testProviderConnection` requires a saved profile and a caller-provided `confirmation_id`. It is the only V2.41 network path, writes minimal redacted call metadata JSONL, and returns `raw_prompt_persisted=false`, `raw_response_persisted=false`, and `raw_secret_returned=false`.
- No raw prompt/response, raw skill body, or credential secret is exposed in status, fixture, report, or profile payloads.
- `docs/v2.42-verification-checklist.md` records the completed V2.42 provider-backed flow validation: protocol preview/confirm calls, confirmed metadata recording, UI preview/confirm controls, and no-write/no-execute boundaries.

V2.42 additive prompt surface:

- `llm.previewPrompt` accepts an action request (`analyze`, `recommend`, `explain_conflict`, `draft_frontmatter`, or `skill_analysis`) and returns `preview_id`, provider/model/destination metadata, prompt scope, included/excluded fields, redaction summary, token/cost estimate, confirmation display fields, and `raw_prompt_persisted=false` / `raw_response_persisted=false`.
- `llm.confirmPromptAndSend` requires the matching `preview_id`, a caller-generated `confirmation_id`, and the original request. The service recomputes the preview, rejects stale/mismatched previews, sends only the redacted prompt to the configured provider, returns copy-only draft output, and records metadata-only audit fields.
- Confirmed output keeps `write_back_allowed=false`, `script_execution_allowed=false`, `config_mutation_allowed=false`, `snapshot_created=false`, and `triage_mutation_allowed=false`.

V2.44 additive readiness surface:

- `task.checkReadiness` accepts `task` (aliases: `user_intent`, `task_text`), optional `agent`, optional `candidate_instance_ids` (alias: `instance_ids`), and optional `limit`.
- The response includes `task`, `score`, `band`, `summary`, `generated_by=deterministic-service`, `catalog_available`, `filters`, `candidate_skills`, `missing_gap_notes`, `blocker_risk_notes`, `evidence_references`, `prompt_request`, and `safety_flags`.
- Each candidate includes skill identity, agent/scope/state/enabled fields, readiness score/band, optional V2.43 quality score, match reasons, enabled/scope/risk state, missing gaps, blocker notes, and evidence ids.
- `prompt_request.available=true` only means an optional provider explanation can be previewed through `llm.previewPrompt` and later confirmed through `llm.confirmPromptAndSend`; `task.checkReadiness` itself never sends provider traffic.
- `safety_flags` keep readiness read-only: `provider_request_sent=false`, `write_back_allowed=false`, `script_execution_allowed=false`, `config_mutation_allowed=false`, `snapshot_created=false`, `triage_mutation_allowed=false`, `credential_accessed=false`, `raw_secret_returned=false`, `raw_prompt_persisted=false`, and `raw_response_persisted=false`.

V2.45 additive routing confidence surface:

- `task.rankSkillRoutes` accepts `task` (aliases: `user_intent`, `task_text`), optional `agent`, optional `candidate_instance_ids` (alias: `instance_ids`), and optional `limit`.
- The response includes `task`, `overall_confidence_score`, `overall_confidence_band`, `summary`, `generated_by=deterministic-service`, `catalog_available`, `filters`, `route_candidates`, `ambiguity_warnings`, `likely_wrong_pick_risks`, `likely_miss_risks`, `evidence_references`, `prompt_request`, and `safety_flags`.
- Each route candidate includes rank, skill identity, agent/scope/state/enabled fields, `confidence_score`, `confidence_band`, match reasons, confidence rationale, ambiguity/collision warnings, wrong-pick/miss risks, and evidence ids.
- `prompt_request.available=true` only means an optional provider explanation can be previewed through `llm.previewPrompt` and later confirmed through `llm.confirmPromptAndSend`; `task.rankSkillRoutes` itself never sends provider traffic.
- `llm.previewPrompt` accepts `request_kind=routing_confidence` / `action=routing_confidence` with the same task/user-intent payload and returns prompt scope, included/excluded fields, token/cost estimate, destination preview, confirmation flags, `raw_prompt_persisted=false`, `raw_response_persisted=false`, and copy-only output metadata.
- `safety_flags` keep routing confidence read-only: `provider_request_sent=false`, `write_back_allowed=false`, `script_execution_allowed=false`, `config_mutation_allowed=false`, `snapshot_created=false`, `triage_mutation_allowed=false`, `credential_accessed=false`, `raw_secret_returned=false`, `raw_prompt_persisted=false`, and `raw_response_persisted=false`.

V2.46 additive benchmark surface:

- `task.listBenchmarks` accepts optional `limit` and returns `benchmarks`, `count`, `app_local_only=true`, `provider_request_sent=false`, `raw_prompt_persisted=false`, and `raw_response_persisted=false`.
- `task.saveBenchmark` accepts `task` (aliases: `task_text`, `user_intent`), optional `id`, optional `title`/`name`, `expected_skill_refs`, `expected_skill_names`, `acceptable_agents`, `acceptable_scopes`, and `success_criteria`. It writes only app-local benchmark metadata and returns the saved benchmark plus `created`, `app_local_only=true`, `provider_request_sent=false`, and `agent_config_mutated=false`.
- `task.deleteBenchmark` accepts `id` (alias: `benchmark_id`) and returns `benchmark_id`, `deleted`, `remaining_count`, `app_local_only=true`, `provider_request_sent=false`, and `agent_config_mutated=false`.
- `task.evaluateBenchmarks` accepts optional `ids` (alias: `benchmark_ids`) and optional `limit`. It evaluates selected app-local benchmarks using deterministic local routing evidence and returns `generated_by=deterministic-service`, `catalog_available`, `evaluated_count`, `summary`, `benchmark_results`, `blocker_notes`, `prompt_request`, and `safety_flags`.
- Each benchmark result includes `benchmark_id`, `title`, `task`, `score`, `band`, `expected_match_status`, `expected_match_reasons`, optional `top_route`, `route_confidence_score`, `route_confidence_band`, `gap_notes`, `blocker_notes`, `evidence_refs`, and item-level `safety_flags`.
- Benchmarks persist only under app data as `task-benchmarks.json`; they do not write agent config, project directories, skill files, snapshots, triage state, provider metadata, or credentials.
- All local benchmark runs are deterministic and use V2.44/V2.45 local evidence: `task` / `metadata` / `findings` / `conflicts` / `analysis` / `adapter diagnostics` / `quality_score` / `task.checkReadiness` / `task.rankSkillRoutes`.
- Local benchmark execution is read-only: `provider_request_sent=false`, `write_back_allowed=false`, `config_mutation_allowed=false`, `snapshot_created=false`, `triage_mutation_allowed=false`, `script_execution_allowed=false`, `credential_accessed=false`, `raw_prompt_persisted=false`, and `raw_response_persisted=false`.
- `task.evaluateBenchmarks` may return `prompt_request.available=true` for copy/display-only explanation previews only when local evaluation produces route evidence; local ranking/risk computation does not depend on provider output and never sends a provider request itself.

V2.47 additive routing-regression surface:

- `task.saveRoutingBaseline` accepts optional `ids` (alias: `benchmark_ids`) and optional `limit`. It runs deterministic V2.46 benchmark evaluation, saves a baseline snapshot to app-local `task-routing-baseline.json`, and returns `generated_by`, `baseline`, `benchmark_count`, `app_local_only=true`, `baseline_file`, `provider_request_sent=false`, `agent_config_mutated=false`, `skill_files_mutated=false`, `raw_prompt_persisted=false`, and `raw_response_persisted=false`.
- The saved baseline includes `schema_version`, `generated_by`, `generated_at`, `catalog_available`, `evaluated_count`, `benchmark_results`, and `safety_flags`.
- Each baseline benchmark result snapshots `benchmark_id`, `title`, `task`, `score`, `band`, `expected_match_status`, optional `top_route`, route confidence score/band, gap/blocker counts and notes, and evidence refs.

- `task.detectRoutingRegression` accepts optional `ids` (alias: `benchmark_ids`), optional `limit`, optional `score_drop_threshold`, and optional `confidence_drop_threshold`. If no app-local baseline exists, it returns `status=baseline_missing`, a current evaluation, and a blocker note without writing a baseline.
- The response includes `generated_by`, `status`, `baseline_available`, `catalog_available`, `baseline_evaluated_count`, `current_evaluated_count`, `regression_count`, `missing_benchmark_count`, `summary`, `items`, `blocker_notes`, optional `baseline`, `current_evaluation`, and `safety_flags`.
- Each item includes `benchmark_id`, `title`, `status` (`unchanged`, `regression`, `missing_current_benchmark`, or `new_current_benchmark`), `regression`, `reasons`, `evidence_refs`, optional `score_delta`, optional `confidence_delta`, baseline/current comparison fields, and item-level safety flags.
- Regression analysis is local and deterministic-first; input evidence sources are V2.46 benchmark runs, V2.44/V2.45 local task evidence, and V2.43 quality signals. No provider calls participate in scoring.
- Optional AI explanation is only copy/display-only and must remain preview/redaction/confirmation-gated through existing V2.42 path.

V2.48 additive trace-import surface:

- `trace.importLocal`:
  - Inputs: `content`（aliases: `trace_text` / `transcript`）、可选 `title`、可选 `source_kind`、可选 `agent`、可选 `task`、可选 `expected_skill_refs`、可选 `expected_skill_names`、可选 `max_excerpt_chars`。
  - 服务端先做本地 redaction（token / key / path / private URL 替换），计算 redacted `excerpt` 与 `redaction_summary`，并持久化元数据到 app-local `trace-imports.json`；默认不落 raw trace（`raw_trace_persisted=false`）与 `trace_imports[].raw_trace`。
  - 返回 deterministic 判读结果：`import.id`, `title`, `source_kind`, optional `agent`, optional `task`, expected refs/names, redacted `excerpt`, `redaction_summary`, `content_hash`, `imported_at`, nested `analysis`, and `safety_flags`。
  - `analysis` includes `generated_by`, `catalog_available`, `outcome`（`hit` / `miss` / `wrong_pick` / `ambiguous` / `unknown`）、`reasons`、`detected_skills`、and `evidence_refs`。
  - 返回与 persisted outcomes 一致的安全边界：`provider_request_sent=false`、`write_back_allowed=false`、`config_mutation_allowed=false`、`snapshot_created=false`、`triage_mutation_allowed=false`、`script_execution_allowed=false`、`credential_accessed=false`、`raw_prompt_persisted=false`、`raw_response_persisted=false`、`raw_trace_persisted=false`。
  - 可选 provider 说明仍走 V2.42 的 `llm.previewPrompt` + `llm.confirmPromptAndSend`，仅 copy/display-only，不改变 deterministic 结果。
- `trace.listImports`:
  - Inputs: 可选 `limit`。
  - Response: `imports`, `count`, `app_local_only`, `provider_request_sent=false`, `raw_trace_persisted=false`; each item is the same redacted `TraceImportRecord` shape returned by `trace.importLocal`。
- `trace.deleteImport`:
  - Inputs: `id`（alias: `import_id`）。
  - Response: `import_id`, `deleted`, `remaining_count`, `app_local_only=true`, `provider_request_sent=false`, `raw_trace_persisted=false`。
  - 行为：仅删除本地 trace import metadata；不改 catalog，不改 triage，不改 agent config，不改 snapshot，不触发脚本执行。

V2.49 additive routing-accuracy surface:

- `routing.accuracyDashboard`:
  - Inputs: optional `agent`, optional `window_days`（bounded; default 30）, optional `limit`, optional `include_history`, optional `include_recent_evidence`。
  - Response: `generated_by=deterministic-service`, `catalog_available`, `filters`, `summary`, `agent_rows`, `history_rows`, `gap_issue_rows`, `recent_evidence_rows`, `blocker_notes`, `prompt_request`, and `safety_flags`。
  - `summary` includes `trace_count`, `hit_count`, `miss_count`, `wrong_pick_count`, `ambiguous_count`, `unknown_count`, `benchmark_count`, `benchmark_matched_count`, `benchmark_gap_count`, `regression_count`, `missing_benchmark_count`, `accuracy_rate`, `known_outcome_rate`, and a human-readable summary string。
  - `agent_rows` group the same outcome counts plus benchmark/regression/evidence counts by agent; `history_rows` bucket trace outcomes by day; `gap_issue_rows` describe benchmark gaps/regressions/blockers; `recent_evidence_rows` cite recent trace/regression evidence refs.
  - Dashboard generation is read-only and does not persist a dashboard artifact. It reads app-local benchmark/regression/trace metadata, but does not store raw trace, raw prompt, raw response, skill body, credentials, or local-path-sensitive data beyond existing redacted records.
  - Local dashboard execution keeps `provider_request_sent=false`, `write_back_allowed=false`, `write_actions_available=false`, `config_mutation_allowed=false`, `snapshot_created=false`, `triage_mutation_allowed=false`, `script_execution_allowed=false`, `execution_actions_available=false`, `credential_accessed=false`, `raw_prompt_persisted=false`, `raw_response_persisted=false`, `raw_trace_persisted=false`, `cloud_sync_performed=false`, and `telemetry_emitted=false`.
- Optional provider explanation remains copy/display-only and must route through V2.42 `llm.previewPrompt` + `llm.confirmPromptAndSend`; provider output never changes deterministic dashboard metrics.

V2.50 additive cross-agent readiness surface:

- `task.compareAgentReadiness`:
  - Inputs: required `task`（aliases: `user_intent` / `task_text`），optional `agents`（list）、optional `candidate_instance_ids`（alias: `instance_ids`）、optional `limit`。
  - Reads app-local deterministic evidence first from `task.checkReadiness` + `task.rankSkillRoutes` + `task.evaluateBenchmarks` + `task.detectRoutingRegression` + `trace.importLocal` + `routing.accuracyDashboard`；输入证据不足时返回 `catalog_available=false` and blocker/gap notes rather than sending provider traffic.
  - Returns `generated_by=deterministic-service`, `catalog_available`, `filters`, `summary`, `agent_rows`, optional `recommended_agent`, `gap_issue_rows`, `evidence_references`, `prompt_request`, and `safety_flags`。
  - `summary` includes `agent_count`, `candidate_count`, `ready_agent_count`, `partial_agent_count`, `blocked_agent_count`, `gap_issue_count`, optional `recommended_agent`, and human-readable summary text.
  - `agent_rows` includes `rank`, `agent`, `display_name`, `comparison_score`, `readiness_score`, `readiness_band`, `routing_confidence_score`, `routing_confidence_band`, `candidate_count`, optional `best_candidate`, `enabled_scope_risk_state`, `blocker_count`, `gap_count`, `reasons`, `blocker_notes`, `gap_notes`, `routing_accuracy_context`, `benchmark_context`, and `evidence_refs`。
  - `best_candidate` carries skill identity and scores: `instance_id`, `definition_id`, `skill_name`, `scope`, `enabled`, `state`, `readiness_score`, `readiness_band`, `routing_confidence_score`, `routing_confidence_band`, and optional `quality_score`。
  - `enabled_scope_risk_state` summarizes the chosen route's enabled/scope/state/risk/writable/adapter status, while `routing_accuracy_context` and `benchmark_context` summarize local trace/accuracy/benchmark/regression evidence.
  - `recommended_agent` is optional and contains the highest scoring agent, display name, comparison/readiness/routing scores, candidate skill name, and reason.
  - This method itself is read-only and deterministic; it does not persist a cross-agent readiness artifact.
  - Cross-agent comparison must not write skill files、agent config、skill snapshots、triage、script execution state、provider secrets、or catalog writes.
- `safety_flags` include `provider_request_sent=false`、`write_back_allowed=false`、`config_mutation_allowed=false`、`snapshot_created=false`、`triage_mutation_allowed=false`、`script_execution_allowed=false`、`credential_accessed=false`、`raw_prompt_persisted=false`、`raw_response_persisted=false`、`raw_trace_persisted=false`、`cloud_sync_performed=false`、`telemetry_emitted=false`。
- Optional provider explanation remains copy/display-only and must follow V2.42 preview/redaction/confirmation flow.

V2.51 additive stale/drift surface:

- `analysis.detectStaleDrift`:
  - Inputs: optional `agent`, optional `candidate_instance_ids`（alias: `instance_ids`）, optional `limit`, optional `stale_days`。
  - Reads deterministic local evidence from catalog fingerprint/mtime/state, current findings, same-agent conflicts, cross-agent analysis, source/root provenance, and adapter diagnostics. Previous-scan drift is only claimed when existing local evidence exists（for example `fingerprint.changed` finding, conflict, or analysis group）; missing timestamp/history is surfaced as gap evidence instead of live source-file reads.
  - Returns `generated_by=deterministic-service`, `catalog_available`, `filters`, `summary`, `stale_drift_rows`, `readiness_impact_rows`, `gap_notes`, `blocker_notes`, `evidence_references`, `prompt_request`, and `safety_flags`.
  - `summary` includes `scanned_skill_count`, `returned_row_count`, `stale_count`, `drift_count`, `high_risk_count`, `medium_risk_count`, `low_risk_count`, `missing_history_count`, and a human-readable summary string.
  - `stale_drift_rows` include skill identity, agent/scope/enabled/state, `stale_drift_score`, `stale_drift_band`, nested `drift_signals`, nested `readiness_impact`, reasons, gap notes, evidence refs, and row-level safety flags.
  - Local execution remains read-only: `provider_request_sent=false`, `write_back_allowed=false`, `skill_files_mutated=false`, `agent_config_mutated=false`, `config_mutation_allowed=false`, `snapshot_created=false`, `triage_mutation_allowed=false`, `script_execution_allowed=false`, `credential_accessed=false`, `raw_prompt_persisted=false`, `raw_response_persisted=false`, `raw_trace_persisted=false`, `cloud_sync_performed=false`, and `telemetry_emitted=false`.
  - Optional provider explanation remains copy/display-only and must follow V2.42 preview/redaction/confirmation flow; provider output never changes deterministic stale/drift scores or rows.

Protocol invariants:

- AI provider calls must be user-triggered and tied to a confirmed prompt preview.
- AI output remains untrusted and cannot directly call config write, skill install, script execution, snapshot rollback, triage mutation, or policy mutation methods.
- Provider profiles must never serialize API keys into SQLite, fixtures, reports, logs, screenshots, or project files.
- OpenAI-compatible and Claude-compatible are interface standards; the product must not assume a specific vendor endpoint.

V2.43/V2.44/V2.45 readiness and routing notes:

- Quality scoring remains read-only and user-triggered (`selected` / `batch` scope first).
- Task readiness remains read-only and user-triggered (`selected` / optional candidate scope first).
- Routing confidence remains read-only and user-triggered (`selected` / optional candidate scope first).
- Local evidence remains the deterministic source (`metadata` / `findings` / `conflicts` / `analysis` / `adapter diagnostics`).
- Optional provider-backed explanations must route through `llm.previewPrompt` + `llm.confirmPromptAndSend`, with prompt scope, included/excluded summary, redaction status, token/cost estimate, destination preview, and explicit confirmation required.
- Provider-backed quality/readiness/routing explanations cannot write triage/config/snapshot states, mutate toggles, start writes/install, or execute scripts. Draft output remains copy/display only.
- Raw prompt/response remains unserialized by default for quality scoring, task readiness, and routing confidence.

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

## V2.35 Local report export (completed)

- `report.exportLocal` is a local, user-triggered action that writes redacted Markdown/JSON audit reports under app data `report-exports`.
- Exported payload includes:
  - agent coverage/status
  - health summary
  - open findings with persisted triage state
  - cleanup queue entries
  - cross-agent comparison insights
- Export generation redacts local environment values using placeholders such as `$HOME`, `<project-root>`, `<project-cwd>`, `<app-data-dir>`, and `<redacted>`.
- Explicit out-of-scope boundaries for V2.35 protocol behavior: no public distribution artifacts, no DMG/ZIP/signing/notarization, no provider/AI call pathway, no credential writes, no script execution, no automatic write-back path.
- Preserve V2.33 safe-batch semantics and V2.34 cross-agent completed read-only semantics in any related protocol or UX flow.

## OpenClaw scope note (V2.39 completed)

- `scanAgent`/`scanSkillRoots` support for OpenClaw is limited to explicit workspace roots `<workspace>/skills` and `<workspace>/.agents/skills`.
- OpenClaw should not infer arbitrary repository or generic project roots.
- OpenClaw write/install/scripting/AI write-back paths remain unsupported in this milestone; protocol behavior remains read-only and workspace-scoped.

## 4.x V2.40 Adapter diagnostics

V2.40 records read-only adapter diagnostics in the service protocol and state/status payloads.

The diagnostic outputs include read-only observability for each adapter. The service contract exposes the following fields after scan, either directly through `adapter.listDiagnostics` or via derived status models:

- Root lifecycle buckets:
  - `discovered`：有效扫描到、可用于后续操作的根路径。
  - `skipped`：非当前会话/权限范围外或不满足发现策略的根路径（含跳过原因）。
  - `blocked`：因权限、环境、解析失败等原因被阻断的根路径（含错误码或原因文本）。
- Config detection:
  - Adapter/agent config detection result per scan, including source path and whether parse/resolve succeeded.
  - Normalized config fingerprint summary for read-only visibility.
- Capability reason:
  - Read-only / writable classification per adapter root with explicit reason text from the existing capability matrix.
  - No implicit assumptions for writable capability.
- Last scan activity:
  - Last successful/failed scan timestamp per agent and elapsed time from the most recent run.
  - Count or status of blocking items in the same refresh cycle (for display only).

Notes:
- The protocol remains read-only-only and does not add write or script-execution fields.
- All fields are for diagnostics and visibility. V2.40 validation covered focused Rust/Swift checks, `pnpm check:macos`, real app smoke launch/window id, `pnpm check:privacy`, and screenshot inspection; Computer Use/AX/capture still reports `cgWindowNotFound` / 0 visible windows and is tracked as a tooling/window blocker.
