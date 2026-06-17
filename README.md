# Agent Copilot

Desktop GUI, internally still built from the `skills-copilot` workspace, for
managing, inspecting, and auditing AI-agent skills across Claude Code, Codex,
opencode, Pi, Hermes, and OpenClaw.

## Current Status

| Area | Status |
| --- | --- |
| Current phase | V2.92 Codex expanded roots completed |
| Completed baseline | V2.1-V2.92 |
| Recent product line | V2.41-V2.92 AI-native analysis, task cockpit, validation hardening, module splitting, read-only Agent Copilot surfaces, per-surface evidence closeout, brand asset refresh, compatibility-first identifier migration, local model-task history, and Codex expanded root diagnostics |
| Agent Copilot line | M1-M4 completed; unlocked app-window evidence captured |
| Maintained UI | Native macOS app in `apps/macos` |
| Service boundary | Rust typed JSON stdio sidecar in `crates/service` |
| Next version | V2.93 opencode custom roots; V2.93-V2.96 near-term plan is tracked in `docs/roadmap.md` and `docs/development-tasks.md` |

V2.84-V2.86 completed the post-V2.83 module-splitting line:

- V2.84 Swift Detail section splitting.
- V2.85 Rust RPC domain module splitting.
- V2.86 Rust helper/test split and module-size gate.

V2.87 implements the first Agent Copilot pass:

- Display-level Agent Copilot brand, Lineup default surface, and Agent Profile.
- Sorted read-only decision queue over local health, cleanup, task, provider, and review evidence.
- Default-off `session.previewLocalSessions` with explicit authorized directories and redacted excerpts only.
- Default-off `evidence.previewMcpServers` with explicit authorized MCP config files and redacted server metadata only.
- Visual evidence note: 2026-06-17 unlocked `pnpm check:macos` passed; fixture-data smoke captured the full Agent Copilot app window at `docs/ui-artifacts/native-macos-shell/completed.png`.

V2.88 closes the handoff/evidence gap:

- Per-surface Computer Use evidence was captured for Lineup, Agent Profile,
  Local Session Preview, and MCP Preview.
- Authorized preview checks used only disposable `/tmp/ac-v288` fixtures and
  kept session/MCP output read-only and redacted.
- V2.87/V2.88 verification checklists are wired into `pnpm verify:gate-parity`.

V2.89 refreshes the Agent Copilot display brand assets:

- Adds `AppIcon.svg` as the reviewable icon source.
- Regenerates `AppIcon.icns` for the bundled macOS app icon.
- At the V2.89 boundary, kept `SkillsCopilot` / `skills-copilot`, bundle id,
  module names, AX ids, app-data paths, and `dist/SkillsCopilot.app`
  unchanged until the V2.90 migration slice.

V2.90 completes the first internal identifier migration slice:

- Changes the primary packaged app to `dist/AgentCopilot.app` with
  `CFBundleIdentifier=dev.agent-copilot.native`.
- Migrates the service default app-data id to `dev.agent-copilot.native` with a
  compatibility copy from legacy `dev.skills-copilot.native` app data when
  needed.
- Preserves Swift module names, Rust crate names, the `skills-copilot-service`
  sidecar, `skills-copilot.*` AX ids, `SKILLS_COPILOT_*` env vars, and the
  legacy Keychain service for compatibility.

V2.91 adds local model-task matching history:

- Adds `llm.listModelTaskMatches`, `llm.recordModelTaskMatch`, and
  `llm.deleteModelTaskMatch` as protocol-backed app-local metadata methods.
- Stores only redacted `model-task-matches.json` records and combines them with
  redacted prompt-run metadata for read-only history rows.
- Surfaces `model_task_history_rows` in Provider Observability without exposing
  write/delete controls in the V2.91 UI.

V2.92 completes Codex expanded roots:

- Adds read-only `$CODEX_HOME/skills`, local plugin marketplace roots, and
  `/etc/codex/skills` scanning/diagnostics when present.
- Includes project `.codex/config.toml` in diagnostics without enabling project
  config writes.
- Keeps Codex toggle writes limited to verified user/project `.agents/skills`
  instances through the user `config.toml` override.

## What It Does

- Scans and compares skills by agent, scope, source, state, and risk.
- Shows findings, conflicts, provenance, adapter diagnostics, lifecycle, and task-readiness evidence.
- Provides guarded enable/disable flows only for verified writable scopes.
- Supports local report export, cleanup queue, guided cleanup, and task-first cockpit views.
- Supports user-configured provider-backed explanations only after prompt preview, redaction, destination visibility, and explicit confirmation.
- Starts from an Agent Copilot lineup overview and Agent Profile surface for read-only, evidence-backed navigation across task, cleanup, observability, and review workflows.

## What It Does Not Do

