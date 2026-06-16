# skills-copilot

Desktop GUI for managing, inspecting, and auditing AI-agent skills across
Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw.

## Current Status

| Area | Status |
| --- | --- |
| Current phase | V2.86 Rust helper/test split and module-size gate closeout completed |
| Completed baseline | V2.1-V2.86 |
| Recent product line | V2.41-V2.86 AI-native analysis, task cockpit, validation hardening, and module splitting |
| Maintained UI | Native macOS app in `apps/macos` |
| Service boundary | Rust typed JSON stdio sidecar in `crates/service` |
| Next version | No post-V2.86 version has been selected yet |

V2.84-V2.86 completed the post-V2.83 module-splitting line:

- V2.84 Swift Detail section splitting.
- V2.85 Rust RPC domain module splitting.
- V2.86 Rust helper/test split and module-size gate.

## What It Does

- Scans and compares skills by agent, scope, source, state, and risk.
- Shows findings, conflicts, provenance, adapter diagnostics, lifecycle, and task-readiness evidence.
- Provides guarded enable/disable flows only for verified writable scopes.
- Supports local report export, cleanup queue, guided cleanup, and task-first cockpit views.
- Supports user-configured provider-backed explanations only after prompt preview, redaction, destination visibility, and explicit confirmation.

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
| `pnpm dev:macos` | Rebuild and launch `dist/SkillsCopilot.app` with real local environment |

## Recent Verification Anchors

This section only keeps machine-checked status anchors. Detailed evidence lives
in `docs/v2.*-verification-checklist.md` and `docs/development-tasks.md`.

Baseline phrase used by docs gates:
V2.86 Rust helper/test split and module-size gate closeout completed.

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

## Development Notes

- Agents should start with `AGENTS.md`; Claude Code also reads `CLAUDE.md`.
- Current implementation work should be tracked in `docs/development-tasks.md`.
- Roadmap changes should stay milestone-level and avoid command logs.
- CHANGELOG entries should be reserved for release-readiness, adapter behavior, risk, validation, and externally meaningful changes.

## License

MIT. See [`LICENSE`](./LICENSE).
