# V2.89 Brand Assets Verification

Status: completed on 2026-06-17.

## Asset Pipeline

- Source: `apps/macos/Sources/SkillsCopilot/Resources/AppIcon.svg`.
- Generated bundle icon: `apps/macos/Sources/SkillsCopilot/Resources/AppIcon.icns`.
- Regeneration command: `pnpm generate:app-icon`.
- Bundle wiring: `script/build_and_run.sh` copies `AppIcon.icns` into
  `dist/SkillsCopilot.app/Contents/Resources/AppIcon.icns` and writes
  `CFBundleIconFile=AppIcon`.

## Visual Review

- The icon uses Agent Copilot visual language: local evidence cards, routed
  decision flow, and a forward navigation mark.
- It contains no small text, local paths, account names, credentials, or
  screenshot content.
- Internal identifiers remain unchanged: `SkillsCopilot`, `skills-copilot`,
  `dev.skills-copilot.native`, and existing AX ids.

## Build And Evidence

- `pnpm check:macos` passed after regenerating the icon.
- `script/capture_app_window.sh` resolved the current workspace
  `dist/SkillsCopilot.app` by exact bundle path and captured window PID `84564`.
- App-window-only evidence: `completed.png`.
- `pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.89-brand-assets`
  passed.

## Known Gaps

- No icon/bundle identifier migration is included here. V2.90 owns internal
  identifier migration and rollback/data preservation design.
