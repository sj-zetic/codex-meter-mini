# Codex Meter

A native macOS menu-bar utility that shows the remaining Codex usage for the ChatGPT account already signed into Codex.

## Privacy

Codex Meter talks only to the local `codex app-server` process. It does not read, copy, or store browser cookies, access tokens, API keys, or conversation content. Usage is refreshed every minute by default and the interval can be changed in the popover.

## Requirements

- macOS 13 or later
- ChatGPT or Codex installed and signed in
- Swift 5.9 or later to build

## Build and run

```sh
make app
open "dist/Codex Meter.app"
```

The built app is ad-hoc signed for local use. For distribution, use your Developer ID identity and Apple notarization.
