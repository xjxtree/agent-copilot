# Development Tasks

> Status: V2.90 Agent Copilot identifier migration is complete.
> V2.84 Swift Detail section splitting, V2.85 Rust RPC domain module splitting,
> and V2.86 Rust helper/test split completed.
> V2.1 through V2.90 are the synchronized completed baseline; V2.87 unlocked `pnpm check:macos` passed on 2026-06-17, V2.88 captured per-surface Computer Use evidence, V2.89 refreshed app icon assets, and V2.90 migrated packaged app identity/default app-data id with compatibility.
> Agent Copilot M1-M4 first implementation pass is integrated; near-term
> post-V2.90 work is scheduled below and in [`roadmap.md`](./roadmap.md).
>
> Document role: this is the agent-facing implementation task ledger.
> Keep concrete task routing, current baseline, closeout links, and validation handoff notes here.
> Keep milestone planning in [`roadmap.md`](./roadmap.md),
> release-risk summaries in [`../CHANGELOG.md`](../CHANGELOG.md),
> and detailed command evidence in `v2.*-verification-checklist.md`.

## Current Baseline

- Product boundary: native macOS SwiftUI/AppKit shell plus Rust service protocol.
- Completed V2 milestones: first Codex slice, V2.1 through V2.90.
- Current completed milestone: V2.90 identifier migration; unlocked macOS validation passed on 2026-06-17.
- Current priority:
  preserve the V2.26-V2.90 completed behavior while keeping future work
  focused on task-centered skill review, local evidence, safe cleanup,
  and maintainable module boundaries.
- Current implementation status:
  provider profiles, prompt preview/redaction, deterministic quality/readiness/routing,
  task cockpit, local skill map, provider observability, lifecycle, guided cleanup,
  and app-local history surfaces are implemented.
- Agent Copilot rollout status:
  displayed product name, Lineup default surface, Agent Profile surface,
  sorted decision queue, default-off local session preview, and default-off MCP
  server preview are implemented. V2.90 migrated the primary packaged app to
  `dist/AgentCopilot.app`, changed the primary bundle/default app-data id to
  `dev.agent-copilot.native`, and retained compatibility for Swift/Rust module
  names, the `skills-copilot-service` sidecar, `skills-copilot.*` AX ids,
  `SKILLS_COPILOT_*` env vars, legacy `dev.skills-copilot.native` app data,
  and the legacy Keychain service.
- UI validation baseline:
  latest Agent Copilot app-window evidence is 2026-06-17:
  `pnpm check:macos` passed, `./script/build_and_run.sh --verify` launched
  `dist/AgentCopilot.app`, fixture-data smoke captured
  `docs/ui-artifacts/native-macos-shell/completed.png`, and V2.88 Computer Use
  evidence captured `docs/ui-artifacts/v2.88-handoff-evidence/`.
  Future user-visible UI changes need fresh unlocked UI validation or one
  canonical blocker code.
- Quality gate for code/UI/protocol work: `pnpm check:macos`; add focused Rust/Swift tests when touching shared behavior.

## Near-Term Post-V2.90 Task Ledger

Treat these as the next planned work queue. Do not start a later write/install
slice until the earlier evidence/design slice has closed or been explicitly
rescheduled.

| Version | Status | Task scope | Required evidence |
| --- | --- | --- | --- |
| V2.88 | Completed | Handoff closeout: reviewed staging scope, preserved V2.87 scope, and captured per-surface app-window-only evidence for Lineup, Agent Profile, Local Session Preview, and MCP Preview. | [`v2.88-verification-checklist.md`](./v2.88-verification-checklist.md), `git status`, staged-file review, `pnpm check:macos`, `pnpm check:privacy`, screenshot artifact verification |
| V2.89 | Completed | Brand asset refresh: implemented app icon / visual asset updates for the Agent Copilot display brand while keeping internal identifiers unchanged. | [`v2.89-verification-checklist.md`](./v2.89-verification-checklist.md), asset diff review, refreshed app-window screenshot, `pnpm check:macos`, privacy gate |
| V2.90 | Completed | Internal identifier migration: migrated packaged app identity and default app-data id to Agent Copilot while preserving module/crate/sidecar/AX/env/Keychain compatibility and legacy app-data copy behavior. | [`v2.90-verification-checklist.md`](./v2.90-verification-checklist.md), app-data migration tests, refreshed app-window screenshot, `pnpm check:macos`, privacy gate |
| V2.91 | Planned | Model-task matching history: design and implement a new local evidence domain for historical model/task fit. | Design-first review, protocol fixtures, privacy/redaction tests, no-provider/no-write defaults |
| V2.92 | Planned | Codex expanded roots: evaluate project config, plugin/admin/system roots, and project-local write policy; keep plugin/admin/system roots read-only unless rollback-safe writes are proven. | Official/local evidence, root allowlist tests, project write rollback tests if scoped |
| V2.93 | Planned | opencode custom roots: evaluate and implement safe `skills.paths` / `skills.urls` behavior. Local paths require canonicalization/dedupe; URLs require explicit user confirmation or metadata-only default. | Disposable fixtures, no uncontrolled network, duplicate/root tests, rollback proof where writes are scoped |
| V2.94 | Planned | Pi install and compatibility-root writes: extend beyond V2.37 guarded native toggles only with disposable install/compat-root evidence. | Disposable round-trip, snapshot/rollback, trust gate, invalid config handling, no script execution |
| V2.95 | Planned | Hermes writable/install: verify schema, credential preservation, external-root semantics, and rollback-safe writes before enabling. | Hermes disposable evidence, credential filtering, rollback proof, capability matrix update |
| V2.96 | Planned | OpenClaw writable/install: verify workspace-scope writes, precedence, install behavior, and rollback before enabling. | OpenClaw disposable evidence, workspace-bound write tests, rollback proof, capability matrix update |

- 2026-06-16 review triage:
  V2.84-V2.86 module-splitting follow-up is complete.
  V2.84 split Swift Detail sections, V2.85 split Rust RPC domain files,
  and V2.86 split Rust helpers/tests plus `verify:module-size`.
- Verification governance:
  V2.46-V2.64 have no separate checklist files. Their command evidence remains
  inline in this ledger and historical closeout text; do not backfill invented
  screenshots, PIDs, or command output.
- Docs gate governance:
  V2.41-V2.72 have no package-level `verify:v2.NN-docs` scripts.
  V2.73+ docs gates are the current automated verification line.
- Checklist format governance:
  V2.41-V2.45 and V2.65-V2.72 checklist sections are historical evidence
  snapshots; V2.73+ uses the modern gate-backed closeout template.

## 2026-06-16 Review Remediation Closeout

Source: 2026-06-16 merged review remediation report, now removed after consolidation.

Completed fixes:

- P0 data/privacy/safety:
  catalog refresh paths now run inside SQLite transactions, LLM persisted
  `draft_output` uses the strong prompt redactor plus high-entropy token
  detection, script-execution audit writes are confined to the app audit root,
  and Swift stdio service calls have timeout/decode/error-path coverage.
- P1 structure:
  Rust service helpers/tests now use real modules instead of `include!`,
  `commands` split out `analysis.rs`, `script_execution.rs`, and `tests.rs`
  with `lib.rs` below the 5k-line default gate, catalog code moved into
  `schema.rs`, `mapping.rs`, `queries.rs`, and `refresh.rs`, adapter YAML/name/path
  helper duplication moved into `crates/adapters/src/shared.rs`, `ServiceClient`
  transport/decode moved into `ServiceClientTransport.swift`, RPC methods moved
  into domain extension files, and `SkillStore` read-only derived state,
  navigation actions, and workflow selectors moved into focused extension files.
- Gates:
  `verify:module-size` now scans Rust, Swift, and `.mjs` trees with no legacy
  module-size budget; `verify:js-syntax` checks all `.mjs` verifier/smoke scripts;
  `verify:rust-docs` builds Rust public API docs; V2.73-V2.86 docs verification
  is consolidated in `scripts/verify-version-validation-docs.mjs`; `verify:benchmark-trends`
  protects measured baselines for large catalog scan, task readiness, routing,
  knowledge search, and native list-model scenarios; GitHub Actions includes
  `cargo audit` and Rust API docs.
- Documentation cleanup:
  the merged review report is the retained source, and the two original
  review files were removed after consolidation.

Remaining maintenance:

| Priority | Task | Boundary |
| --- | --- | --- |
| P2 | Continue public API doc comments on stable command/catalog/adapter boundaries | `cargo doc --workspace --no-deps` is now a health gate; do not chase coverage percentage |
| P2 | Consider deeper Swift domain-store extraction only when a future feature needs clearer state ownership | Do not widen `@Published private(set)` write access merely for a formal split |

## User-centered Optimization Direction

Current app optimization should stay anchored in concrete skill user jobs rather than broad governance artifacts:

1. Know what skills exist, where they came from, and whether they are safe to use. Preserve scan accuracy, provenance, adapter capability explanations, and readable finding drill-downs.
2. Decide which skill/agent should handle a real task. Keep task readiness, routing confidence, benchmark/regression, and cross-agent readiness focused on user-entered tasks rather than abstract scores.
3. Review whether an agent actually used the right skill. V2.62 centers on imported/pasted agent sessions and answers: expected skill, observed skill, miss/wrong-pick/ambiguity/unknown, duplicate or similar-skill interference, evidence, and safe next step.
4. Understand the local skill landscape at a glance. V2.63 should turn knowledge index, similar grouping, taxonomy, conflicts, and task coverage into a navigable skill map without creating a second source of truth.
5. Trust slow provider-backed analysis. V2.64 makes calls observable through history, duration, model/provider, destination, status/error, token/cost estimate, retry/rerun context, retention recommendations, and evidence refs without storing secrets, raw prompts, raw response JSON, raw traces, or unredacted paths by default.
6. Keep high-volume text out of cramped inline panels. Long previews, prompts, and model outputs should open in readable detail views with copy actions and Markdown rendering where appropriate.

V2.65-V2.77 completed those next product directions: a task-first cockpit that groups readiness/routing/session-review evidence by user task, a skill lifecycle view that shows new/stale/duplicate/risky skills over time, a guided cleanup flow that keeps write paths preview-first and explicit-confirm only, a cockpit-first IA that makes those surfaces reachable without hunting through one dense Analysis panel, screenshot-safe path display for validation evidence, smaller Swift/Rust feature modules for safer follow-up work, safe guided-cleanup links into existing review/preview surfaces, a hardened validation harness that rejects invalid UI evidence, bounded Task Cockpit timeout/fallback/cancel/retry recovery for real catalogs, stable real-local launch/window targeting, resilient Task Cockpit task input, progressive staged Cockpit feedback for long-running local evidence aggregation, and a read-only validation workbench for canonical real-local blocker guidance.

## Post-V2.67 Consolidation Plan

The completed post-V2.67 consolidation made the existing evidence surfaces easier to use and safer to validate before adding new analytic capability:

| Version | Work area | Planned scope | Non-goals |
| --- | --- | --- | --- |
| V2.68 | Task Cockpit 主入口 / Analysis IA 重组 | Completed: Task Cockpit is the default task-centered entry; Analysis is split into Task Cockpit, Skill Map/Lifecycle, Guided Cleanup, Provider Observability, and Review; existing read-only service methods are reused | No new provider default calls, no hidden task state, no new write path |
| V2.69 | Privacy / Screenshot Mode + 本地化收束 | Completed: screenshot/demo-safe path redaction, long-path collapse/reveal-on-demand, localized cockpit/guided/provider labels, screenshot artifact verifier, and locked/black capture rejection | No credential display, no raw path persistence, no broad UI rewrite |
| V2.70 | Swift / Rust feature modularization | Completed: extracted Task Cockpit and detail presentation primitives from `DetailView.swift`, extracted Rust cleanup queue into `cleanup_queue.rs`, and updated layout verification to aggregate split files | No service semantic change, no new capability endpoint merely for refactor |
| V2.71 | Guided Cleanup safe-action deep links | Completed: cleanup steps/actions expose safe deep links to existing safe previews and filters: cleanup/detail sections, remediation plan/drafts/impact/batch review, lifecycle, cockpit, safe batch preview panel, and guided metadata record | No hidden apply, no direct write from guidance, no bypass of explicit confirmation |
| V2.72 | Validation harness hardening | Completed: added canonical validation blocker taxonomy, classifier CLI, smoke lock-session preflight, black/transparent/flat screenshot rejection wording, fixture/real screenshot matrix, and docs/checklist alignment | No product semantics change; smoke screenshots remain insufficient for blocked real-local checks |

## Post-V2.72 Real-local Experience Plan

The 2026-06-15 real-local audit found two product-facing issues before the session locked again: real-catalog Task Cockpit can stay in `Preparing...`, and automated task input can be corrupted by the active input method unless pasted. Locked-session evidence then blocked further screenshot/interaction completion, as intended by V2.72.

| Version | Work area | Planned scope | Non-goals |
| --- | --- | --- | --- |
| V2.73 | Task / remediation performance and timeout recovery | Completed: task readiness/routing/cross-agent/remediation/batch review paths now return bounded aggregation metadata, scan/detail limits, fallback result rows, cancel/retry UI, and tests that prevent indefinite Cockpit loading | No provider default calls, no write/apply path, no safety-boundary expansion |
| V2.74 | Real-local launch and window targeting stability | Completed: dev launch, smoke, and capture now target the current workspace bundle path/PID/window identity; duplicate same-bundle launches fail closed; Swift exposes stable main-window and Task Cockpit AX anchors; unlocked Computer Use evidence is recorded | No signing/notarization/public distribution |
| V2.75 | Task input and input-method resilience | Completed: AX-settable multiline task input, exact nonblank raw task preservation, whitespace-only blocking, explicit Build submit, and real-local Computer Use evidence | No raw prompt persistence, cloud sync, provider default calls, write paths, script execution, credential reads, telemetry, or broad text editor rewrite |
| V2.76 | Progressive Cockpit feedback | Completed: shows readiness/routing/cross-agent/remediation/provider/session staged feedback, partial rows, elapsed time, timeout/fallback explanations, skipped rows, and clear blocked states | No new provider default calls, no write/apply path, no script execution, no credential reads, no cloud sync, no telemetry, and no new analysis surface by default |
| V2.77 | Real-local validation workbench | Completed: added a focused read-only workbench for lock state, Screen Recording permission, window-not-found/no-AX-window, stale or duplicate bundle, invalid screenshot blockers, Computer Use timeout, remote connection, activation failure, and unknown tool-layer blockers | No substitute for unlocked visual review |

V2.73 closeout evidence lives in [`v2.73-verification-checklist.md`](./v2.73-verification-checklist.md) and is guarded by `pnpm verify:v2.73-docs`. The checklist records implementation evidence, focused tests, shared gates, screenshot evidence, and unlocked real-local Computer Use validation.

V2.74 closeout evidence lives in [`v2.74-verification-checklist.md`](./v2.74-verification-checklist.md) and is guarded by `pnpm verify:v2.74-docs`. V2.74 is completed with exact workspace bundle/PID targeting, duplicate same-bundle detection/fail-closed behavior, canonical blocker handling, unlocked real-local Computer Use evidence, screenshot evidence, and no signing/notarization/distribution scope expansion.

V2.75 closeout evidence lives in [`v2.75-verification-checklist.md`](./v2.75-verification-checklist.md) and is guarded by `pnpm verify:v2.75-docs`. V2.75 is completed with an AX-settable Task Cockpit input, exact nonblank service-call text preservation, whitespace-only submit blocking, explicit Build behavior, PID `43079` real-local Computer Use evidence, screenshot evidence, and no raw prompt persistence, cloud sync, provider default calls, write paths, script execution, credential reads, telemetry, or broad text editor rewrite.

V2.76 closeout evidence lives in [`v2.76-verification-checklist.md`](./v2.76-verification-checklist.md) and is guarded by `pnpm verify:v2.76-docs`. V2.76 is completed with progressive staged feedback for readiness/routing/cross-agent/remediation/provider/session, partial rows, elapsed-time read-back, timeout/fallback/blocked/skipped states, PID `39728` real-local Computer Use evidence, `skills-copilot.task-cockpit.stage-progress`, screenshot evidence, and unchanged no-provider/write/execute/credential/cloud/telemetry semantics.

V2.77 closeout evidence lives in [`v2.77-verification-checklist.md`](./v2.77-verification-checklist.md) and is guarded by `pnpm verify:v2.77-docs`. V2.77 is completed with a read-only validation workbench, canonical blocker explanations, stable `skills-copilot.validation-workbench`, PID `34909` real-local Computer Use evidence, screenshot evidence at `docs/ui-artifacts/v2.77-validation-workbench/completed.png`, and unchanged no-provider/write/apply/script/credential/cloud/telemetry semantics.

V2.78 closeout evidence lives in [`v2.78-verification-checklist.md`](./v2.78-verification-checklist.md) and is guarded by `pnpm verify:v2.78-docs`. V2.78 is completed with protocol/docs/gate parity, `pnpm verify:service-protocol-drift`, CI/local `pnpm verify:gate-parity`, the then-current 88 `SUPPORTED_METHODS` documented, file-level session review fixtures, V2.46-V2.64 verification-history governance, and unchanged no protocol rename/payload expansion/provider/write/script/cloud/telemetry semantics.

V2.79 closeout evidence lives in [`v2.79-verification-checklist.md`](./v2.79-verification-checklist.md) and is guarded by `pnpm verify:v2.79-docs`. It is completed with privacy fixture code, localization/UI evidence, focused tests, shared gates, and fresh unlocked real-local Computer Use evidence. No credential reads, network behavior change, scanner/catalog fact mutation, provider/write/script/cloud/telemetry expansion is allowed in this slice.

V2.80 closeout evidence lives in [`v2.80-verification-checklist.md`](./v2.80-verification-checklist.md) and is guarded by `pnpm verify:v2.80-docs`. V2.80 Verification Checklist（completed） records Detail navigation and visual density polish implementation, focused verifier coverage, shared gates, PID `82571` real-local Computer Use evidence, `docs/ui-artifacts/v2.80-detail-density/completed.png`, and safety-boundary confirmation. It did not add a service method, provider default call, write/apply path, hidden task state, scanner/catalog fact mutation, script execution, credential read, raw prompt/response/trace persistence, cloud sync, telemetry, or public distribution automation.

V2.81 closeout evidence lives in [`v2.81-verification-checklist.md`](./v2.81-verification-checklist.md) and is guarded by `pnpm verify:v2.81-docs`. The checklist records completed Swift stdio sidecar cancellation cleanup evidence, focused Swift cancellation and force-kill tests, shared gate evidence, the no-new-UI screenshot decision, and the no daemon/socket redesign by default, service protocol method/payload changes, provider default calls, write/apply paths, hidden task state, scanner/catalog fact mutation, script execution, credential reads, raw prompt/response/trace persistence, cloud sync, telemetry, public distribution, signing/notarization/DMG/ZIP boundary.

V2.82 closeout evidence lives in [`v2.82-verification-checklist.md`](./v2.82-verification-checklist.md) and is guarded by `pnpm verify:v2.82-docs`. The checklist records completed provider-test environment isolation, core model wire/default/identity test floor, focused tests, shared gate evidence, no-new-UI screenshot decision, no-capture fixture smoke, and the current `locked-session` blocker for `pnpm check:macos` / `./script/build_and_run.sh --verify` UI evidence capture. Boundary: no provider credential persistence changes, service protocol method/payload changes, provider default calls, write/apply paths, hidden task state, scanner/catalog fact mutation, script execution, credential reads beyond existing explicitly confirmed provider tests, raw prompt/response/trace persistence, cloud sync, telemetry, public distribution/signing/notarization/DMG/ZIP.

V2.83 closeout evidence lives in [`v2.83-verification-checklist.md`](./v2.83-verification-checklist.md) and is guarded by `pnpm verify:v2.83-docs`. The checklist records completed continued module splitting, split protocol/detail/test fixture modules, focused Rust protocol tests, Swift tests, shared gate evidence, no-new-UI screenshot decision, no-capture fixture smoke, and the current `locked-session` blocker for `pnpm check:macos` UI evidence capture. Boundary: no service protocol method or payload changes, protocol version bump, new UI surface, provider default calls, write/apply paths, hidden task state, scanner/catalog fact mutation, script execution, credential reads, raw prompt/response/trace persistence, cloud sync, telemetry, public distribution/signing/notarization/DMG/ZIP.

V2.84 closeout evidence lives in [`v2.84-verification-checklist.md`](./v2.84-verification-checklist.md) and is guarded by `pnpm verify:v2.84-docs`. It records completed Swift Detail section splitting: `DetailView.swift` is a small router/composer, `DetailGuidedCleanupFlowPanel.swift`, `DetailProviderObservabilityPanel.swift`, `DetailReviewCoreSection.swift`, and peer Detail section files preserve existing UI semantics, `TaskCockpitPanel.swift` and `ValidationWorkbenchPanel.swift` remain dedicated, and `verify:module-size` plus native layout aggregation guard the split files.

V2.85 closeout evidence lives in [`v2.85-verification-checklist.md`](./v2.85-verification-checklist.md) and is guarded by `pnpm verify:v2.85-docs`. It records completed Rust RPC domain module splitting across `service_host.rs`, `service_cleanup.rs`, `service_knowledge.rs`, `service_llm.rs`, `service_remediation.rs`, and `service_task.rs`; protocol drift verification scans split service files while preserving the then-current 88-method service protocol.

V2.86 closeout evidence lives in [`v2.86-verification-checklist.md`](./v2.86-verification-checklist.md) and is guarded by `pnpm verify:v2.86-docs`. It records completed Rust helper/test split and module-size gate closeout: helpers such as `service_support_helpers.rs` and Rust service test chunks under `crates/service/src/tests/` are checked by `pnpm verify:module-size`, which is wired into `pnpm verify:gate-parity`.

V2.87 closeout evidence lives in [`v2.87-verification-checklist.md`](./v2.87-verification-checklist.md) and is guarded by `pnpm verify:v2.87-docs`. It records completed Agent Copilot first pass evidence: Lineup default surface, Agent Profile, sorted decision queue, default-off `session.previewLocalSessions`, default-off `evidence.previewMcpServers`, 90-method service protocol parity, and unchanged no-provider/write/script/credential/cloud/telemetry boundary.

