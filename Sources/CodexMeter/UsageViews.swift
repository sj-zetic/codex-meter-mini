import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 4) {
            if let icon = MeterArtwork.image {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .accessibilityHidden(true)
            }
            Text(store.menuBarText)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Codex usage")
        .accessibilityValue(store.state.snapshot.map { "\($0.mostConstrained?.remainingPercent ?? 0) percent remaining" } ?? "Unavailable")
    }
}

struct UsagePopover: View {
    @ObservedObject var store: UsageStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 332)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            MeterIcon(size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Codex Usage").font(.headline)
                if let plan = store.state.snapshot?.plan {
                    Text("ChatGPT \(plan)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Live account limits").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: store.refresh) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.isRefreshing && !reduceMotion ? 360 : 0))
                    .animation(store.isRefreshing && !reduceMotion ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
            }
            .buttonStyle(.borderless)
            .help("Refresh usage")
            .disabled(store.isRefreshing)
            .accessibilityLabel(store.isRefreshing ? "Refreshing usage" : "Refresh usage")
        }
        .padding(14)
    }

    @ViewBuilder private var content: some View {
        switch store.state {
        case .loading:
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Checking your limits…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 210)
        case .ready(let snapshot):
            UsageDetails(snapshot: snapshot, syncError: store.lastError)
                .padding(14)
        case .signedOut:
            EmptyState(
                symbol: "person.crop.circle.badge.exclamationmark",
                title: "Sign in to Codex",
                message: "Open Codex and sign in with your ChatGPT account, then try again.",
                action: store.retry
            )
        case .unavailable(let message):
            EmptyState(
                symbol: "exclamationmark.triangle",
                title: "Usage unavailable",
                message: message,
                action: store.retry
            )
        }
    }

    private var footer: some View {
        HStack {
            Menu {
                Picker("Refresh interval", selection: $store.refreshInterval) {
                    Text("Every 15 seconds").tag(TimeInterval(15))
                    Text("Every minute").tag(TimeInterval(60))
                    Text("Every 5 minutes").tag(TimeInterval(300))
                }
            } label: {
                Label("Refresh", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()
            Button("Quit Codex Meter", action: store.quit)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct UsageDetails: View {
    let snapshot: UsageSnapshot
    let syncError: String?

    var body: some View {
        VStack(spacing: 14) {
            if let primary = snapshot.primary {
                HeroGauge(window: primary)
            }

            VStack(spacing: 8) {
                ForEach(snapshot.windows) { window in
                    LimitRow(window: window)
                }
            }

            HStack {
                Label(syncError == nil ? statusText : "Last sync failed", systemImage: syncError == nil ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(syncError == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                    .help(syncError ?? "Usage is up to date")
                Spacer()
                Text(snapshot.fetchedAt, style: .relative)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Updated \(snapshot.fetchedAt.formatted(.relative(presentation: .named)))")
            }
            .font(.caption)
        }
    }

    private var statusText: String {
        if snapshot.creditIsUnlimited { return "Credits unlimited" }
        if let balance = snapshot.creditBalance { return "\(balance) credits" }
        return "Synced securely"
    }
}

private struct HeroGauge: View {
    let window: UsageWindow

    var body: some View {
        HStack(spacing: 16) {
            Gauge(value: window.remainingFraction) {
                Text("Remaining")
            } currentValueLabel: {
                Text("\(window.remainingPercent)%")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(meterColor)
            .frame(width: 70, height: 70)
            .accessibilityLabel(window.kind.title)
            .accessibilityValue("\(window.remainingPercent) percent remaining")

            VStack(alignment: .leading, spacing: 4) {
                Text("\(window.remainingPercent)% remaining")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(resetDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let duration = window.durationMinutes {
                    Text(durationLabel(duration))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var meterColor: Color {
        if window.remainingPercent <= 10 { return .red }
        if window.remainingPercent <= 30 { return .orange }
        return .accentColor
    }

    private var resetDescription: String {
        guard let reset = window.resetsAt else { return "Reset time unavailable" }
        return "Resets \(reset.formatted(.relative(presentation: .named)))"
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes >= 1_440 { return "\(minutes / 1_440)-day rolling window" }
        if minutes >= 60 { return "\(minutes / 60)-hour rolling window" }
        return "\(minutes)-minute rolling window"
    }
}

private struct LimitRow: View {
    let window: UsageWindow

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Label(window.kind.title, systemImage: window.kind.symbol)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(window.remainingPercent)% left")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }
            ProgressView(value: window.remainingFraction)
                .tint(color)
                .accessibilityLabel(window.kind.title)
                .accessibilityValue("\(window.remainingPercent) percent remaining")
            HStack {
                Text(resetText)
                Spacer()
                Text("\(window.usedPercent)% used")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private var resetText: String {
        guard let date = window.resetsAt else { return "Reset unavailable" }
        return "Resets \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private var color: Color {
        if window.remainingPercent <= 10 { return .red }
        if window.remainingPercent <= 30 { return .orange }
        return .accentColor
    }
}

private struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try Again", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 210)
    }
}
