# Development Tasks

> Status: current planning and execution queue as of 2026-06-09. V2.1 through V2.10 are closed on the main line. Near-term priority is comprehensive agent adapter support for Pi, opencode writable support, Hermes, and OpenClaw evidence/implementation in the macOS app.

## Current Baseline

- Current branch baseline: `main` after V2.10 execution safety boundary docs/release consistency and 2026-06-09 real local Computer Use validation.
- Product boundary: native macOS SwiftUI/AppKit shell plus Rust service protocol.
- Completed V2 milestones: first Codex slice, V2.1 through V2.10.
- Current priority: close the remaining agent adapter evidence and implementation gaps in the macOS app.
- Real local Computer Use baseline: passed on 2026-06-09 for the current mainline app against real local HOME/app data/Claude/Codex/opencode roots; future user-visible, UI, or service protocol changes must rerun it.
- Quality gate for code/UI/protocol work: `pnpm check:macos`; add focused Rust/Swift tests when touching shared behavior.

## Near-Term Priority: Comprehensive Agent Adapter Support

**Goal**: make the macOS app agent matrix materially more complete.

**Priority order**

1. Pi disposable local round-trip and adapter implementation plan.
2. opencode writable evidence, toggle/install design, and guarded implementation if evidence supports it.
3. Hermes maintainer-confirmed spec and adapter plan.
4. OpenClaw maintainer-confirmed spec and adapter plan.

**Tasks**

- Build disposable local evidence harnesses for Pi and opencode writable semantics so tests never mutate the developer's real config by default.
- Verify Pi scan roots, config schema, enable/disable semantics, project/global precedence, rollback behavior, and fixture coverage before implementing writes.
- Verify opencode `permission.skill` patching, wildcard precedence, disable/re-enable behavior, config ownership, rollback path, and native-root-only scope before relaxing the read-only guard.
- Obtain maintainer-confirmed Hermes roots, config schema, package/task model, toggle semantics, and credential-handling guidance before implementation.
- Obtain maintainer-confirmed OpenClaw skill schema, config safety rules, install/toggle semantics, and credential-handling guidance before implementation.
- Keep every new adapter behind the existing service protocol, snapshot, audit, permission, and privacy boundaries.
- Update native macOS UI only as needed to expose newly supported agents, statuses, filters, findings, and guarded writable actions.
- Add fixtures and non-destructive tests for every supported adapter mode before enabling writes.

**Exit Criteria**

- Pi has verified read/write semantics or an explicit blocker with disposable local evidence.
- opencode writable support is either implemented behind tests and snapshots or remains blocked with precise missing evidence.
- Hermes has maintainer-confirmed evidence sufficient for implementation, or remains explicitly blocked with the missing facts listed.
- OpenClaw has maintainer-confirmed evidence sufficient for implementation, or remains explicitly blocked with the missing facts listed.
- `docs/agent-adapters.md`, `docs/agent-adapter-spec-worklists.md`, `docs/development-tasks.md`, `docs/roadmap.md`, and `AGENTS.md` agree on adapter priority and current support state.

## Cross-Version Backlog

These items are real work, but they are not unfinished V2.1-V2.10 tasks.

| Priority | Work item | Current status | Next concrete task | Completion signal |
| --- | --- | --- | --- | --- |
| P0 | Real local Computer Use rerun gate | Completed for the current mainline app on 2026-06-09; recurring for future user-visible changes | Rerun the real app against local HOME after UI/service/protocol changes, covering project context, scan-all, agent filter, findings filtering/grouping, opencode read-only toggle, and script safety preview | App-window-only evidence and runbook notes updated for the new candidate |
| P0 | Pi comprehensive adapter support | Evidence incomplete; promoted to near-term priority | Use disposable local Pi config/skill roots to verify scan and toggle semantics before implementation | Pi adapter has verified roots, schema, toggle behavior, fixtures, non-destructive tests, and UI/service status |
| P0 | opencode writable support | Read-only native-root support exists; writable semantics remain unverified; promoted to near-term priority | Verify `permission.skill` exact patch, re-enable behavior, wildcard precedence, config ownership, and rollback path | opencode writable toggle/install design is accepted and implemented behind snapshots/tests, or blocker remains explicit |
| P0 | Hermes adapter support | Blocked by missing maintainer-confirmed semantics; promoted to near-term priority | Obtain maintainer-confirmed roots, config schema, package/task model, and toggle semantics | Hermes adapter spec moves from blocked to implementable, then read/write scope is implemented as evidence permits |
| P0 | OpenClaw adapter support | Blocked/partial evidence; promoted to near-term priority | Obtain maintainer-confirmed skill schema, config safety rules, install/toggle semantics, and credential handling guidance | OpenClaw adapter spec moves from blocked to implementable, then read/write scope is implemented as evidence permits |
| P1 | Real sandbox runner | Deferred after V2.10 boundary | Design interpreter allowlist, cwd/env/network/files enforcement, stdout/stderr policy, resource limits, and audit persistence | Tests prove default-deny, confirmed execution, blocked/cancelled/failed/completed records, and no LLM-triggered execution |
| P3 | GitHub clone import | Deferred from V2.9 | Define network opt-in, clone sandbox, source verification, and audit model | `catalog.importSkill` can support GitHub with explicit confirmation and no uncontrolled network behavior |
| P3 | Script-file install | Deferred from V2.9/V2.10 | Define install target semantics for script files separate from tool-global skill directory install | Install flow supports script files without bypassing adapter verified paths |

## Version Selection Rule

- If the task is Pi, opencode writable, Hermes, or OpenClaw support, use the Comprehensive Agent Adapter Support priority above.
- If the task is real execution, adapter evidence, or a future real Computer Use rerun, use the backlog item name and priority above instead of inventing a V2.12 number.
- Create a new numbered version only after the adapter priority exits or a deferred backlog item becomes large enough to need its own milestone.
