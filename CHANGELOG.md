# Changelog

This file tracks release-readiness notes for adapter behavior, risk, validation, and deferred blockers. It is a manual tracking document, not a public release artifact log.

Use it for externally meaningful changes and release-risk summaries. Do not use it
as the active task queue; current implementation work belongs in
`docs/development-tasks.md`, and version planning belongs in `docs/roadmap.md`.

Current usage:

- Active as a release-readiness / risk log.
- Not a replacement for `docs/v2.*-verification-checklist.md`.
- Not every internal refactor needs an entry unless it changes release risk,
  validation posture, adapter behavior, or public-facing capability claims.

Current release-readiness guardrails:

- V2.1-V2.96 are the synchronized completed baseline.
- Real local validation evidence is version-specific. Use the matching verification checklist for exact screenshots, blockers, and commands.
- Fixture smoke screenshots still do not replace required real local validation for user-visible changes.
- Tool-global import/export/install is integrated. Local directory import writes only app-controlled staging/catalog, export creates reproducible local bundles, and confirmed install routes through verified write paths.
- Opencode support includes native roots, official compatibility roots, and configured local `skills.paths` roots. Writable support remains guarded and limited to verified managed `permission.skill` behavior; install targets remain native roots.
- Pi production writes are guarded: native and `.agents/skills` compatibility toggles use Pi settings with trust/snapshot checks, and tool-global install targets are limited to native `~/.pi/agent/skills` / project `.pi/skills`; Pi package install/remove and `.agents` direct skill-file installs remain blocked.
- Hermes native-root install is supported for confirmed local ToolGlobal `SKILL.md` copies into `~/.hermes/skills`; Hermes config toggles, project installs, external_dirs writes, hub/URL/tap/update/uninstall/reset, and network-backed operations remain blocked.
- OpenClaw native/workspace install is supported for confirmed local ToolGlobal `SKILL.md` copies into `~/.openclaw/skills` and confirmed workspace `<workspace>/skills`; `.agents` direct installs, config toggles, `skills.entries` writes, ClawHub, Git, update, verify, workshop, and network-backed operations remain blocked.
- No cloud sync, accounts, telemetry, anonymous crash reports, or uncontrolled outbound network calls.
- Signing, notarization, DMG/ZIP packaging, updater work, and release artifact automation are deferred until public release work resumes.

## V2 Adapter Impact Log

Entries are ordered newest first. Add new version entries directly below this
heading.

### Unreleased - Agent Workspace IA adjustment

Product changes:

- Removed the user-facing Lineup surface from the current app IA.
- Replaced standalone sidebar work entries for Agent Profile and Task Preflight
  with a default selected Agent Workspace row at the top of the sidebar.
- Moved the agent selector into the right side of the selected Agent Workspace
  sidebar row and removed the duplicate selector from the detail page.
- Merged Choose Project and Recent Projects into one project menu in the
  Project sidebar title row, with project actions kept beside it.
- Reworked Agent Profile metrics into a white agent summary container with
  the selected agent icon/name and aligned metric cells.
- The Agent Workspace detail page now orders Agent Profile, Adapter
  capability, Task Preflight, MCP Sources, and final Local Report Export.
- Adapter capability/diagnostic presentation now lives only inside the Agent
  Workspace detail page instead of being duplicated in the sidebar.
- The sidebar Work section has been removed; Provider Observability moved to
  Settings with Dashboard and Logs tabs.
- Guided Cleanup, Validation Workbench, Skill Map, and global Review are
  retired from the current user-facing app IA; selected-skill Review remains in
  the skill detail switcher.
- Local Report Export moved from the sidebar skill-list controls into the Agent
  Workspace detail page, uses the current agent/filter scope without silently
  narrowing to a previously selected skill, and exposes Open, Reveal in Finder,
  and Copy Path actions after export.
- Safe Batch changed from a persistent sidebar card to a skill-list Batch
  button with a multi-select sheet; it still previews selected current-list
  skills first and applies only after explicit confirmation.
- Provider Observability now defaults to a chart-first dashboard for call
  status, model token use, destination cost, model latency, and model-task fit;
  the Logs tab supports status, provider, model, destination, issue-only, and
  search filtering over detailed evidence rows.
- UI polish pass aligned the Task Preflight icon/copy with a preflight mental
  model, renamed the MCP preview surface to MCP Sources in the app UI, and
  tightened Settings log filters into labeled menu controls.
- Selected-skill Intelligent Analysis now renders copy-only provider output as
  pane-friendly Markdown: compact previews fold tables, detail views recover
  collapsed historical Markdown and render long quality-score tables as cards,
  and prompt instructions ask providers for section/bullet output instead of
  wide tables or whole-answer code fences.

Risk/security notes:

- UI routing only; no service protocol, provider, write, script, credential,
  cloud sync, telemetry, signing, packaging, or release automation expansion.
- Provider output remains untrusted and copy-only; the rendering change does
  not add write-back, script execution, raw prompt/response persistence, or
  automatic application of LLM recommendations.

### V2.96 - 2026-06-18

Status:

- Complete.
- OpenClaw native/workspace install completed within an install-only,
  evidence-backed slice.

Adapter behavior changes:

- `skill.install` can now copy a confirmed local ToolGlobal `SKILL.md` into
  OpenClaw native `~/.openclaw/skills/<name>/SKILL.md`.
- `skill.install` can also copy into confirmed OpenClaw workspace
  `<workspace>/skills/<name>/SKILL.md` when the selected project is the
  confirmed workspace or inside it.
- OpenClaw capability status is now `install-only` with
  `verified-native-workspace-v2.96` install and `install-only-v2.96` writable
  status.

Product/protocol changes:

- Updated adapter capability fixtures and command tests to expose OpenClaw
  native/workspace install support.
- Hardened OpenClaw workspace path matching for canonical macOS paths.
- No service protocol method count changed; `SUPPORTED_METHODS` remains 93.

Risk/security notes:

