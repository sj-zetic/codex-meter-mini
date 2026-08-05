import Foundation

struct UsageWindow: Equatable, Identifiable {
    enum Kind: String {
        case session
        case weekly

        var title: String {
            switch self {
            case .session: return "Session limit"
            case .weekly: return "Weekly limit"
            }
        }

        var symbol: String {
            switch self {
            case .session: return "bolt.fill"
            case .weekly: return "calendar"
            }
        }
    }

    let kind: Kind
    let usedPercent: Int
    let resetsAt: Date?
    let durationMinutes: Int?

    var id: String { kind.rawValue }
    var remainingPercent: Int { max(0, min(100, 100 - usedPercent)) }
    var remainingFraction: Double { Double(remainingPercent) / 100 }
}

struct UsageSnapshot: Equatable {
    let plan: String?
    let primary: UsageWindow?
    let secondary: UsageWindow?
    let creditBalance: String?
    let hasCredits: Bool
    let creditIsUnlimited: Bool
    let limitName: String?
    let fetchedAt: Date

    var windows: [UsageWindow] { [primary, secondary].compactMap { $0 } }
    var mostConstrained: UsageWindow? { windows.min { $0.remainingPercent < $1.remainingPercent } }
}

enum UsageState: Equatable {
    case loading
    case ready(UsageSnapshot)
    case signedOut
    case unavailable(String)

    var snapshot: UsageSnapshot? {
        if case .ready(let value) = self { return value }
        return nil
    }
}

enum UsageParser {
    static func parse(_ object: [String: Any], now: Date = Date()) -> UsageSnapshot? {
        guard let result = object["result"] as? [String: Any] else { return nil }

        let buckets = result["rateLimitsByLimitId"] as? [String: Any]
        let preferred = (buckets?["codex"] as? [String: Any])
            ?? buckets?.values.compactMap { $0 as? [String: Any] }.first
        guard let limits = preferred ?? result["rateLimits"] as? [String: Any] else { return nil }

        return UsageSnapshot(
            plan: prettifyPlan(limits["planType"] as? String),
            primary: parseWindow(limits["primary"], kind: .session),
            secondary: parseWindow(limits["secondary"], kind: .weekly),
            creditBalance: (limits["credits"] as? [String: Any])?["balance"] as? String,
            hasCredits: (limits["credits"] as? [String: Any])?["hasCredits"] as? Bool ?? false,
            creditIsUnlimited: (limits["credits"] as? [String: Any])?["unlimited"] as? Bool ?? false,
            limitName: limits["limitName"] as? String,
            fetchedAt: now
        )
    }

    private static func parseWindow(_ value: Any?, kind: UsageWindow.Kind) -> UsageWindow? {
        guard let dictionary = value as? [String: Any],
              let used = number(dictionary["usedPercent"]) else { return nil }
        let reset = number(dictionary["resetsAt"]).map { Date(timeIntervalSince1970: $0) }
        let duration = number(dictionary["windowDurationMins"]).map(Int.init)
        let inferredKind: UsageWindow.Kind
        if let duration {
            inferredKind = duration >= 1_440 ? .weekly : .session
        } else {
            inferredKind = kind
        }
        return UsageWindow(kind: inferredKind, usedPercent: Int(used), resetsAt: reset, durationMinutes: duration)
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func prettifyPlan(_ plan: String?) -> String? {
        guard let plan else { return nil }
        switch plan {
        case "plus": return "Plus"
        case "pro": return "Pro"
        case "team": return "Team"
        case "business", "self_serve_business_usage_based": return "Business"
        case "enterprise", "enterprise_cbp_usage_based": return "Enterprise"
        case "edu": return "Education"
        case "free": return "Free"
        case "go": return "Go"
        case "prolite": return "Pro Lite"
        default: return plan.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

enum ResetCountdownFormatter {
    static func string(until resetAt: Date, now: Date = Date(), locale: Locale = .autoupdatingCurrent) -> String {
        let remaining = resetAt.timeIntervalSince(now)
        guard remaining > 0 else { return String(localized: "now") }

        let roundedToMinute = max(60, ceil(remaining / 60) * 60)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar

        switch roundedToMinute {
        case 86_400...:
            formatter.allowedUnits = [.day, .hour]
        case 3_600...:
            formatter.allowedUnits = [.hour, .minute]
        default:
            formatter.allowedUnits = [.minute]
        }

        return formatter.string(from: roundedToMinute) ?? String(localized: "soon")
    }
}
