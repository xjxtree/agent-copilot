# Agent Copilot

Agent Copilot is a native macOS control surface for inspecting local coding-agent
sessions, skills, configuration snapshots, and validation evidence without
expanding the repository's write, script, credential, cloud, or telemetry
surface.

## What It Does

- Shows local agent sessions, skill catalogs, and supported config snapshots.
- Uses a typed Rust JSON stdio service behind the native macOS app.
- Keeps local analysis deterministic by default.
- Gates optional provider calls behind preview, redaction, destination
  visibility, and explicit confirmation.
- Treats skill scripts, transcripts, LLM output, and config files as untrusted
  input.

## What It Does Not Do

- No cloud sync, accounts, telemetry, anonymous crash reports, or uncontrolled
  outbound network calls.
- No default provider calls.
- No hidden apply/write paths.
- No skill-script execution from scans, imports, previews, recommendations, or
  LLM output.
- No credential storage in project directories, SQLite, logs, prompts,
  screenshots, reports, or response artifacts.
- No public distribution, signing, notarization, DMG, ZIP, updater, or release
  automation by default.

## Documentation

| File | Use |
| --- | --- |
| `AGENTS.md` | Agent-facing operating rules |
| `CLAUDE.md` | Claude Code-specific compatibility behavior |
| `docs/architecture.md` | Repository architecture |
| `docs/adapters/agent-adapters.md` | Adapter roots, write scopes, and blocked operations |
| `docs/service-protocol.md` | Typed service method contract |
| `docs/security-model.md` | Security and privacy rules |
| `docs/data-model.md` | Persisted and transient data model |
| `docs/ai-layer.md` | Provider and LLM safety boundary |
| `docs/ui-delivery-standards.md` | UI and screenshot validation standards |
| `docs/plans/roadmap.md` | Future work and non-goals |
| `docs/plans/development-tasks.md` | Active task routing |
| `CHANGELOG.md` | Versioned release-impact notes |
| `docs/verification/` | Version checklists and benchmark trends |

## Common Commands

```sh
cargo test --workspace
cargo clippy --workspace --all-targets --all-features
pnpm test:macos-native-models
swift test --package-path apps/macos
pnpm check:macos
pnpm check:privacy
pnpm verify:gate-parity
pnpm verify:service-protocol-drift
pnpm verify:module-size
pnpm verify:macos-ui-layout
pnpm smoke:macos-app -- --fixture-data --capture-window
pnpm dev:macos
```
