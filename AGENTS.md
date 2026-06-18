# AGENTS.md

Shared instruction entrypoint for Codex, Claude Code, Pi, opencode, and other
coding agents working in this repository.

## Purpose

- `AGENTS.md` is agent-facing. Keep it short, operational, and safe.
- `CLAUDE.md` imports this file and only adds Claude Code-specific behavior.
- Detailed procedures live in `docs/`; do not duplicate them here.
- Human-facing overview belongs in `README.md`.
- Version planning belongs in `docs/roadmap.md`.
- Active implementation tasks and closeout evidence pointers belong in `docs/development-tasks.md`.
- Release-impact summaries and risk notes belong in `CHANGELOG.md`.

## Current State

- Current phase: **V2.95 Hermes native-root install completed**.
- Completed baseline: V2.1-V2.95. V2.87 unlocked validation passed on 2026-06-17 via `pnpm check:macos`; V2.88 added Computer Use per-surface evidence under `docs/ui-artifacts/v2.88-handoff-evidence/`; V2.89 refreshed the app icon assets; V2.90 migrated the packaged app identity and default app-data id with compatibility; V2.91 added local model-task matching history; V2.92 added Codex read-only expanded roots and a native-root write allowlist; V2.93 added opencode configured local `skills.paths` scanning; V2.94 added Pi `.agents/skills` compatibility scanning/toggles and native-root installs; V2.95 added Hermes native `~/.hermes/skills` tool-global installs.
- Completed product slice: Agent Copilot M1-M4. The displayed product name and primary packaged app identity are Agent Copilot; Swift module/source names, Rust crate names, sidecar name, AX ids, env vars, and legacy Keychain service intentionally retain `SkillsCopilot` / `skills-copilot` compatibility.
- Current Agent Copilot surfaces: Lineup default surface, Agent Profile, sorted read-only decision queue, default-off local session preview, and default-off MCP server preview.
- Near-term post-V2.95 planning: V2.96 covers the OpenClaw writable/install evidence slice.
- Maintained product UI: native macOS app in `apps/macos`.
- Service boundary: Rust typed JSON stdio sidecar in `crates/service`.
- Current app bundle path: `dist/AgentCopilot.app`.
- Legacy Tauri/React UI is removed. Do not recreate `ui/`, `src-tauri/`, or Tauri IPC.
- V2.91 model-task history stores only redacted app-local `model-task-matches.json`
  metadata. Provider Observability displays `model_task_history_rows` read-only;
  do not add write/delete UI controls without a new scoped version and explicit
  safety review.

## Documentation Ownership

| File | Audience | Owns |
| --- | --- | --- |
| `AGENTS.md` | AI agents | Shared rules, safety boundaries, validation expectations |
| `CLAUDE.md` | Claude Code | Claude-specific compatibility and Computer Use defaults |
| `README.md` | Humans | Product overview, quick status, document map, common commands |
| `docs/roadmap.md` | Humans + agents | Version milestones, planned/completed roadmap scope |
| `docs/development-tasks.md` | Agents + maintainers | Current task ledger, closeout pointers, routing decisions |
| `CHANGELOG.md` | Humans + agents | Release-readiness and externally meaningful change/risk log |
| `docs/v2.*-verification-checklist.md` | Agents + reviewers | Version-specific evidence snapshots |
| `docs/service-protocol.md` | Agents + implementers | Service method contract and protocol drift source |

## Architecture Rules

- Keep product logic in Rust workspace crates, not in the UI shell.
- `crates/core` is the no-I/O base layer. Higher crates may depend on it; it must not depend on higher crates.
- New UI work must call the typed Rust service protocol.
- SwiftUI/AppKit code should stay in the native macOS shell and follow existing view/model/service patterns.
- New service behavior must keep `docs/service-protocol.md`, fixtures, and protocol drift verification in sync.

## Adapter Scope

- Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw are the current adapter families.
- Codex scans verified user/project `.agents/skills`, `$CODEX_HOME/skills`, local plugin marketplace roots, and `/etc/codex/skills` when present. `$CODEX_HOME/skills`, plugin/admin/system roots, and project `.codex/config.toml` are read-only diagnostics; writable toggles remain limited to user/project `.agents/skills` instances through the user config override.
- Opencode scans native roots, official `.claude` / `.agents` compatibility roots, and configured local `skills.paths` roots. `skills.urls` is metadata-only: do not fetch network skill indexes unless a future explicit confirmation flow is scoped. Writable support remains limited to exact managed `permission.skill` overrides; installs remain limited to native opencode roots.
- Pi scans native `~/.pi/agent/skills` / project `.pi/skills` roots plus `.agents/skills` compatibility roots. Guarded toggles may update Pi settings for native and `.agents` compatibility instances after trust/snapshot checks. Tool-global installs are limited to native `~/.pi/agent/skills` and project `.pi/skills`; Pi package install/remove and `.agents` direct skill-file installs remain blocked.
- Hermes native-root install is limited to confirmed local ToolGlobal `SKILL.md` copies into `~/.hermes/skills`. Hermes external roots are explicit read-only roots. Do not infer generic project roots. Hermes config toggles, per-platform enablement writes, external_dirs writes, hub/URL/tap/update/uninstall/reset operations, and uncontrolled network fetch remain blocked.
- OpenClaw workspace scope is read-only and limited to `<workspace>/skills` and `<workspace>/.agents/skills`. OpenClaw writable/install is scheduled for V2.96 and remains blocked until verified.

