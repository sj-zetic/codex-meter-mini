# Codex Meter

<p align="center">
  <img src="Sources/CodexMeter/Resources/CodexIcon.png" width="128" alt="Codex Meter app icon">
</p>

An unofficial, native macOS menu-bar utility that shows the remaining usage for the ChatGPT account currently signed in to Codex.

> [!IMPORTANT]
> Codex Meter is an independent community project. It is not affiliated with, sponsored by, or endorsed by OpenAI.

## What it shows

- The remaining percentage and reset countdown in the menu bar.
- Session and weekly rolling limits in an accessible SwiftUI popover.
- The account plan and credit balance when the local Codex service provides them.
- Automatic refresh every minute by default, with 15-second and 5-minute options.

The menu-bar percentage is the **most constrained available limit**: whichever reported window has the lowest remaining percentage. Open the popover to see every available window separately.

## Compatibility notice

Codex Meter launches the locally installed `codex app-server` and reads `account/rateLimits/read`. This interface is experimental and is not a public compatibility promise. A ChatGPT or Codex update may temporarily break the app.

## Privacy

Codex Meter has no analytics, advertising, or independent network client. It communicates with a local `codex app-server` process and keeps returned usage information in memory. The selected refresh interval is stored in macOS `UserDefaults`.

The local Codex process may communicate with OpenAI as part of its normal operation. Codex Meter does not read or store browser cookies, access tokens, API keys, or conversation content.

## Requirements

- macOS 13 or later.
- ChatGPT, Codex, or the Codex CLI installed and signed in.
- Swift 5.9 or later when building from source.
- A full Xcode installation when running the XCTest suite. Command Line Tools alone may not include XCTest.

Codex Meter looks for the executable in the ChatGPT and Codex application bundles, Homebrew locations, and the current `PATH`.

## Build and run

```sh
git clone https://github.com/sj-zetic/codex-meter.git
cd codex-meter
make test
make app
open "dist/Codex Meter.app"
```

The locally built app is ad-hoc signed. macOS may ask you to confirm the first launch. Public binary distribution requires Developer ID signing and Apple notarization.

## Troubleshooting

### The menu item is missing

- Codex Meter automatically restores its status item after a monitor is connected or disconnected. If it does not return within a second, quit and reopen the app and include your display setup in a bug report.
- Check whether the camera notch or other menu-bar items have pushed it out of view.
- Temporarily close another menu-bar utility to make room.

### Usage is unavailable

- Open ChatGPT or Codex and confirm that you are signed in.
- Confirm that `codex` is installed at one of the supported locations or available on `PATH`.
- Click **Try Again** or use the refresh button after signing in.

### A Codex update broke the app

Open a bug report with your macOS version, Codex or ChatGPT version, installation method, and the visible error message. Never include tokens, cookies, or other credentials.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request, and use [SECURITY.md](SECURITY.md) for vulnerability reports.

## License and trademarks

The source code and original Codex Meter artwork are available under the [MIT License](LICENSE).

OpenAI, ChatGPT, and Codex are trademarks of OpenAI. Their use here is solely to identify compatibility with the relevant service. No OpenAI logos or artwork are distributed by this project.
