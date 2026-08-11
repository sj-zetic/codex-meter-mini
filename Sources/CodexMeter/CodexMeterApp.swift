import AppKit
import Combine
import SwiftUI

@main
enum CodexMeterApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        delegate.installStatusItem()
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
    }

    func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 332, height: 440)
        popover.contentViewController = NSHostingController(rootView: UsagePopover(store: store))

        if let button = item.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            button.setAccessibilityLabel("Codex usage")
        }

        Publishers.CombineLatest(store.$state, store.$isRefreshing)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateStatusItem() }
            .store(in: &cancellables)
        updateStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        button.title = " \(store.menuBarText)"
        button.setAccessibilityValue(store.state.snapshot.map {
            guard let window = $0.mostConstrained else { return "Unavailable" }
            if let reset = window.resetsAt {
                return "\(window.remainingPercent) percent remaining, resets in \(ResetCountdownFormatter.string(until: reset))"
            }
            return "\(window.remainingPercent) percent remaining"
        } ?? "Unavailable")

        guard let source = MeterArtwork.image?.copy() as? NSImage else {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: nil)
            return
        }
        source.size = NSSize(width: 18, height: 18)
        source.isTemplate = false
        button.image = source
    }
}