## Safety Boundaries

- No cloud sync, accounts, telemetry, anonymous crash reports, or uncontrolled outbound network calls.
- Optional LLM/provider features must be explicitly enabled by the user.
- Provider calls require prompt preview, redaction, destination visibility, and explicit confirmation.
- Credentials must prefer Keychain. Never write credentials to SQLite, project directories, logs, prompts, response artifacts, screenshots, or reports.
- LLM output is untrusted and copy-only unless a normal explicit user edit/save flow validates it.
- Skill scripts are untrusted. Script execution remains default-denied and must not be triggered by imports, LLM output, analyzer recommendations, previews, or cleanup guidance.
- Do not add hidden apply/write paths, hidden task state, raw prompt/response/trace persistence, public distribution automation, signing, notarization, DMG, or ZIP work unless explicitly scoped.

## Required Verification

- For small code changes, run focused checks for the touched area.
- For major changes, user-visible behavior, UI work, service protocol changes, or milestone completion, run `pnpm check:macos`.
- For docs that claim implementation status, screenshots, or validation results, run the relevant verifier or change the wording.
- Before committing, pushing, or handing off evidence, run `pnpm check:privacy`.
- Smoke validation uses fixture data and must not touch real user config.
- Real local validation uses the developer's real local HOME, app data, and agent configs.
- Completed UI screenshots must capture only the full app window. Full desktop screenshots are forbidden.
- If the macOS session is locked, cannot be confirmed interactive, or Computer Use/window capture is blocked, record the canonical blocker. Do not substitute a smoke screenshot for real local validation.

## Common Commands

```sh
cargo test --workspace
cargo clippy --workspace --all-targets --all-features
swift test --package-path apps/macos
pnpm check:macos
pnpm check:privacy
pnpm verify:gate-parity
pnpm verify:service-protocol-drift
pnpm verify:module-size
pnpm verify:macos-ui-layout
pnpm smoke:macos-app -- --fixture-data --capture-window
pnpm dev:macos
```

## Read Before Editing

| Change area | Read first |
| --- | --- |
| Architecture | `docs/architecture.md` |
| Agent workflow / validation | `docs/ai-agent-workflow.md` |
| macOS run / smoke | `docs/macos-app-runbook.md` |
| UI / screenshot standards | `docs/ui-delivery-standards.md` |
| Service protocol | `docs/service-protocol.md` |
| Data model | `docs/data-model.md` |
| Security / privacy | `docs/security-model.md` |
| Roadmap status | `docs/roadmap.md` |
| Active task ledger | `docs/development-tasks.md` |
| Adapter scope | `docs/agent-adapters.md`, `docs/agent-adapter-spec-worklists.md` |

## Git and Editing Rules

- Do not revert user changes unless explicitly asked.
- Keep edits scoped to the requested task and relevant architecture boundary.
- Prefer existing project patterns over new abstractions.
- Update docs when behavior, commands, architecture, validation flow, or UI state changes.
- Before committing, check the working tree and only include intended changes.
- For multi-agent parallel work, create one isolated git worktree and branch per task before assigning subagents.
  Subagents must stay in their assigned worktree, must not switch branches,
  and must not edit the coordinator checkout.

## Gate Anchors

This section keeps compact machine-checked milestone anchors. Full details live in
`docs/development-tasks.md` and the version verification checklists.

### V2.74-V2.78

- V2.74 completed boundary: exact workspace bundle/PID targeting for `dist/SkillsCopilot.app`.
- V2.75 completed boundary: Task input and input-method resilience, PID `43079`, no raw prompt persistence.
- V2.76 completed boundary: Progressive Cockpit feedback, PID `39728`, `skills-copilot.task-cockpit.stage-progress`, no provider/write/execute/credentials/cloud/telemetry expansion.
- V2.77 completed boundary: `skills-copilot.validation-workbench`, PID `34909`, no provider/write/apply/script/credential/cloud/telemetry expansion.
- V2.78 completed boundary: Protocol / validation gate parity over the then-current 88 `SUPPORTED_METHODS`, `pnpm verify:service-protocol-drift`, `pnpm verify:gate-parity`, file-level session review fixtures, and V2.46-V2.64 verification-history governance without invented evidence.

### V2.79-V2.83

- V2.79 validation: multi-agent V2.79 implementation completed.
  privacy fixture and evidence-surface localization sweep; PID `68064`;
  `docs/ui-artifacts/v2.79-privacy-localization/completed.png`.