V2.88 closeout evidence lives in [`v2.88-verification-checklist.md`](./v2.88-verification-checklist.md) and is guarded by `pnpm verify:v2.88-docs`. It records completed handoff and per-surface evidence: Lineup, Agent Profile, Local Session Preview default-off/authorized fixture output, MCP Preview default-off/authorized fixture output, V2.87/V2.88 docs-gate wiring, and unchanged no-provider/write/script/credential/cloud/telemetry boundary.

V2.89 closeout evidence lives in [`v2.89-verification-checklist.md`](./v2.89-verification-checklist.md) and is guarded by `pnpm verify:v2.89-docs`. It records completed Agent Copilot brand asset refresh: reviewable `AppIcon.svg`, regenerated `AppIcon.icns`, manual `pnpm generate:app-icon` helper, refreshed app-window evidence, and unchanged internal `SkillsCopilot` / `skills-copilot` identifiers.

V2.90 closeout evidence lives in [`v2.90-verification-checklist.md`](./v2.90-verification-checklist.md) and is guarded by `pnpm verify:v2.90-docs`. It records completed compatibility-first identifier migration: `dist/AgentCopilot.app`, `dev.agent-copilot.native`, default app-data migration from legacy `dev.skills-copilot.native`, `agent-copilot-app-data-migration.json`, refreshed app-window evidence, and preserved Swift/Rust module, sidecar, AX, env-var, and Keychain compatibility.

## Post-V2.78 Version Plan

The remaining 2026-06-15 Minimax-m3 and GLM-5.1 review findings are assigned into the regular version sequence below. Do not mark any version completed until code/docs, focused tests, shared gates, and real-local validation requirements are satisfied where applicable.

| Version | Priority | Work area | Planned scope | Completion signal |
| --- | --- | --- | --- | --- |
| V2.79 | P0 | Privacy fixture and evidence-surface localization sweep | Completed: replaced literal fixed local provider host-port fixtures; extended privacy scanning for non-allowlisted `localhost:PORT` / `127.0.0.1:PORT`; applied path redaction/collapse/reveal and Chinese localization consistently across Guided Cleanup, Local Skill Map, Review, Task Cockpit, Provider Observability, Validation Workbench, and nested evidence cards | Privacy check catches fixed local host-port fingerprints, and unlocked real-local screenshots can be inspected without exposing local paths or mixed-language primary workflows |
| V2.80 | P1 | Detail navigation and visual density polish | Completed: reset Detail scroll to a stable top anchor when switching major surfaces; added counted/collapsible dense evidence-card lists and screenshot-safe evidence labels for real catalog data | No service/provider/write/hidden-state/scanner/script/credential/raw-persistence/cloud/telemetry/public-distribution expansion |
| V2.81 | P1 | Swift service IPC cancellation cleanup | Completed: kept the short-lived stdio sidecar shape while adding cancellation/timeout cleanup around `ServiceClient.runService`, child-process termination, pipe-handle cleanup, Task Cockpit service-task cancellation, and TERM-to-SIGKILL escalation | Swift tests cover cancelled and stubborn service calls without leaked child processes; no daemon/socket is introduced by default |
| V2.82 | P1 | Test isolation and core model test floor | Completed: provider-related `std::env::set_var` / `remove_var` tests use RAII cleanup and serialization; core tests cover `AgentId`, `Scope`, safe defaults, and identity/state fields without adding serde dependencies | Provider tests remain deterministic under normal parallel cargo test runs, and `cargo test -p skills-copilot-core` covers stable wire/model assumptions |
| V2.83 | P2 | Continued module splitting | Completed: extracted `crates/service/src/protocol.rs`, `DetailOverviewSection.swift`, and `FakeServiceScript.swift`; updated split-file verifiers; preserved protocol names, payload semantics, and visible UI behavior | Smaller modules landed behind focused Rust protocol tests, Swift tests, shared gates, and no-new-UI validation documentation |
| V2.84 | P2 | Swift Detail section splitting | Completed: `DetailView.swift` became a router/composer; Task Cockpit / Skill Map / Guided Cleanup / Provider Observability / Review section UI moved into split Detail files including `DetailGuidedCleanupFlowPanel.swift`; `verify:module-size` guards the <= 5000-line target | Refactor-only native UI split with no user-visible behavior change |
| V2.85 | P2 | Rust RPC domain module splitting | Completed: `ServiceHost` RPC handling moved into domain files including `service_host.rs` and `service_task.rs`; protocol drift verification scans split service files | No service protocol method/payload/version change |
| V2.86 | P2 | Rust helper/test split and module-size gate | Completed: helpers such as `service_support_helpers.rs` and tests under `crates/service/src/tests/` are split and guarded by `pnpm verify:module-size` in gate parity | Refactor-only validation hardening; no product or protocol semantics change |

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
| V2.39 | OpenClaw workspace deepening | Completed | Tightened workspace-scope detection and skipped/blocked root explanations without arbitrary repo inference or writes |
| V2.40 | Adapter diagnostics | Completed | Surface discovered/skipped/blocked roots, config detected, read-only/writable reason, and last scan activity per agent via read-only protocol/status/state fields and sidebar UI; no new writes, execution, provider calls, credentials, or telemetry |
| V2.41 | AI Provider Foundation | Completed | User-configured OpenAI-compatible and Claude-compatible endpoint/API key/model settings, Keychain-first storage, explicit test connection, budget controls, disabled/unconfigured state, and minimal redacted test-call metadata; no automatic analysis, writes, scripts, telemetry, or credential leakage |
| V2.42 | Prompt preview / redaction / token estimate | Completed | Every AI call shows prompt scope, included/excluded fields, redaction summary, estimated tokens/cost, network destination, and explicit confirmation before network request; confirmed calls record minimal redacted audit metadata |
| V2.43 | AI Skill Quality Score | Completed | `analysis.scoreSkillQuality` and native Analysis UI provide user-triggered read-only local quality scoring from metadata/findings/conflicts/analysis/adapter diagnostics; optional provider explanation uses V2.42 prompt preview/redaction/confirmation and remains copy-only |
| V2.44 | AI Task Readiness Check | Completed | User enters a real task; app evaluates local candidate skills for availability, enabled/scope/risk state, gaps, blockers, evidence, and safety flags |
| V2.45 | AI Routing Confidence | Completed | Rank candidate skills for a task with confidence, match reasons, ambiguity/collision warnings, and likely wrong-pick / likely miss explanations |
| V2.46 | Task Benchmark Set | Completed | Users define common tasks and expected/acceptable skills for repeatable local readiness evaluation |
| V2.47 | Routing Regression Detection | Completed | Detect when skill changes, disablement, drift, or findings reduce task-to-skill readiness versus the benchmark baseline with `task.saveRoutingBaseline` + `task.detectRoutingRegression` |
| V2.48 | Agent Behavior Trace Import | Completed | Import local transcript/log evidence, redact sensitive content before persistence, and analyze deterministic expected-vs-actual routing（命中/漏选/错选/歧义）；默认不落 raw trace |
| V2.49 | Routing Accuracy Dashboard | Completed | Summarize benchmark/trace hit rate, miss rate, wrong-pick rate, ambiguity, gaps, per-agent rows, history buckets, and recent evidence |
| V2.50 | Cross-agent Task Readiness | Completed | Compare Claude/Codex/opencode/Pi/Hermes/OpenClaw readiness for the same task using deterministic outputs from `task.checkReadiness`, `task.rankSkillRoutes`, `task.evaluateBenchmarks`, `task.detectRoutingRegression`, `trace.importLocal` and `routing.accuracyDashboard`; include skill visibility, scope/quality readiness, gap/blocker deltas, per-agent confidence, and evidence provenance |
| V2.51 | Stale / Drift Detection | Completed | Identify stale skills, fingerprint drift, finding drift, source drift, and changed readiness impact via `analysis.detectStaleDrift` |
| V2.52 | Local Knowledge Index | Completed | Build local-only `knowledge.search` over existing catalog evidence, derived tags, quality/readiness/stale-drift context, facets, evidence refs, and safety flags; no default network/provider |
| V2.53 | Similar Skill Grouping | Completed | Group duplicate/similar/confusable skills with `knowledge.groupSimilarSkills` using local catalog evidence, V2.52 tags, quality/readiness/stale-drift context, and explicit coverage redundancy vs routing ambiguity explanations |
| V2.54 | Capability Taxonomy | Completed | `knowledge.buildCapabilityTaxonomy` classifies skills into capability domains and maps coverage, gaps, redundancy, routing ambiguity, representative skills, and evidence across agents/workspaces |
| V2.55 | Workspace Readiness Check | Completed | `workspace.checkReadiness` evaluates whether the current project has the right skills enabled and scoped per agent for expected work, using local catalog/taxonomy/readiness/routing/stale-drift evidence only |
| V2.56 | AI Remediation Planner | Completed | `remediation.plan` converts findings, gaps, ambiguity, drift, readiness, taxonomy, workspace, and adapter evidence into prioritized read-only remediation plans |
| V2.57 | Fix Preview Drafts | Completed | `remediation.previewDrafts` generates copy/edit-ready frontmatter, description, permission, dependency, and policy drafts locally by default; no direct apply/write path from AI output |
| V2.58 | Impact Preview | Completed | `remediation.previewImpact` previews impacted tasks, agents, skills, risk deltas, snapshot/rollback plans, writable capability/filtering/blockers, and evidence refs before enable/disable/edit/remediation actions without applying changes |
| V2.59 | Batch Review Workflow | Completed | `remediation.batchReview` groups local review items by task, risk, rule, agent, and workspace with safe next-step labels, evidence refs, gap/blocker notes, prompt metadata, and safety flags; writes remain separate preview-first and explicit-confirm only |
| V2.60 | Remediation History | Completed | `remediation.listHistory` / `remediation.recordHistory` / `remediation.deleteHistory` track local remediation decisions, recurrence, reopened issues, task-readiness/routing improvements, and redacted app-local history records with no provider/network/skill-write/agent-config/script/credential/raw prompt/raw response/raw trace/cloud/telemetry paths |
| V2.61 | AI Analysis UX / Prompt Run History | Completed | Consolidates the single-skill Analysis page to 3 high-value items, sets provider-backed AI analysis timeout to 10 minutes, persists redacted prompt run task/result records in app data, hydrates latest results after restart, and allows reruns as new history records |
| V2.62 | Agent Session Skill Review | Completed | `session.reviewAgentSkillUse` / `session.listSkillReviews` / `session.deleteSkillReview` create/list/delete local read-only review sessions from imported traces, pasted agent transcripts, or future explicitly selected local agent sessions; judge skill discovery/selection/use, hit/miss/wrong-pick/ambiguous/unknown, duplicate-skill interference, detected vs expected skills, evidence refs, and safe next steps. App AI prompt runs are auxiliary evidence only |
| V2.63 | Local Skill Map | Completed | `knowledge.buildLocalSkillMap` builds a local-only deterministic map of skill relationships, sources, capabilities, similar groups, conflicts, cross-agent analysis, task coverage, readiness/routing/session-review context, stale/drift, and risk evidence; no new source of truth, no default persistence/provider/write/script path |
| V2.64 | AI Provider Observability | Completed | `llm.providerObservability` derives summary, call/history rows, provider/model/destination grouping rows, status rows, budget usage hints, retention recommendations, evidence refs, prompt metadata, and safety flags from V2.61 prompt run metadata plus existing minimal provider call metadata |
| V2.65 | Task-first Cockpit | Completed | Group readiness, routing, benchmark/regression, trace/session review, provider-run context, and remediation next steps by user task so users can decide what to use and what to fix from one place |
| V2.66 | Skill Lifecycle Timeline | Completed | `skill.lifecycleTimeline` shows per-skill / per-agent / per-workspace lifecycle rows from existing catalog evidence, scan/provenance/fingerprint state, stale/drift, finding/triage/remediation history, prompt run metadata, provider observability metadata, session review outcomes, and relevant evidence refs |
| V2.67 | Guided Cleanup Flow | Completed | Turn findings, cleanup queue, similar groups, stale/drift, readiness/routing/task cockpit, lifecycle timeline, remediation plan/drafts/impact/batch review, adapter diagnostics, and source provenance into stepwise cleanup guidance while keeping all writes on existing preview-first, explicit-confirm safe paths |
| V2.68 | Task Cockpit primary entry / Analysis IA | Completed | Task Cockpit is the first task-centered surface; Work surfaces are visible before diagnostics; Analysis navigation is split into clear areas without adding provider defaults, hidden task state, or write paths |
| V2.69 | Privacy / Screenshot Mode + localization polish | Completed | Real-local UI evidence can be captured with redacted paths and consistent terminology; long paths/identifiers are collapsed by default with explicit reveal |
| V2.70 | Swift / Rust feature modularization | Completed | Task Cockpit and shared detail primitives have dedicated Swift modules; cleanup queue has a Rust service module; protocol semantics and test coverage are preserved |
| V2.71 | Guided Cleanup safe-action links | Completed | Guided cleanup steps/actions deep-link to existing safe preview/review flows and filters; actual writes remain separate preview-first actions |
| V2.72 | Validation harness hardening | Completed | Lock-screen and black/transparent/flat screenshot checks are enforced; invalid captures become canonical blockers instead of completed UI evidence |

