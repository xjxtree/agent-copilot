# macOS App Runbook

This runbook describes local development, smoke validation, and real-local UI
validation for the native macOS app.

## App Bundle

`script/build_and_run.sh` builds the Rust service, builds the Swift app, and
regenerates `dist/AgentCopilot.app`.

Common entrypoints:

```sh
./script/build_and_run.sh run
./script/build_and_run.sh --verify
pnpm dev:macos
pnpm build:macos
pnpm check:macos
```

`pnpm smoke:macos-app` validates the existing bundle; it does not rebuild it.

## Scenarios

| Scenario | Command | Data environment | Use |
| --- | --- | --- | --- |
| Local App Run | `./script/build_and_run.sh run` or `pnpm dev:macos` | Real local HOME and app data | Manual behavior and visual checks |
| Launch Verify | `./script/build_and_run.sh --verify` or `pnpm build:macos` | Real local HOME and app data | Rebuild and confirm launch |
| Smoke App Run | `pnpm smoke:macos-app -- --fixture-data --capture-window` | Temporary fixture HOME, app data, and project roots | Automated validation without real config |
| macOS Check | `pnpm check:macos` | Combined local gate | fmt/test/clippy/build/launch/smoke/window screenshot |

## Gate Parity

`pnpm verify:gate-parity` is the deterministic local/CI shared gate. It covers
service protocol drift, module-size budgets, documentation governance, JS syntax,
Rust docs, benchmark trends, fixture verifiers, version checklist verifiers,
validation blocker classification, and screenshot artifact checks.

This gate does not replace real-local UI operation when a user-visible change
needs visual or interaction evidence.

## Smoke Rules

Smoke validation must use fixture data:

```sh
pnpm smoke:macos-app -- --fixture-data --capture-window
```

Smoke must:

- use temporary HOME, app data, and project roots;
- avoid real Claude, Codex, opencode, Pi, Hermes, and OpenClaw config mutation;
- validate the existing app bundle;
- capture only the app window;
- cover scan, toggle, settings save, snapshot preview, rollback, project
  context, and configured fixture roots when supported by the smoke script;
- avoid script execution through scan, import, export, install, LLM prepare,
  state snapshot, or detail loading.

## Screenshot Rules

- Completed screenshots must be app-window-only.
- Do not commit full desktop screenshots.
- Keep screenshot privacy mode enabled for committed evidence.
- Do not expose real HOME paths, app data, `/var/folders`, fixture temp roots,
  tokens, keys, or credential placeholders.
- Run `pnpm verify:screenshot-artifacts` after screenshot changes.
- Manually inspect new screenshots; the verifier is not OCR.

## Real-Local Validation

Use the developer's real environment only when the runbook or task explicitly
requires real-local validation:

```sh
pnpm dev:macos
```

or:

```sh
./script/build_and_run.sh run
```

Operate the visible app window with Computer Use/AX when available. If the app
process launches but the window cannot be resolved, record one canonical
blocker and do not substitute fixture smoke for real-local validation.

Useful classifier:

```sh
pnpm classify:validation-blocker -- "<tool output>"
```

Canonical blockers include locked session, timeout, window not found, remote
connection, missing AX window, activation failure, Screen Recording permission,
black/flat/transparent/invalid capture, stale bundle, and unknown tool-layer
failure.
