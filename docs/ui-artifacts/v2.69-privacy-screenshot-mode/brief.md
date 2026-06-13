# V2.69 Privacy / Screenshot Mode Brief

## Goal

Make real-local and fixture UI evidence safer to review by default. Local paths should not appear as raw absolute paths in normal screenshots, and invalid locked/black captures must be rejected instead of treated as completed visual evidence.

## Scope

- App-local screenshot privacy preference, default on.
- UI presentation helpers for redacted/collapsed paths with explicit reveal.
- Coverage for high-risk visible paths: skill source, project root, adapter roots, catalog path, local report path, and install preview source/target.
- Localized Task Cockpit, Guided Cleanup, and Provider Observability labels.
- Screenshot artifact verification and capture rejection for locked/black/flat images.

## Non-goals

- No scanner/catalog fact mutation.
- No report-export redaction replacement.
- No service method addition.
- No write/apply/execute/provider/cloud/telemetry path.