## Baseline and Next Priority: V2.26-V2.72

**Goal**: keep the completed V2.26-V2.72 management/analysis/provider/prompt-safety/task-routing/benchmark/regression/trace/accuracy/cross-agent readiness/stale-drift/remediation/history/session-review/local-skill-map/provider-observability/task-cockpit/lifecycle/guided-cleanup/cockpit-first IA/privacy/module-boundary/safe-link/validation baseline stable. Users should start from a task-centered cockpit, understand why findings exist, where skills came from, which agent/skill should handle a task, whether real sessions used the expected skills, how skills connect across local evidence, what provider-backed analysis cost or failed, how skills changed over time, which cleanup step safely maps to an existing preview/confirm action, and whether UI evidence is valid without leaking local paths.

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
10. V2.36-V2.40 Adapter trust and diagnostics: completed; V2.36 Pi writable evidence harness, V2.37 minimal guarded Pi native toggle, V2.38 Hermes external roots, V2.39 OpenClaw workspace scope, and V2.40 read-only adapter diagnostics are complete. Do not extend write semantics without fresh rollback-safe evidence.
11. V2.41-V2.77 AI-native skill review, observability, privacy-safe presentation, module boundaries, safe guided-cleanup navigation, validation hardening, bounded cockpit recovery, launch/window targeting stability, task input resilience, progressive Cockpit feedback, and real-local validation workbench: V2.41 provider foundation, V2.42 prompt safety, V2.43 skill quality, V2.44 task readiness, V2.45 routing confidence, V2.46 task benchmark set, V2.47 routing regression detection, V2.48 trace import, V2.49 routing accuracy dashboard, V2.50 cross-agent task readiness, V2.51 stale/drift detection, V2.52 local knowledge index, V2.53 similar skill grouping, V2.54 capability taxonomy, V2.55 workspace readiness, V2.56 remediation planner, V2.57 fix preview drafts, V2.58 impact preview, V2.59 batch review, V2.60 remediation history, V2.61 prompt run history, V2.62 Agent Session Skill Review, V2.63 Local Skill Map, V2.64 Provider Observability, V2.65 Task-first Cockpit, V2.66 Skill Lifecycle Timeline, V2.67 Guided Cleanup Flow, V2.68 cockpit-first IA, V2.69 Privacy / Screenshot Mode, V2.70 Swift/Rust feature modularization, V2.71 Guided Cleanup safe-action links, V2.72 Validation harness hardening, V2.73 Task / remediation timeout recovery, V2.74 Real-local launch/window targeting stability, V2.75 Task input and input-method resilience, V2.76 Progressive Cockpit feedback, and V2.77 Real-local validation workbench are complete.
12. Next consolidation: V2.78-V2.86 are completed within the same version line: protocol/validation gate parity, privacy fixture and evidence-surface localization, detail navigation/visual density, Swift IPC cancellation cleanup, test isolation/core model tests, continued module splitting, Swift Detail section splitting, Rust RPC domain module splitting, and Rust helper/test split with module-size gate. Preserve the V2.77 validation workbench evidence baseline before adding or changing user-visible validation surfaces.

### V2.73 Verification Checklist（completed）

See [`v2.73-verification-checklist.md`](./v2.73-verification-checklist.md). V2.73 is completed with bounded Cockpit loading, timeout/fallback/cancel/retry, real-local validation blocker handling, screenshot evidence, unchanged safety boundaries, and unlocked Computer Use evidence against the current `dist/SkillsCopilot.app`.

### V2.74 Verification Checklist（completed）

See [`v2.74-verification-checklist.md`](./v2.74-verification-checklist.md). V2.74 is completed with current workspace `dist/SkillsCopilot.app` rebuild/launch, exact bundle path/PID identity, duplicate same-bundle fail-closed behavior, CG/AX/Computer Use window matching, unlocked Computer Use interaction evidence, app-window-only screenshot evidence, and no signing, notarization, DMG/ZIP, or public distribution scope.

### V2.75 Verification Checklist（completed）

See [`v2.75-verification-checklist.md`](./v2.75-verification-checklist.md). V2.75 completed Task input and input-method resilience across committed Chinese text, paste/automation text, multiline tasks, leading/trailing whitespace, emoji, explicit submit, focus/result stability, and real-local Computer Use evidence. The closeout records the AX-settable task input, PID `43079`, app-window evidence, focused tests, shared validation, docs closeout, screenshot evidence, and unchanged read-only safety boundary.

### V2.76 Verification Checklist（completed）

See [`v2.76-verification-checklist.md`](./v2.76-verification-checklist.md). V2.76 is completed for Progressive Cockpit feedback only: readiness/routing/cross-agent/remediation/provider/session staged feedback, partial rows, elapsed time, timeout/fallback/blocked/skipped states, PID `39728` unlocked real-local Computer Use evidence, `skills-copilot.task-cockpit.stage-progress`, and screenshot evidence. The verifier `pnpm verify:v2.76-docs` now rejects planned status and requires completed evidence.

### V2.77 Verification Checklist（completed）

See [`v2.77-verification-checklist.md`](./v2.77-verification-checklist.md). V2.77 is completed for Real-local validation workbench only: blocker explanations for locked-session, window-not-found/no-ax-window, screen-recording-permission, stale-bundle/duplicate bundle, black/flat/transparent/invalid-capture, computer-use-timeout, remote-connection, activation-failed, and tool-layer-unknown. The verifier `pnpm verify:v2.77-docs` now requires completed evidence, including stable `skills-copilot.validation-workbench`, PID `34909` unlocked Computer Use evidence, app-window screenshot evidence at `docs/ui-artifacts/v2.77-validation-workbench/completed.png`, and no provider/write/apply/script/credential/cloud/telemetry safety expansion.

### V2.71 Verification Checklist（completed）

1. Multi-agent V2.71 analysis completed across service/protocol safety, Swift UI routing, and docs/validation risk.
2. Service protocol completed: `GuidedCleanupFlowStep.safe_action_deep_link` and `GuidedCleanupSafeNextAction.deep_link` are emitted with allowlisted targets, triggers, evidence refs, and safety flags.
3. Swift UI completed: Guided Cleanup step/action cards render safe-link buttons; `SkillStore.openGuidedCleanupSafeLink` routes only to existing read-only or preview-first surfaces; Analysis now mounts remediation plan/drafts/impact/batch/history panels so links have visible destinations.
4. Safe batch link remains non-applying: `openSafeBatchPreviewPanel` only selects the cleanup/safe batch context and does not auto-preview, auto-apply, toggle, write config, execute scripts, or confirm providers.
5. Focused Rust checks passed: `cargo fmt --all -- --check`, `cargo test -p skills-copilot-service --lib guided_cleanup`, `cargo test -p skills-copilot-service --lib service_protocol_fixtures_decode`, and `cargo test -p skills-copilot-service --lib supported_methods_have_dispatch_coverage`.
6. Focused Swift/native checks passed: `swift test --package-path apps/macos`, `pnpm verify:macos-ui-layout`, and `pnpm verify:screenshot-artifacts`.
7. Rebuilt no-capture fixture smoke passed: `./script/build_and_run.sh --verify` then `pnpm smoke:macos-app -- --fixture-data`.
8. `pnpm check:privacy` and `git diff --check` passed.
9. Full `pnpm check:macos` passed build/test/service stages, then failed closed at fixture capture with `locked-session: macOS session is locked; refusing to create screenshot evidence`.
10. Real-local Computer Use returned `timeoutReached`; full visual screenshot validation must be retried in an unlocked session.

### V2.70 Verification Checklist（completed）

1. Multi-agent V2.70 analysis completed across Swift modularization, Rust service modularization, and validation/docs risk.
2. Swift modularization completed: `TaskCockpitPanel.swift` owns Task Cockpit rendering; `DetailPresentationPrimitives.swift` owns shared detail UI primitives; `DetailView.swift` keeps routing/IA orchestration.
3. Rust modularization completed: `cleanup_queue.rs` owns cleanup queue DTOs, `ServiceHost::cleanup_list_queue`, and cleanup-specific sorting/priority helpers; dispatch and method names remain unchanged.
4. Focused Rust checks passed: `cargo fmt --all -- --check`, `cargo test -p skills-copilot-service --lib cleanup_queue`, `cargo test -p skills-copilot-service --lib supported_methods_have_dispatch_coverage`, and `cargo test -p skills-copilot-service --lib service_protocol_fixtures_decode`.
5. Focused Swift/native checks passed: `swift build --package-path apps/macos`, `swift test --package-path apps/macos`, `pnpm verify:macos-ui-layout`, and `pnpm verify:screenshot-artifacts`.
6. No-capture fixture smoke passed: `pnpm smoke:macos-app -- --fixture-data`.
7. `pnpm check:privacy`, `git diff --check`, and `git diff --cached --check` passed.
8. Full `pnpm check:macos` passed build/test/service stages, then failed closed at fixture capture with `locked-session: macOS session is locked; refusing to create screenshot evidence`.
9. Real-local Computer Use returned `timeoutReached`; `ioreg` reported `CGSSessionScreenIsLocked=Yes`; direct capture exited 6 with `locked-session`. Full visual validation must be retried in an unlocked session.

