# macOS Native Product Plan

> Decision status: **accepted and binding**. The only maintained product UI shell is the native macOS app. `apps/macos` contains the SwiftUI/AppKit shell and `crates/service` contains the first typed JSON stdio sidecar. The old Tauri + React UI has been removed after native parity. Rust core and service protocol remain reusable for future Windows and Linux desktop builds.

## 1. Why This Direction

The next six months prioritize a polished macOS desktop app. That locks the UI tradeoff:

- macOS users expect system sidebars, toolbars, split views, keyboard focus, Settings, accessibility behavior, and window resizing to feel native.
- Liquid Glass is a system design material, not just a CSS blur style. Standard SwiftUI/AppKit navigation and controls can inherit system behavior on current macOS releases; a webview can only approximate it.
- The project already has valuable Rust assets: adapters, scanner, catalog, rules, snapshots, config writes, and tests. Those should not be rewritten for one platform.
- Future Windows/Linux support should reuse the same Rust service and protocol instead of depending on macOS UI code or the deprecated web UI.

## 2. Architecture Decision

Use **Rust core + service protocol + native platform shell**:

```text
┌──────────────────────────────┐
│ macOS shell                  │
│ SwiftUI + AppKit interop     │
│ NavigationSplitView, Toolbar │
│ Settings, Inspector, menus   │
└───────────────┬──────────────┘
                │ JSON-RPC over stdio or local socket
┌───────────────┴──────────────┐
│ skills-copilot service        │
│ Rust commands facade          │
│ scan/list/toggle/config/etc.  │
└───────────────┬──────────────┘
                │
┌───────────────┴──────────────┐
│ Rust workspace crates         │
│ core/adapters/scanner/catalog │
│ ai-core/commands              │
└──────────────────────────────┘
```

The historical Tauri command surface was the prototype of the service API. V1 stabilizes that surface into a protocol that the native macOS app calls directly.

## 3. UI Shell Lifecycle

| Shell | Status | Role |
| --- | --- | --- |
| SwiftUI + AppKit macOS app | Scaffolded in `apps/macos`; **only maintained product UI** | Primary product shell for native UI, Liquid Glass, menus, Settings, toolbar, accessibility |
| Tauri 2 + React + Vite | **Removed** | Historical MVP/V1 validation shell; no current code path |
| Windows/Linux shell | Future | Evaluate after macOS native shell reaches parity; can use WinUI, GTK, Qt, Tauri, or another shell that speaks the same service protocol |

Removed UI rules:

- Do not recreate `ui/`, `src-tauri/`, or Tauri IPC for product work.
- Historical Web/Tauri artifacts are represented only by docs and git history.
- Reusable verification assets now live in native scripts, service fixtures, and `docs/ui-artifacts/native-macos-shell/`.

## 4. Protocol First

The first service boundary is implemented in `crates/service` as a short-lived stdio sidecar. Before expanding the SwiftUI UI, keep this boundary durable:

- Message format: JSON-RPC 2.0 or a similarly small typed JSON envelope.
- Transport: start with stdio sidecar for simplest packaging; local socket is acceptable if app lifecycle or streaming events need it.
- API source of truth: [`service-protocol.md`](./service-protocol.md), service protocol schemas, and fixtures. Method lists in this plan are implementation snapshots, not the source of truth.
- Event stream: catalog changed, scan progress, config write completed, error notification.
- Schema: maintain request/response fixtures for each method.
- Error model: stable error code + localized UI message key + diagnostic detail.

Initial implemented methods:

- `app.version`
- `app.stateSnapshot`
- `service.status`
- `project.getContext`
- `project.setContext`
- `project.clearContext`
- `project.validateContext`
- `catalog.listSkills`
- `catalog.getSkill`
- `catalog.listFindings`
- `catalog.listConflicts`
- `catalog.scanAll`
- `catalog.scanClaude`
- `config.toggleSkill`
- `config.readClaudeSettings`
- `config.saveClaudeSettings`
- `snapshot.list`
- `snapshot.previewRollback`
- `snapshot.rollback`

## 5. macOS UI Shape

Use native structures as the default:

- `NavigationSplitView`: source list, skill list, detail/inspector.
- `Toolbar`: scan, refresh, enable/disable, snapshot, analyze, search.
- Sidebar catalog controls: search, state filter, visible count, and sort order.
- `Table` or list-backed views for dense skill rows.
- Native `Settings` scene for language, provider preferences, privacy, and future keychain-backed credentials.
- `Inspector`-style right panel for metadata, findings, conflicts, config, and Analyze.
- macOS menu commands for scan, refresh, snapshots, search focus, and help.
- Keyboard-first interactions: arrow selection, Return open, Command-F search, Command-R rescan, Escape close transient panels.