- Does not replace any agent runtime.
- Does not run skill scripts by default.
- Does not cloud-sync, create accounts, or emit telemetry.
- Does not let LLM output trigger hidden writes, hidden apply, execution, or user confirmation.
- Does not perform signing, notarization, DMG/ZIP packaging, updater work, or public distribution automation.

## Documentation Map

### Human-Facing

| Need | Document |
| --- | --- |
| Product overview and common commands | `README.md` |
| Version milestones and planning | [`docs/roadmap.md`](./docs/roadmap.md) |
| Release-readiness and externally meaningful changes | [`CHANGELOG.md`](./CHANGELOG.md) |
| Architecture overview | [`docs/architecture.md`](./docs/architecture.md) |
| macOS native product direction | [`docs/macos-native-plan.md`](./docs/macos-native-plan.md) |
| Security and privacy model | [`docs/security-model.md`](./docs/security-model.md) |
| Contribution workflow | [`CONTRIBUTING.md`](./CONTRIBUTING.md) |

### AI-Agent-Facing

| Need | Document |
| --- | --- |
| Shared coding-agent rules | [`AGENTS.md`](./AGENTS.md) |
| Claude Code-specific compatibility | [`CLAUDE.md`](./CLAUDE.md) |
| Current task ledger and closeout pointers | [`docs/development-tasks.md`](./docs/development-tasks.md) |
| Multi-agent workflow and validation rules | [`docs/ai-agent-workflow.md`](./docs/ai-agent-workflow.md) |
| macOS run/smoke/capture rules | [`docs/macos-app-runbook.md`](./docs/macos-app-runbook.md) |
| UI and screenshot standards | [`docs/ui-delivery-standards.md`](./docs/ui-delivery-standards.md) |
| Service method contract | [`docs/service-protocol.md`](./docs/service-protocol.md) |
| Adapter scope and evidence gates | [`docs/agent-adapters.md`](./docs/agent-adapters.md), [`docs/agent-adapter-spec-worklists.md`](./docs/agent-adapter-spec-worklists.md) |

Version-specific evidence lives in `docs/v2.*-verification-checklist.md`.
Those files are evidence snapshots, not roadmap pages.

## Technical Shape

| Layer | Implementation |
| --- | --- |
| macOS product shell | SwiftUI + AppKit interop in `apps/macos` |
| Core/service | Rust workspace crates under `crates/` |
| Service protocol | Typed JSON / JSON-RPC-style stdio sidecar in `crates/service` |
| Persistence | Local SQLite catalog + JSON app-local runtime state |
| LLM/provider features | User-configured provider profiles, Keychain-first secrets, preview/redaction/confirmation gates |

The old Tauri/React UI and Tauri IPC shell have been removed. Do not recreate
`ui/`, `src-tauri/`, or Tauri IPC for product work.

## Common Commands

| Command | Use |
| --- | --- |
| `cargo test --workspace` | Rust workspace tests |
| `cargo clippy --workspace --all-targets --all-features` | Rust linting |
| `swift test --package-path apps/macos` | Swift package tests |
| `pnpm check:macos` | Full local macOS gate |
| `pnpm check:privacy` | Privacy/path/secret scan |
| `pnpm verify:gate-parity` | CI/local gate parity |
| `pnpm verify:service-protocol-drift` | Service protocol drift check |
| `pnpm verify:module-size` | V2.86 single-file size gate |
| `pnpm verify:macos-ui-layout` | Native UI static layout checks |
| `pnpm smoke:macos-app -- --fixture-data --capture-window` | Fixture smoke with app-window capture |
| `pnpm dev:macos` | Rebuild and launch `dist/AgentCopilot.app` with real local environment |

## Recent Verification Anchors

This section only keeps machine-checked status anchors. Detailed evidence lives
in `docs/v2.*-verification-checklist.md` and `docs/development-tasks.md`.

Baseline phrase used by docs gates:
V2.92 Codex expanded roots completed.

### V2.74-V2.78

- V2.74 验证清单（completed）:
  [`docs/v2.74-verification-checklist.md`](./docs/v2.74-verification-checklist.md),
  `pnpm verify:v2.74-docs`.
- V2.75 validation; V2.75 验证清单（completed）:
  [`docs/v2.75-verification-checklist.md`](./docs/v2.75-verification-checklist.md),
  `pnpm verify:v2.75-docs`, AX-settable input, PID `43079`,
  `docs/ui-artifacts/v2.75-task-input-resilience/completed.png`.
- V2.76 validation; V2.76 验证清单（completed）:
  PID `39728`, `skills-copilot.task-cockpit.stage-progress`,
  `docs/ui-artifacts/v2.76-progressive-cockpit-feedback/completed.png`.
- V2.77 validation; V2.77 验证清单（completed）:
  PID `34909`, `skills-copilot.validation-workbench`,
  `docs/ui-artifacts/v2.77-validation-workbench/completed.png`.
