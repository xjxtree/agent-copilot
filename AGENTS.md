# AGENTS.md

This file is the shared project instruction entrypoint for coding agents such as Codex, Claude Code, Pi, opencode, and other compatible tools.

## Project State

- Current phase: V2.10 skill execution safety boundary and release/docs consistency are documented.
- Near-term priority: comprehensive agent adapter support for Pi, opencode writable support, Hermes, and OpenClaw in the macOS app.
- Current mainline real local app Computer Use validation passed on 2026-06-09.
- V2.8 rules/permissions governance, V2.9 Tool-global skill pool, and V2.10 docs/release consistency are integrated.
- Earlier integrated phases: MVP, Product UI/UX Hardening, V1 native macOS baseline, macOS Native Productization, V2 Prep security gates, refresh-summary UX, native test hardening, adapter evidence gates, first Codex adapter slice, and V2.1 through V2.7.
- The V2.2/V2.3 historical macOS/AX window-resolution blocker was resolved for the current mainline validation pass on 2026-06-09. Future user-visible, UI, or service-protocol changes must rerun real local Computer Use validation against the developer's real environment and keep any new blocker explicit; do not substitute smoke screenshots for real local validation.
- V2.8 covers LLM status protocol compatibility, permissions roundtrip, explicit severity ordering, findings filtering/grouping UI, and `app.stateSnapshot` refresh optimization.
- V2.8 completed local rules: `frontmatter.tools-not-empty`, `permissions.network-declared`, `permissions.exec-needs-human`, `name.canonical-case`, `script.no-shebang`, `body.too-long`, and `dependency.unknown`.
- V2.9 covers tool-global catalog/staging records, local directory import with rule audit, reproducible local export bundle/manifest, manifest reimport stability, native read-only preview UI, and confirmed install to Claude/Codex verified skill roots. GitHub clone import and script-file install remain out of scope. opencode writable install is a near-term evidence priority and must remain blocked until evidence verifies writable semantics.
- V2.10 covers the documented skill execution safety boundary only: no real execution by default, per-request human confirmation before any future execution path, cwd/env/network/files preview, local audit records for blocked/cancelled/failure attempts, and hard separation from LLM actions. Do not claim a completed script runner, sandbox runtime, public execution API, or successful execution output log exists.
- Near-term work prioritizes comprehensive agent adapter support. Track Pi disposable local round-trip, opencode writable evidence/implementation, Hermes maintainer-confirmed spec, and OpenClaw maintainer-confirmed spec as the top adapter priorities in `docs/development-tasks.md`; do not reopen V2.1-V2.10 for those closed items.
- V2.3 Codex adapter hardening covers config patch robustness, adapter state expression, security regressions, smoke coverage, and documentation/status synchronization.
- V2.4 opencode is the third adapter and is read-only only. The scoped scan roots are native opencode roots only: `~/.config/opencode/skills` and active project `.opencode/skills`. Do not scan opencode `.agents` / `.claude` compatibility roots for V2.4, and keep writable opencode toggles blocked.
- The maintained product UI is the native macOS app in `apps/macos`, built with SwiftUI and AppKit interop.
- The Rust service protocol in `crates/service` is the UI boundary for the macOS app.
- The old Tauri/React UI and Tauri IPC shell have been removed. Do not recreate `ui/`, `src-tauri/`, or Tauri IPC for product work.
- The only current app bundle path is `dist/SkillsCopilot.app`.
- V2.7 LLM local assist must remain disabled by default. The finished implementation boundary is service/UI gate plus request prepare/estimate; do not claim real provider clients, network calls, or credential storage exist.

## Architecture Rules

