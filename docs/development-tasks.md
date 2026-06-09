# Development Tasks

> Status: current planning and execution queue as of 2026-06-09. V2.1 through V2.10 are closed on the main line. The only remaining numbered V2 milestone is V2.11; deferred cross-version work is tracked separately here so it is not mistaken for unfinished V2.1-V2.10 scope.

## Current Baseline

- Current branch baseline: `main` after V2.10 execution safety boundary docs/release consistency and 2026-06-09 real local Computer Use validation.
- Product boundary: native macOS SwiftUI/AppKit shell plus Rust service protocol.
- Completed V2 milestones: first Codex slice, V2.1 through V2.10.
- Real local Computer Use baseline: passed on 2026-06-09 for the current mainline app against real local HOME/app data/Claude/Codex/opencode roots; future user-visible, UI, or service protocol changes must rerun it.
- Quality gate for code/UI/protocol work: `pnpm check:macos`; add focused Rust/Swift tests when touching shared behavior.

## Next Numbered Version: V2.11

**Goal**: future desktop shell and local sharing planning without adding cloud sync, accounts, telemetry, or default networking.

**Tasks**

- Define the non-macOS shell boundary: Windows/Linux shells must call the Rust service protocol and must not import macOS UI code or Rust internals directly.
- Build or specify at least one minimal non-macOS shell prototype that can read service fixtures and exercise `service.status`, `app.stateSnapshot`, and read-only catalog methods.
- Draft a local sharing threat model: explicit opt-in, local-only transport, no anonymous telemetry, no account identity, no uncontrolled outbound network behavior.
- Define local sharing UX states: disabled by default, enable confirmation, peer/source visibility, revoke/disable flow, and clear privacy wording.
- Specify catalog merge/conflict behavior for local sharing: identity, duplicate skill handling, stale snapshot handling, and rollback boundaries.
- Design watcher/menu bar lifecycle: permission prompts, resource budget, stop/quit controls, failure recovery, and no default always-on daemon behavior.
- Update service fixtures or docs if V2.11 introduces additive protocol fields; no breaking protocol change without fixture migration notes.

**Exit Criteria**

- At least one non-macOS shell prototype or documented fixture reader proves service-protocol portability.
- `docs/security-model.md` covers local sharing threat boundaries and watcher/menu bar lifecycle risks.
- `docs/service-protocol.md` records any additive V2.11 protocol assumptions.
- `docs/roadmap.md`, `README.md`, and `AGENTS.md` agree on V2.11 status.

## Cross-Version Backlog

These items are real work, but they are not unfinished V2.1-V2.10 tasks.

| Priority | Work item | Current status | Next concrete task | Completion signal |
| --- | --- | --- | --- | --- |
| P0 | Real local Computer Use rerun gate | Completed for the current mainline app on 2026-06-09; recurring for future user-visible changes | Rerun the real app against local HOME after UI/service/protocol changes, covering project context, scan-all, agent filter, findings filtering/grouping, opencode read-only toggle, and script safety preview | App-window-only evidence and runbook notes updated for the new candidate |
| P1 | Real sandbox runner | Deferred after V2.10 boundary | Design interpreter allowlist, cwd/env/network/files enforcement, stdout/stderr policy, resource limits, and audit persistence | Tests prove default-deny, confirmed execution, blocked/cancelled/failed/completed records, and no LLM-triggered execution |
| P1 | Release gate and public distribution | Deferred until product maturity | Decide signing/notarization/DMG/ZIP/updater/checksum strategy without adding credentials to repo | Release checklist and distribution runbook move from deferred to implemented with validation evidence |
| P2 | Pi disposable local round-trip | Evidence incomplete | Use disposable local Pi config/skill roots to verify scan and toggle semantics before implementation | Pi adapter spec has verified roots, schema, toggle behavior, fixtures, and non-destructive tests |
| P2 | Opencode writable evidence | Blocked by missing writable semantics | Verify `permission.skill` exact patch, re-enable behavior, wildcard precedence, config ownership, and rollback path | opencode writable toggle design accepted; read-only guard can be relaxed with tests |
| P2 | Hermes maintainer spec | Blocked | Obtain maintainer-confirmed roots, config schema, package/task model, and toggle semantics | Hermes adapter spec moves from blocked to implementable |
| P2 | OpenClaw maintainer spec | Blocked | Obtain maintainer-confirmed skill schema, config safety rules, and credential handling guidance | OpenClaw adapter spec moves from blocked to implementable |
| P3 | GitHub clone import | Deferred from V2.9 | Define network opt-in, clone sandbox, source verification, and audit model | `catalog.importSkill` can support GitHub with explicit confirmation and no uncontrolled network behavior |
| P3 | Script-file install | Deferred from V2.9/V2.10 | Define install target semantics for script files separate from tool-global skill directory install | Install flow supports script files without bypassing adapter verified paths |

## Version Selection Rule

- If the task is future shell portability or local sharing, use V2.11.
- If the task is real execution, distribution, adapter evidence, or a future real Computer Use rerun, use the backlog item name and priority above instead of inventing a V2.12 number.
- Create a new numbered version only after V2.11 exits or a backlog item becomes large enough to need its own milestone.
