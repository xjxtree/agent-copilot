# V2.93 opencode Custom Roots UI Evidence

Status: blocked

## Scope

- V2.93 is primarily adapter/diagnostic behavior, not a new macOS surface.
- App-window evidence should confirm the Agent Copilot shell still launches
  after opencode configured local root discovery and provenance changes.
- The screenshot is app-window-only and avoids full desktop capture.
- Current capture state is canonical `locked-session`; full desktop screenshots
  and smoke screenshots must not be substituted for real app-window evidence.

## Expected Behavior

- opencode native and official compatibility roots remain visible.
- JSON/JSONC `skills.paths` local directories are visible as configured,
  read-only opencode roots.
- `skills.urls` remains metadata-only/no-fetch.
- No provider calls, script execution, credential reads, cloud sync, telemetry,
  URL fetch, configured-root write/install target, or hidden write path is
  introduced.

## Artifact

- `completed.png` should capture `dist/AgentCopilot.app` after an unlocked
  V2.93 validation run.
- Current blocker:
  `./script/build_and_run.sh --verify` built the service/app, then failed
  closed with canonical `locked-session` before launch/evidence capture.

## Commands

```sh
./script/build_and_run.sh --verify
pnpm smoke:macos-app -- --fixture-data --capture-window
./script/capture_app_window.sh dist/AgentCopilot.app docs/ui-artifacts/v2.93-opencode-custom-roots/completed.png
pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.93-opencode-custom-roots
```