- OpenClaw `.agents` roots remain scan-only and are not direct install
  targets.
- OpenClaw config toggles, `skills.entries` writes, ClawHub, Git, update,
  verify, workshop, and network-backed operations remain blocked.
- No provider request, credential read, raw prompt/response/trace persistence,
  script execution, cloud sync, telemetry, signing, notarization, DMG, ZIP, or
  release automation was added.

Validation posture:

- Closeout evidence is tracked in
  [`docs/v2.96-verification-checklist.md`](docs/v2.96-verification-checklist.md).

### V2.95 - 2026-06-18

Status:

- Complete.
- Hermes native-root install completed within an install-only, evidence-backed
  slice.

Adapter behavior changes:

- `skill.install` can now copy a confirmed local ToolGlobal `SKILL.md` into
  Hermes native `~/.hermes/skills/<name>/SKILL.md`.
- Hermes capability status is now `install-only` with
  `verified-native-root-v2.95` install and `install-only-v2.95` writable
  status.
- Hermes active/profile home scanning and explicit `skills.external_dirs`
  read-only external roots remain unchanged.

Product/protocol changes:

- Updated adapter capability fixtures and service tests to expose Hermes
  native-root install support.
- No service protocol method count changed; `SUPPORTED_METHODS` remains 93.

Risk/security notes:

- Hermes config toggles, per-platform enablement writes, project installs,
  `skills.external_dirs` writes, hub / URL / tap / update / uninstall / reset
  operations, and uncontrolled network fetch remain blocked.
- Hermes cron jobs remain evidence-only and are not mapped to `SkillInstance`.
- No provider request, credential read, raw prompt/response/trace persistence,
  script execution, cloud sync, telemetry, signing, notarization, DMG, ZIP, or
  release automation was added.

Validation posture:

- Closeout evidence is tracked in
  `docs/v2.95-verification-checklist.md`.
- App-window evidence is tracked in
  `docs/ui-artifacts/v2.95-hermes-native-install/`.

### V2.94 - 2026-06-18

Status:

- Complete.
- Pi install and compatibility-root writes completed within a guarded,
  evidence-backed slice.

Adapter behavior changes:

- Pi now scans global/project `.agents/skills` compatibility roots as
  `RootSource::Compatibility` in addition to native `~/.pi/agent/skills` and
  project `.pi/skills`.
- Pi toggles can disable/re-enable native and `.agents` compatibility skill
  instances through Pi settings JSON with snapshot/read-back/rollback behavior.
- Project compatibility toggles write through project `.pi/settings.json` and
  require `project.trusted`.
- Tool-global install now supports Pi native roots only:
  `~/.pi/agent/skills` and project `.pi/skills`.

Product/protocol changes:

- Updated adapter capability fixtures and fixture smoke to expose Pi native
  install and compatibility-root toggles.
- No service protocol method count changed; `SUPPORTED_METHODS` remains 93.

Risk/security notes:

- Pi package install/remove remains blocked.
- `.agents/skills` compatibility roots are scan/toggleable but are not direct
  install targets.
- Direct root `.md` files remain filtered for Pi to avoid ordinary resource
  document noise.
- No provider request, credential read, raw prompt/response/trace persistence,
  script execution, cloud sync, telemetry, uncontrolled network fetch, signing,
  notarization, DMG, ZIP, or release automation was added.

Validation posture:

- Focused Pi adapter, scanner, commands, service fixture, protocol drift, docs
  gate, gate parity, and privacy checks are tracked in
  `docs/v2.94-verification-checklist.md`.
- V2.94 app-window evidence notes are under
  `docs/ui-artifacts/v2.94-pi-install-compat-writes/`; current capture is
  recorded behind canonical `locked-session` if the local session is locked.

Near-term follow-up plan:

- V2.95 later completed Hermes native-root install; V2.96 covers OpenClaw
  writable/install.

### V2.93 - 2026-06-17

Status:

- Complete.
- opencode custom roots completed for local `skills.paths`; `skills.urls`
  remains metadata-only with no default network fetch.

Adapter behavior changes:

- opencode now reads JSON/JSONC `skills.paths` from declared user/project
  config paths and exposes local directories as `RootSource::Configured`.
- Configured local paths are canonicalized/deduped before scanning; project
  config paths that resolve outside the active project are not added.
- Configured roots are scan/read sources only for skill files; install targets
  remain native `~/.config/opencode/skills` and project `.opencode/skills`.
- `skills.urls` is recognized as a config boundary but is not fetched during
  scan or diagnostics.

Product/protocol changes:

- Added opencode configured provenance labels in the macOS model/detail display.
- Updated adapter capability fixtures and service diagnostics tests.
- No service protocol method count changed; `SUPPORTED_METHODS` remains 93.

Risk/security notes:

- No uncontrolled outbound network call was added.
- No credential reads, raw prompt/response/trace persistence, script execution,
  cloud sync, telemetry, signing, notarization, DMG, ZIP, or release automation
  was added.
- opencode config writes still use exact managed `permission.skill` overrides
  with existing snapshot/rollback behavior and preserve unrelated config such as
  `skills.paths`.

Validation posture:

- Focused opencode adapter, scanner, commands, service diagnostics, Swift model,
  service protocol fixture, and protocol drift checks passed.
- V2.93 docs gate, gate parity, UI evidence blocker, and privacy gate are
  tracked in `docs/v2.93-verification-checklist.md`.
- V2.93 app-window evidence notes are under
  `docs/ui-artifacts/v2.93-opencode-custom-roots/`; current capture failed
  closed with canonical `locked-session`.

Near-term follow-up plan:

- V2.94 later completed Pi install and compatibility writes.
- V2.95 later completed Hermes native-root install; V2.96 covers OpenClaw
  writable/install.

### V2.92 - 2026-06-17

Status:

- Complete.
- Codex expanded roots completed as a read-only diagnostics and native-root
  write-allowlist slice.

Adapter behavior changes:

