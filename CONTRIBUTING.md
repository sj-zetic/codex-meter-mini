# Contributing to Codex Meter

Thanks for helping improve Codex Meter. Small, focused pull requests are easiest to review.

## Before you start

- Search existing issues before opening a new one.
- Open an issue before making a large behavior, architecture, or visual-design change.
- Do not include credentials, account data, or output containing private user information.
- Keep the project independent. Do not modify, relicense, or add third-party artwork without documenting its provenance and applicable terms.

## Development setup

You need macOS 13 or later, Swift 5.9 or later, a full Xcode installation for XCTest, and a local Codex installation for live usage testing.

```sh
git clone https://github.com/sj-zetic/codex-meter.git
cd codex-meter
swift test
make app
open "dist/Codex Meter.app"
```

## Pull requests

1. Create a branch from `main`.
2. Keep changes scoped to one concern.
3. Add or update tests for parsing and non-UI behavior.
4. Run `swift test` and `swift build -c release`.
5. Describe user-visible changes and manual testing in the pull request.

## Manual quality checklist

- The status item appears after launch and after reconnecting a display.
- The menu-bar value matches the lowest remaining reported limit.
- Session and weekly reset times are understandable.
- Manual refresh and every supported refresh interval work.
- Loading, signed-out, unavailable, and stale-data states remain usable.
- VoiceOver labels communicate percentage, reset time, and button purpose.
- Reduce Motion is respected.
- Light mode, dark mode, increased contrast, and common text sizes remain legible.
- The app quits cleanly without leaving a `codex app-server` child process.

## Code style

- Prefer native AppKit and SwiftUI APIs over new dependencies.
- Keep account-service parsing separate from presentation code.
- Treat the local app-server response as untrusted input and fail safely.
- Preserve backward compatibility where practical because the local interface is experimental.

By contributing, you agree that your contribution is licensed under the MIT License. This does not apply to third-party material identified in `THIRD_PARTY_NOTICES.md`.
