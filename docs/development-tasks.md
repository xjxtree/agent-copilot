# Development Tasks

> Status: current planning and execution queue as of 2026-06-10. V2.1 through V2.26 are synchronized baseline. The next execution line is V2.27-V2.30, with V2.27 next.

## Current Baseline

- Current branch baseline: `main` after V2.16-V2.26 management/analysis/history/explainability line and 2026-06-10 real local Computer Use validation; V2.22 finding/conflict 语义、V2.23 Health Dashboard / Adapter Capability UX、V2.24 Detail 诊断口径、V2.25 Agent-config timeline、V2.26 Finding explainability 均已收口。
- Product boundary: native macOS SwiftUI/AppKit shell plus Rust service protocol.
- Completed V2 milestones: first Codex slice, V2.1 through V2.20.
- Current priority: V2.27 skill identity/provenance dedupe, then V2.28-V2.30. Keep V2.26 finding explainability stable: rule source + trigger reason/message + affected instances + scan entries + severity/risk relation must remain visible. Keep V2.24/V2.25 boundaries: Findings=issue groups, Conflicts=current-agent only, Analysis=read-only/offline, History=toggle/config events, no skill-content snapshot, and rollback remains preview+confirm.
- Real local Computer Use baseline: passed on 2026-06-10 for the current mainline app against real local HOME/app data/Claude/Codex/opencode roots; validation explicitly targeted the current `dist/SkillsCopilot.app` bundle after detecting a stale same-bundle-id worktree app. Future user-visible, UI, or service protocol changes must rerun it.
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
| V2.27 | Skill identity/provenance dedupe | Planned | Agent/path/root/provenance identity is deterministic; Pi `.md` noise stays excluded; opencode compatibility roots are explainable |
| V2.28 | Conflict semantic closeout | Planned | Same-agent conflicts and cross-agent analysis are separated in every UI/protocol surface |
| V2.29 | Finding triage persistence | Planned | reviewed/ignored/needs-follow-up are persisted locally without writing agent config; changed fingerprints reopen findings |
| V2.30 | AI skill analysis workflow | Planned | Disabled-by-default read-only AI analysis supports batch summaries and suggestion drafts without writes/execution/credentials |
| V2.31-V2.35 | Cleanup workflow | Planned | Cleanup queue, rule tuning/suppression, safe batch actions, cross-agent comparison, local report export |
| V2.36-V2.40 | Adapter trust and diagnostics | Planned | Pi writable evidence harness, guarded Pi slice if proven, Hermes external roots, OpenClaw workspace deepening, adapter diagnostics |
| V2.41-V2.45 | Long-term governance | Planned | Quality score, stale/drift detection, local knowledge index, policy packs, review session mode |

## Near-Term Priority: V2.26-V2.30 可解释、可追踪、可整理

**Goal**: turn current scan/health/detail/analysis surfaces into an explainable management workflow. Users should understand why a finding exists, where a skill came from, whether a conflict is same-agent or cross-agent, which issues are already reviewed, and how read-only AI can help summarize risks without causing writes or execution.

**Priority order**

1. V2.26 Finding explainability: make every finding group explain rule source, trigger reason/message, affected instances, scan entries, severity/risk mapping, and next action.
2. V2.27 Skill identity/provenance dedupe: make agent/root/path/provenance deterministic; keep Pi `.md` resource noise excluded; label opencode native vs compatibility roots clearly.
3. V2.28 Conflict semantic closeout: keep same-agent runtime/name collisions in Conflicts and move cross-agent duplicate/source overlap to Analysis only.
4. V2.29 Finding triage persistence: add reviewed/ignored/needs-follow-up state in app-local catalog; do not write agent config; reopen changed fingerprints.
5. V2.30 AI skill analysis workflow: improve disabled-by-default read-only AI summaries and suggestion drafts without provider calls by default, writes, execution, or credential storage.
6. V2.31-V2.35 Cleanup workflow: build cleanup queue, rule tuning/suppression, safe batch actions, cross-agent comparison, and local report export after semantics are stable.
7. V2.36-V2.40 Adapter trust and diagnostics: only after the management workflow is stable, run Pi writable evidence harness and deepen Hermes/OpenClaw diagnostics without guessing write semantics.
8. V2.41-V2.45 Long-term governance: quality score, stale/drift detection, local knowledge index, policy packs, and review sessions.

**Tasks**

- Keep finding/risk/analysis labels explainable: risk is a subset of findings; analysis is cross-agent insight; conflict is selected-agent runtime/name collision.
- Keep skill identity deterministic across all adapters and expose provenance labels in UI where user confusion is likely.
- Keep triage state in app-local storage only; never hide unresolved high-risk findings by default.
- Keep optional AI analysis read-only, disabled by default, and separate from all write/config/script paths.
- Keep Hermes/OpenClaw writable/install blocked until individual skill disable schema, credential preservation, and rollback-safe writes are verified.
- Keep Pi writable support blocked until the disposable evidence harness proves exact mutation and rollback semantics.
- Keep every new write path behind service protocol, snapshot, audit, permission, and privacy boundaries.
- Update native macOS UI only as needed to expose clearer explanations, statuses, filters, finding groups, and guarded writable actions.

**Exit Criteria**

- V2.26-V2.30 docs and code make finding/risk/conflict/analysis semantics explainable from Health, list, detail, and analysis views.
- Skill provenance and dedupe behavior are deterministic enough that Pi/opencode/compatibility-root surprises can be explained from the UI.
- Triage persistence helps reduce repeated noise without writing agent config or hiding changed high-risk findings.
- AI-assisted analysis remains opt-in, read-only, privacy-safe, and impossible to use as an execution/write path.
- `docs/agent-adapters.md`, `docs/agent-adapter-spec-worklists.md`, `docs/development-tasks.md`, `docs/roadmap.md`, `docs/service-protocol.md`, `docs/data-model.md`, `docs/ui-delivery-standards.md`, and `AGENTS.md` agree on the current support state and next version line.

