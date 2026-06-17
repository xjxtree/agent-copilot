# V2.91 Model-task History Verification

Status: completed on 2026-06-17.

## Scope

- Provider Observability includes read-only model-task history rows from
  `model_task_history_rows`.
- The backing service stores only redacted app-local
  `model-task-matches.json` metadata.
- The service methods are `llm.listModelTaskMatches`,
  `llm.recordModelTaskMatch`, and `llm.deleteModelTaskMatch`.
- The native V2.91 UI exposes no record/delete controls for this history.

## Evidence

- Focused Rust model-task history tests passed.
- Service protocol fixture decode and dispatch coverage passed.
- Swift Provider Observability decode/store tests passed.
- `./script/build_and_run.sh --verify` launched and verified
  `dist/AgentCopilot.app`.
- `pnpm smoke:macos-app -- --fixture-data --capture-window` launched
  `AgentCopilot`, captured the fixture app window, and completed service smoke.
- App-window-only evidence: `completed.png`.
- Screenshot artifact verifier passed for this directory.

## Boundary

No provider request, credential read, raw prompt/response/trace persistence,
skill/config write, hidden apply path, script execution, cloud sync,
telemetry, signing, notarization, DMG, or ZIP work was added.