- Codex now scans/diagnoses `$CODEX_HOME/skills`, local plugin marketplace
  skill roots, and `/etc/codex/skills` when present.
- Codex diagnostics include project `.codex/config.toml`.
- Codex toggle writes remain limited to native user/project `.agents/skills`
  instances through the user `config.toml` `[[skills.config]]` override.
- Project config, compatibility-root, plugin, admin, and system root writes
  remain blocked.

Product/protocol changes:

- Added `RootSource::Compatibility`, `RootSource::Admin`,
  `RootSource::Plugin`, and `RootSource::System` for adapter provenance.
- Updated adapter capability and diagnostics explanations for Codex expanded
  roots.
- No service protocol method count changed; `SUPPORTED_METHODS` remains 93.

Risk/security notes:

- Local plugin marketplace parsing accepts only local in-root plugin paths and
  skips escaping or remote sources.
- Expanded roots are scan-only and do not run plugin hooks, MCP servers,
  installers, scripts, provider calls, or network fetches.
- No credential reads, raw prompt/response/trace persistence, skill file
  mutation, cloud sync, telemetry, signing, notarization, DMG, or ZIP work was
  added.

Validation posture:

- Focused Codex adapter and commands tests passed.
- V2.92 docs gate, service protocol drift, gate parity, screenshot artifact
  verification, and privacy gate passed.
- V2.92 app-window evidence is under
  `docs/ui-artifacts/v2.92-codex-expanded-roots/`.
- `pnpm check:macos` passed.
- `pnpm check:privacy` passed.

Near-term follow-up plan:

- V2.93 later completed opencode configured local `skills.paths` scanning while
  keeping `skills.urls` metadata-only/no-fetch.
- V2.94 later completed Pi install/compat writes, V2.95 later completed Hermes
  native-root install, and V2.96 later completed OpenClaw native/workspace
  install.

### V2.91 - 2026-06-17

Status:

- Complete.
- Model-task matching history completed as a local evidence-domain slice.

Adapter behavior changes:

- No adapter scan roots, writable scopes, install scopes, or config schemas changed.
- Codex expanded-root diagnostics completed in V2.92; opencode configured local
  roots completed in V2.93; Pi install/compat writes completed in V2.94;
  Hermes native-root install later completed in V2.95, and OpenClaw
  native/workspace install later completed in V2.96.

Product/protocol changes:

- Added `llm.listModelTaskMatches`, `llm.recordModelTaskMatch`, and
  `llm.deleteModelTaskMatch`.
- Added app-local redacted `model-task-matches.json` metadata for historical
  model/task fit.
- Extended Provider Observability with read-only `model_task_history_rows`.
- Added protocol request/response fixtures and Swift/Rust decode tests.

Risk/security notes:

- V2.91 record/delete methods only mutate app-local redacted metadata.
- The V2.91 native UI exposes read-only history rows and no write/delete controls.
- No provider default calls, hidden apply paths, product script execution,
  credential reads, raw prompt/response/trace persistence, skill file mutation,
  agent config mutation, snapshots, triage mutation, cloud sync, telemetry,
  signing, notarization, DMG, or ZIP work was added.

Validation posture:

- Focused Rust model-task history tests passed.
- Service protocol fixture decode and dispatch coverage passed.
- `swift test --package-path apps/macos` passed.
- V2.91 app-window evidence is under
  `docs/ui-artifacts/v2.91-model-task-history/`.
- `pnpm check:macos` passed.
- `pnpm check:privacy` passed.

Near-term follow-up plan:

- V2.92 completed Codex expanded roots/project config/plugin/admin/system-root
  read-only diagnostics.
- V2.93 later completed opencode custom local roots; V2.94 later completed Pi
  install/compat writes; V2.95 later completed Hermes native-root install; and
  V2.96 later completed OpenClaw native/workspace install.

### V2.90 - 2026-06-17

Status:

- Complete.
- Agent Copilot internal identifier migration completed as a compatibility-first slice.

Adapter behavior changes:

- No adapter scan roots, writable scopes, install scopes, or config schemas changed.
- `SKILLS_COPILOT_*` environment variables remain supported.

Product/protocol changes:

- Primary packaged app changed to `dist/AgentCopilot.app`.
- `CFBundleName` and `CFBundleExecutable` are now `AgentCopilot`.
- Primary bundle id and service default app-data id changed to
  `dev.agent-copilot.native`.
- Legacy app-data id `dev.skills-copilot.native` is retained as a migration
  source and compatibility boundary.
- Existing legacy app data is copied to the new default directory when the new
  directory is absent; the legacy directory is not deleted.
- Added migration marker `agent-copilot-app-data-migration.json`.
- No service protocol method, payload, or protocol version changed.

Risk/security notes:

- Swift package/product/target/module names remain `SkillsCopilot`.
- Rust crate names remain `skills-copilot-*`.
- Sidecar binary remains `skills-copilot-service`.
- AX identifiers remain `skills-copilot.*`.
- Keychain service remains `dev.skills-copilot.native.llm`; V2.90 does not copy
  or duplicate credentials.
- No provider default calls, hidden write/apply paths, product script execution,
  credential copies, raw prompt/response/trace persistence, cloud sync,
  telemetry, signing, notarization, DMG, or ZIP work was added.

Validation posture:

- Focused Rust app-data migration tests passed.
- `swift test --package-path apps/macos` passed.
- `./script/build_and_run.sh --verify` launched and verified
  `dist/AgentCopilot.app`.
- `pnpm smoke:macos-app -- --fixture-data --capture-window` launched
  `AgentCopilot` and passed.
- V2.90 app-window evidence is under
  `docs/ui-artifacts/v2.90-identifier-migration/`.
- `pnpm check:macos` passed.
- `pnpm check:privacy` passed.

Near-term follow-up plan:

