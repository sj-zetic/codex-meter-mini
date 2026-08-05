.PHONY: build test app clean

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

clean:
	swift package clean
	rm -rf dist
