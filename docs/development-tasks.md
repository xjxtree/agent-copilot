# Development Tasks

> Status: current planning and execution queue as of 2026-06-10. V2.1 through V2.38 are synchronized baseline, and V2.39 is active/in-progress.

## Current Baseline

- Current branch baseline: `main` after V2.16-V2.28 management/analysis/history/explainability/provenance/conflict-semantics line and 2026-06-10 real local Computer Use validation; V2.22 finding/conflict 语义、V2.23 Health Dashboard / Adapter Capability UX、V2.24 Detail 诊断口径、V2.25 Agent-config timeline、V2.26 Finding explainability、V2.27 Skill identity/provenance dedupe、V2.28 Conflict semantic closeout 均已收口。
- Product boundary: native macOS SwiftUI/AppKit shell plus Rust service protocol.
- Completed V2 milestones: first Codex slice, V2.1 through V2.38.
- Current priority: V2.39 OpenClaw workspace deepening is active after V2.38 Hermes external roots completed. Keep V2.26 finding explainability, V2.27 identity/provenance, V2.28 conflict semantics, V2.29 finding triage persistence, V2.30 read-only AI analysis, V2.31 read-only cleanup queue, V2.32 app-local rule tuning, V2.33 preview-first + explicit-confirm batch actions, V2.34 read-only comparison, V2.35 local redacted export, V2.36 disposable evidence, V2.37 guarded Pi toggle, and V2.38 Hermes external roots stable. V2.39 must tighten OpenClaw workspace scope without generic repo inference; writable/install remain blocked, no script execution, no AI automatic writes, no credential persistence.
- Real local Computer Use baseline: passed on 2026-06-10 for the previous mainline app against real local HOME/app data/Claude/Codex/opencode roots; validation explicitly targeted the current `dist/SkillsCopilot.app` bundle after detecting a stale same-bundle-id worktree app. V2.38 completed real app smoke launch/window id check, but Computer Use/AX/capture returned `cgWindowNotFound` / no visible window; future user-visible, UI, or service protocol changes must rerun Computer Use and keep any blocker explicit.
- Quality gate for code/UI/protocol work: `pnpm check:macos`; add focused Rust/Swift tests when touching shared behavior.

## Versioned Adapter Plan

