# V2.94 Pi Install And Compatibility Writes UI Evidence

Status: captured

## Scope

- V2.94 is primarily adapter/capability behavior, not a new macOS surface.
- App-window evidence should confirm the Agent Copilot shell still launches
  after Pi native install and compatibility-root toggle changes.
- The screenshot is app-window-only and avoids full desktop capture.
- Dedicated V2.94 app-window evidence was captured after an unlocked validation
  run. Full desktop screenshots are not used.

## Expected Behavior

- Pi native roots remain visible.
- Pi `.agents/skills` compatibility roots are visible with compatibility
  provenance.
- Pi native and `.agents` compatibility toggles route through guarded Pi
  settings writes.
- Tool-global installs target native `~/.pi/agent/skills` or project
  `.pi/skills` only.
- Pi package install/remove and `.agents` direct skill-file installs remain
  blocked.
- No provider calls, script execution, credential reads, cloud sync, telemetry,
  uncontrolled network fetch, package install/remove, or hidden write path is
  introduced.

## Artifact

- `completed.png` captures `dist/AgentCopilot.app` after an unlocked V2.94
  validation run.
- `pnpm check:macos` also refreshed the shared native macOS app-window artifact
  at `docs/ui-artifacts/native-macos-shell/completed.png`.

## Commands

```sh
./script/build_and_run.sh --verify
pnpm smoke:macos-app -- --fixture-data --capture-window
./script/capture_app_window.sh dist/AgentCopilot.app docs/ui-artifacts/v2.94-pi-install-compat-writes/completed.png
pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.94-pi-install-compat-writes
```

## Result

- `./script/build_and_run.sh --verify` passed and exposed a visible
  `AgentCopilot` window.
- `./script/capture_app_window.sh dist/AgentCopilot.app docs/ui-artifacts/v2.94-pi-install-compat-writes/completed.png`
  captured window `43960`, PID `46067`, at `1840x1304`.
- `pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.94-pi-install-compat-writes`
  passed.
