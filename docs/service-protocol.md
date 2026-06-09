# skills-copilot Service Protocol

> Status: V2.13 Pi read-only scanner/parser is complete; V2.14 Hermes adapter support is next.
>
> Integrated: V2.9 Tool-global import/export/install, V2.10 skill execution safety boundary, and 2026-06-09 real local Computer Use validation for the current mainline app. V2.11 added adapter capability status to the service protocol and macOS UI. V2.12 marks opencode writable for native roots after exact permission.skill deny/re-enable, snapshot/rollback, install, and fixture smoke validation pass.
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
| `app.stateSnapshot` | No | Native macOS launch/read flow | status plus current skills, findings, conflicts, and compatibility snapshot payload |
| `service.status` | No | Diagnostics, adapter gating, and smoke tests | protocol version, app version, app data dir, catalog path, user home, supported methods, adapter capabilities, refresh capability state, and LLM gate status |
| `adapter.listCapabilities` | No | Native macOS agent selector/status gating | adapter capability matrix for scan, project scan, config toggle, config snapshot, install, writable state, and current blockers |
| `llm.status` | No | Native macOS LLM affordance gating | disabled-by-default LLM status: enabled/configured/provider/model/reason/token limit/budget/credential persistence policy |
| `llm.prepareAction` | No | Native macOS user-triggered LLM preflight | provider/model/token/cost estimate, confirmation requirement, prompt scope, privacy notes, and write-back guard for a requested LLM action |
| `script.previewExecution` | No | Native macOS script safety preview | command/cwd/env/network/files previews, risks, and confirmation requirement |
| `script.execute` | No | Native macOS script execution intent (default-deny path) | blocked/cancelled/failed attempt audit with redacted preview metadata; no real execution while runner is deferred |
| `project.getContext` | No | Native macOS project selector/read flow | `{ active: ProjectContext|null, recent: ProjectContext[] }` |
| `project.setContext` | Yes, writes app state | Native macOS project selector | validates and stores `{ root_path, current_cwd?, name? }`, then returns project context state |
| `project.clearContext` | Yes, writes app state | Native macOS project selector | clears active context, keeps recent contexts |
| `project.validateContext` | No | Native macOS project selector preflight | validates `{ root_path, current_cwd?, name? }` and returns a `ProjectContext` with `validation_error` set on failure |
| `catalog.listSkills` | No | Native macOS launch/read flow | `SkillRecord[]` |
| `catalog.getSkill` | No | Native macOS Overview detail | `SkillDetailRecord` for `{ "instance_id": "..." }` |
| `catalog.listFindings` | No | Native macOS Findings segment | `RuleFindingRecord[]` |
| `catalog.listConflicts` | No | Native macOS Conflicts segment | `ConflictGroupRecord[]` |
| `catalog.importSkill` | Yes, writes app-controlled staging/catalog only | V2.9 tool-global import | imported read-only `SkillRecord`, staging path, filtered findings, and audit summary |
| `catalog.scanAll` | Yes, refreshes catalog | Native macOS toolbar Scan action | scanned count, refreshed `SkillRecord[]`, and refresh activity summary for supported adapters |
| `catalog.scanClaude` | Yes, refreshes catalog | Compatibility / Claude-only diagnostics | scanned count, refreshed `SkillRecord[]`, and refresh activity summary |
| `skill.exportBundle` | Yes, writes app-controlled export files | V2.9 local tool-global/staging export | manifest path, bundle path, fingerprint, and reproducible metadata |
| `skill.install` | Yes, after confirmation | V2.9 install/copy from tool-global to target agent | preview or completed install record with target path, files, risks, confirmation, and optional snapshot id for future config-backed installs |
| `skill.listEvents` | No | Native macOS skill detail Recent Activity | recent local `skill_event` records for `{ "instance_id": "...", "limit"?: 12 }` |
| `config.toggleSkill` | Yes, writes agent config | Native macOS Enable / Disable action | updated `SkillRecord` |
| `config.readClaudeSettings` | No | Native macOS Settings editor load action | `ConfigDocumentRecord` |
| `config.saveClaudeSettings` | Yes, writes Claude settings and rescans | Native macOS Settings editor Save action | saved `ConfigDocumentRecord` |
| `snapshot.list` | No | Compatibility / diagnostics | global `ConfigSnapshotRecord[]` |
| `snapshot.listAgentConfig` | No | Native macOS Agent Config History | agent-config `ConfigSnapshotRecord[]` filtered by `{ "agent": "...", "scope"?: "agent-global" }` |
| `snapshot.previewRollback` | No | Native macOS Agent Config History preview action | snapshot, current content, read error, and changed flag |
| `snapshot.rollback` | Yes, writes agent config snapshot content and rescans | Native macOS Agent Config History rollback action | rescanned skill count |

