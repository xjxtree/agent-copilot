# V2.88 Handoff Evidence Verification

Status: completed on 2026-06-17.

## Build And Session

- Command: `pnpm check:macos` passed in an unlocked interactive macOS session.
- Bundle: current workspace `dist/SkillsCopilot.app`.
- Window: `Agent Copilot`, accessibility id `skills-copilot.main-window`.
- Capture helper: `script/capture_app_window.sh`, using `screencapture -l`.
- Screenshot verifier: `pnpm verify:screenshot-artifacts docs/ui-artifacts/v2.88-handoff-evidence` passed.

## Captured Surfaces

| Surface | Screenshot | Result |
| --- | --- | --- |
| Lineup | `lineup.png` | Decision queue, agent lineup, evidence refs, and read-only awareness mode visible |
| Agent Profile / MCP default-off | `agent-profile-mcp-default-off.png` | Agent Profile health/capability surface visible; MCP Preview remains explicit authorization / default-off |
| Local Session default-off | `local-session-default-off.png` | Local Session Preview says no authorized directories are scanned |
| Local Session authorized preview | `local-session-authorized-preview.png` | Disposable `/tmp/ac-v288/sessions` fixture returns `authorized-read-only`, redacted excerpt, and session evidence refs |
| MCP authorized preview | `mcp-authorized-preview.png` | Disposable `/tmp/ac-v288/mcp/config.json` fixture returns `authorized-read-only`, server metadata, args count, env-key count, and MCP evidence refs |

## Disposable Fixture

The authorized preview checks used only `/tmp/ac-v288` fixture files:

- `/tmp/ac-v288/sessions/session.jsonl`
- `/tmp/ac-v288/mcp/config.json`

The MCP fixture included an env value to verify redaction behavior. The UI showed
only `Env keys: 1`; it did not return the env value or raw config content.

## Known Gaps

- No V2.88 blocker remained after the unlocked Computer Use pass.
- Fixture smoke screenshots remain supporting evidence only; the V2.88 evidence
  above is from the resolved real app window.