### V2.69 Verification Checklist（completed）

1. Multi-agent V2.69 analysis completed across scope calibration, UI/localization, and privacy/screenshot validation.
2. Localization syntax passed: `plutil -lint apps/macos/Sources/SkillsCopilot/Resources/en.lproj/Localizable.strings apps/macos/Sources/SkillsCopilot/Resources/zh-Hans.lproj/Localizable.strings`.
3. Focused native checks passed: `pnpm test:macos-list-model`, `pnpm verify:macos-ui-layout`, `pnpm verify:screenshot-artifacts`, and `swift test --package-path apps/macos`.
4. No-capture fixture smoke passed: `pnpm smoke:macos-app -- --fixture-data`.
5. Full gate attempted: `pnpm check:macos` passed the build/test/service stages, then failed closed at fixture capture with `locked-session: macOS session is locked; refusing to create screenshot evidence`.
6. No fresh V2.69 screenshot was committed; rerun capture in an unlocked session before adding visual evidence.
7. `pnpm check:privacy`, `git diff --check`, and `git diff --cached --check` passed.
8. Real-local Computer Use remains pending until an unlocked interactive macOS session is available; invalid locked/black/flat captures are blockers rather than visual evidence.

### V2.68 Verification Checklist（completed）

1. Multi-agent V2.68 review completed: UI/IA, service/protocol, and verification/docs agents all concluded this should be a SwiftUI IA consolidation over existing read-only service methods.
2. Focused Rust/protocol checks passed: `task.buildCockpit`, `service_protocol_fixtures_decode`, and `guided_cleanup` tests still pass, confirming no service semantic change was needed.
3. Focused Swift/UI checks passed: `swift test --package-path apps/macos`; Task Cockpit is the default detail entry, Work surfaces are modeled explicitly, and detail navigation exposes Task Cockpit, Skill Map, Cleanup, Guided Cleanup, Observability, Findings, Conflicts, History, and Review.
4. Native layout checks passed: `pnpm verify:macos-ui-layout` now verifies the bounded menu section switcher, hidden picker label, Work surfaces before diagnostics, and Task Cockpit rendering before the empty-detail fallback.
5. `pnpm check:macos` passed, including Rust fmt/tests/clippy, native list/store model checks, native layout check, Swift build/tests, Local App Launch Verify, fixture smoke, and fixture app-window capture.
6. Fixture screenshot inspection passed against `docs/ui-artifacts/native-macos-shell/completed.png` and `docs/ui-artifacts/v2.68-task-cockpit-ia/completed.png`; the image shows Work surfaces before Adapter/Health diagnostics and Task Cockpit selected by default.
7. Real local launch against current `dist/SkillsCopilot.app` succeeded and CG window metadata found the `SkillsCopilot` window. The macOS session was locked (`CGSSessionScreenIsLocked=Yes`), Computer Use timed out, and the final direct capture was black; this is recorded as the V2.68 locked-session/window-capture blocker. The black screenshot was not committed.
8. `pnpm check:privacy` and `git diff --check` passed.
9. 复核 V2.68 口径：Task Cockpit primary entry / Analysis IA remains a UI consolidation. It does not add service methods, provider default calls, hidden task state, skill/config writes, triage mutation, snapshot creation/rollback, script execution, credential reads, raw prompt/response/trace persistence, cloud sync, or telemetry.

**Closeout status**: completed with explicit V2.68 locked-session/window-capture blocker. The committed fixture screenshot is valid app-window-only evidence; real-local visual evidence must be retried after unlocking.

### V2.65 Verification Checklist（completed）

1. Focused Rust/protocol checks passed: `task.buildCockpit` derives cockpit sections, task rows, agent route rows, skill candidate rows, readiness rows, session-review/provider/remediation context, gap/blocker notes, evidence refs, prompt metadata, and safety flags from existing local evidence only.
2. Focused Swift/UI checks passed: Task-first Cockpit records decode service-native `cockpit_sections`, `task_rows`, `agent_route_rows`, `skill_candidate_rows`, `readiness_rows`, `provider_observability_rows`, `remediation_next_steps`, `gap_notes`, `blocker_notes`, and prompt/safety metadata without exposing raw prompt/raw response/raw trace or unredacted paths.
3. `pnpm check:macos` passed, including clippy, Swift build/tests, fixture launch, window capture, and smoke coverage.
4. Real local launch attempted against current `dist/SkillsCopilot.app`; the process launched and System Events confirmed `SkillsCopilot`, but System Events reported 0 windows after activation and Computer Use returned `cgWindowNotFound`. This is the V2.65 window/tool-layer blocker.
5. `pnpm check:privacy` and `git diff --check` passed.
6. 复核 V2.65 口径：Task-first Cockpit remains user-triggered, deterministic/read-only, and derived from existing app-local/local catalog evidence. It does not create hidden task state, write skill files or agent config, mutate triage, create or roll back snapshots, execute scripts, send provider/network requests by default, read credentials, persist raw prompt/response/trace/secrets/unredacted paths, sync cloud data, or emit telemetry.

**Closeout status**: completed with explicit V2.65 window/tool-layer blocker. Focused Rust/protocol, Swift model/store, service fixture, `pnpm check:macos`, `pnpm check:privacy`, `git diff --check`, and fixture smoke passed on 2026-06-12; real local Computer Use could not inspect the UI because the launched process exposed no AX-visible windows.

### V2.64 Verification Checklist（completed）

1. Focused Rust/protocol checks passed: `llm.providerObservability` derives summary, call/history rows, provider/model/destination grouping rows, status rows, budget usage hints, retention recommendations, evidence refs, prompt metadata, and safety flags from V2.61 prompt run metadata plus existing minimal provider call metadata only.
2. Focused Swift/UI checks passed: Provider Observability records decode service-native `grouping_rows`, `budget_usage_hints`, `retention_recommendations`, and `prompt_metadata`, and render no-write/no-provider safety flags without exposing raw prompt/raw response JSON/API keys/credentials/raw traces/unredacted paths.
3. `pnpm check:macos` passed, including clippy, Swift build/tests, fixture launch, window capture, and smoke coverage.
4. Real local launch attempted against current `dist/SkillsCopilot.app`; the process launched, but System Events reported 0 windows after activation and clean relaunch, and Computer Use returned `cgWindowNotFound`. This is the V2.64 window/tool-layer blocker.
5. `pnpm check:privacy` and `git diff --check` passed.
6. 复核 V2.64 口径：Provider Observability remains user-triggered, deterministic/read-only, and derived from app-local evidence only. It does not persist raw prompt/raw response JSON/API keys/credentials/raw traces/secrets/unredacted paths, write skill files or agent config, mutate triage, create or roll back snapshots, execute scripts, send provider/network requests by default, sync cloud data, or emit telemetry. Export/cleanup remains recommendations only in this slice.

**Closeout status**: completed with explicit V2.64 window/tool-layer blocker. Focused Rust/protocol, Swift model/store, service fixture, `pnpm check:macos`, `pnpm check:privacy`, `git diff --check`, and fixture smoke passed on 2026-06-12; real local Computer Use could not inspect the UI because the launched process exposed no AX-visible windows.

### V2.63 Verification Checklist（completed）

1. Focused Rust/protocol checks: `knowledge.buildLocalSkillMap` must derive summary, nodes, edges, clusters, coverage rows, gap/blocker notes, evidence refs, prompt metadata, and safety flags from existing catalog/knowledge/similar/taxonomy/conflict/task/risk evidence only.
2. Focused Swift/model checks: Local Skill Map records must decode and render map summary, nodes, edges, clusters, coverage rows, gap/blocker notes, evidence refs, and no-write/no-provider safety flags without exposing raw prompt/raw response/raw trace/secrets/unredacted paths.
3. `pnpm check:macos`.
4. Real local launch (`./script/build_and_run.sh run` or `pnpm dev:macos`) and current `dist/SkillsCopilot.app` Computer Use / AX attempt; exercise the Local Skill Map flow against real local app data and keep any window/tool blocker explicit.
5. `pnpm check:privacy`.
6. 复核 V2.63 口径：Local Skill Map remains user-triggered, deterministic/read-only, and derived from existing catalog/knowledge/similar/taxonomy/conflict/task/risk evidence. It must not create a new source of truth, persist a map artifact by default, write skill files or agent config, mutate triage, create or roll back snapshots, execute scripts, send provider requests by default, persist raw prompt/response/trace/secrets/unredacted paths, sync cloud data, or emit telemetry.

**Closeout status**: completed on 2026-06-12. Focused Rust/protocol tests (`cargo test -p skills-copilot-service local_skill_map -- --nocapture`), full service tests, service protocol fixture decode, supported-method dispatch coverage, focused Swift model/store tests, full `swift test --package-path apps/macos`, `pnpm check:macos`, `pnpm check:privacy`, and `git diff --check` passed. Real local Computer Use reached single-skill Analysis, displayed Local Skill Map, clicked `Build Map`, and rendered live results with nodes, edges, clusters, evidence, and safety sections; no live screenshot was committed. A later coordinator exact-path attach hit `cgWindowNotFound` / `remoteConnection` with duplicate same-bundle app processes present, recorded as a tool/window-layer retry blocker.

### V2.62 Verification Checklist（completed）

1. Focused Rust/protocol checks: `session.reviewAgentSkillUse` accepts pasted/imported agent sessions or `trace_import_ids`, derives deterministic hit/miss/wrong-pick/ambiguous/unknown outcomes, reports detected vs expected skills, duplicate/similar-skill interference, evidence refs, safe next steps, redaction summary, and safety flags without provider traffic; `session.listSkillReviews` and `session.deleteSkillReview` manage only app-local `agent-session-reviews.json` metadata.
2. Focused Swift checks: review records decode and render outcome, expected/detected skill rows, interference notes, safe next steps, evidence refs, and app-local history state without exposing raw transcript/raw prompt/raw response/secrets/unredacted paths.
3. `pnpm check:macos`.
4. Real local launch (`./script/build_and_run.sh run`) and current `dist/SkillsCopilot.app` Computer Use / AX attempt; import or paste a redacted session/trace, confirm the review output, and keep any window/tool blocker explicit.
5. `pnpm check:privacy`.
6. 复核 V2.62 口径：Agent Session Skill Review remains user-triggered, deterministic/read-only, and app-local redacted metadata only. It may persist `agent-session-reviews.json` records containing review title/source kind, redacted excerpt metadata, task/agent/expected refs, referenced trace import ids, detected skill refs, outcome, duplicate/similar-skill interference notes, safe next steps, evidence refs, timestamps, redaction summary, and safety flags. It must not persist raw transcript, raw prompt, raw response, secrets, unredacted local paths, skill files, or agent config; it must not mutate triage, create or roll back snapshots, execute scripts, send provider requests, sync cloud data, or emit telemetry.

**Closeout status**: completed for the current candidate. Focused Rust/protocol tests, full service tests, focused/full Swift tests, `pnpm check:macos`, `pnpm check:privacy`, fixture screenshot inspection, and real local Computer Use validation passed on 2026-06-12. Real local validation initially exposed a Swift decode mismatch for service-wire session review records; the tolerant model fix and matching Swift wire fixture were added, the UI then rendered the session review record correctly, and the temporary app-local review metadata was deleted. Keep V2.63+ work scoped to local skill map, provider observability, task-first cockpit, lifecycle timeline, and guided cleanup without reopening write/execute/provider-default paths.

