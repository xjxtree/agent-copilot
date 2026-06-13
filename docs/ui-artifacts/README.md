# UI Artifacts

This directory stores UI prototypes, completed screenshots, and verification notes.

Use one folder per major version or major feature:

```text
docs/ui-artifacts/
└── <feature-or-version>/
    ├── brief.md
    ├── prototype.png
    ├── prototype-notes.md
    ├── completed.png
    └── verification.md
```

Rules:

- Create or update prototype artifacts before implementation starts.
- Update completed screenshots after development and validation.
- Completed screenshots must be complete app-window-only captures. Use `script/capture_app_window.sh` for macOS artifacts. Do not use full-desktop screenshots.
- Run `pnpm verify:screenshot-artifacts` after adding or regenerating PNG evidence. It rejects unreadable, near-black, mostly transparent, near-flat, or binary-string-sensitive screenshots, but it does not perform OCR.
- App screenshots should be taken with screenshot privacy mode enabled unless a maintainer explicitly needs full paths for local debugging; do not commit screenshots with raw local paths.
- Record macOS Computer Use verification for every code change that affects runtime behavior.
- Future Windows/Linux shells should keep their own completed screenshots while sharing the same service fixtures and UX contracts.

Current artifacts:

- `service-protocol/brief.md`: first typed JSON service boundary brief.
- `native-macos-shell/brief.md`: first native macOS shell brief.
- `native-macos-shell/prototype-notes.md`: first split-view prototype notes.
- `native-macos-shell/completed.png`: completed screenshot after launch and interaction validation.
- `native-macos-shell/verification.md`: macOS Computer Use verification record.
- `v2.68-task-cockpit-ia/brief.md`: cockpit-first IA feature brief.
- `v2.68-task-cockpit-ia/completed.png`: fixture app-window screenshot for V2.68.
- `v2.68-task-cockpit-ia/prototype-notes.md`: V2.68 IA notes.
- `v2.68-task-cockpit-ia/verification.md`: V2.68 command and screenshot verification record.
- `v2.69-privacy-screenshot-mode/brief.md`: V2.69 screenshot privacy and localization brief.
- `v2.69-privacy-screenshot-mode/completed.png`: pending; V2.69 locked-session capture failed closed and no fresh screenshot was committed.
- `v2.69-privacy-screenshot-mode/prototype-notes.md`: V2.69 implementation notes.
- `v2.69-privacy-screenshot-mode/verification.md`: V2.69 command and screenshot verification record.
