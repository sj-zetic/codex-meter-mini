import AppKit
import Combine
import Foundation

@MainActor
final class UsageStore: NSObject, ObservableObject {
    @Published private(set) var state: UsageState = .loading
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            scheduleRefresh()
        }
    }

    private let service = CodexUsageService()
    private var timer: Timer?

    override init() {
        let stored = UserDefaults.standard.double(forKey: "refreshInterval")
        refreshInterval = stored > 0 ? stored : 60
        super.init()
        service.onSnapshot = { [weak self] snapshot in
            self?.state = .ready(snapshot)
            self?.isRefreshing = false
            self?.lastError = nil
        }
        service.onFailure = { [weak self] message in
            guard let self else { return }
            if self.state.snapshot == nil {
                let normalized = message.lowercased()
                if normalized.contains("login") || normalized.contains("sign in") || normalized.contains("unauthorized") {
                    self.state = .signedOut
                } else {
                    self.state = .unavailable(message)
                }
            } else {
                self.lastError = message
            }
            self.isRefreshing = false
        }
        service.connect()
        scheduleRefresh()
    }

    var menuBarText: String {
        guard let window = state.snapshot?.mostConstrained else { return "—" }
        guard let resetsAt = window.resetsAt else { return "\(window.remainingPercent)%" }
        let countdown = ResetCountdownFormatter.string(until: resetsAt)
        return "\(window.remainingPercent)% · \(countdown)"
    }

    var compactMenuBarText: String {
        guard let window = state.snapshot?.mostConstrained else { return "—" }
        guard let resetsAt = window.resetsAt else { return "\(window.remainingPercent)%" }
        let countdown = ResetCountdownFormatter.string(until: resetsAt)
        let firstUnit = countdown.split(whereSeparator: \Character.isWhitespace).first.map(String.init) ?? countdown
        return "\(window.remainingPercent)% · \(firstUnit)"
    }

    var minimalMenuBarText: String {
        guard let window = state.snapshot?.mostConstrained else { return "—" }
        return "\(window.remainingPercent)%"
    }

    var menuBarSymbol: String {
        guard let percentage = state.snapshot?.mostConstrained?.remainingPercent else { return "gauge.with.dots.needle.33percent" }
        if percentage <= 10 { return "exclamationmark.circle.fill" }
        if percentage <= 30 { return "gauge.with.dots.needle.67percent" }
        return "gauge.with.dots.needle.33percent"
    }

    func refresh() {
        isRefreshing = true
        service.refresh()
    }

    func retry() {
        state = .loading
        refresh()
    }

    func quit() { NSApplication.shared.terminate(nil) }

    private func scheduleRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: refreshInterval,
            target: self,
            selector: #selector(refreshTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = min(5, refreshInterval * 0.1)
    }

    @objc private func refreshTimerFired(_ timer: Timer) {
        refresh()
    }
}