- V2.91 covers model-task matching history as a new evidence domain.
- At the time, V2.92-V2.96 were planned for Codex/opencode/Pi/Hermes/OpenClaw
  adapter unblock slices; V2.92-V2.96 are now complete, with Hermes and
  OpenClaw config/network expansions still requiring separate evidence gates.

### V2.89 - 2026-06-17

Status:

- Complete.
- Agent Copilot brand asset refresh completed.

Adapter behavior changes:

- No adapter scan roots, writable scopes, install scopes, or config schemas changed.
- No internal bundle/module/AX/app-data identifier migration; V2.90 still owns that work.

Product/protocol changes:

- Added `AppIcon.svg` as the reviewable Agent Copilot display brand icon source.
- Regenerated `AppIcon.icns` for the bundled macOS app icon.
- Added `script/generate_app_icon.sh` and `pnpm generate:app-icon` for manual local regeneration.
- No service protocol method, payload, or protocol version changed.

Risk/security notes:

- The asset refresh is visual-only and build-time only.
- Internal `SkillsCopilot` / `skills-copilot` identifiers, `dist/SkillsCopilot.app`, `APP_NAME`, `BUNDLE_ID`, Swift module names, and AX ids remain unchanged.
- No provider default calls, write/apply paths, product script execution, credential reads, raw prompt/response/trace persistence, cloud sync, telemetry, signing, notarization, DMG, or ZIP work was added.

Validation posture:

- `pnpm generate:app-icon` regenerated `AppIcon.icns` from `AppIcon.svg`.
- `pnpm check:macos` passed after the asset refresh.
- V2.89 app-window evidence is under `docs/ui-artifacts/v2.89-brand-assets/`.
- `pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.89-brand-assets` passed.
- `pnpm check:privacy` passed.

Near-term follow-up plan:

- V2.90 covers internal identifier migration with data/validation migration.
- V2.91 covers model-task matching history as a new evidence domain.
- At the time, V2.92-V2.96 were planned for Codex/opencode/Pi/Hermes/OpenClaw adapter unblock slices; V2.92-V2.96 are now complete, with Hermes and OpenClaw config/network expansions still requiring separate evidence gates.

### V2.88 - 2026-06-17

Status:

- Complete.
- Handoff and per-surface Agent Copilot evidence closeout completed.

Adapter behavior changes:

- No adapter scan roots, writable scopes, install scopes, or config schemas changed.
- Pi install/compatibility-root writes later completed in V2.94; Hermes native-root install later completed in V2.95 while config toggles remain blocked; OpenClaw native/workspace install later completed in V2.96 while config/network operations remain blocked; opencode custom local roots completed in V2.93 with `skills.urls` metadata-only/no-fetch.

Product/protocol changes:

- No product feature expansion beyond V2.87 evidence closeout and docs/gate synchronization.
- Added V2.87 and V2.88 verification checklist gates to `pnpm verify:gate-parity`.
- Captured per-surface app-window evidence for Lineup, Agent Profile, Local Session Preview, and MCP Preview.

Risk/security notes:

- Authorized Local Session and MCP preview checks used disposable `/tmp/ac-v288` fixtures only.
- Local Session Preview remained explicit-authorized, read-only, and redacted.
- MCP Preview returned server metadata, args count, env-key count, and evidence refs; it did not return env values or raw config content.
- No provider default calls, write/apply paths, script execution, credential reads, raw prompt/response/trace persistence, cloud sync, telemetry, signing, notarization, DMG, or ZIP work was added.

Validation posture:

- `pnpm check:macos` passed in an unlocked interactive session.
- Computer Use resolved the current workspace `dist/SkillsCopilot.app` window.
- V2.88 screenshots are under `docs/ui-artifacts/v2.88-handoff-evidence/`.
- `pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.88-handoff-evidence` passed.
- `pnpm check:privacy` passed.

Near-term follow-up plan:

- V2.89 covers brand assets.
- V2.90 covers internal identifier migration with data/validation migration.
- V2.91 covers model-task matching history as a new evidence domain.
- At the time, V2.92-V2.96 were planned for Codex/opencode/Pi/Hermes/OpenClaw adapter unblock slices; V2.92-V2.96 are now complete, with Hermes and OpenClaw config/network expansions still requiring separate evidence gates.

### V2.87 - 2026-06-17

Status:

- Complete.
- Agent Copilot first implementation pass with unlocked macOS app-window evidence.

Adapter behavior changes:

- No adapter scan roots, writable scopes, install scopes, or config schemas changed.
- Display-level product name is Agent Copilot; internal bundle/module/AX/app-data identifiers remain `SkillsCopilot` / `skills-copilot`.

Product/protocol changes:

- Added the Lineup default surface, Agent Profile surface, and sorted read-only decision queue.
- Added default-off `session.previewLocalSessions` for explicitly authorized local session directories.
- Added default-off `evidence.previewMcpServers` for explicitly authorized MCP JSON config files.
- Service protocol support increased to 90 methods with request/response fixtures and drift verification.

Risk/security notes:

- New Agent Copilot surfaces remain read-only local evidence previews.
- Local session preview returns redacted metadata/excerpts/evidence refs only and does not persist raw transcripts or create trace/review records.
- MCP server preview returns redacted server metadata plus args/env-key counts only and does not return env values or raw config content.
- No provider default calls, write/apply paths, script execution, credential reads, raw prompt/response/trace persistence, cloud sync, telemetry, signing, notarization, DMG, or ZIP work was added.

Validation posture:

- 2026-06-17 unlocked `pnpm check:macos` passed end to end.
- `./script/build_and_run.sh --verify` launched `dist/SkillsCopilot.app`.
- Fixture-data smoke captured full app-window evidence at `docs/ui-artifacts/native-macos-shell/completed.png`.
- `pnpm verify:gate-parity` and `pnpm check:privacy` passed.

Near-term follow-up plan:

