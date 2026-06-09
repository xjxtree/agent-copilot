# Development Tasks

> Status: current planning and execution queue as of 2026-06-10. V2.1 through V2.15 are closed on the main line. Current phase is P0 adapter implementation from evidence: OpenClaw read-only scanner, Hermes read-only scanner, and Pi writable evidence harness.

## Current Baseline

- Current branch baseline: `main` after V2.10 execution safety boundary docs/release consistency and 2026-06-09 real local Computer Use validation.
- Product boundary: native macOS SwiftUI/AppKit shell plus Rust service protocol.
- Completed V2 milestones: first Codex slice, V2.1 through V2.10.
- Current priority: implement read-only scanner slices for OpenClaw and Hermes from confirmed public docs plus local/macmini evidence, then build a disposable Pi writable evidence harness before opening production writes.
- Real local Computer Use baseline: passed on 2026-06-09 for the current mainline app against real local HOME/app data/Claude/Codex/opencode roots; future user-visible, UI, or service protocol changes must rerun it.
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

## Near-Term Priority: Comprehensive Agent Adapter Support

**Goal**: make the macOS app agent matrix materially more complete.

**Priority order**

1. OpenClaw read-only scanner candidate: filesystem scan only, no CLI calls during ordinary scan, writable/install blocked.
2. Hermes read-only scanner candidate: active Hermes home `skills/**/SKILL.md` only, no cron-to-skill mapping, writable/install blocked.
3. Pi writable evidence harness: disposable settings mutation/rollback tests before production writable support.

**Tasks**

- Keep the service/UI adapter capability matrix current for Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw so the macOS app can expose precise scan/toggle/install status before each adapter is fully implemented.
- Build disposable local evidence harnesses for Pi and opencode writable semantics so tests never mutate the developer's real config by default.
- Verify Pi scan roots, config schema, enable/disable semantics, project/global precedence, rollback behavior, and fixture coverage before implementing writes.
- Verify opencode `permission.skill` patching, wildcard precedence, disable/re-enable behavior, config ownership, rollback path, and native-root-only scope before relaxing the read-only guard.
- Keep Hermes writable/install blocked until individual skill disable schema, profile scope, and rollback-safe writes are verified.
- Keep OpenClaw writable/install blocked until disposable config mutation, credential preservation, and rollback-safe writes are verified.
- Keep every new adapter behind the existing service protocol, snapshot, audit, permission, and privacy boundaries.
- Update native macOS UI only as needed to expose newly supported agents, statuses, filters, findings, and guarded writable actions.
- Add fixtures and non-destructive tests for every supported adapter mode before enabling writes.

**Exit Criteria**

- Pi has verified read/write semantics or an explicit blocker with disposable local evidence.
- opencode writable support is either implemented behind tests and snapshots or remains blocked with precise missing evidence.
- Hermes remains explicitly blocked with the missing facts listed until maintainer-confirmed evidence becomes available.
- OpenClaw remains explicitly blocked with the missing facts listed until maintainer-confirmed evidence becomes available.
- `docs/agent-adapters.md`, `docs/agent-adapter-spec-worklists.md`, `docs/development-tasks.md`, `docs/roadmap.md`, and `AGENTS.md` agree on adapter priority and current support state.

## Cross-Version Backlog

These items are real work, but they are not unfinished V2.1-V2.10 tasks.

| Priority | Work item | Current status | Next concrete task | Completion signal |
| --- | --- | --- | --- | --- |
| P0 | Real local Computer Use rerun gate | Completed for the current mainline app on 2026-06-09; recurring for future user-visible changes | Rerun the real app against local HOME after UI/service/protocol changes, covering project context, scan-all, agent filter, findings filtering/grouping, opencode read-only toggle, and script safety preview | App-window-only evidence and runbook notes updated for the new candidate |
| P0 | V2.11 Adapter Capability Matrix | Completed and in use | Run focused protocol/UI checks when needed, then use the matrix as the gate for future Pi/opencode/Hermes/OpenClaw work | macOS UI shows precise scan/toggle/install status and blockers for all six agents |
| P0 | Pi comprehensive adapter support | Read-only scanner complete; writable evidence supports a harness but not production writes | Implement disposable writable evidence harness for Pi-native roots and package filters; exclude `.agents/skills` compatibility roots from first writable slice | Harness proves native/global/project/package toggle, rollback, trust gate, invalid JSON behavior, and re-enable strategy |
| P0 | opencode writable support | Read-only native-root support exists; writable semantics remain unverified; promoted to near-term priority | Verify `permission.skill` exact patch, re-enable behavior, wildcard precedence, config ownership, and rollback path | opencode writable toggle/install design is accepted and implemented behind snapshots/tests, or blocker remains explicit |
| P0 | Hermes adapter support | Read-only scanner candidate after P0 evidence; writable/install blocked | Implement scoped read-only scan of active Hermes home `skills/**/SKILL.md`; skip dot dirs/archives unless represented as explicit evidence | Hermes skills appear in catalog read-only; project scan and writes remain blocked |
| P0 | OpenClaw adapter support | Read-only scanner candidate after P0 evidence; writable/install blocked | Implement scoped read-only filesystem scan over documented roots; no OpenClaw CLI calls during ordinary scan | OpenClaw skills appear in catalog read-only; writes/install remain blocked |
| P1 | Real sandbox runner | Deferred after V2.10 boundary | Design interpreter allowlist, cwd/env/network/files enforcement, stdout/stderr policy, resource limits, and audit persistence | Tests prove default-deny, confirmed execution, blocked/cancelled/failed/completed records, and no LLM-triggered execution |
| P3 | GitHub clone import | Deferred from V2.9 | Define network opt-in, clone sandbox, source verification, and audit model | `catalog.importSkill` can support GitHub with explicit confirmation and no uncontrolled network behavior |
| P3 | Script-file install | Deferred from V2.9/V2.10 | Define install target semantics for script files separate from tool-global skill directory install | Install flow supports script files without bypassing adapter verified paths |

## Version Selection Rule

- If the task is adapter capability, Pi, opencode writable, Hermes, or OpenClaw support, use the Versioned Adapter Plan above.
- If the task is real execution, adapter evidence, or a future real Computer Use rerun, use the backlog item name and priority above instead of inventing a V2.12 number.
- Create a new numbered version only after the adapter priority exits or a deferred backlog item becomes large enough to need its own milestone.