## Current Backlog

These items keep the product focused on managing, inspecting, and analyzing skills. Script execution, GitHub clone import, and script-file install are removed from the active backlog.

| Priority | Work item | Current status | Next concrete task | Completion signal |
| --- | --- | --- | --- | --- |
| P0 | Real local Computer Use rerun gate | Completed for the current mainline app on 2026-06-10; recurring for future user-visible changes | Rerun the real app against local HOME after UI/service/protocol changes, explicitly targeting the current `dist/SkillsCopilot.app` bundle when stale same-bundle-id worktree apps exist, covering project context, scan-all, agent filter, findings filtering/grouping, health dashboard, AI review preview, and script safety preview | App-window-only evidence and runbook notes updated for the new candidate |
| P0 | V2.11 Adapter Capability Matrix | Completed and in use | Run focused protocol/UI checks when needed, then use the matrix as the gate for future Pi/opencode/Hermes/OpenClaw work | macOS UI shows precise scan/toggle/install status and blockers for all six agents |
| P0 | Pi comprehensive adapter support | Read-only scanner complete; writable evidence supports a harness but not production writes | Implement disposable writable evidence harness for Pi-native roots and package filters; exclude `.agents/skills` compatibility roots from first writable slice | Harness proves native/global/project/package toggle, rollback, trust gate, invalid JSON behavior, and re-enable strategy |
| P0 | opencode support | Native and official compatibility roots are scanned; guarded `permission.skill` writes are implemented; install targets remain native roots | Keep compatibility-root scan coverage and managed permission/write tests current; custom `skills.paths` / `skills.urls` remain deferred pending evidence | opencode-visible skills match current official discovery roots without enabling unverified custom paths or unsafe file writes |
| P0 | Hermes adapter support | Read-only scanner implemented; writable/install blocked | Keep scoped read-only scan of active Hermes home `skills/**/SKILL.md`; skip generic project roots, `.env`/`auth.json`/`logs`/cron content, and read-only scan CLI calls | Hermes skills appear in catalog read-only; generic project scan and writes remain blocked |
| P0 | OpenClaw adapter support | Read-only scanner implemented; writable/install blocked | Keep scoped read-only filesystem scan over documented roots; project scan only for confirmed OpenClaw workspace roots; no OpenClaw CLI calls during ordinary scan | OpenClaw skills appear in catalog read-only; arbitrary repo roots and writes/install remain blocked |
| P0 | Cross-agent skill analysis | Implemented read-only | Keep catalog summaries for duplicate/conflict/precedence/source-overlap groups aligned with fixtures and UI needs | Users can identify conflicting or duplicated skills across agents without manually comparing lists |
| P0 | Skill health dashboard | Implemented read-only | Keep dashboard summary cards and actionable filters for findings, conflicts, disabled skills, malformed metadata, risky scripts, and permission issues aligned with service health payload | Users can prioritize cleanup from a single management view |
| P0 | V2.21 scan accuracy / dedupe / agent metrics | Completed | Add scan contract coverage for canonical path/id collision handling, source overlap handling, and per-agent stats consistency checks across scan activity + health payloads | Duplicate and overlap records are deterministic; per-agent counts in scan/activity and health payloads are documented and testable |
| P0 | V2.22 finding/conflict semantics sync | Completed | Keep conflict definition / cross-agent analysis separation stable when adding new UI | Conflict/finding behavior is uniform across roadmap/tasks/service-protocol/data-model/adapter docs and can be traced in same scan context |
| P0 | V2.23 Health Dashboard / Adapter Capability UX 同步 | Completed | Keep selected-agent health card and capability matrix semantics stable when adding triage/explainability | 核心工作流（侧栏、adapter matrix、findings 过滤）口径一致 |
| P0 | V2.24 Skill Detail 诊断口径 | Completed | Keep Detail=single skill workbench; Findings=issue groups; Conflicts=current-agent; Analysis read-only/offline; History=toggle/config events | catalog.detail（single skill）与 list/health/analysis 数字口径一致 |
| P0 | V2.26 Finding explainability | Completed | Keep rule source, trigger reason/message, affected instances, severity/risk mapping, and next action visible in finding/detail surfaces | Users can understand every finding count and drill down from Health to concrete skill/rule/path context |
| P0 | V2.27 Skill identity/provenance dedupe | Planned | Normalize and label agent/root/path/provenance; keep Pi `.md` noise excluded; clarify opencode native vs compatibility roots | Users can explain why each skill appears once, appears under multiple agents, or is intentionally excluded |
| P0 | V2.28 Conflict semantic closeout | Planned | Audit remaining UI/protocol wording so same-agent conflicts and cross-agent analysis never share the same counter | Conflict tabs only show current-agent collisions; Analysis owns cross-agent duplicate/source-overlap |
| P0 | V2.29 Finding triage persistence | Planned | Add app-local reviewed/ignored/needs-follow-up state with changed-fingerprint reopening | Users can separate known issues from new actionable findings without writing agent config |
| P0 | V2.30 AI skill analysis workflow | Planned | Extend disabled-by-default read-only AI analysis to batch summaries and suggestion drafts | Users get readable skill analysis with no writes, no script execution, no provider calls by default, and no credential storage |
| P1 | Finding triage persistence | Planned | Add reviewed/ignored state and grouping by rule, severity, agent, and source without writing agent config or hiding unresolved high-risk findings | Users can separate known issues from new actionable findings |
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