- V2.88 closes staging/per-surface evidence.
- V2.89 covers brand assets.
- V2.90 covers internal identifier migration with data/validation migration.
- V2.91 covers model-task matching history as a new evidence domain.
- At the time, V2.92-V2.96 were planned for Codex/opencode/Pi/Hermes/OpenClaw adapter unblock slices; V2.92-V2.96 are now complete, with Hermes and OpenClaw config/network expansions still requiring separate evidence gates.

### 2026-06-16 Review Remediation

Status:

- Complete as a post-V2.86 remediation pass, not a new public release version.

Adapter behavior changes:

- Shared adapter parser helpers were extracted for YAML frontmatter, required
  strings, kebab-case skill names, and stable path ids.
- Adapter scan roots, writable support, install support, and config schemas did
  not change.

Risk/security notes:

- Catalog refreshes are transaction-protected.
- Persisted LLM draft output now uses the strong redaction path and high-entropy
  secret detection before storage.
- Blocked script-execution audit writes are confined to the app audit root.
- Swift stdio service calls have bounded timeout/decode/error coverage.
- CI now includes `cargo audit` and Rust API docs; `verify:gate-parity`
  includes `.mjs` syntax verification, Rust doc generation, module-size,
  and benchmark trend verification.
- V2.73-V2.86 docs verification now uses one consolidated
  `verify-version-validation-docs.mjs` implementation behind the existing
  per-version pnpm aliases.
- Dedicated benchmark commands now cover task readiness, routing confidence,
  and knowledge search, with measured baselines in `docs/benchmark-trends.md`.

Validation posture:

- Structure work continued without adding service protocol methods, provider
  default calls, script execution, cloud sync, telemetry, signing, notarization,
  DMG, or ZIP work.
- DetailView section splitting was already below the target size and remains
  covered by existing split view files.
- `crates/commands/src/lib.rs` is below the default 5k module-size gate with no
  legacy exception; catalog query/refresh/mapping logic is split out of
  `crates/catalog/src/lib.rs`; `ServiceClient` RPC methods are split into domain
  extension files behind the existing shared decode/error path; and `SkillStore`
  read-only selectors/navigation actions are split without widening state write
  access.

### V2.86 - 2026-06-16

Status:

- Complete.
- Refactor-only module split closeout plus validation-gate hardening.

Adapter behavior changes:

- No adapter scan roots, parser semantics, writable scope, install scope, or config schema changed.
- Service protocol method names and payload shapes remain unchanged.

Risk/security notes:

- Swift Detail sections were split out of `DetailView.swift`.
- Rust service RPC handling, helpers, and tests were split into smaller files.
- `pnpm verify:module-size` now enforces the single-file <= 5000-line target
  for split service/test/Detail files.
- No provider default calls, write/apply path, hidden task state,
  scanner/catalog fact mutation, script execution, credential reads,
  raw prompt/response/trace persistence, cloud sync, telemetry, signing,
  notarization, DMG, or ZIP work was added.

Validation run:

- `cargo test --workspace` passed.
- `cargo clippy --workspace --all-targets --all-features -- -D warnings` passed.
- `swift test --package-path apps/macos` passed.
- `pnpm verify:gate-parity` passed.
- `pnpm check:privacy` passed.
- `pnpm check:macos` passed, including fixture smoke app-window capture and screenshot artifact verification.

Deferred blockers:

- No V2.86-specific blocker remains.
- Public release packaging/signing/notarization remains deferred.

### V2.10 - 2026-06-09

Status:

- Complete / real local validation passed for the current mainline app.
- V2.10 remains a skill execution safety-boundary release, not a completed script runner release.

Adapter behavior changes:

- No adapter scan root, writable-toggle, or config-path behavior changed during the real local validation closeout.
- Native macOS validation exercised Claude Code, Codex, read-only opencode,
  findings, conflicts, snapshots, project context, LLM disabled state,
  and script safety preview surfaces against the real local environment.

Risk/security notes:

- `script.previewExecution` and `script.execute` remain default-deny /
  intent-boundary methods. No real sandbox runner, stdout/stderr capture,
  successful execution output log, or public execution API is claimed.
- Real catalog data contained no structured script command records during the pass.
  The script preview UI reached a safe missing-command preview-only state and did not execute.
  Service tests remain the evidence for command/cwd/env/network/files preview contracts.
- `mcp__computer_use.get_app_state` resolved the app window, but click returned
  an activation error. UI operation used macOS AX/System Events clicks with
  Computer Use state read-back after each step.

Validation run:

- `pnpm check:macos` passed on 2026-06-09.
- Launched `<repo>/dist/SkillsCopilot.app` against the real local `HOME`, app data, Claude config, Codex roots, and opencode roots.
- Operated scan-all, findings severity filter, conflicts, snapshot preview, Codex/opencode agent filters, project context set/clear, opencode read-only disabled toggle, LLM disabled controls, and V2.10 script safety preview.
- App-window-only evidence captured at `docs/ui-artifacts/native-macos-shell/real-local-computer-use-2026-06-09.png`.

Deferred blockers:

- Future candidate changes must rerun real local Computer Use validation.
- Real sandbox runner, interpreter allowlist, stdout/stderr policy, resource limits, signed public distribution, GitHub clone import, opencode writable install, and script-file install remain deferred.

### V2.9 - 2026-06-09

Status:

- Complete / automated validation passed.
- Native macOS UI/model supports tool-global read-only preview and confirm-before-install expression.
- Rust service supports `catalog.importSkill`, `skill.exportBundle`, and `skill.install`.

Adapter behavior changes:

- Tool-global rows enter catalog as `agent = tool-global`, `scope = tool-global` and remain separate from adapter scan/missing sweeps.
- Local directory import copies skill content into app-controlled `tool-global/skills` staging, then refreshes rule findings/conflicts.
- Export produces directory-form bundles with reproducible `manifest.json` metadata and path-relative `skill/SKILL.md`.
- Reimport validation recomputes fingerprint and preserves manifest metadata.
- Tool-global rows are displayed as read-only previews in the native sidebar and detail header.
- Enable/Disable toggle is disabled for `scope = tool-global` with copy/install-specific disabled reason text.
- Detail overview shows an install preview affordance with target agent selection, target path/risk display, and confirmed install action.
- Swift service client uses `skill.install` with `confirmed=false/true` and falls back to local preview only for older services without install support.
- Confirmed install supports Claude/Codex verified skill roots; opencode remains read-only and unsupported for install.