| Version | Goal | Status | Completion signal |
| --- | --- | --- | --- |
| V2.10 | Skill execution safety boundary and docs consistency | Closed | Safety boundary documented and release/docs consistency synchronized |
| V2.11 | Adapter Capability Matrix | Completed | Service protocol and macOS UI expose scan/toggle/install status and blockers for Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw |
| V2.12 | opencode writable support | Complete | Disposable local evidence verifies `permission.skill` writes, then guarded toggle/install is implemented and validated, or blocker remains explicit |
| V2.13 | Pi adapter support | Complete | Pi-native global/project scanner/parser is implemented read-only; writable toggle/install remains blocked pending settings mutation/rollback evidence |
| V2.14 | Hermes adapter support | Complete evidence-gate closeout; read-only later implemented in V2.17 | P0 evidence later confirmed first-class Hermes skills; writable/install remains blocked |
| V2.15 | OpenClaw adapter support | Complete evidence-gate closeout; read-only later implemented in V2.16 | P0 evidence later confirmed OpenClaw roots/schema for read-only scan; writable/install remains blocked |
| V2.16 | OpenClaw read-only scanner | Completed | OpenClaw documented roots appear in catalog read-only; scan is filesystem-only; project scan is workspace-scoped only (`<workspace>/skills`, `<workspace>/.agents/skills`); no arbitrary repo roots, CLI calls, writes, or installs |
| V2.17 | Hermes read-only scanner | Completed | Active/profile Hermes home `skills/**/SKILL.md` appears in catalog read-only; no generic project scan, cron mapping, writes, installs, CLI calls, or `.env`/`auth.json`/`logs`/`cron` mapping |
| V2.18 | Cross-agent skill analysis | Completed | Duplicate names, shadowing, precedence conflicts, malformed skills, disabled states, and source overlap are grouped across agents |
| V2.19 | Skill health dashboard and triage UX | Completed | `app.stateSnapshot.health` and native sidebar dashboard summarize health, findings, conflicts, risky scripts/permissions, and provide read-only triage filters |
| V2.20 | Read-only AI skill analysis assist | Completed | Disabled-by-default offline review preview summarizes skill purpose/risk/findings without provider calls, network, credentials, writes, configs, prompts, or script execution |
| V2.21 | Scan accuracy, dedupe behavior, and agent metric alignment | Completed | Normalize scan roots/path IDs, define deterministic duplicate handling across adapters, and align cross-agent visibility with catalog analysis + per-agent scan/activity and health metrics |
| V2.22 | finding/conflict 语义与验收同步 | Completed | Conflict=same-agent runtime/name collision; cross-agent duplicate/source-overlap lives in analysis; default findings use issue groups |
| V2.23 | Health Dashboard / Adapter Capability UX | Completed | Health card action summaries, selected-agent filtering, and scan/toggle/install/read-only/blocked capability status are aligned |
| V2.24 | Skill Detail 诊断工作台口径 | Completed | Detail=single skill workbench；Findings=issue groups；Conflicts=current-agent only；Analysis=read-only offline；History=toggle/config events only |
| V2.25 | Agent-config timeline | Completed | Per-agent config timeline, preview diff + confirm rollback, no skill-toggle snapshot, no skill-content snapshot |
| V2.26 | Finding explainability | Completed | Rule source, trigger reason/message, affected instances, scan entries, severity/risk mapping, and Health/Detail drill-down to concrete skill/rule/path are visible |
| V2.27 | Skill identity/provenance dedupe | Completed | Agent/scope/definition/path identity is deterministic; Pi `.md` noise stays excluded; opencode native and compatibility roots are explainable in UI |
| V2.28 | Conflict semantic closeout | Completed | Conflicts = selected/current agent runtime/name collisions only; cross-agent duplicate/source-overlap/enabled-mismatch = `Analysis` only; health conflict_count must not include cross-agent analysis groups |
| V2.29 | Finding triage persistence | Completed | reviewed/ignored/needs-follow-up are persisted in app-local catalog/app data; no agent-config writes, no skill-toggle snapshot, no skill-content snapshot; no script execution / AI write-back / credential persistence; findings reopen when fingerprint or affected-instance set changes |
| V2.30 | AI skill analysis workflow | Completed | User-triggered selected/batch read-only previews with summary + risk explanation + cleanup draft. Default local prepare/preview only; no background analysis; no writes, agent-config writes, snapshots, execution, or credential persistence |
| V2.31 | Cleanup Queue | Completed | Aggregate open findings, integrity issues, same-agent conflicts, and analysis insights into a read-only review queue; next actions map to existing safe affordances; no new automatic write/execute path |
| V2.32 | Rule tuning / suppression | Completed | Add app-local rule severity overrides and suppression with audit/revert semantics; no skill-file/agent-config writes, snapshots, provider calls, or credential side effects |
| V2.33 | Safe batch actions | Completed | Preview-first batch enable/disable for verified writable agents/roots only; show skipped items + reasons and explicit snapshot/rollback planning; Apply requires explicit confirmation and matching preview id |
| V2.34 | Cross-agent comparison view | Completed | Compare same-name/similar skills across agents by state, source, risk, writable capability, and differences; read-only by default |
| V2.35 | Local report export | Completed | Export redacted Markdown/JSON local audit reports for agent coverage, health summary, open findings, triage state, cleanup queue, and comparison insights |
| V2.36 | Pi writable evidence harness | Complete | Disposable agentDir/fixture project validates Pi global/project/package toggle, rollback, trust gate, invalid JSON/config handling, and re-enable behavior; production writable remains blocked |
| V2.37 | Pi writable guarded slice | Completed | Evidence-backed minimal Pi native toggle (global / project / package) with preview/snapshot/rollback/disabled-state rescan; Pi install remains blocked, no script execution, no AI automatic writes, no credential persistence, and no arbitrary compatibility write roots |
| V2.38 | Hermes external roots | Completed | Explicit `skills.external_dirs` are modeled as read-only external roots in adapter/scanner/UI provenance; no generic project scan, writable toggle, install, scripts, AI write-back, or credentials |
| V2.39 | OpenClaw workspace deepening | In Progress | Tighten workspace-scope detection and skipped/blocked root explanations without arbitrary repo inference or writes |
| V2.40 | Adapter diagnostics | Planned | Surface discovered/skipped/blocked roots, config detected, read-only/writable reason, and last scan activity per agent |
| V2.41-V2.45 | Long-term governance | Planned | Quality score, stale/drift detection, local knowledge index, policy packs, review session mode |

## Near-Term Priority: V2.26-V2.35 可解释、可追踪、可整理

**Goal**: turn current scan/health/detail/analysis surfaces into an explainable management workflow. Users should understand why a finding exists, where a skill came from, whether a conflict is same-agent or cross-agent, which issues are already reviewed, and how read-only AI can help summarize risks without causing writes or execution.

**Priority order**