- V2.80 completed boundary: Detail navigation and visual density polish.
  PID `82571`; `skills-copilot.validation-workbench`;
  `docs/ui-artifacts/v2.80-detail-density/completed.png`.
- 2026-06-15 V2.81 validation: `StdioServiceProcessRunner`.
  Task Cockpit cancel/timeout cancels the active service task.
  No fresh Computer Use screenshot is required because V2.81 has no user-visible native UI change.
  V2.81 completed boundary.
- 2026-06-15 V2.82 validation: serialized RAII cleanup in `crates/service/src/lib.rs`.
  `crates/core/src/model.rs` locks `AgentId` / `Scope` wire strings without adding serde dependencies.
  `pnpm check:macos` and `./script/build_and_run.sh --verify` failed closed with canonical `locked-session` before UI evidence capture.
  no fresh Computer Use screenshot is required because V2.82 has no user-visible native UI or service-protocol behavior change.
  V2.82 completed boundary.
- 2026-06-15 V2.83 validation: multi-agent V2.83 implementation completed.
  `crates/service/src/protocol.rs`, `DetailOverviewSection.swift`, and `FakeServiceScript.swift` were split out.
  no fresh Computer Use screenshot is required because V2.83 has no user-visible native UI or service-protocol behavior change.
  V2.83 completed boundary.

### V2.84-V2.86

- V2.84 Swift Detail section splitting: `DetailView.swift`, `DetailGuidedCleanupFlowPanel.swift`, `verify:module-size`.
- V2.85 Rust RPC domain module splitting: `service_host.rs`, `service_task.rs`.
- V2.86 Rust helper/test split and module-size gate closeout: `service_support_helpers.rs`, `crates/service/src/tests/`, `verify:module-size`.
- V2.87 Agent Copilot first pass: `AgentCopilotOverviewPanel.swift`, `AgentCopilotDecision.swift`, `LocalSessionPreview.swift`, `McpServerPreview.swift`, `service_task.rs`, `service_evidence.rs`, and protocol fixtures for `session.previewLocalSessions` / `evidence.previewMcpServers`.
- V2.88 handoff/evidence closeout: `docs/v2.88-verification-checklist.md` and `docs/ui-artifacts/v2.88-handoff-evidence/` record unlocked Computer Use evidence for Lineup, Agent Profile, Local Session Preview, and MCP Preview.
- V2.89 brand asset refresh: `AppIcon.svg`, regenerated `AppIcon.icns`, `script/generate_app_icon.sh`, `docs/v2.89-verification-checklist.md`, and `docs/ui-artifacts/v2.89-brand-assets/`; internal `SkillsCopilot` / `skills-copilot` identifiers remain unchanged.
- V2.90 identifier migration: `dist/AgentCopilot.app`, `dev.agent-copilot.native`, `dev.skills-copilot.native` app-data compatibility migration, `agent-copilot-app-data-migration.json`, `docs/v2.90-verification-checklist.md`, and `docs/ui-artifacts/v2.90-identifier-migration/`; Swift/Rust module names, `skills-copilot-service`, AX ids, env vars, and legacy Keychain service remain stable.
- V2.91 model-task matching history: `llm.listModelTaskMatches`,
  `llm.recordModelTaskMatch`, `llm.deleteModelTaskMatch`,
  redacted `model-task-matches.json`, Provider Observability
  `model_task_history_rows`, and no provider/default-write/script/credential/
  cloud/telemetry expansion.
- V2.92 Codex expanded roots: `RootSource::Compatibility`,
  `RootSource::Admin`, `RootSource::Plugin`, `$CODEX_HOME/skills`,
  local plugin marketplace roots, `/etc/codex/skills`, project
  `.codex/config.toml` diagnostics, and a native `.agents/skills`
  write allowlist; no plugin/admin/system/compat write expansion.
- V2.93 opencode custom roots: `RootSource::Configured`, JSON/JSONC
  `skills.paths` local directory scanning, configured-root
  canonicalization/dedupe, opencode configured provenance labels, and
  `skills.urls` metadata-only/no-fetch boundary; installs remain native-root
  only.
- V2.94 Pi install/compat writes: `RootSource::Compatibility` for Pi
  `.agents/skills`, guarded native/compat Pi settings toggles, and native-root
  installs; package install/remove and `.agents` direct installs remain blocked.
- V2.95 Hermes native install: `skill.install` can copy confirmed local
  ToolGlobal `SKILL.md` records into `~/.hermes/skills`; Hermes project
  installs, config toggles, external_dirs writes, hub/URL/tap/update/uninstall/
  reset operations, scripts, credentials, cloud sync, telemetry, and
  uncontrolled network fetch remain blocked.
- V2.94 Pi install and compatibility writes: `RootSource::Compatibility` for
  Pi `.agents/skills`, guarded native/compat toggles through Pi settings,
  native-root tool-global installs to `~/.pi/agent/skills` and project
  `.pi/skills`, project trust gating, and package install/remove plus
  `.agents` direct installs remain blocked.
