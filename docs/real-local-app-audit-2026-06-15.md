# Real Local App Audit 2026-06-15

Scope: current `main` after the V2.72 closeout docs, current bundle `dist/SkillsCopilot.app`, launched from the local workspace and exercised with Computer Use plus app-window screenshots.

## Evidence

- Build/run: current app bundle rebuilt and launched successfully.
- Initial locked attempt: `CGSSessionScreenIsLocked=1`; reliable screenshots and Computer Use interaction were blocked until unlock.
- Computer Use while locked: absolute app path returned `cgWindowNotFound`.
- Capture helper while locked: `script/capture_app_window.sh` failed closed with `locked-session`.
- Classifier: `pnpm classify:validation-blocker` mapped `cgWindowNotFound` to `window-not-found` and lock output to `locked-session`.
- Earlier same-session unlocked window observation reached the Task Cockpit first screen and captured UI tree/screenshot evidence before lock state returned.
- Current rerun: direct `task.buildCockpit` RPC against the rebuilt app bundle produced no stdout/stderr within 10 seconds before termination.
- Unlocked continuation: Computer Use resolved the exact app bundle path and direct app-window capture produced valid non-black screenshots kept outside the repository under a temporary evidence directory.
- Real UI paths exercised: Task Cockpit, Provider Observability, Local Skill Map, Guided Cleanup Flow, guided cleanup safe-link navigation, and Review.
- Provider Observability returned app-local empty/redacted metadata quickly, but it also surfaced the stale message `another catalog operation is running` while a different long-running task was still pending.
- Guided Cleanup Flow returned 7 local read-only steps and 3 safe next-action rows. Safe links navigated to existing read-only Skill Map/Lifecycle context and did not expose Apply/Fix/Write actions.
- Local Skill Map eventually rendered 120 nodes, 146 edges, and 6 clusters after safe-link navigation.

## Findings

1. Task Cockpit can remain in `Preparing...` on real local catalog data.
   - UI trigger works and disables the button.
   - Direct `task.buildCockpit` service call produced no output within 30 seconds.
   - Subcall matrix showed `task.checkReadiness`, `task.rankSkillRoutes`, `task.compareAgentReadiness`, `remediation.plan`, and `remediation.batchReview` did not return within 12 seconds, while `session.listSkillReviews` and `llm.providerObservability` returned in about 9 ms.
   - This is a product performance and feedback issue, not only a UI tree issue.

2. Task input is sensitive to active input method during automation.
   - Direct key events can corrupt Chinese/ASCII task text under the current input method.
   - Clipboard paste preserves task text correctly.
   - Real user input still needs unlocked manual validation, but automated validation should prefer paste or controlled input-source switching.

3. Multiple local `SkillsCopilot.app` bundles with the same bundle id can confuse activation and Computer Use targeting.
   - App-name activation can start or focus an older worktree bundle.
   - Real-local validation should kill stale same-name processes and bind by full path/PID.
   - Development bundles should consider a unique dev bundle id or launch guard to reduce false UI evidence.

4. Locked session handling is now correct but blocks completion.
   - The app cannot be visually certified while the session is locked.
   - V2.72 tooling correctly rejects locked/invalid evidence.

5. Guided Cleanup safe links match the planned safety boundary.
   - The loaded flow exposes read-only guidance, app-local metadata messaging, safe next-action rows, and disabled `can apply fix` semantics.
   - The tested safe link opened an existing Skill Map/Lifecycle context instead of applying a cleanup action.
   - This aligns with the V2.67/V2.71 planning boundary.

6. Privacy presentation is inconsistent across evidence surfaces.
   - Review collapses real paths to `$HOME/...`.
   - Guided Cleanup step cards still display an unredacted local source path in the duplicate/source-overlap explanation.
   - This conflicts with the V2.69 path redaction/collapse/reveal goal and means real-local screenshots still cannot be committed safely.

7. Work-surface navigation preserves an old detail scroll offset.
   - Switching from a scrolled Guided Cleanup or Skill Map surface into Review can land the user mid-panel with the page title partly off screen.
   - This makes navigation feel stateful in a surprising way and weakens the cockpit-first IA.

8. Localization and visual density are uneven.
   - Task Cockpit, Guided Cleanup, and Provider Observability primary labels are localized.
   - Local Skill Map and several nested cards still show English titles, descriptions, risk labels, and service metadata.
   - Dense two-column evidence cards are useful for power users but should provide clearer hierarchy, collapse controls, or per-section summaries before long evidence lists.

## Planning Implications

Recommended follow-up line:

- V2.73 Task/Remediation performance and timeout recovery.
- V2.74 Real-local launch/window targeting stability.
- V2.75 Task input and input-method resilience.
- V2.76 Progressive Cockpit feedback and cancel/retry affordances.
- V2.77 Real-local validation workbench.
- V2.78 Evidence-surface privacy and localization sweep.
- V2.79 Detail navigation and visual density polish.

These are planned follow-ups only. They must not be marked completed until code, docs, automated checks, and unlocked real-local Computer Use validation prove completion.