1. V2.27 Skill identity/provenance dedupe: completed; keep agent/scope/definition/path identity deterministic, Pi `.md` resource noise excluded, and native vs compatibility roots explainable.
2. V2.28 Conflict semantic closeout: completed; keep same-agent runtime/name collisions in Conflicts for selected/current agent, keep cross-agent duplicate/source overlap/enabled-mismatch in Analysis, and ensure health conflict_count stays aligned to selected/current conflict groups.
3. V2.29 Finding triage persistence: completed; add reviewed/ignored/needs-follow-up state in app-local catalog/app data; do not write agent config, skill-toggle snapshot, or skill-content snapshot; no script execution / AI write-back / credential persistence; reopen when finding fingerprint or affected-instance set changes.
4. V2.30 AI skill analysis workflow: completed; disabled-by-default read-only AI summaries and suggestion drafts are prepared without provider calls by default, writes, execution, or credential storage.
5. V2.31 Cleanup Queue: completed; app-local review queue now aggregates open findings, integrity issues, same-agent conflicts, and analysis insights before later tuning/suppression/reporting work.
6. V2.32 Rule tuning / suppression: completed; local rule severity overrides and suppressions are auditable, reversible, and isolated from skill files, agent config, snapshots, provider calls, and credentials.
7. V2.33 Safe batch actions: completed; added preview-first batch enable/disable for verified writable agents/roots only, with explicit capability filtering, skipped item + reason reporting, rollback planning, and explicit confirmation before apply.
8. V2.34 Cross-agent comparison view: completed; compare same-name/similar skills across agents by state, source, risk, writable capability, and differences without adding write paths.
9. V2.35 Local report export: completed; generate redacted local Markdown/JSON audit reports from existing read models without distribution, provider calls, credentials, scripts, or automatic writes.
10. V2.36-V2.40 Adapter trust and diagnostics: active; V2.36 Pi writable evidence harness, V2.37 minimal guarded Pi native toggle, and V2.38 Hermes external roots are complete. Next deepen OpenClaw workspace scope and adapter diagnostics without guessing write semantics.
11. V2.41-V2.45 Long-term governance: quality score, stale/drift detection, local knowledge index, policy packs, and review sessions.

**Tasks**

- Keep finding/risk/analysis labels explainable: risk is a subset of findings; analysis is cross-agent insight; conflict is selected-agent runtime/name collision.
- Keep skill identity deterministic across all adapters and expose provenance labels in UI where user confusion is likely.
- Keep triage state in app-local storage only; never hide unresolved high-risk findings by default.
- Keep optional AI analysis read-only, disabled by default, and separate from all write/config/script paths. It must remain explicit user-triggered, support selected/batch preview only, and must not perform provider calls or triage state changes by default.
- Keep Hermes/OpenClaw writable/install blocked until individual skill disable schema, credential preservation, and rollback-safe writes are verified.
- Keep Pi install and compatibility-root writes blocked; Pi toggle support is limited to the V2.37 guarded native global/project/package scope with snapshot/rollback.
- Keep every new write path behind service protocol, snapshot, audit, permission, and privacy boundaries.
- Update native macOS UI only as needed to expose clearer explanations, statuses, filters, finding groups, and guarded writable actions.

**Exit Criteria**

- V2.26-V2.30 docs and code make finding/risk/conflict/analysis semantics explainable from Health, list, detail, and analysis views.
- Skill provenance and dedupe behavior are deterministic enough that Pi/opencode/compatibility-root surprises can be explained from the UI.
- Triage persistence helps reduce repeated noise while avoiding agent-config writes, script execution, AI write-back, and credential persistence; affected-instance drift should reopen triage automatically.
- AI-assisted analysis remains opt-in, read-only, privacy-safe, user-triggered, and impossible to use as an execution/write path. It must keep analysis scope read-only, copy-only draft outputs, and no background triggers.
- `docs/agent-adapters.md`, `docs/agent-adapter-spec-worklists.md`, `docs/development-tasks.md`, `docs/roadmap.md`, `docs/service-protocol.md`, `docs/data-model.md`, `docs/ui-delivery-standards.md`, and `AGENTS.md` agree on the current support state and next version line.

## Current Backlog

These items keep the product focused on managing, inspecting, and analyzing skills. Script execution, GitHub clone import, and script-file install are removed from the active backlog.

