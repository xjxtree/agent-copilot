# V2.68 Task Cockpit IA Brief

## Goal

Make the app start from the user's task instead of a selected skill detail page, while keeping all V2.65-V2.67 analysis and cleanup boundaries intact.

## Scope

- Promote Task Cockpit to the default detail section.
- Show Work surfaces in the sidebar before diagnostic cards.
- Replace the crowded detail segmented picker with a bounded menu picker.
- Split the former dense Analysis stack into clear surfaces:
  - Task Cockpit
  - Skill Map / Lifecycle
  - Guided Cleanup
  - Provider Observability
  - Review

## Non-goals

- No new service method.
- No provider request by default.
- No hidden task state.
- No skill/config writes, triage mutation, snapshot, script execution, cloud sync, or telemetry.
