# V2.90 Identifier Migration Verification

Status: completed on 2026-06-17.

## Migration Scope

- Primary app bundle is now `dist/AgentCopilot.app`.
- `Info.plist` verifies `CFBundleName=AgentCopilot`,
  `CFBundleExecutable=AgentCopilot`, and
  `CFBundleIdentifier=dev.agent-copilot.native`.
- Service default app-data id is now `dev.agent-copilot.native`.
- Legacy app-data id `dev.skills-copilot.native` is retained as a migration
  source and compatibility signal.
- Legacy app-data is copied to the new default directory only when the new
  directory is absent; the old directory is not deleted.
- Migration marker: `agent-copilot-app-data-migration.json`.

## Preserved Compatibility

- Swift module/source/test names remain `SkillsCopilot`.
- Rust crate names remain `skills-copilot-*`.
- Sidecar binary remains `skills-copilot-service`.
- AX identifiers remain `skills-copilot.*`.
- Environment variables remain `SKILLS_COPILOT_*`.
- Keychain service remains `dev.skills-copilot.native.llm`; V2.90 does not copy
  or duplicate credentials.
- Historical screenshots and checklists retain their original paths.

## Evidence

- Focused Rust app-data migration tests passed.
- `swift test --package-path apps/macos` passed.
- `./script/build_and_run.sh --verify` launched and verified
  `dist/AgentCopilot.app`.
- `pnpm smoke:macos-app -- --fixture-data --capture-window` launched
  `AgentCopilot`, captured the fixture app window, and completed service smoke.
- App-window-only evidence: `completed.png`.
- Screenshot artifact verifier passed for this directory.

## Boundary

No service protocol method/payload/version changed. No provider default call,
hidden write/apply path, script execution, credential copy, cloud sync,
telemetry, signing, notarization, DMG, or ZIP work was added.
