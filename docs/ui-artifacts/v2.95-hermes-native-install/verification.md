# V2.95 Hermes Native Install UI Evidence

Status: captured

## Scope

- V2.95 is primarily adapter capability and install-path behavior, not a new
  macOS surface.
- App-window evidence confirms the Agent Copilot shell still launches after
  Hermes native-root install capability changes.
- The screenshot is app-window-only and avoids full desktop capture.
- Dedicated V2.95 app-window evidence was captured after an unlocked validation
  run. Full desktop screenshots are not used.

## Expected Behavior

- Hermes active/profile home skill scanning remains visible.
- Hermes explicit `skills.external_dirs` roots remain read-only external roots.
- Tool-global installs can target native `~/.hermes/skills` only.
- Hermes project install, config toggles, per-platform enablement writes,
  external_dirs writes, hub / URL / tap / update / uninstall / reset
  operations, and uncontrolled network fetch remain blocked.
- No provider calls, script execution, credential reads, cloud sync, telemetry,
  or hidden write path is introduced.

## Artifact

- `completed.png` captures `dist/AgentCopilot.app` after an unlocked V2.95
  validation run.
- `pnpm check:macos` also refreshes the shared native macOS app-window artifact
  at `docs/ui-artifacts/native-macos-shell/completed.png`.

## Commands

```sh
./script/build_and_run.sh --verify
./script/capture_app_window.sh dist/AgentCopilot.app docs/ui-artifacts/v2.95-hermes-native-install/completed.png
pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.95-hermes-native-install
```

## Result

- `./script/build_and_run.sh --verify` passed and exposed a visible
  `AgentCopilot` window.
- `./script/capture_app_window.sh dist/AgentCopilot.app docs/ui-artifacts/v2.95-hermes-native-install/completed.png`
  captured window `44005`, PID `88205`, at `1840x1304`.
- `pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.95-hermes-native-install`
  passed.