- V2.78 validation; V2.78 验证清单（completed）:
  V2.78 gate parity, CI/local gate parity, Service protocol drift,
  `pnpm verify:service-protocol-drift`, `pnpm verify:v2.78-docs`,
  and `pnpm verify:gate-parity`.

### V2.79-V2.83

- V2.79 validation: multi-agent V2.79 implementation completed.
  Privacy fixture and evidence-surface localization sweep; PID `68064`;
  `docs/ui-artifacts/v2.79-privacy-localization/completed.png`;
  `pnpm verify:v2.79-docs`; V2.79 验证清单（completed）.
- V2.80 validation; Detail navigation and visual density polish.
  PID `82571`; `skills-copilot.validation-workbench`;
  `docs/ui-artifacts/v2.80-detail-density/completed.png`;
  V2.80 验证清单（completed）; `pnpm verify:v2.80-docs`.
- V2.81 Swift service IPC cancellation cleanup completed.
  V2.81 validation; multi-agent V2.81 implementation completed;
  TERM-ignoring sidecar force-kill cleanup.
  No fresh Computer Use screenshot is required because V2.81 does not change user-visible native UI.
  V2.81 验证清单（completed）; `pnpm verify:v2.81-docs`.
- V2.82 test isolation and core model test floor completed.
  V2.82 validation; multi-agent V2.82 implementation completed;
  provider environment mutation tests now use serialized RAII cleanup;
  without adding serde dependencies.
  `pnpm check:macos` and `./script/build_and_run.sh --verify` failed closed with canonical `locked-session` before UI evidence capture.
  no fresh Computer Use screenshot is required because V2.82 has no user-visible native UI or service-protocol behavior change.
  V2.82 验证清单（completed）; `pnpm verify:v2.82-docs`.
- V2.83 validation; Continued module splitting.
  multi-agent V2.83 implementation completed;
  `crates/service/src/protocol.rs`, `DetailOverviewSection.swift`,
  `FakeServiceScript.swift`.
  no fresh Computer Use screenshot is required because V2.83 has no user-visible native UI or service-protocol behavior change.
  V2.83 验证清单（completed）; `pnpm verify:v2.83-docs`.

### V2.84-V2.86

- V2.84 Swift Detail section splitting:
  `DetailView.swift`, `DetailGuidedCleanupFlowPanel.swift`,
  `verify:module-size`, `pnpm verify:v2.84-docs`.
- V2.85 Rust RPC domain module splitting:
  `service_host.rs`, `service_task.rs`, `pnpm verify:v2.85-docs`.
- V2.86 Rust helper/test split:
  module-size, `service_support_helpers.rs`, `crates/service/src/tests/`,
  `pnpm verify:v2.86-docs`, `pnpm check:macos` passed.

### V2.87

- Agent Copilot first implementation pass:
  Lineup default surface, Agent Profile, sorted decision queue,
  `session.previewLocalSessions`, `evidence.previewMcpServers`,
  and protocol drift count 90.
- 2026-06-17 unlocked `pnpm check:macos` passed end to end, including
  `./script/build_and_run.sh --verify`, fixture-data app-window capture at
  `docs/ui-artifacts/native-macos-shell/completed.png`, screenshot artifact
  verification, and privacy check.

### V2.88-V2.92

- V2.88 handoff/evidence closeout:
  [`docs/v2.88-verification-checklist.md`](./docs/v2.88-verification-checklist.md),
  per-surface app-window evidence under
  `docs/ui-artifacts/v2.88-handoff-evidence/`.
- V2.89 brand asset refresh:
  [`docs/v2.89-verification-checklist.md`](./docs/v2.89-verification-checklist.md),
  `AppIcon.svg`, regenerated `AppIcon.icns`.
- V2.90 identifier migration:
  [`docs/v2.90-verification-checklist.md`](./docs/v2.90-verification-checklist.md),
  `dist/AgentCopilot.app`, `dev.agent-copilot.native`, and legacy app-data
  compatibility.
- V2.91 model-task matching history:
  [`docs/v2.91-verification-checklist.md`](./docs/v2.91-verification-checklist.md),
  app-local `model-task-matches.json` and Provider Observability rows.
- V2.92 Codex expanded roots:
  [`docs/v2.92-verification-checklist.md`](./docs/v2.92-verification-checklist.md),
  read-only `$CODEX_HOME/skills`, plugin marketplace, `/etc/codex/skills`,
  project `.codex/config.toml` diagnostics, and native `.agents/skills`
  write allowlist.

## Development Notes

- Agents should start with `AGENTS.md`; Claude Code also reads `CLAUDE.md`.
- Current implementation work should be tracked in `docs/development-tasks.md`.
- Roadmap changes should stay milestone-level and avoid command logs.
- CHANGELOG entries should be reserved for release-readiness, adapter behavior, risk, validation, and externally meaningful changes.

## License

MIT. See [`LICENSE`](./LICENSE).
