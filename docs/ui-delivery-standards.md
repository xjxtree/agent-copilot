# UI Delivery Standards

> Status: **mandatory for product work**. These standards apply to every major version, major feature, UI-facing workflow, bug fix that changes behavior, and macOS app run/check work.

## 1. Product UI Target

The only maintained product UI shell is the native macOS app:

- Location: `apps/macos/`
- Stack: SwiftUI + AppKit interop
- Runtime access: Rust service protocol only
- Visual system: native macOS controls first, Liquid Glass only on functional surfaces

The old Tauri/React UI has been removed. Do not recreate `ui/`, `src-tauri/`, or Tauri IPC for product work.

## 2. Prototype Before Build

Before every major version or major feature starts:

- Add or update a UI prototype artifact.
- Define the target shell: macOS native now; future Windows/Linux shell only after macOS parity.
- Document the user flow, states, data dependencies, empty/error/loading states, keyboard flow, and accessibility concerns.
- Record expected screenshots or wireframes for desktop and minimum supported window size.

Recommended artifact layout:

```text
docs/ui-artifacts/
└── <feature-or-version>/
    ├── brief.md
    ├── prototype.png
    ├── prototype-notes.md
    ├── completed.png
    └── verification.md
```

If the prototype is text-only at first, `prototype-notes.md` must still describe the layout clearly enough to implement and review.

## 3. Completed UI Evidence

After development and test verification:

- Update the completed UI screenshot for every changed high-level view.
- Completed screenshots must capture the complete app window only. Full-desktop screenshots are forbidden.
- For macOS artifacts, use `script/capture_app_window.sh` where possible. It performs a window-id capture for the target app window. If a region capture is unavoidable, crop strictly to the app window bounds and verify no desktop, wallpaper, menu bar, Dock, or unrelated window is visible.
- Update `verification.md` with the app build, date, tested flows, and known gaps.
- If the finished UI intentionally differs from the prototype, document the reason.
- Do not mark a UI feature complete if the latest completed screenshot is stale.

## 4. Required macOS App Verification

Every task that changes code must be verified by launching the macOS app and operating the affected behavior with macOS Computer Use before the task is considered complete, but only when the macOS session is confirmed unlocked and interactive.

This includes:

- Feature work
- Bug fixes
- Refactors that can affect runtime behavior
- App run/check or version metadata work
- Service protocol changes
- Native macOS UI changes

Documentation-only changes are exempt. If the app cannot be launched, the macOS session is locked or not clearly interactive, or Computer Use returns `remoteConnection`, `cgWindowNotFound`, or activation errors, record the blocker and do not claim runtime verification.

Minimum verification record:

- App build or launch command
- Screens or flows operated
- Result
- Screenshot path when UI changed
- Known gaps

## 5. Cross-platform UI Compatibility

Future Windows/Linux UI shells should not copy macOS implementation code. They should align through:

- Rust service protocol
- Shared request/response fixtures
- Shared view model vocabulary
- Shared information architecture
- Shared design tokens and interaction principles
- Per-platform native controls
- Per-platform completed UI screenshots

The compatibility target is consistent capability and mental model, not pixel-perfect sameness.

## 6. Pull Request Checklist Additions

> 下面是每次 PR / 任务完成时复制使用的模板项；保持未勾选是刻意的，不代表当前项目进度遗漏。

For code changes:

- [ ] I launched the macOS app and operated the affected flow with macOS Computer Use.
- [ ] I recorded the verification result.

For UI changes:

- [ ] I updated or added the prototype artifact before implementation.
- [ ] I updated the completed UI screenshot after implementation, using a complete app-window-only capture.
- [ ] I checked minimum window size, keyboard flow, and accessibility-sensitive settings where relevant.