### V2.61 Verification Checklist（completed）

1. Focused Rust checks: provider prompt timeout clamps to 600,000 ms; `llm.confirmPromptAndSend` records app-local prompt runs; `llm.listPromptRuns` returns redacted metadata and copy-only output without raw prompt/raw response/secrets.
2. Focused Swift checks: persisted prompt run records decode, hydrate latest send results after restart-like reload, and keep reruns visible as newer records.
3. `pnpm check:macos`.
4. Real local launch (`./script/build_and_run.sh run`) and current `dist/SkillsCopilot.app` Computer Use / AX attempt; keep any window/tool blocker explicit.
5. `pnpm check:privacy`.
6. 复核 V2.61 口径：provider-backed AI analysis remains user-triggered, prompt-previewed, redacted, explicit-confirm, read-only, and copy-only. It may persist app-local prompt run records containing action/request kind, scope, skill refs, redacted task text, provider/model/destination metadata, status/error/duration/token/cost, and extracted draft output. It must not persist raw prompt, raw provider response JSON, API keys, credentials, raw trace, skill files, agent config mutations, snapshots, triage mutations, scripts, cloud sync, or telemetry.

**Closeout status**: completed for the current candidate. Focused Rust/Swift tests, `pnpm check:macos`, `pnpm check:privacy`, and real local Computer Use against `dist/SkillsCopilot.app` passed on 2026-06-12. The real local Analysis tab showed the consolidated three-panel structure and no Computer Use window blocker remained for this pass.

### V2.41 Verification Checklist（文档同步）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`.
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并进行明确的 `SkillsCopilot` 窗口 `Computer Use`/AX 操作；若窗口分辨失败，显式记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 按 V2.41 边界复核：仅用户显式触发 provider 网络路径；无后台分析；无新写入脚本/执行/telemetry/AI write-back。

**Tasks**

- Keep finding/risk/analysis labels explainable: risk is a subset of findings; analysis is cross-agent insight; conflict is selected-agent runtime/name collision.
- Keep skill identity deterministic across all adapters and expose provenance labels in UI where user confusion is likely.
- Keep triage state in app-local storage only; never hide unresolved high-risk findings by default.
- Keep optional AI analysis user-triggered and separated from all write/config/script paths. Starting V2.41, provider calls are allowed only when the user explicitly configures an OpenAI-compatible or Claude-compatible endpoint/key/model and confirms a redacted prompt preview; AI output remains untrusted and cannot directly write, execute, or change triage/config state.
- Keep Hermes/OpenClaw writable/install blocked until the scheduled V2.95/V2.96 evidence slices verify individual skill disable schema, credential preservation, and rollback-safe writes.
- Keep Pi install and compatibility-root writes blocked until the scheduled V2.94 evidence slice closes; Pi toggle support is limited to the V2.37 guarded native global/project/package scope with snapshot/rollback.
- Keep every new write path behind service protocol, snapshot, audit, permission, and privacy boundaries.
- Update native macOS UI only as needed to expose clearer explanations, statuses, filters, finding groups, and guarded writable actions.

### V2.42 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并进行明确的 `SkillsCopilot` 窗口 `Computer Use`/AX 操作；若窗口分辨失败，显式记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.42 口径：provider-backed 每次请求必须先显示 prompt scope、included/excluded 字段、redaction summary、token/cost estimate、destination；发送前必须用户确认；确认后记录最小 redacted metadata。
7. 复核 V2.42 关闭项：无背景调用、无脚本执行、无 telemetry、无 AI write-back/apply/config/snapshot side effects。

### V2.43 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并进行 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口解析失败，记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符。
6. 复核 V2.43 口径：quality score 必须是 user-triggered、selected/batch 范围、默认只读；无 background/周期性调度；本地输入仅限 metadata/findings/conflicts/analysis/adapter diagnostics。
7. 复核关闭边界：无脚本执行、无 telemetry、无 AI write-back / config mutation / snapshot / triage side effect；provider 可选路径需经过 V2.42 prompt preview + redaction + confirmation。
8. 复核隐私边界：不落盘 raw prompt/response，不引入 new credential path；provider path 若存在只允许 Keychain-first key 存储和 V2.42 级最小调用 metadata。

**Closeout status**: completed. V2.43 integrates service protocol, Rust deterministic scoring, native Analysis UI, prompt-preview compatibility, focused Rust/Swift tests, `pnpm check:macos`, real local Computer Use validation, fixture screenshot inspection, and `pnpm check:privacy`.

**Exit Criteria**

- V2.26-V2.30 docs and code make finding/risk/conflict/analysis semantics explainable from Health, list, detail, and analysis views.
- Skill provenance and dedupe behavior are deterministic enough that Pi/opencode/compatibility-root surprises can be explained from the UI.
- Triage persistence helps reduce repeated noise while avoiding agent-config writes, script execution, AI write-back, and credential persistence; affected-instance drift should reopen triage automatically.
- AI-assisted analysis remains opt-in, read-only, privacy-safe, user-triggered, and impossible to use as an execution/write path. It must keep analysis scope read-only, copy-only draft outputs, and no background triggers.
- `docs/agent-adapters.md`, `docs/agent-adapter-spec-worklists.md`, `docs/development-tasks.md`, `docs/roadmap.md`, `docs/service-protocol.md`, `docs/data-model.md`, `docs/ui-delivery-standards.md`, and `AGENTS.md` agree on the current support state and next version line.

### V2.44 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并进行明确的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口解析失败，显式记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.44 口径：User provides a real task; service/UI evaluates candidate skills using local deterministic evidence（metadata / findings / conflicts / analysis / adapter diagnostics / V2.43 quality）并输出可读的 available/enabled/scoped/risky/missing 视图；无 background/周期性 readiness 轮询；结果保持 read-only。
7. 复核 V2.44 关闭边界：无脚本执行、无 telemetry、无 AI write-back、无 config/snapshot/triage side effect；未经 provider 的路径不发起网络。
8. 复核 optional provider explanation：必须走 V2.42 的 prompt preview / redaction / explicit confirmation；无 raw prompt/response 持久化；可保存的仅最小 redacted metadata。
9. 复核密钥与隐私：继续执行 V2.41 Keychain-first provider 密钥策略；不得将 secrets 落地到 SQLite、项目目录、日志、提示/响应 artifacts、截图或报告文件中。

**Closeout status**: completed. V2.44 integrates service protocol, Rust deterministic readiness scoring, native Analysis UI, prompt-preview compatibility, focused Rust/Swift tests, `pnpm check:macos`, real local Computer Use validation, fixture screenshot inspection, and `pnpm check:privacy`.

### V2.45 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并验证路由候选 ranking 流程；若窗口识别失败，记录 blocker（`cgWindowNotFound`/窗口不可见属于工具层 blocker）。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.45 目标口径：基于 user task 和可选 agent/candidate filter 生成 read-only ranking：
   - 输出项包含：`confidence`、`match_reasons`、`ambiguity/collision warnings`、`likely_wrong_pick`、`likely_miss`。
   - 证据源包括 `metadata`、`findings`、`conflicts`、`analysis`、`adapter diagnostics`、`quality_score`；`task.checkReadiness` 的本地 evidence remains primary.
   - optional provider explanation 继续走 V2.42 prompt preview + redaction + confirmation，不改变 candidate 排名。
7. 复核关闭边界：routing confidence 不可直接触发 `config.toggleSkill` / `snapshot.create/rollback`；不发起 provider 请求；不改 triage；不执行脚本；不写 agent config；不写 snapshots。
8. 验收触发条件：
   - [x] `task.rankSkillRoutes` 在 protocol 层可用且定义明确
   - [x] 返回 ranking/safety fields 与 evidence 结构经过 schema 定义
   - [x] 文档齐套（`AGENTS.md`、`docs/roadmap.md`、`docs/ai-layer.md`、`docs/service-protocol.md`、`docs/security-model.md`、`docs/v2.45-verification-checklist.md`）

**Closeout status**: completed. V2.45 integrates `task.rankSkillRoutes`, deterministic local route ranking, native Analysis UI, routing prompt preview compatibility, focused Rust/Swift tests, `pnpm check:macos`, real local Computer Use validation against the current bundle path, fixture screenshot inspection, and `pnpm check:privacy`.

### V2.46 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并执行 V2.46 目标流程的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口解析失败，记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符。
6. 复核 V2.46 目标口径：
   - 用户维护的本地 benchmark set（task、预期 skill refs/names、acceptable agent/scope、成功标准）持久化在 app-local `task-benchmarks.json`。
   - `task.listBenchmarks` / `task.saveBenchmark` / `task.deleteBenchmark` / `task.evaluateBenchmarks` 为 additive service protocol 方法。
   - 本地 evidence-only 评估复用 V2.44 `task.checkReadiness` 与 V2.45 `task.rankSkillRoutes`，输出 expected/acceptable match status、top route、score/band、gap/blocker notes、evidence refs 与 safety flags。
   - 本地 benchmark 评估不发起 provider 请求；可选说明性 provider 输出仅走 V2.42 `llm.previewPrompt` + `llm.confirmPromptAndSend`，并保持 copy-only。
7. 复核关闭边界：
   - 不调用 `config.toggleSkill` / `snapshot.create` / `snapshot.rollback` / `config.save`。
   - 不执行脚本。
   - 不改 triage。
   - 不读取 credentials；不持久化 raw prompt/response；不引入 cloud sync 或 telemetry。

**Closeout status**: completed with explicit Computer Use blocker. V2.46 integrates app-local task benchmark CRUD/evaluation in the Rust service, native Analysis benchmark UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, and `pnpm check:privacy`. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name even after stale same-bundle-id processes were removed. The captured real-local screenshot exposed local paths and was not committed.

### V2.47 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并执行 V2.47 目标流程的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口解析失败，显式记录 blocker。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.47 目标口径：
   - 方法层面由 `task.saveRoutingBaseline`（保存基线快照）与 `task.detectRoutingRegression`（读取/重跑基线对比）组成。
   - app-local baseline 来源为 V2.46 的 deterministic `TaskBenchmark` evaluation，保存于 `task-routing-baseline.json`，比较维度为 score/confidence delta、expected-match 状态变化、top-route 变化、gap/blocker 增量、missing/current-only benchmark 与 catalog 可用性。
   - `task.detectRoutingRegression` 采用本地证据输入（`TaskReadiness` + `TaskBenchmark` + `V2.43`~`V2.46` evidence），输出 `status`、`summary`、`items`、`baseline`、`current_evaluation`、`blocker_notes` 与 `safety_flags`，结果保持 app-local、deterministic、read-only。
7. 复核 V2.47 安全边界：不发 provider 请求用于回归评分；不读 credentials；不写 agent config；不创建/回滚 snapshot；不改 triage；不执行脚本；无 cloud sync 与 telemetry；可选 provider 说明仅走现有 V2.42 `llm.previewPrompt` + `llm.confirmPromptAndSend` 的 preview/redaction/确认/ copy-only 路径。

