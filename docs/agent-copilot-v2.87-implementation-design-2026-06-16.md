# Agent Copilot V2.87 Implementation Design

> Scope: rollout M1-M4 first implementation pass for the display-level Agent Copilot pivot.
> Internal identifiers remain `SkillsCopilot` / `skills-copilot`.

## Status

- Design record: complete for the landed implementation.
- Implementation status: landed in the worktree.
- Validation: protocol, Swift, macOS static UI, privacy, and diff gates pass. 2026-06-17 unlocked `pnpm check:macos` passed end to end, including `./script/build_and_run.sh --verify`, fixture-data app-window capture, and screenshot artifact verification.

## Object Model

| Object | Role | Source |
| --- | --- | --- |
| Lineup | Default decision-first overview for the current agent lineup | Existing catalog, health, cleanup, task, provider, and review evidence |
| Agent Profile | Agent-level status and nearby evidence surfaces | Adapter capabilities/diagnostics, health summary, scan summaries |
| Decision Item | Sorted read-only recommendation row | `AgentCopilotDecisionItem` with priority, impact score, target, and evidence refs |
| Local Session Preview | Explicitly authorized local session source preview | `session.previewLocalSessions` result rows |
| MCP Server Preview | Explicitly authorized MCP config preview | `evidence.previewMcpServers` result rows |

## Protocol Increment

| Method | Input | Output | Boundary |
| --- | --- | --- | --- |
| `session.previewLocalSessions` | `authorized_roots`, optional `agent`, `limit`, `max_files`, `max_excerpt_chars` | Authorized roots, redacted session rows, gap/blocker notes, redaction summary, safety flags | Default-off; no default session store scan; no raw transcript persistence; no trace/review creation |
| `evidence.previewMcpServers` | `authorized_config_paths`, optional `limit` | Authorized config paths, redacted server rows, args/env-key counts, gap/blocker notes, redaction summary, safety flags | Default-off; no default config scan; no env values or raw config persistence |

`crates/service/src/protocol.rs` remains the method source of truth. The current protocol surface is 90 methods.

## UI Prototype

| Surface | Layout | Interaction |
| --- | --- | --- |
| Lineup | Header metrics + decision queue + agent lineup snapshot | Decision rows navigate only to existing read-only/detail surfaces |
| Agent Profile | Agent metrics + capability/scan cards + MCP preview + evidence navigation | Agent selector changes the profile context |
| Local Session Preview | Text field for authorized directories + preview button + redacted cards | User supplies directories explicitly; empty input shows authorization-required state |
| MCP Server Preview | Text field for authorized config files + preview button + redacted cards | User supplies config files explicitly; empty input shows authorization-required state |

No new UI control directly writes, toggles, applies, executes, confirms provider sends, or mutates triage/snapshot state.

## State Flow

1. User selects Lineup or Agent Profile.
2. UI reads existing `SkillStore` evidence and renders read-only decision/profile state.
3. Optional local evidence preview requires explicit user-entered paths.
4. Store normalizes comma/newline/semicolon-separated authorized paths.
5. Swift service client calls the Rust stdio sidecar.
6. Rust service canonicalizes authorized roots/files, reads bounded content, redacts before returning, and emits safety flags.
7. UI renders redacted path/excerpt/command/evidence refs with `PrivacyEvidenceText`.

## Acceptance Criteria

- Display brand is Agent Copilot while internal identifiers remain stable.
- Lineup is the default object-level surface before skill detail fallback.
- Decision queue sorting is deterministic by priority, impact score, evidence count, and stable id.
- Local session preview is default-off and requires explicit authorized directories.
- MCP server preview is default-off and requires explicit authorized config files.
- Returned local evidence includes redaction summary, evidence refs, and safety flags.
- No raw transcript, raw MCP config, env values, credentials, raw prompt, raw response, cloud sync, telemetry, write/apply/toggle/script path, or hidden provider request is introduced.
- Protocol fixtures, dispatch coverage, status fixture methods, Swift model tests, native UI layout verifier, privacy gate, and diff whitespace gate pass.
- Unlocked macOS validation passes `pnpm check:macos`; fixture-data smoke captures the full app window for the Lineup surface. Future per-surface Computer Use screenshots, when required, must capture only app windows and must not use locked/black/invalid screenshots.