| Priority | Work item | Current status | Next concrete task | Completion signal |
| --- | --- | --- | --- | --- |
| P0 | Real local Computer Use rerun gate | Previous mainline pass completed on 2026-06-10; V2.37 slice hit Computer Use `cgWindowNotFound` despite direct CG/AX window evidence | Rerun the real app against local HOME after UI/service/protocol changes, explicitly targeting the current `dist/SkillsCopilot.app` bundle when stale same-bundle-id worktree apps exist, covering project context, scan-all, agent filter, findings filtering/grouping, health dashboard, AI review preview, and script safety preview | App-window-only evidence and runbook notes updated for the new slice, or an explicit tool/session blocker is recorded |
| P0 | V2.11 Adapter Capability Matrix | Completed and in use | Run focused protocol/UI checks when needed, then use the matrix as the gate for future Pi/opencode/Hermes/OpenClaw work | macOS UI shows precise scan/toggle/install status and blockers for all six agents |
| P0 | Pi comprehensive adapter support | Read-only scanner complete; V2.37 guarded native toggle complete; install and compatibility-root writes blocked | Keep Pi toggle limited to global/project/package write scope and keep install/AI auto-write/script execution credentials-unsafe paths blocked; exclude arbitrary compatibility roots from write path | Guarded native toggle preserves preview/snapshot/rollback, trust gate, invalid JSON/config handling, re-enable behavior, and disabled-state rescan |
| P0 | opencode support | Native and official compatibility roots are scanned; guarded `permission.skill` writes are implemented; install targets remain native roots | Keep compatibility-root scan coverage and managed permission/write tests current; custom `skills.paths` / `skills.urls` remain deferred pending evidence | opencode-visible skills match current official discovery roots without enabling unverified custom paths or unsafe file writes |
| P0 | Hermes adapter support | Read-only scanner implemented; writable/install blocked | Keep scoped read-only scan of active Hermes home `skills/**/SKILL.md`; treat `skills.external_dirs` as explicit external roots only (not generic project-scope inference); keep `.env`/`auth.json`/`logs`/cron content filtered and CLI-only scan read-only | Hermes skills appear in catalog read-only; generic project scan and writes remain blocked |
| P0 | OpenClaw adapter support | Read-only scanner implemented; writable/install blocked | Keep scoped read-only filesystem scan over documented roots; project scan only for confirmed OpenClaw workspace roots; no OpenClaw CLI calls during ordinary scan | OpenClaw skills appear in catalog read-only; arbitrary repo roots and writes/install remain blocked |
| P0 | Cross-agent skill analysis | Implemented read-only | Keep catalog summaries for duplicate/conflict/precedence/source-overlap groups aligned with fixtures and UI needs | Users can identify conflicting or duplicated skills across agents without manually comparing lists |
| P0 | Skill health dashboard | Implemented read-only | Keep dashboard summary cards and actionable filters for findings, conflicts, disabled skills, malformed metadata, risky scripts, and permission issues aligned with service health payload | Users can prioritize cleanup from a single management view |
| P0 | V2.21 scan accuracy / dedupe / agent metrics | Completed | Add scan contract coverage for canonical path/id collision handling, source overlap handling, and per-agent stats consistency checks across scan activity + health payloads | Duplicate and overlap records are deterministic; per-agent counts in scan/activity and health payloads are documented and testable |
| P0 | V2.22 finding/conflict semantics sync | Completed | Keep conflict definition / cross-agent analysis separation stable when adding new UI | Conflict/finding behavior is uniform across roadmap/tasks/service-protocol/data-model/adapter docs and can be traced in same scan context |
| P0 | V2.23 Health Dashboard / Adapter Capability UX 同步 | Completed | Keep selected-agent health card and capability matrix semantics stable when adding triage/explainability | 核心工作流（侧栏、adapter matrix、findings 过滤）口径一致 |
| P0 | V2.24 Skill Detail 诊断口径 | Completed | Keep Detail=single skill workbench; Findings=issue groups; Conflicts=current-agent; Analysis read-only/offline; History=toggle/config events | catalog.detail（single skill）与 list/health/analysis 数字口径一致 |
| P0 | V2.26 Finding explainability | Completed | Keep rule source, trigger reason/message, affected instances, severity/risk mapping, and next action visible in finding/detail surfaces | Users can understand every finding count and drill down from Health to concrete skill/rule/path context |
| P0 | V2.27 Skill identity/provenance dedupe | Completed | Keep agent/scope/definition/path identity deterministic; keep Pi `.md` noise excluded; label opencode native vs compatibility roots | Users can explain why each skill appears once, appears under multiple agents, or is intentionally excluded |
| P0 | V2.28 Conflict semantic closeout | Completed | Keep UI/protocol wording so same-agent conflicts and cross-agent analysis never share the same counter | Conflict tabs only show current-agent collisions; Analysis owns cross-agent duplicate/source-overlap |
| P0 | V2.29 Finding triage persistence | Completed | Add app-local reviewed/ignored/needs-follow-up state in catalog/app data with automatic reopen on changed finding fingerprint or affected-instance set; no agent-config writes, no skill-toggle snapshot, no skill-content snapshot; no script execution / AI write-back / credential persistence | Users can separate known issues from new actionable findings without write-path side effects |
| P0 | V2.30 AI skill analysis workflow | Completed | Extend disabled-by-default read-only AI analysis to batch summaries and suggestion drafts | Users get readable skill analysis with no writes, no script execution, no provider calls by default, and no credential storage |
| P0 | V2.31 Cleanup Queue | Completed | Turn open findings, integrity issues, and analysis insights into an app-local read-only queue with clear next actions that only point to existing safe action paths | Users can work down skill cleanup items without introducing new automatic write/execute paths |
| P0 | V2.32 Rule tuning / suppression | Completed | Add app-local rule severity overrides and suppression records with audit/revert semantics, without touching skill files/agent config/snapshots or provider/credential paths | Users can quiet intentional findings and tune priority while preserving reviewability |
| P0 | V2.33 Safe batch actions | Completed | Add preview-first batch enable/disable for verified writable agents/roots only, with skipped-item reasons for read-only scope, snapshot/rollback plans, explicit confirmation, and matching preview id before any write | Users can safely act on multiple selected skills without hidden writes |
| P0 | V2.34 Cross-agent comparison view | Completed | Add read-only comparison for same-name/similar skills across agents, including state/source/risk/capability/diff summaries | Users can understand cross-agent drift before cleanup/export |
| P0 | V2.35 Local report export | Completed | Add user-triggered redacted Markdown/JSON local audit export from existing read models; no public distribution, provider calls, credentials, scripts, or automatic writes | Users can share/review skill inventory and risk state without leaking local paths or widening write scope |
| P0 | V2.36 Pi writable evidence harness | Complete | Validate Pi writable semantics only in disposable roots with rollback proof before any production toggle/install surface is enabled | Pi writable can advance only with evidence instead of assumptions |
| P1 | Finding triage usability and grouping | Planned | Add grouping and shortcut filters for reviewed/ignored/needs follow-up findings (by rule / severity / agent / source) without writing agent config, script execution, AI write-back, or credentials | Users can act on persistent triage faster without widening state persistence scope |
| P1 | Agent-config timeline | Completed | Keep per-agent config snapshots and activity history only for config/toggle events; enforce preview diff and second-step confirmation for rollback; do not add skill-content snapshot or skill-toggle snapshot | Users can understand config changes and rollback points |
| P1 | Read-only AI skill analysis assist | Implemented offline preview | Keep V2.7 disabled-by-default gate and V2.20 offline purpose/risk/finding summaries free of provider/client/storage/write/execution paths | Users get human-readable analysis without any write, execution, or credential risk |