## 6. Liquid Glass Rules

Use system-provided materials first; custom Liquid Glass is a sparing accent, not the main content surface.

- Current deployment decision: keep `apps/macos/Package.swift` at `.macOS(.v13)` and `script/build_and_run.sh` `LSMinimumSystemVersion=13.0` for compatibility. This is the minimum runtime version, not a cap on the appearance used when the app runs on newer macOS releases.
- Build with the current Apple SDK so standard SwiftUI/AppKit structures can inherit the newest system control, toolbar, sidebar, and material behavior on macOS versions that provide it.
- Custom Liquid Glass-only APIs introduced in macOS 26, such as SwiftUI `glassEffect` or AppKit `NSGlassEffectView`, must be wrapped with `if #available(macOS 26, *)` and provide macOS 13-25 fallbacks using standard controls and materials.
- Do not raise the minimum deployment target to macOS 26 only for visual polish. Raising it is a product distribution decision and should happen only if a required feature cannot be acceptably gated or backfilled.
- Prefer standard SwiftUI/AppKit controls so the system can adapt appearance, accessibility settings, and motion/transparency preferences.
- Apply glass effects only to high-value functional surfaces: toolbar groups, floating inspectors, transient command bars, popovers, and compact overlays.
- Keep the main skill list and details readable with stable contrast and density.
- Support reduced transparency and reduced motion.
- Gate new APIs with availability checks; older macOS versions fall back to standard materials.
- Avoid decorative glass panels that do not carry controls or navigation.

## 7. Migration Plan

### Phase A: Service Boundary

- [x] Extract the existing Tauri command logic into a reusable service facade for the first status/list/scan methods.
- [x] Add JSON fixtures for every method.
- [x] Add a sidecar binary target.
- Historical Tauri commands remain only as MVP implementation record.
- Add contract tests for request/response compatibility.

### Phase B: Native macOS Shell

- [x] Scaffold `apps/macos` with SwiftUI.
- [x] Build the main split-view shell and Settings scene.
- [x] Connect read-only catalog methods first (`catalog.listSkills`, `catalog.getSkill`, `catalog.listFindings`, `catalog.listConflicts`, `snapshot.list`).
- [x] Add scan, toggle, snapshot preview, and rollback UI flows.
- [x] Add native Claude settings config edit.
- [x] Add sidebar catalog filtering and sorting controls.
- [x] Add native list model test, native 10k list benchmark, and native layout static check.
- [x] Move primary native user-visible copy behind `UIStrings` and Swift `Localizable.strings` resources.
- Match MVP/V1 smoke coverage with native UI tests where practical.

### Phase C: UI Parity and Old UI Removal

- Compare native macOS flows against MVP/V1 completed flows.
- Move any still-useful smoke fixtures and performance harnesses away from the deprecated web UI.
- [x] Keep GitHub Actions and package defaults focused on the native macOS product shell.
- [x] Delete deprecated `ui/` and obsolete Tauri UI glue after parity.
- [x] Update README, package scripts, CI, app run scripts, and docs so native macOS is the only active product UI.

### Phase D: Product Polish

- Add native menus, keyboard shortcuts, toolbar customization, inspector behavior, and accessibility checks. Initial Scan/Reload/detail-section/search/settings commands are implemented.
- Apply Liquid Glass only after the layout works with normal materials.
- Future distribution work can add packaging, signing, and notarization after the current Local App Run / Smoke App Run stage is stable.

### Phase E: Future Desktop Platforms

- Keep the Rust service protocol stable.
- Decide Windows/Linux shell after macOS has a proven product shape.
- Reuse service fixtures and contract tests across shells.

## 8. Non-goals

- Do not rewrite scanner/catalog/adapters/rules in Swift.
- Do not make SwiftUI depend on a UI shell-specific backend.
- Do not recreate the deprecated Tauri/React UI.
- Do not implement Windows/Linux native shells before the macOS product shell proves the protocol.
- Do not sacrifice offline-by-default, snapshot-before-write, or no-telemetry rules for UI polish.

## 9. Required UI Delivery Process

All macOS UI and future cross-platform UI work must follow [ui-delivery-standards.md](./ui-delivery-standards.md):

- Prototype before every major version or major feature.
- Update completed UI screenshots after implementation and verification.
- Launch and operate the macOS app with macOS Computer Use for every code change before calling the task complete.
- Document verification gaps when app launch or Computer Use is blocked.