**Closeout status**: completed with explicit Computer Use blocker. V2.47 integrates app-local routing baseline persistence and deterministic regression detection in the Rust service, native Analysis routing regression UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, and `pnpm check:privacy`. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name after stale same-bundle-id processes were removed. No real-local screenshot was committed.

### V2.48 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并执行 V2.48 目标流程的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口不可见，明确记录 blocker（例如 `cgWindowNotFound` / `timeoutReached`）。
4. `pnpm check:privacy`。
5. App-window-only 截图并手工复核路径/凭据占位符脱敏。
6. 复核 V2.48 口径：
   - `trace.importLocal` 接收 pasted/local trace text 与可选 task/agent/expected skill refs/names。
   - redaction 先行，默认不落 raw trace（`raw_trace_persisted=false`）；仅持久化可复查 metadata、`redaction_summary`、redacted `excerpt` 与 deterministic `analysis` 到 `trace-imports.json`。
   - 判读输出为 deterministic local 结果：`analysis.outcome`（`hit` / `miss` / `wrong_pick` / `ambiguous` / `unknown`）、detected skills、expected skill refs/names、reasons、evidence refs 与 safety flags。
   - `trace.listImports` / `trace.deleteImport` 仅操作 app-local metadata，不改 triage、不改 agent config、不改 snapshot、不执行脚本。
   - 可选 provider 说明仍走 V2.42 preview/redaction/confirmation，保持 copy-only，不改变 deterministic 结果。

**Closeout status**: completed with explicit Computer Use blocker. V2.48 integrates app-local trace import/list/delete in the Rust service, redacted trace metadata persistence in `trace-imports.json`, deterministic trace outcome analysis, native Analysis trace import UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, and `pnpm check:privacy`. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name after stale same-bundle-id processes were removed. No real-local screenshot was committed.

### V2.49 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test -p skills-copilot-service -- --nocapture`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并执行 V2.49 routing accuracy dashboard 的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口不可见，明确记录 blocker（例如 `cgWindowNotFound` / `timeoutReached`）。
4. `pnpm check:privacy`。
5. Fixture screenshot 与 app-window-only 截图手工复核路径/凭据占位符脱敏；真实本机截图不得提交。
6. 复核 V2.49 口径：
   - `routing.accuracyDashboard` 只读聚合 V2.46 benchmark、V2.47 baseline/regression 与 V2.48 redacted trace import evidence。
   - 输出包含 `summary`、`agent_rows`、`history_rows`、`gap_issue_rows`、`recent_evidence_rows`、`blocker_notes`、`prompt_request` 与 `safety_flags`。
   - 指标覆盖 `hit` / `miss` / `wrong_pick` / `ambiguous` / `unknown`、accuracy rate、known outcome rate、benchmark gaps、regression count 与 recent evidence。
   - 本地 dashboard 不写新 artifact、不落 raw trace、不发 provider 请求、不改 triage/config/snapshot/skill 文件、不执行脚本、不读 credentials、不做 cloud sync/telemetry。
   - 可选 provider 说明仍走 V2.42 preview/redaction/confirmation，保持 copy-only，不改变 deterministic dashboard 结果。

**Closeout status**: completed with explicit Computer Use blocker. V2.49 integrates read-only `routing.accuracyDashboard` in the Rust service, native Analysis routing accuracy UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, and `pnpm check:privacy`. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name. No real-local screenshot was committed.

### V2.50 Verification Checklist（完成）

1. Focused Rust/Swift checks：`cargo test -p skills-copilot-service -- --nocapture`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` / `pnpm dev:macos`) 并进行 V2.50 目标流程的 `SkillsCopilot` 窗口 `Computer Use`/AX 观察；若窗口不可见，记录 blocker（例如 `cgWindowNotFound` / `timeoutReached`）。
4. `pnpm check:privacy`。
5. fixture data 与 App-window-only 截图手工复核路径/凭据占位符脱敏。
6. 复核 V2.50 口径：
   - `task.compareAgentReadiness` 以只读方式横向对比该任务在 Claude/Codex/opencode/Pi/Hermes/OpenClaw 的候选与 readiness 信号。
   - 输入来源为 `task.checkReadiness`、`task.rankSkillRoutes`、`task.evaluateBenchmarks`、`task.detectRoutingRegression`、`trace.importLocal`、`routing.accuracyDashboard`，并返回 per-agent readiness、routing confidence、quality 传播链路、gap/blocker 说明、evidence refs。
   - 默认不发 provider 请求；默认不改 triage、agent config、snapshot、catalog、skill files；不写 comparison artifact。
   - 可选 provider 说明仍通过 V2.42 `llm.previewPrompt` + `llm.confirmPromptAndSend`，copy-only。

**Closeout status**: completed with explicit Computer Use blocker. V2.50 integrates read-only `task.compareAgentReadiness` in the Rust service, native Analysis cross-agent readiness UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, fixture screenshot inspection, `pnpm check:privacy`, and real local launch validation. Real local app launch against the current `dist/SkillsCopilot.app` bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute bundle path and `timeoutReached` for the app name. No real-local screenshot was committed because the live UI exposes local paths.

### V2.51 Verification Checklist（完成）

1. Focused Rust/Swift checks：`cargo test -p skills-copilot-service -- --nocapture`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` / `pnpm dev:macos`) 并对当前 `dist/SkillsCopilot.app` bundle 进行 `Computer Use`/AX 尝试；若窗口解析失败，记录 blocker。
4. Fixture screenshot inspection 并手工核查路径/凭据占位符脱敏。
5. `pnpm check:privacy`。
6. 复核 V2.51 口径：`analysis.detectStaleDrift` 仅做 read-only、deterministic、本地 evidence-first stale/drift 评估；默认不发 provider 请求，不写 skill/agent config/snapshot/triage/stale-drift artifact，不执行脚本，不持久化 raw prompt/response/trace。

**Closeout status**: completed with explicit Computer Use blocker. V2.51 integrates read-only `analysis.detectStaleDrift` in the Rust service, native Analysis stale/drift UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, fixture screenshot inspection, `pnpm check:privacy`, and real local launch validation. Real local app launch against the current bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute app path and `timeoutReached` for the app name. No real-local screenshot was committed because the live UI exposes local paths.

### V2.52 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并对当前 `dist/SkillsCopilot.app` bundle 进行 `Computer Use`/AX 尝试；若窗口解析失败，显式记录 blocker。
4. Fixture screenshot inspection 并手工核查路径/凭据占位符脱敏；真实本机截图不得提交。
5. `pnpm check:privacy`。
6. 复核 V2.52 口径：`knowledge.search` 仅做 local-only、read-only、deterministic、user-triggered search；默认不发 provider 请求、不联网、不写 skill/agent config/snapshot/triage/index artifact，不执行脚本，不持久化 raw prompt/response/trace。

**Closeout status**: completed with explicit Computer Use blocker. V2.52 integrates read-only `knowledge.search` in the Rust service, native Analysis local knowledge UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, fixture screenshot inspection, `pnpm check:privacy`, and real local launch validation. Real local app launch against the current bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute app path and `timeoutReached` for the app name. No real-local screenshot was committed because the live UI exposes local paths.

### V2.53 Verification Checklist（完成）

1. Focused Rust/Swift checks: `cargo test --workspace`、`cargo clippy --workspace --all-targets --all-features`、`swift test --package-path apps/macos`。
2. `pnpm check:macos`。
3. Real local launch (`./script/build_and_run.sh run` 或 `pnpm dev:macos`) 并对当前 `dist/SkillsCopilot.app` bundle 进行 `Computer Use`/AX 尝试；若窗口解析失败，显式记录 blocker。
4. Fixture screenshot inspection 并手工核查路径/凭据占位符脱敏；真实本机截图不得提交。
5. `pnpm check:privacy`。
6. 复核 V2.53 口径：`knowledge.groupSimilarSkills` 仅做 local-only、read-only、deterministic、user-triggered grouping；默认不发 provider 请求、不联网、不写 skill/agent config/group artifact/snapshot/triage，不执行脚本，不持久化 raw prompt/response/trace。

**Closeout status**: completed with explicit Computer Use blocker. V2.53 integrates read-only `knowledge.groupSimilarSkills` in the Rust service, native Analysis similar grouping UI, tolerant Swift models, protocol fixtures, focused Rust/Swift tests, `pnpm check:macos`, fixture screenshot inspection, `pnpm check:privacy`, and real local launch validation. Real local app launch against the current bundle succeeded and direct window capture found the app window, but Computer Use returned `cgWindowNotFound` for the absolute app path and `timeoutReached` for the app name. No real-local screenshot was committed because the live UI exposes local paths.

## Current Backlog

These items keep the product focused on managing, inspecting, and analyzing skills. Script execution, GitHub clone import, and script-file install are removed from the active backlog.

