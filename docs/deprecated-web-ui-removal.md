# Deprecated Web UI Removal Record

> Status: completed removal. Native smoke, service fixtures, native list-model tests, and native layout checks replaced the old Web/Tauri validation entrypoints. The `ui/` and `src-tauri/` directories, Tauri workspace membership, Tauri npm dependency, and `*:web-deprecated` package scripts have been removed.

## Current Rule

The Tauri + React UI has been removed. Product features belong in `apps/macos/` and the Rust service protocol. Do not recreate a Web/Tauri product shell unless a future architecture decision explicitly reverses the native macOS direction.

## Assets To Preserve Or Replace

| Asset | Current handling |
| --- | --- |
| Former Tauri/Web smoke entrypoint | Replaced by `pnpm smoke:macos-app`, which targets `dist/SkillsCopilot.app`, checks bundle freshness, and uses the packaged Rust sidecar. |
| Service request/response examples | Preserved as native/future-shell fixtures in `fixtures/service-protocol/`. |
| Completed UI screenshots | Captured through `script/capture_app_window.sh`; full-desktop screenshots are forbidden. |
| Synthetic scan benchmark | Preserved as `pnpm benchmark:10k`; independent of Web UI. |
| Synthetic Web UI list benchmark | Replaced by `pnpm benchmark:macos-list-model`, which compiles the real Swift list model and measures 10k native records. |
| Web layout static check | Replaced by `pnpm verify:macos-ui-layout`, which checks native SwiftUI layout constraints. |
| i18n terminology from `ui/src/strings.ts` | Native user-visible copy now has a Swift-side `UIStrings` entrypoint and `Resources/en.lproj/Localizable.strings`; Web strings are migration reference only. |
| Regression examples for MVP information architecture | Migration reference only; native artifacts now live under `docs/ui-artifacts/native-macos-shell/`. |

## Deletion Gates

- Native macOS shell covers Scan, List, Detail, Findings, Conflicts, Snapshots, Enable/Disable, Claude Settings edit, Snapshot Preview, and Snapshot Rollback.
- Service protocol fixtures cover every UI-facing method.
- Smoke App Run can launch the existing `.app`, run core fixture write flows through the packaged service sidecar, and capture app-window-only screenshots; each code-change task still requires separate macOS Computer Use operation before completion.
- macOS app runbook documents Local App Run, Smoke App Run, bundle refresh timing, and fixture smoke coverage.
- README/package/CI no longer present Web UI as a product target. Deprecated Web UI scripts have been removed.

## Current Replacement Status

| Web-era dependency | Replacement status | Delete readiness |
| --- | --- | --- |
| Tauri/Web smoke flow | Replaced by native `pnpm smoke:macos-app -- --fixture-data --capture-window`; CI now runs native macOS checks and bundle smoke instead of Web UI lint/test/build as a product gate. | Deleted. |
| Tauri command surface | Replaced for native shell by `crates/service`; old Tauri commands now exist only as historical documentation in the MVP record. | Deleted from current code. |
| Web list search/filter/sort interaction | Native sidebar now has search, State filter, visible count, and Sort picker; `pnpm test:macos-list-model` verifies the Swift list model behavior. | Deleted. |
| Web completed screenshot artifact | Replaced by `docs/ui-artifacts/native-macos-shell/completed.png` from app-window-only capture. | Deleted. |
| Web settings/editor interaction reference | Native Settings scene supports read/save of Claude settings through service protocol; unlocked real Local App Run confirmed read, save, snapshot, and rollback on 2026-06-08. | Deleted. |
| Web UI benchmark (`benchmark:web-ui-10k`) | Replaced by `pnpm benchmark:macos-list-model`; old script removed. | Deleted. |
| Web layout static check (`verify:web-ui-layout`) | Replaced by `pnpm verify:macos-ui-layout`; old script removed. | Deleted. |
| Web i18n string source | Native copy moved behind `UIStrings` and `Localizable.strings`; current `.app` copies localized resources into `Contents/Resources`. | Deleted. |

## Deleted Scope

- `ui/`
- obsolete Tauri UI glue under `src-tauri/`
- deprecated Web UI package scripts with `*:web-deprecated` names
- Tauri npm dependency and Tauri Rust workspace dependencies

## Preserved Assets

- Rust crates shared by native macOS and future platform shells.
- Service protocol fixtures and contract tests.
- Smoke assets for native `.app` validation.
- App icon source, moved to `apps/macos/Sources/SkillsCopilot/Resources/AppIcon.icns`.

## Follow-up Tasks

- Keep historical MVP docs clear that Tauri/Web was a past validation shell, not current code.
- Continue to run native macOS validation for every code change.
