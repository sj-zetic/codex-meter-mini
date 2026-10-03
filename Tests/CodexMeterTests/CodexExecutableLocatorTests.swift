import XCTest
@testable import CodexMeter

final class CodexExecutableLocatorTests: XCTestCase {
    func testFindsLauncherInUpdatedDesktopApps() {
        for app in ["ChatGPT", "Codex"] {
            let launcher = "/Applications/\(app).app/Contents/Resources/codex-cli/bin/codex"
            XCTAssertEqual(CodexExecutableLocator.locate(path: "", isExecutable: { $0 == launcher }), launcher)
        }
    }

    func testPrefersLauncherOverNestedAndLegacyExecutables() {
        let root = "/Applications/ChatGPT.app/Contents/Resources/"
        let executables = Set([
            root + "codex-cli/bin/codex",
            root + "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            root + "codex"
        ])
        XCTAssertEqual(
            CodexExecutableLocator.locate(path: "", isExecutable: executables.contains),
            root + "codex-cli/bin/codex"
        )
    }

    func testFallsBackWhenLauncherIsMissingOrNotExecutable() {
        for executable in [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/custom/bin/codex"
        ] {
            XCTAssertEqual(
                CodexExecutableLocator.locate(path: "/custom/bin", isExecutable: { $0 == executable }),
                executable
            )
        }
    }

    func testReturnsNilIfNoExecutableExists() {
        XCTAssertNil(CodexExecutableLocator.locate(path: "", isExecutable: { _ in false }))
    }
}
