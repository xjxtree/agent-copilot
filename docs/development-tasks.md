# Development Tasks

> Status: current planning and execution queue as of 2026-06-10. V2.1 through V2.21 are closed on the main line. V2.22 finding/conflict 语义与验收同步正在进行中。

## Current Baseline

- Current branch baseline: `main` after V2.16-V2.21 management/analysis line and 2026-06-10 real local Computer Use validation; V2.22 finding/conflict 语义同步正在推进。
- Product boundary: native macOS SwiftUI/AppKit shell plus Rust service protocol.
- Completed V2 milestones: first Codex slice, V2.1 through V2.20.
- Current priority: keep read-only management and analysis stable while completing V2.22 finding/conflict semantics sync, preparing Pi writable evidence, finding triage persistence, and agent-config timeline follow-ups. V2.21 completed explicit scan accuracy, dedupe, and per-agent statistic requirements.
- Real local Computer Use baseline: passed on 2026-06-10 for the current mainline app against real local HOME/app data/Claude/Codex/opencode roots; validation explicitly targeted the current `dist/SkillsCopilot.app` bundle after detecting a stale same-bundle-id worktree app. Future user-visible, UI, or service protocol changes must rerun it.
- Quality gate for code/UI/protocol work: `pnpm check:macos`; add focused Rust/Swift tests when touching shared behavior.

## Versioned Adapter Plan

| Version | Goal | Status | Completion signal |
| --- | --- | --- | --- |
| V2.10 | Skill execution safety boundary and docs consistency | Closed | Safety boundary documented and release/docs consistency synchronized |
| V2.11 | Adapter Capability Matrix | Completed | Service protocol and macOS UI expose scan/toggle/install status and blockers for Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw |
| V2.12 | opencode writable support | Complete | Disposable local evidence verifies `permission.skill` writes, then guarded toggle/install is implemented and validated, or blocker remains explicit |
| V2.13 | Pi adapter support | Complete | Pi-native global/project scanner/parser is implemented read-only; writable toggle/install remains blocked pending settings mutation/rollback evidence |
| V2.14 | Hermes adapter support | Complete evidence-gate closeout; P0 read-only candidate | P0 evidence later confirmed first-class Hermes skills; writable/install remains blocked |
| V2.15 | OpenClaw adapter support | Complete evidence-gate closeout; P0 read-only candidate | P0 evidence later confirmed OpenClaw roots/schema for read-only scan; writable/install remains blocked |
| V2.16 | OpenClaw read-only scanner | Completed | OpenClaw documented roots appear in catalog read-only; scan is filesystem-only; project scan is workspace-scoped only (`<workspace>/skills`, `<workspace>/.agents/skills`); no arbitrary repo roots, CLI calls, writes, or installs |
| V2.17 | Hermes read-only scanner | Completed | Active/profile Hermes home `skills/**/SKILL.md` appears in catalog read-only; no generic project scan, cron mapping, writes, installs, CLI calls, or `.env`/`auth.json`/`logs`/`cron` mapping |
| V2.18 | Cross-agent skill analysis | Completed | Duplicate names, shadowing, precedence conflicts, malformed skills, disabled states, and source overlap are grouped across agents |
| V2.19 | Skill health dashboard and triage UX | Completed | `app.stateSnapshot.health` and native sidebar dashboard summarize health, findings, conflicts, risky scripts/permissions, and provide read-only triage filters |
| V2.20 | Read-only AI skill analysis assist | Completed | Disabled-by-default offline review preview summarizes skill purpose/risk/findings without provider calls, network, credentials, writes, configs, prompts, or script execution |
| V2.21 | Scan accuracy, dedupe behavior, and agent metric alignment | Completed | Normalize scan roots/path IDs, define deterministic duplicate handling across adapters, and align cross-agent visibility with catalog analysis + per-agent scan/activity and health metrics |
| V2.22 | finding/conflict 语义与验收同步 | In progress | Unify conflict definition as same-agent runtime/name collision; move cross-agent duplicate/source-overlap to analysis insights; align default finding groups and count semantics |

## Near-Term Priority: Comprehensive Agent Adapter Support

**Goal**: make the macOS app materially better at managing, inspecting, and analyzing skills across agents.

**Priority order**