- Keep product logic in Rust workspace crates, not in the UI shell.
- `crates/core` is the no-I/O base layer. Higher crates may depend on it; it must not depend on higher crates.
- New UI work must call the typed Rust service protocol.
- Current implemented adapter scope is Claude Code, Codex, and read-only opencode.
- Codex support is limited to verified user/project roots, cwd-to-repo-root project discovery, `catalog.scanAll`, project-context-scoped scanning, agent filtering/status display, and user-config writable toggles through `~/.codex/config.toml` / `$CODEX_HOME/config.toml`.
- Project-local Codex config writes, plugin/admin/system roots, Pi, Hermes, and OpenClaw remain blocked or read-only planning only per their evidence docs.
- Opencode must remain read-only and native-root-only until a later evidence pass verifies writable semantics.
- No cloud sync, accounts, telemetry, anonymous crash reports, or uncontrolled outbound network calls.
- Optional LLM features must be explicitly enabled by the user. V2.7 currently must not save credentials; future macOS credential storage must prefer Keychain, and fallback `~/.config/skills-copilot/llm.yaml` must be permission-checked as `0600`. Credentials must never be written to SQLite, project directories, logs, prompts, or response artifacts.
- LLM output is untrusted. Draft frontmatter is display/copy-only in V2.7; do not add Apply/Write paths from LLM output. Real writes must go through the normal user edit/save flow and Rust service validation.
- Skill scripts are untrusted. V2.10 keeps script execution default-denied: LLM output, analyzer recommendations, imports, and tool-global previews must not trigger command execution. Any future execution path must require a fresh user confirmation and show cwd, env, network, and file scope before it can run.

## Required Verification

- For code changes, run the focused checks needed for the touched area.
- For major changes, user-visible behavior, UI work, service protocol changes, or milestone completion, run `pnpm check:macos`, then run the real local app with `pnpm dev:macos` or `./script/build_and_run.sh run` and operate it with macOS Computer Use only after confirming the macOS session is unlocked and interactive.
- Smoke validation uses fixture data and must not touch the real user Claude config.
- Real local validation uses the developer's real local HOME, app data, and Claude config.
- Completed UI screenshots must capture only the full app window. Full desktop screenshots are forbidden.
- If the macOS session is locked, cannot be confirmed interactive, or Computer Use/window capture is blocked, state the blocker explicitly. Do not substitute a smoke screenshot for real local validation.
- Before committing, pushing, or handing off evidence, run `pnpm check:privacy`. Do not commit real local user paths, usernames, home directories, app-data paths, temp directories, credentials, tokens, proxy-managed credential placeholders, or screenshots that visibly expose those values. Use `$HOME`, `<repo>`, `<worktree>`, `<project-root>`, `<app-data-dir>`, and `<redacted>` placeholders in docs and fixtures. New screenshots require manual visual inspection because automated binary string scans do not perform OCR.

## Common Commands

```sh
cargo test --workspace
cargo clippy --workspace --all-targets --all-features
./script/build_and_run.sh --verify
pnpm build:macos
pnpm dev:macos
pnpm smoke:macos-app -- --fixture-data --capture-window
pnpm check:macos
pnpm check:privacy
pnpm capture:macos-window
swift test --package-path apps/macos
pnpm test:macos-list-model
pnpm benchmark:macos-list-model
pnpm verify:macos-ui-layout
```

## Read Before Editing

- Architecture changes: `docs/architecture.md`
- Agent workflow and verification rules: `docs/ai-agent-workflow.md`
- macOS app run and smoke rules: `docs/macos-app-runbook.md`
- UI prototype, screenshot, and verification standards: `docs/ui-delivery-standards.md`
- macOS native product plan: `docs/macos-native-plan.md`
- Data model: `docs/data-model.md`
- Security and privacy model: `docs/security-model.md`
- Roadmap and milestone status: `docs/roadmap.md`
- Current development task queue: `docs/development-tasks.md`
- Adapter scope and TBD specs: `docs/agent-adapters.md`
- Non-Claude adapter evidence gates: `docs/agent-adapter-spec-worklists.md`

## Git and Editing Rules

- Do not revert user changes unless explicitly asked.
- Keep edits scoped to the requested task and the relevant architecture boundary.
- Prefer existing project patterns over new abstractions.
- Update docs when behavior, commands, architecture, validation flow, or UI state changes.
- Before committing, check the working tree and only include intended changes.
- For multi-agent parallel work, create one isolated git worktree and branch per task before assigning subagents. Subagents must be told to work only in their assigned worktree, must not switch branches, and must not edit the coordinator checkout.
