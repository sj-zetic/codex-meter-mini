.PHONY: build test app install uninstall clean

SWIFT_FLAGS ?=

build:
	swift build -c release $(SWIFT_FLAGS)

test:
	swift test $(SWIFT_FLAGS)

app: build
	mkdir -p "dist/Codex Meter.app/Contents/MacOS" "dist/Codex Meter.app/Contents/Resources"
	cp .build/release/CodexMeter "dist/Codex Meter.app/Contents/MacOS/CodexMeter"
	cp Resources/Info.plist "dist/Codex Meter.app/Contents/Info.plist"
	cp Sources/CodexMeter/Resources/CodexIcon.png "dist/Codex Meter.app/Contents/Resources/CodexIcon.png"
	xattr -cr "dist/Codex Meter.app"
	codesign --force --deep --sign - "dist/Codex Meter.app"

install: app
	ditto "dist/Codex Meter.app" "/Applications/Codex Meter.app"
	mkdir -p "$(HOME)/Library/LaunchAgents"
	cp Resources/com.seongjun.codexmeter.plist "$(HOME)/Library/LaunchAgents/com.seongjun.codexmeter.plist"
	launchctl bootout "gui/$$(id -u)/com.seongjun.codexmeter" 2>/dev/null || true
	launchctl bootstrap "gui/$$(id -u)" "$(HOME)/Library/LaunchAgents/com.seongjun.codexmeter.plist"

uninstall:
	launchctl bootout "gui/$$(id -u)/com.seongjun.codexmeter" 2>/dev/null || true
	rm -f "$(HOME)/Library/LaunchAgents/com.seongjun.codexmeter.plist"
	rm -rf "/Applications/Codex Meter.app"

clean:
	swift package clean
	rm -rf dist
