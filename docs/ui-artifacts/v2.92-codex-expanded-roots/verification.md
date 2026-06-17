# V2.92 Codex Expanded Roots UI Evidence

Status: completed

## Scope

- V2.92 is primarily adapter/diagnostic behavior, not a new visible macOS
  surface.
- App-window evidence confirms the Agent Copilot shell still launches after
  Codex expanded root discovery and write-boundary changes.
- The screenshot is app-window-only and avoids full desktop capture.

## Expected Behavior

- Codex user/project `.agents/skills` roots remain writable through the user
  `config.toml` override.
- `$CODEX_HOME/skills`, local plugin marketplace roots, `/etc/codex/skills`,
  and project `.codex/config.toml` diagnostics are visible only as read-only
  evidence.
- No provider calls, script execution, credential reads, network fetches, cloud
  sync, telemetry, or hidden write path is introduced.

## Artifact

- `completed.png` captures `dist/AgentCopilot.app` after the V2.92 validation
  run.

## Commands

```sh
./script/build_and_run.sh --verify
pnpm smoke:macos-app -- --fixture-data --capture-window
./script/capture_app_window.sh dist/AgentCopilot.app docs/ui-artifacts/v2.92-codex-expanded-roots/completed.png
pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.92-codex-expanded-roots
```