1. V2.16 OpenClaw read-only scanner: completed filesystem scan only, project scope limited to confirmed OpenClaw workspace roots `<workspace>/skills` and `<workspace>/.agents/skills`, no CLI calls during ordinary scan, no arbitrary repo roots, writable/install blocked.
2. V2.17 Hermes read-only scanner: completed active Hermes home `skills/**/SKILL.md` only, no generic project scan, no cron-to-skill mapping, no `.env`/`auth.json`/`logs`/`cron` mapping, no CLI calls, writable/install blocked.
3. V2.18 Cross-agent skill analysis: completed duplicate/conflict/precedence/source-overlap analysis across supported agents.
4. V2.19 Skill health dashboard and triage UX: completed aggregate health, findings, conflicts, risk, and read-only triage filters.
5. V2.20 Read-only AI skill analysis assist: completed disabled-by-default, offline read-only summaries and finding explanations.
6. Pi writable evidence harness: keep planned, but schedule after read-only management and analysis improvements unless user explicitly prioritizes Pi writes.
7. V2.21 scan accuracy / dedupe / stats pass: completed doc/spec/test coverage for deterministic duplicate handling and agent-scoped counting before downstream triage rules depend on the data.
8. V2.22 finding/conflict semantics sync: align same-agent conflict definition and cross-agent analysis separation before triage persistence.

**Tasks**

- Keep the service/UI adapter capability matrix current for Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw so the macOS app can expose precise scan/toggle/install status before each adapter is fully implemented.
- Add cross-agent analysis data to the service protocol without duplicating adapter-specific logic in the UI.
- Add dashboard/triage UI that helps users answer: which skills exist, which are risky, which conflict, which are disabled, and what needs attention first.
- Keep scan accuracy and dedupe behavior as blocking criteria for any new write-path work until duplicate handling is consistent across adapters.
- Keep optional AI analysis read-only, disabled by default, and separate from all write/config/script paths.
- Keep Hermes writable/install blocked until individual skill disable schema, profile scope, and rollback-safe writes are verified.
- Keep OpenClaw writable/install blocked until disposable config mutation, credential preservation, and rollback-safe writes are verified.
- Keep every new adapter behind the existing service protocol, snapshot, audit, permission, and privacy boundaries.
- Update native macOS UI only as needed to expose newly supported agents, statuses, filters, findings, and guarded writable actions.
- Add fixtures and non-destructive tests for every supported adapter mode before enabling writes.

**Exit Criteria**

- OpenClaw and Hermes read-only skills are visible and correctly scoped in catalog/detail views.
- Cross-agent duplicate/conflict/precedence analysis gives actionable grouping without inventing unsupported roots.
- Skill health dashboard and triage UX reduce list scanning and make high-risk or broken skills easy to find.
- AI-assisted analysis remains opt-in, read-only, privacy-safe, and impossible to use as an execution/write path.
- `docs/agent-adapters.md`, `docs/agent-adapter-spec-worklists.md`, `docs/development-tasks.md`, `docs/roadmap.md`, and `AGENTS.md` agree on adapter priority and current support state.
- V2.21 scan correctness rules are implemented and documented before adding triage persistence and metrics-consuming automation.

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
| P0 | V2.22 finding/conflict semantics sync | In progress | Finalize conflict definition / cross-agent analysis separation; align default finding groups + instance/entry count retention; keep health and detail/list filter statistics consistent | Conflict/finding behavior is uniform across roadmap/tasks/service-protocol/data-model/adapter docs and can be traced in same scan context |
| P1 | Finding triage persistence | Planned | Add reviewed/ignored state and grouping by rule, severity, agent, and source without writing agent config or hiding unresolved high-risk findings | Users can separate known issues from new actionable findings |
| P1 | Agent-config timeline | Planned | Show agent-config snapshots and activity history per agent without adding skill-content snapshots | Users can understand config changes and rollback points |
| P1 | Read-only AI skill analysis assist | Implemented offline preview | Keep V2.7 disabled-by-default gate and V2.20 offline purpose/risk/finding summaries free of provider/client/storage/write/execution paths | Users get human-readable analysis without any write, execution, or credential risk |

## Version Selection Rule

- If the task is OpenClaw/Hermes scanner work, use V2.16/V2.17.
- If the task is cross-agent analysis, dashboard, scan accuracy, dedupe, finding/conflict semantics, or triage, use V2.18-V2.22.
- Do not create versions for script execution, GitHub clone import, script-file install, signing, notarization, DMG/ZIP, public distribution, or full-platform UI adaptation unless the product direction changes explicitly.
