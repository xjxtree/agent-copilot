# UI Delivery Standards

This file captures UI and evidence standards.

## Product Shell

- The maintained UI is the native macOS app in `apps/macos`.
- Do not recreate `ui/`, `src-tauri/`, or Tauri IPC.
- User-facing behavior should use existing SwiftUI/AppKit view, model, service,
  localization, and fixture patterns.

## Current Surface Rules

- Primary navigation contains Sessions, Skills, and Config.
- Session, skill, and config detail panes should render only the selected item
  or overview for the selected mode.
- Agent Usage Report and Task Preflight are compact preview tools.
- Retired surfaces should not reappear without a new scoped version.

## Evidence Screenshots

- Completed screenshots must capture only the full app window.
- Full desktop screenshots are forbidden.
- Fixture smoke screenshots are not substitutes for required real-local UI
  evidence unless the checklist explicitly says no fresh UI evidence is needed.
- If the session is locked or app-window capture is blocked, record the
  canonical blocker.

## Validation

- For UI changes, run focused Swift tests when appropriate and `pnpm
  check:macos` for milestone or user-visible changes.
- Use `pnpm verify:macos-ui-layout` through `pnpm check:macos`, not as a
  replacement for the full gate.
- Use `pnpm verify:screenshot-artifacts` when adding, removing, or reorganizing
  screenshot evidence.