Risk/security notes:

- Import writes only app-controlled staging and catalog records; it does not write agent config.
- GitHub repo import is explicitly deferred and returns a stable unsupported error without clone/network writes.
- Confirmed install requires target agent/scope/path confirmation, creates pre-install audit snapshots, uses lock/atomic write/read-back verification, and rescans the target adapter.
- Tool-global staging remains app-controlled and is not confused with scanned agent-global or project-local roots.

Validation run:

- `cargo test -p skills-copilot-commands -p skills-copilot-service` passed during integration.
- `swift test --package-path apps/macos` passed.
- `pnpm check:macos` passed.

Deferred blockers:

- GitHub clone/import remains deferred; users must provide a local source path after any explicit clone/unpack.
- Signed/zipped/public distribution of exported bundles remains out of scope.
- Script file install is limited by current scanner/model support; V2.9 copies `SKILL.md`.
- Future real local Computer Use reruns for later user-visible changes.

### V2.8 - 2026-06-08

Status:

- Complete / automated validation passed.
- Completed the five governance remediation targets and seven new local rules: `frontmatter.tools-not-empty`, `permissions.network-declared`, `permissions.exec-needs-human`, `name.canonical-case`, `script.no-shebang`, `body.too-long`, and `dependency.unknown`.
- Real local Computer Use was pending for the V2.8 closeout; the current mainline app later passed the real local validation pass on 2026-06-09.

Adapter behavior changes:

- Added local rule coverage for non-empty declared tools, declared network permissions, human confirmation for exec permissions, canonical skill-name casing, script shebang avoidance, oversized body detection, and unknown dependency detection.
- Kept LLM status protocol compatibility so older and newer status payload readers remain tolerant during the V2.8 transition.
- Kept permissions roundtrip coverage for V2.8 rules so normalized permission fields do not silently drop raw or unknown-safe data.
- Kept explicit severity ordering so rule output, grouping, and display use one stable order.
- Kept findings filtering/grouping UI for severity, rule, and agent dimensions.
- Kept `app.stateSnapshot`-based refresh optimization so unchanged app state does not force unnecessary UI refresh work.

Risk/security notes:

- Permissions remain unknown-safe: unverified fields must display as unknown/raw and must not be inferred as safe or unsafe.
- Findings filtering must not hide high-severity results by default or make grouped counts disagree with the underlying rule output.
- Refresh optimization must not reuse stale findings, stale permission state, or stale selected details after scan, filter, project-context, or adapter-state changes.

Validation run:

- Worker focused checks passed for catalog, Swift UI/model, layout, docs, and `git diff --check`.
- Coordinator integration ran `swift test --package-path apps/macos`, `cargo test -p skills-copilot-catalog`, `pnpm verify:macos-ui-layout`, `git diff --check`, stale-claim searches, and full `pnpm check:macos`; all passed. Final mainline closeout validation passed again on 2026-06-09.
- Fixture Smoke App Run refreshed the app-window screenshot during validation; the generated screenshot diff was restored and not committed as release evidence.
- Docs closeout gate kept stale wording checks for provider/client/network/key storage completion claims, Computer Use completion claims, and old open-milestone claims, with `git diff --check` clean before the V2.8 milestone was marked integrated.

Deferred blockers:

- V2.8 itself closed before the later 2026-06-09 real local validation pass; future changes still require a fresh real local pass.
- Next implementation direction is V2.10: Skill execution and script safety, plus release-gate follow-through and remaining adapter evidence work.

### V2.7 - 2026-06-08

Status:

- Complete; disabled-by-default service/UI gate and prepare/estimate path integrated.
- Real local Computer Use validation was pending at V2.7 closeout; the current mainline app later passed on 2026-06-09.

Adapter behavior changes:

- No adapter scan root, parser, catalog attribution, or toggle behavior changed.
- V2.7 LLM local assist scope is disabled-by-default service/UI gate plus request prepare/estimate for Analyze, Recommend, conflict explanation, and draft frontmatter.
- Real provider clients, provider network calls, and credential storage are not claimed in this stage.

Risk/security notes:

- Current stage must not save credentials. Future macOS storage must prefer Keychain; fallback `~/.config/skills-copilot/llm.yaml` must be permission-checked as `0600`.
- Credentials, prompts, responses, token/cost estimates, and API keys must not be written to SQLite, project directories, logs, crash reports, or smoke fixtures.
- Draft frontmatter is display/copy-only. There is no Apply/Write path from LLM output; real writes must use the normal user edit/save flow and Rust service validation.
- LLM features remain default-off and user-triggered; prepare/estimate must show provider, model, token/cost estimate, budget status, and disabled/unconfigured reason before any future provider call.

Validation run:

- `cargo test -p skills-copilot-service` passed.
- `swift test --package-path apps/macos` passed after service/UI payload integration.
- `pnpm verify:macos-ui-layout` passed.
- `git diff --check` passed; stale-claim searches for provider/client/network/credential completion wording stayed clean at closeout.
- Coordinator closeout ran full `pnpm check:macos`; it passed and covered Rust fmt/test/clippy, native list model, native layout guard, SwiftPM tests/build, local app launch verify, and fixture smoke app run.

Deferred blockers:

- V2.7 closed before the later 2026-06-09 current-mainline real local pass.
- Actual provider client, network call, Keychain/fallback credential storage, and response rendering remain future work.
- Next development milestone is V2.8 Rules and Permissions Governance.

### V2.6 - 2026-06-08

Status:

- Complete; docs-only release readiness completed.
- Real local Computer Use validation was pending at V2.6 closeout; the current mainline app later passed on 2026-06-09.

