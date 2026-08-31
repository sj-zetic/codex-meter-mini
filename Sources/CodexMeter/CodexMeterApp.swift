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
    private static let statusItemAutosaveName = "CodexMeterStatusItem"
    private static let preferredPositionKey = "NSStatusItem Preferred Position \(statusItemAutosaveName)"

    private enum MenuBarDensity: Int {
        case full
        case compact
        case minimal
        case iconOnly

        var next: MenuBarDensity? {
            MenuBarDensity(rawValue: rawValue + 1)
        }
    }

    private let store = UsageStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var isObservingStore = false
    private var isObservingDisplayChanges = false
    private var menuBarDensity = MenuBarDensity.full

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        observeDisplayChangesIfNeeded()
        scheduleStatusItemRecovery(resetDensity: false)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        scheduleStatusItemRecovery(resetDensity: false)
    }

    func installStatusItem() {
        guard statusItem == nil else { return }
        if UserDefaults.standard.object(forKey: Self.preferredPositionKey) == nil {
            UserDefaults.standard.set(280, forKey: Self.preferredPositionKey)
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = Self.statusItemAutosaveName
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

        observeStoreIfNeeded()
        updateStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(recoverStatusItemAfterDisplayChange),
            object: nil
        )
        NotificationCenter.default.removeObserver(self)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    private func observeStoreIfNeeded() {
        guard isObservingStore == false else { return }
        isObservingStore = true
        Publishers.CombineLatest(store.$state, store.$isRefreshing)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateStatusItem() }
            .store(in: &cancellables)
    }

    private func observeDisplayChangesIfNeeded() {
        guard isObservingDisplayChanges == false else { return }
        isObservingDisplayChanges = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func displayConfigurationDidChange(_ notification: Notification) {
        scheduleStatusItemRecovery(resetDensity: true)
    }

    private func scheduleStatusItemRecovery(resetDensity: Bool) {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(recoverStatusItemAfterDisplayChange),
            object: nil
        )
        if resetDensity {
            menuBarDensity = .full
            updateStatusItem()
        }
        for delay in [0.5, 1.5, 3.0, 6.0] {
            perform(#selector(recoverStatusItemAfterDisplayChange), with: nil, afterDelay: delay)
        }
    }

    @objc private func recoverStatusItemAfterDisplayChange() {
        guard statusItemIsOnActiveScreen == false else {
            statusItem?.isVisible = true
            updateStatusItem()
            return
        }

        if let nextDensity = menuBarDensity.next {
            menuBarDensity = nextDensity
            updateStatusItem()
            statusItem?.isVisible = true
            return
        }

        popover.performClose(nil)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
        installStatusItem()
        statusItem?.isVisible = true
    }

    private var statusItemIsOnActiveScreen: Bool {
        guard let windowFrame = statusItem?.button?.window?.frame else { return false }
        return NSScreen.screens.contains { screen in
            let intersection = screen.frame.intersection(windowFrame)
            return intersection.width >= min(windowFrame.width, 24)
                && intersection.height >= min(windowFrame.height, 12)
        }
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
        let title: String
        switch menuBarDensity {
        case .full: title = store.menuBarText
        case .compact: title = store.compactMenuBarText
        case .minimal: title = store.minimalMenuBarText
        case .iconOnly: title = ""
        }
        statusItem?.length = menuBarDensity == .iconOnly
            ? NSStatusItem.squareLength
            : NSStatusItem.variableLength
        button.title = title.isEmpty ? "" : " \(title)"
        button.toolTip = "Codex usage: \(store.menuBarText)"
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
