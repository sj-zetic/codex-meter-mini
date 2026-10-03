import Foundation

enum CodexExecutableLocator {
    static func locate(
        path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> String? {
        let applications = ["/Applications/ChatGPT.app", "/Applications/Codex.app"]
        // Prefer the packaged launcher, which can set up the CLI environment.
        // Retain both the nested binary and legacy layout as fallbacks.
        let layouts = [
            "Contents/Resources/codex-cli/bin/codex",
            "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "Contents/Resources/codex"
        ]
        let bundled = applications.flatMap { app in layouts.map { "\(app)/\($0)" } }
        let candidates = bundled + ["/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
            + path.split(separator: ":").map { "\($0)/codex" }
        return candidates.first(where: isExecutable)
    }
}