| Priority | Work item | Current status | Next concrete task | Completion signal |
| --- | --- | --- | --- | --- |
| P0 | Real local Computer Use rerun gate | Previous mainline pass completed on 2026-06-10; V2.37 slice hit Computer Use `cgWindowNotFound` despite direct CG/AX window evidence | Rerun the real app against local HOME after UI/service/protocol changes, explicitly targeting the current `dist/SkillsCopilot.app` bundle when stale same-bundle-id worktree apps exist, covering project context, scan-all, agent filter, findings filtering/grouping, health dashboard, AI review preview, and script safety preview | App-window-only evidence and runbook notes updated for the new slice, or an explicit tool/session blocker is recorded |
| P0 | V2.41 AI Provider Foundation | Completed | Keep provider profiles, Keychain-first storage, explicit Test Connection, budget fields, and minimal redacted metadata stable while building V2.45+ | Users can safely configure their own endpoint/key/model without any background calls, writes, scripts, telemetry, or credential leakage; minimal call metadata exists before full observability |
| P0 | V2.42 Prompt Preview / Redaction | Completed | Keep prompt preview, redaction summary, included/excluded field display, token/cost estimate, destination preview, explicit confirmation, and minimal redacted audit metadata stable while building V2.45+ | Every model call is visible, redacted, user-confirmed, and auditable before network egress |
| P0 | V2.44 AI Task Readiness Check | Completed | Keep deterministic task readiness aligned with local evidence, V2.43 quality, safety flags, and V2.42-gated optional provider explanation | Users can judge whether a real task has available, enabled, scoped, low-risk candidate skills before routing confidence is added |
| P0 | V2.45 AI Routing Confidence | Completed | Keep route ranking confidence aligned with local readiness evidence plus V2.42-gated optional provider explanation | Users can understand which candidate skill is most likely to be selected correctly and where ambiguity may cause wrong picks |
| P1 | V2.50 Cross-agent task readiness | Completed | Keep completed V2.50 comparison aligned with V2.47 regression, V2.48 trace import, and V2.49 routing accuracy evidence | Users can compare expected vs actual skill selection and choose the best agent/skill route for a task |
| P1 | V2.51-V2.60 Knowledge / remediation workflow | Completed | Keep completed `analysis.detectStaleDrift`, local knowledge index, similar skill grouping, capability taxonomy, workspace readiness, AI remediation planner, fix drafts, impact preview, batch review, and app-local remediation history stable | Users can find, prioritize, and safely work through skill quality/routing issues |
| P1 | V2.64 Provider Observability | Completed | Keep `llm.providerObservability` aligned with focused protocol/Swift/UI checks, `pnpm check:macos`, real local Computer Use attempts, and privacy scan | Users can inspect provider usage/cost/failures from app-local redacted metadata without raw prompt/response JSON, credentials, unredacted paths, writes, provider requests, cloud sync, or telemetry |
| P1 | V2.65-V2.77 Cockpit / lifecycle / guided cleanup / IA / privacy / modularization / safe links / validation / recovery / launch targeting / input resilience / progressive feedback / validation workbench | V2.65 completed; V2.66 completed; V2.67 completed; V2.68 completed; V2.69 completed; V2.70 completed; V2.71 completed; V2.72 completed; V2.73 completed; V2.74 completed; V2.75 completed; V2.76 completed; V2.77 completed | Keep Task-first Cockpit, Skill Lifecycle Timeline, Guided Cleanup Flow, cockpit-first IA, screenshot privacy, module boundaries, safe guided-cleanup navigation, validation blocker taxonomy, bounded timeout recovery, launch/window targeting, task input resilience, progressive Cockpit feedback, and real-local validation workbench stable | Users can work from a task-centered cockpit, see skill change history, clean up issues through safe guided steps, reach major evidence surfaces, produce screenshot evidence without leaking local paths, reject invalid screenshot evidence, recover from slow real-catalog cockpit calls, validate the current app without stale-bundle ambiguity, enter tasks reliably, see staged long-running cockpit progress, inspect validation blocker state in-app, and benefit from safer follow-up maintenance |
| P0 | V2.69 Privacy / Screenshot Mode + localization polish | Completed | Added screenshot/demo-safe redaction, long-path collapse/reveal-on-demand, localized cockpit/guided/provider labels, app-language propagation, and validation-safe UI evidence flow | Users can produce real-local evidence without leaking local paths or accepting black/locked screenshots |
| P1 | V2.70 Swift / Rust feature modularization | Completed | Extracted Task Cockpit/detail primitives and cleanup queue modules after capturing current behavior with focused tests | Future feature work touches smaller modules without changing protocol semantics accidentally |
| P1 | V2.71 Guided Cleanup safe-action links | Completed | Added safe deep links from guided cleanup steps/actions to existing remediation, lifecycle, cockpit, cleanup/detail, safe batch preview, and guided metadata surfaces | Cleanup guidance becomes actionable while all writes remain preview-first and explicit-confirm |
| P0 | V2.72 Validation harness hardening | Completed | Added canonical blocker taxonomy, classification CLI, lock-screen preflight, screenshot artifact rejection labels, fixture/real evidence matrix, and closeout checklist | Locked-session or all-black captures fail fast and cannot be used as completed UI evidence |
| P0 | V2.73 Task / remediation performance and timeout recovery | Completed | Real-catalog task/remediation service calls now return bounded aggregation metadata and visible timeout/fallback/cancel/retry states instead of leaving Task Cockpit in `Preparing...` | Users can trust the task-centered cockpit on real local catalogs instead of seeing an indefinite loading state |
| P0 | V2.74 Real-local launch and window targeting stability | Completed | Current bundle path/PID launch, duplicate bundle fail-closed handling, window restoration, AX/Computer Use targeting, and lock-screen diagnosis are repeatable | Real local validation can target the latest app without stale-bundle or no-window ambiguity |
| P1 | V2.75 Task input and input-method resilience | Completed | AX-settable task input preserves user task text across Chinese text, paste/automation input, multiline entry, focus/result changes, emoji, and leading/trailing spaces while blocking whitespace-only submit | Users can enter tasks reliably before readiness/routing analysis |
| P1 | V2.76 Progressive Cockpit feedback | Completed | Keep staged readiness/routing/remediation/provider/session progress, partial results, elapsed time, timeout/fallback/blocked rows, and `pnpm verify:v2.76-docs` docs gate stable | Users can tell whether the app is working, blocked, or safely degraded without adding provider/write/execute/credential/cloud/telemetry semantics |
| P1 | V2.77 Real-local validation workbench | Completed | Keep lock/window/AX/permission/stale-bundle/duplicate-bundle/screenshot/tool-layer blocker state visible and actionable through `skills-copilot.validation-workbench`; preserve PID `34909` unlocked evidence and `docs/ui-artifacts/v2.77-validation-workbench/completed.png` closeout | Invalid screenshots still remain blockers, not accepted evidence |
| P0 | V2.78 Protocol / validation gate parity | Completed | Service-protocol docs were synchronized with the then-current 88 supported methods; `pnpm verify:service-protocol-drift`, `pnpm verify:v2.78-docs`, and `pnpm verify:gate-parity` are wired into local/CI gates; V2.46-V2.64 verification history is documented without invented evidence | Future protocol/docs drift is caught automatically, and maintainers have one reliable gate story |
| P0 | V2.79 Privacy fixture and evidence-surface localization sweep | Completed | Replaced literal local host-port fixtures, extended privacy scanning for host-port fingerprints, and applied path redaction/collapse/reveal plus Chinese localization across evidence surfaces | Real-local screenshots can be visually inspected without exposing local paths, and Chinese users do not hit mixed-language primary workflows |
| P1 | V2.80 Detail navigation and visual density polish | Completed | Reset Detail scroll to a stable top anchor when switching major surfaces; improve dense evidence-card hierarchy, long-list folding, summary rows, and two-column responsive behavior | PID `82571` real-local evidence and `docs/ui-artifacts/v2.80-detail-density/completed.png` closeout are recorded |
| P1 | V2.81 Swift service IPC cancellation cleanup | Completed | Added cancellation/timeout cleanup around the short-lived stdio sidecar without introducing a background daemon by default | Cancelled and stubborn service calls terminate/reap children and close stdio handles |
| P1 | V2.82 Test isolation and core model test floor | Completed | Provider env mutation isolation and core model wire/default/identity stability tests landed with docs/gate closeout | Parallel tests remain deterministic and core identity/scope assumptions are covered |
| P2 | V2.83 Continued module splitting | Completed | Split Rust protocol DTO/constants, Swift Detail overview helpers, and Swift fake service test helpers by existing domains | Follow-up work landed in smaller modules without changing service protocol or product semantics |
| P2 | V2.84 Swift Detail section splitting | Completed | Split `DetailView.swift` into section files including `DetailGuidedCleanupFlowPanel.swift`, with native layout verification aggregating the split Detail surface | Detail UI remains behaviorally unchanged while the file-size target is enforced |
| P2 | V2.85 Rust RPC domain module splitting | Completed | Split `ServiceHost` RPC handling across `service_host.rs`, `service_cleanup.rs`, `service_knowledge.rs`, `service_llm.rs`, `service_remediation.rs`, and `service_task.rs` | Protocol drift verification covers split files without changing methods or payloads |
| P2 | V2.86 Rust helper/test split and module-size gate | Completed | Split helpers such as `service_support_helpers.rs` and service tests under `crates/service/src/tests/`; add `verify:module-size` to gate parity | Single-file <= 5000-line target is now automated |
| P0 | V2.11 Adapter Capability Matrix | Completed and in use | Run focused protocol/UI checks when needed, then use the matrix as the gate for future Pi/opencode/Hermes/OpenClaw work | macOS UI shows precise scan/toggle/install status and blockers for all six agents |
| P0 | Pi comprehensive adapter support | Read-only scanner complete; V2.37 guarded native toggle complete; install and compatibility-root writes blocked | Keep Pi toggle limited to global/project/package write scope and keep install/AI auto-write/script execution credentials-unsafe paths blocked; exclude arbitrary compatibility roots from write path | Guarded native toggle preserves preview/snapshot/rollback, trust gate, invalid JSON/config handling, re-enable behavior, and disabled-state rescan |
| P0 | opencode support | Native and official compatibility roots are scanned; guarded `permission.skill` writes are implemented; install targets remain native roots | Keep compatibility-root scan coverage and managed permission/write tests current; custom `skills.paths` / `skills.urls` are scheduled for V2.93 and remain blocked pending evidence | opencode-visible skills match current official discovery roots without enabling unverified custom paths or unsafe file writes |
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
- If the task is AI provider foundation, prompt safety, AI quality/readiness/routing, task benchmark/regression, trace analysis, knowledge index, remediation, Agent Session Skill Review, Local Skill Map, provider observability, task cockpit, skill lifecycle, guided cleanup, cockpit-first IA, screenshot/privacy-safe UI presentation, completed Swift/Rust feature modularization, guided-cleanup safe-action links, validation harness hardening, completed Task/remediation timeout recovery, completed launch/window targeting stability, completed task input resilience, completed progressive Cockpit feedback, completed real-local validation workbench, completed protocol/docs/gate parity, completed privacy fixture/evidence localization, completed detail navigation/visual density polish, completed Swift service IPC cancellation cleanup, completed test isolation/core model floor, completed continued module splitting, completed Swift Detail section splitting, completed Rust RPC domain module splitting, completed Rust helper/test split and module-size gate, completed Agent Copilot first pass, completed Agent Copilot per-surface evidence closeout, completed brand asset refresh, or completed identifier migration, use V2.41-V2.90.
- If the task is post-V2.71 product consolidation or validation harness hardening, use V2.72.
- If the task is privacy fixture hardening or evidence-surface privacy/localization sweep after V2.77, use completed V2.79 and preserve its no credential/network/scanner/provider/write/script/cloud/telemetry boundary.
- If the task is detail navigation or visual density polish, use V2.80.
- If the task is Swift service IPC cancellation cleanup, use V2.81.
- If the task is provider-test environment isolation or core model test floor, use V2.82.
- If the task is continued Swift/Rust module splitting after V2.70, use V2.83-V2.86 depending on scope: protocol constants/envelopes use V2.83, Detail section views use V2.84, Rust RPC domain files use V2.85, and Rust helpers/tests plus module-size gate work use V2.86.
- Do not create versions for script execution, GitHub clone import, script-file install, signing, notarization, DMG/ZIP, public distribution, or full-platform UI adaptation unless the product direction changes explicitly.

## V2.35 Local report export — completed
- [x] Document local export intent and completed status in user-facing docs (README + roadmap + AGENTS).
- [x] Record report scope: agent coverage/status, health summary, open findings/triage state, cleanup queue, cross-agent comparison insights.
- [x] Document redaction requirements for exported data: local paths and environment roots must be replaced with placeholders.
- [x] Document explicit non-goals: public distribution, DMG/ZIP/signing/notarization, cloud sync, telemetry, provider calls, credential storage, script execution, automatic write-back.
- [x] Confirm V2.33/V2.34 semantics are preserved in updated docs.
- [x] Validate with `pnpm check:macos`, real local App export, and generated report path-redaction check.

## V2.39 OpenClaw workspace deepening (completed)

- Task definition: perform OpenClaw workspace-scoped deepening, constrained to `<workspace>/skills` and `<workspace>/.agents/skills`.
- Explicitly avoid arbitrary repo-root inference.
- Keep capabilities read-only; writable/install, scripts, AI auto-write, and credentials remain blocked.
- Completed after implementation, focused checks, `pnpm check:macos`, and explicit real-app Computer Use/window blocker documentation.