`catalog.scanAll` is the native UI scan path.

It currently scans:

- Claude Code
- Codex
- opencode (verified writable for native roots)

It resolves the effective `ProjectContext` before adapter scanning.

## Adapter Capability Payload

`adapter.listCapabilities` and `service.status.adapter_capabilities` expose the same additive protocol v1 matrix:

```json
{
  "agent": "opencode",
  "display_name": "opencode",
  "status": "read-only",
  "scan": { "supported": true, "status": "verified" },
  "project_scan": { "supported": true, "status": "verified" },
  "config_toggle": {
    "supported": false,
    "status": "blocked",
    "reason": "opencode permission.skill patching, re-enable behavior, wildcard precedence, config ownership, and rollback path are not verified."
  },
  "config_snapshot": {
    "supported": false,
    "status": "blocked",
    "reason": "No rollback-safe opencode config write path is verified yet."
  },
  "install": {
    "supported": false,
    "status": "blocked",
    "reason": "opencode install remains blocked until writable semantics are verified."
  },
  "writable": {
    "supported": false,
    "status": "blocked",
    "reason": "opencode is native-root read-only until disposable local evidence proves safe writes."
  },
  "blockers": [
    "Verify permission.skill exact patch and re-enable behavior.",
    "Verify wildcard precedence and managed config ownership.",
    "Verify rollback-safe config writes before enabling toggle/install."
  ]
}
```

Current matrix:

| Agent | Top-level status | Scan | Writable/toggle |
| --- | --- | --- | --- |
| Claude Code | `verified` | Supported | Supported through verified settings writes |
| Codex | `verified` | Supported | Supported through user `config.toml`; project-local `.codex/config.toml` remains blocked |
| opencode | `verified` | Supported for native roots | Supported through exact `permission.skill` deny/re-enable and strict JSON writes |
| Pi | `read-only` | Pi-native roots scan | Writable toggle/install blocked pending settings mutation/rollback evidence |
| Hermes | `blocked` | Not implemented | Blocked pending maintainer-confirmed spec |
| OpenClaw | `blocked` | Not implemented | Blocked pending maintainer-confirmed spec |

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

The result is a preflight only: `allowed` is currently `false`, `requires_confirmation` is `true`, `write_back_allowed` is always `false`, and `draft_requires_user_copy` is always `true`. The response includes provider/model placeholders, estimated input/output/total tokens, estimated cost, prompt scope labels, and privacy notes suitable for UI display.

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
- `llm.prepareAction` is read-only preflight. It must never execute a provider, perform network I/O, write model output, write credentials/config, create a catalog when none exists, or return selected skill paths/body text in the response.
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
- `config.toggleSkill` snapshots the target agent config, takes a file lock, writes atomically, verifies read-back content, rolls back on verification failure, records a local `skill_event`, and refreshes catalog state. Claude Code writes `.claude/settings*.json`; Codex writes only the user `config.toml` `[[skills.config]]` override and never project `.codex/config.toml`. Opencode is read-only in V2.4: UI should disable toggle for opencode rows with a read-only adapter reason, and direct service attempts return a stable unsupported/read-only error without creating or modifying opencode config.
- `config.saveClaudeSettings` validates JSON, snapshots the target config, takes a file lock, writes atomically, verifies read-back content, rolls back on verification failure, and rescans before returning.
- `snapshot.listAgentConfig` is the product UI path for rollback history. It returns config snapshots by agent/scope and must not be treated as skill content history.
- `snapshot.rollback` writes the stored agent config snapshot content through the locked write path and rescans before returning the refreshed count.
- Future write methods must document snapshot, lock, verification, rollback, and rescan behavior before being exposed in native UI.

## Contract Fixtures

Shared request/response examples live in [`../fixtures/service-protocol`](../fixtures/service-protocol). The service crate has a fixture decoding test so schema drift is caught during `cargo test --workspace`.
