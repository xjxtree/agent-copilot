# Real Local App Audit 2026-06-15

Scope: current `main` at `d61791ae`, current bundle `dist/SkillsCopilot.app`, launched with `./script/build_and_run.sh --verify`.

## Evidence

- Build/run: current app bundle rebuilt and launched successfully.
- Session state: `CGSSessionScreenIsLocked=1`; reliable screenshots and Computer Use interaction are blocked until unlock.
- Computer Use: absolute app path returned `cgWindowNotFound` while locked.
- Capture helper: `script/capture_app_window.sh` failed closed with `locked-session`.
- Classifier: `pnpm classify:validation-blocker` mapped `cgWindowNotFound` to `window-not-found` and lock output to `locked-session`.
- Earlier same-session unlocked window observation reached the Task Cockpit first screen and captured UI tree/screenshot evidence before lock state returned.
- Current rerun: direct `task.buildCockpit` RPC against the rebuilt app bundle produced no stdout/stderr within 10 seconds before termination.

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

## Planning Implications

Recommended follow-up line:

- V2.73 Task/Remediation performance and timeout recovery.
- V2.74 Real-local launch/window targeting stability.
- V2.75 Task input and input-method resilience.
- V2.76 Progressive Cockpit feedback and cancel/retry affordances.
- V2.77 Real-local validation workbench.

These are planned follow-ups only. They must not be marked completed until code, docs, automated checks, and unlocked real-local Computer Use validation prove completion.