Adapter behavior changes:

- No runtime adapter behavior changed in this milestone.
- Added manual release-readiness checklist coverage for current local candidate validation, fixture smoke isolation, real local Computer Use follow-up, and current artifact boundary.
- Added changelog tracking fields for future adapter behavior changes, risk/security notes, validation runs, and deferred blockers.

Risk/security notes:

- Reaffirmed that the only current local candidate artifact boundary is `dist/SkillsCopilot.app`.
- Signing, notarization, stapling, DMG/ZIP packaging, updater work, checksums, public download, and release artifact automation remain deferred.
- Release-readiness evidence must not claim fixture smoke screenshots as real local validation, and must not touch real user Claude, Codex, or opencode config during fixture smoke.

Validation run:

- Worker closeout ran `git diff --check` on docs-only branches and searched for incorrect claims that formal distribution automation already exists.
- Coordinator integration must rerun docs whitespace/stale-claim checks after merge.
- Full `pnpm check:macos` was not required for worker docs-only changes; run it for milestone closeout if the coordinator treats the docs milestone as requiring the full local gate.

Deferred blockers:

- Real local app Computer Use validation for V2.2-V2.6 behavior.
- Public release work: signing, notarization, DMG/ZIP packaging, updater work, checksums, public download, and artifact automation.

### V2.5 - 2026-06-08

Status:

- Complete; automated validation passed.
- Real local Computer Use validation was pending at V2.5 closeout; the current mainline app later passed on 2026-06-09.

Adapter behavior changes:

- Hardened scanner override isolation for fixture roots, extra roots, project-context overrides, and adapter native roots.
- Kept Claude Code, Codex, and read-only opencode behavior within the existing supported boundaries.
- Tightened UI/service behavior for stale selection, busy writes, read-only rows, broken rows, missing rows, shadowed rows, and opencode rows so unsupported toggles do not call write APIs.
- Strengthened service fixture typing around supported adapter summaries, opencode read-only rejection, project context payloads, snapshot preview errors, and stable error codes.

Risk/security notes:

- Reconfirmed that writable adapter behavior must use snapshot, file lock, atomic write, read-back verification, rollback handling, and root/permission checks.
- Reinforced that read/preview flows must surface path/root errors and remain read-only.
- Opencode remained read-only; no opencode config creation or modification was introduced.
- Documentation status drift is treated as a release-readiness risk.

Validation run:

- `pnpm check:macos` passed after implementation changes.
- Focused tests covered the audit-hardening items or recorded explicit deferred rationale.
- Docs closeout included stale-status checks and `git diff --check`.
- Real local Computer Use was blocked at V2.5 closeout because macOS/AX could not resolve the visible app window; the current mainline app later passed on 2026-06-09.

Deferred blockers:

- Real local app Computer Use validation for V2.2/V2.3/V2.4/V2.5 behavior.
- Public release work: signing, notarization, DMG/ZIP packaging, updater work, and artifact automation.

### V2.4 - 2026-06-08

Status:

- Complete; automated validation passed.
- Real local Computer Use validation was pending at V2.4 closeout; the current mainline app later passed on 2026-06-09.

Adapter behavior changes:

- Added opencode as the third adapter in read-only mode.
- Scans only opencode native roots: user `~/.config/opencode/skills` and active project `.opencode/skills`.
- Does not scan opencode `.agents/skills` or `.claude/skills` compatibility roots.
- Parses opencode `SKILL.md` frontmatter with required `name` and `description`; directory/name mismatch or missing required metadata becomes broken/malformed catalog data rather than aborting the scan.
- Integrated opencode with `catalog.scanAll`, project context, agent filter/status, and read-only toggle rejection.

Risk/security notes:

- Writable opencode behavior remains blocked until exact `permission.skill` patch, re-enable, wildcard precedence, managed config, and override semantics are verified.
- Read-only support must not create or modify real user opencode config.
- Compatibility roots remain deferred to avoid duplicate catalog pollution and adapter-boundary confusion.

Validation run:

- Smoke fixture uses temporary HOME/project native opencode roots and asserts global/project visibility plus read-only toggle rejection.
- Automated validation passed.
- Fixture smoke screenshots do not replace real local Computer Use validation.

Deferred blockers:

- Disposable local round-trip for writable opencode semantics.
- V2.93 later exposed opencode configured local `skills.paths` roots as read-only; `skills.urls` remains metadata-only/no-fetch pending a future explicit confirmation/cache design.
- Future real local app Computer Use reruns for later candidates.

### V2.3 - 2026-06-08

Status:

- Complete; automated validation passed.
- Real local Computer Use validation was pending at V2.3 closeout; the current mainline app later passed on 2026-06-09.

Adapter behavior changes:

- Hardened Codex user `config.toml` patching for disable/re-enable behavior.
- Disable normalizes only the target absolute `SKILL.md` path entries and writes one `enabled = false` entry.
- Re-enable removes all target path entries and does not write `enabled = true`.
- Preserves comments, unknown keys, non-target tables, non-target skill overrides, and final newline.
- Improved adapter state expression for disabled, broken, missing, shadowed/unknown, skipped-root, and root-error cases.

Risk/security notes:

- Codex writes remain limited to verified user config at `~/.codex/config.toml` / `$CODEX_HOME/config.toml`.
- At the V2.3 boundary, project-local `.codex/config.toml`, `/etc/codex/skills`, `$CODEX_HOME/skills`, plugin/admin/system roots, and other unverified roots remained unsupported. V2.92 later added read-only diagnostics for those expanded roots while keeping writes blocked.
- Added regression coverage for unsafe `CODEX_HOME`, config path canonicalization, project-boundary write checks, and stale catalog selection.

Validation run:

- Focused Codex adapter/config tests passed.
- Focused service/commands tests passed.
- Security regression tests passed.
- `cargo test --workspace` and `pnpm check:macos` passed on 2026-06-08.
- Documentation-only sync validation included stale-status `rg` scans and `git diff --check`.
- Real local Computer Use validation remains blocked by the visible-window issue.

