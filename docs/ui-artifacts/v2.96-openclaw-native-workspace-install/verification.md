# V2.96 OpenClaw Native/Workspace Install UI Evidence

## Purpose

- V2.96 is primarily adapter capability and install-path behavior, not a new
  visual surface.
- Dedicated app-window evidence verifies the shipped Agent Copilot shell still
  launches after the OpenClaw native/workspace install changes.
- Evidence must be full app-window only, not full desktop.

## Capture

- App bundle: `dist/AgentCopilot.app`
- Evidence image: `completed.png`
- Capture command:
  `./script/capture_app_window.sh dist/AgentCopilot.app docs/ui-artifacts/v2.96-openclaw-native-workspace-install/completed.png`

## Expected Boundary

- The app can display updated adapter capability/status data from the service.
- OpenClaw is install-only for confirmed local ToolGlobal copies into
  `~/.openclaw/skills` and confirmed OpenClaw workspace `<workspace>/skills`.
- OpenClaw `.agents` roots remain scan-only.
- OpenClaw config toggles, `skills.entries` writes, ClawHub, Git, update,
  verify, workshop, scripts, credentials, cloud sync, telemetry, and
  uncontrolled network operations remain blocked.

## Result

- `completed.png` captures `dist/AgentCopilot.app` after an unlocked V2.96
  validation run.
- Capture metadata: AgentCopilot window `44119`, PID `64971`, screenshot
  dimensions `1840x1304`.
- `pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.96-openclaw-native-workspace-install`
  validates the evidence directory.
