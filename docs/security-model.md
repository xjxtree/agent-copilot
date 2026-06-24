# Security Model

This file describes security and privacy boundaries.

## Trust Boundaries

- Rust crates own product logic and policy decisions.
- The native macOS app presents state and sends typed requests to the Rust stdio
  service.
- Local agent files, skills, transcripts, LLM output, screenshots, and generated
  reports are untrusted inputs.
- Fixture smoke validation must not touch real user config. Real-local
  validation may read the developer's real HOME and app data only when the
  runbook explicitly calls for it.

## Privacy Rules

- No cloud sync, accounts, telemetry, anonymous crash reports, or uncontrolled
  outbound network calls.
- Provider calls are optional and require user enablement, prompt preview,
  redaction, destination visibility, and explicit confirmation.
- Raw transcripts, prompts, responses, traces, credentials, screenshots, and
  reports must not persist secrets.
- Session preview data is redacted and bounded before it crosses the service
  boundary.

## Credentials

- Credentials must prefer Keychain.
- Never write credentials to SQLite, project directories, logs, prompts,
  response artifacts, screenshots, or reports.
- Provider Observability may show redacted metadata only; it must not expose
  raw secrets or add write/delete controls without a new scoped safety review.

## Writes And Scripts

- Skill scripts are untrusted. Script execution is default-denied and must not
  be triggered by imports, LLM output, analyzer recommendations, previews, or
  cleanup guidance.
- Adapter writes stay limited to the documented guarded toggles and install
  roots in `AGENTS.md` and `docs/adapters/agent-adapters.md`.
- Hidden apply/write paths, hidden task state, raw prompt/response/trace
  persistence, public distribution automation, signing, notarization, DMG, and
  ZIP work require explicit new scope.

## Screenshot Evidence

- Completed UI screenshots must capture only the full app window.
- Full desktop screenshots are forbidden.
- If the macOS session is locked, cannot be confirmed interactive, or window
  capture is blocked, record the canonical blocker instead of substituting
  unrelated evidence.

## Verification

Use `pnpm check:privacy` before committing, pushing, or handing off evidence.
Use `pnpm check:macos` for milestone, user-visible, UI, service protocol, or
major validation changes.