Deferred blockers:

- Real local app validation of project context, scan-all, agent filter, Codex toggle, and Codex restart note.
- Any expansion of Codex roots or project-local writes requires a new evidence pass.

### V2.2 - 2026-06-08

Status:

- Complete; implementation and automated validation passed.
- Real local UI operation remains blocked.

Adapter behavior changes:

- Formalized project context with persisted local app state and environment override support.
- `catalog.scanAll` uses the current effective project context to scope project-local Claude Code and Codex roots.
- No-project mode scans user/global roots only and does not scan project-local Claude/Codex roots or attach results to a stale project.
- Multi-project switching keeps catalog records tied to `project_root`; toggles must match the current safe project context.

Risk/security notes:

- `ProjectContext.current_cwd` and `root_path` must canonicalize, and `current_cwd` must stay inside `root_path`.
- Env overrides are for development/test launch and are not persisted.
- Project context is local app state only; there is no cloud sync, account, telemetry, crash reporting, or remote project memory.
- Codex toggle still writes only user config; project-local Codex config writes remain blocked.

Validation run:

- `cargo test --workspace`, `cargo clippy --workspace --all-targets --all-features`, `swift test --package-path apps/macos`, and `pnpm check:macos` passed on 2026-06-08.
- Fixture project-context smoke scenario covered no-project, set project cwd, scan-all, switch/clear project, catalog ownership, and toggle target isolation.
- `pnpm dev:macos` / `open -n dist/SkillsCopilot.app` launched the real bundle process, but no visible window was available to Computer Use/AX.

Deferred blockers:

- Real local app operation for setting, switching, and clearing project context; scan-all; Codex cwd-to-repo-root behavior; and app-window-only evidence capture.

### V2.1 - 2026-06-08

Status:

- Complete; automated validation passed.
- Real local app validation attempted but blocked.

Adapter behavior changes:

- Stabilized the dual Claude Code/Codex adapter experience.
- `catalog.scanAll` provides per-agent refresh summaries.
- Native macOS UI added agent filter/grouping for All, Claude Code, and Codex.
- List/detail/refresh log expose skill source, scan root, scan counts, failed roots, and adapter-visible state.
- Codex toggle success includes a Codex runtime restart note and does not imply live reload.
- Claude Code scan/list/detail/toggle/settings/snapshot behavior remained in scope for regression protection.

Risk/security notes:

- Filtering changes visible UI state only; it must not mutate catalog data or trigger writes.
- Codex restart note must refer to Codex runtime config reload, not restarting SkillsCopilot.
- No third adapter was added in this slice.
- Codex root scope and write scope did not expand.

Validation run:

- `pnpm check:macos` passed and fixture smoke window evidence was updated.
- `pnpm dev:macos` launched the real local app process, but System Events reported zero SkillsCopilot windows and Computer Use returned `cgWindowNotFound`.

Deferred blockers:

- Real local app validation for scan-all, agent filters, Codex visibility or missing-root state, Claude Code regression, Codex toggle restart note, and app-window-only screenshot.

### V2.0 - 2026-06-08

Status:

- Complete; first Codex adapter implementation slice integrated.
- Real local app Computer Use validation was waived for the slice and remains required for later code changes.

Adapter behavior changes:

- Added Codex as the second real adapter.
- Codex scanning is limited to verified roots: user `$HOME/.agents/skills` and project `.agents/skills` discovered from adapter `project_cwd` upward to `project_root`.
- Codex parser supports `SKILL.md` frontmatter with required `name` and `description`, preserving raw frontmatter and body.
- Malformed Codex skills become broken catalog records rather than aborting the scan.
- Codex user-config writable toggle patches only `~/.codex/config.toml` / `$CODEX_HOME/config.toml` using absolute `SKILL.md` paths in `[[skills.config]]`.
- Re-enable removes matching entries from user config.
- Catalog/service/native UI can distinguish `claude-code` and `codex` records.

Risk/security notes:

- Does not write `<repo>/.codex/config.toml`.
- At this initial boundary, scan support did not include `/etc/codex/skills`, plugin-distributed skills, system/admin roots, or `$CODEX_HOME/skills`. V2.92 later added read-only diagnostics for those roots while keeping writes blocked.
- Does not infer permissions, dependencies, or enablement state from `agents/openai.yaml`, unknown frontmatter fields, or plugin metadata.
- Pi, opencode, Hermes, and OpenClaw were not implemented in this slice.
- Signing, notarization, DMG/ZIP packaging, and release artifact automation were not implemented.

Validation run:

- `cargo test --workspace`, focused adapter/commands tests, service fixtures, and `pnpm check:macos` passed.
- Real macOS Computer Use operation was waived for the V2.0 slice.

Deferred blockers:

- Restore real local Computer Use validation for app-window operation.
- Resolve Codex project-local toggle behavior before any project config write support.
- Decide whether unsupported Codex roots should ever be scanned.

## Future Entry Template

### Vx.y - YYYY-MM-DD

Status:

- Complete / in progress / blocked / deferred.

Adapter behavior changes:

- Added, removed, or changed scan roots.
- Changed parser behavior, malformed-skill handling, catalog attribution, UI state, or toggle semantics.
- Changed writable/read-only support, config paths, snapshots, atomic writes, or rollback behavior.

Risk/security notes:

- Path/root boundary changes.
- Config write, snapshot, lock, read-back, rollback, or permission-model changes.
- Compatibility-root, duplicate-root, stale-selection, project-context, or adapter-isolation risks.
- Privacy/network posture changes.

Validation run:

- Commands run and exact result summary.
- Fixture smoke coverage.
- Real local Computer Use result, screenshot path, or explicit blocker.

Deferred blockers:

- Remaining real local validation, evidence gaps, unsupported roots, unsupported writes, release packaging/signing, or other follow-up work.