## Version Selection Rule

- If the task is OpenClaw/Hermes scanner work, use V2.16/V2.17.
- If the task is already-completed cross-agent analysis, dashboard, scan accuracy, dedupe, finding/conflict semantics, single-skill detail, or agent-config timeline maintenance, reference V2.18-V2.25.
- If the task improves finding explanations, skill identity/provenance, conflict semantics, triage persistence, or read-only AI analysis workflow, use V2.26-V2.30.
- If the task builds cleanup queue, policy tuning, safe batch actions, cross-agent comparison, or local report export, use V2.31-V2.35.
- If the task is Pi writable evidence, Hermes external roots, OpenClaw workspace deepening, or adapter diagnostics, use V2.36-V2.40.
- If the task is quality scoring, stale/drift detection, local knowledge index, policy packs, or review session mode, use V2.41-V2.45.
- Do not create versions for script execution, GitHub clone import, script-file install, signing, notarization, DMG/ZIP, public distribution, or full-platform UI adaptation unless the product direction changes explicitly.

## V2.35 Local report export — completed
- [x] Document local export intent and completed status in user-facing docs (README + roadmap + AGENTS).
- [x] Record report scope: agent coverage/status, health summary, open findings/triage state, cleanup queue, cross-agent comparison insights.
- [x] Document redaction requirements for exported data: local paths and environment roots must be replaced with placeholders.
- [x] Document explicit non-goals: public distribution, DMG/ZIP/signing/notarization, cloud sync, telemetry, provider calls, credential storage, script execution, automatic write-back.
- [x] Confirm V2.33/V2.34 semantics are preserved in updated docs.
- [x] Validate with `pnpm check:macos`, real local App export, and generated report path-redaction check.
