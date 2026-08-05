import XCTest
@testable import CodexMeter

final class UsageParserTests: XCTestCase {
    func testParsesCodexBucketAndRemainingValues() throws {
        let response: [String: Any] = [
            "result": [
                "rateLimits": ["primary": ["usedPercent": 99]],
                "rateLimitsByLimitId": [
                    "codex": [
                        "planType": "plus",
                        "limitName": "Codex",
                        "primary": ["usedPercent": 23, "resetsAt": 2_000_000_000, "windowDurationMins": 300],
                        "secondary": ["usedPercent": 61, "resetsAt": 2_000_100_000, "windowDurationMins": 10_080],
                        "credits": ["balance": "12.50", "hasCredits": true, "unlimited": false]
                    ]
                ]
            ]
        ]

        let snapshot = try XCTUnwrap(UsageParser.parse(response, now: Date(timeIntervalSince1970: 1)))
        XCTAssertEqual(snapshot.plan, "Plus")
        XCTAssertEqual(snapshot.primary?.remainingPercent, 77)
        XCTAssertEqual(snapshot.secondary?.remainingPercent, 39)
        XCTAssertEqual(snapshot.mostConstrained?.kind, .weekly)
        XCTAssertEqual(snapshot.creditBalance, "12.50")
        XCTAssertEqual(snapshot.fetchedAt, Date(timeIntervalSince1970: 1))
    }

    func testClampsRemainingPercent() throws {
        let response: [String: Any] = ["result": ["rateLimits": ["primary": ["usedPercent": 140]]]]
        XCTAssertEqual(UsageParser.parse(response)?.primary?.remainingPercent, 0)
    }

    func testInfersWeeklyWindowFromDuration() throws {
        let response: [String: Any] = [
            "result": ["rateLimits": ["primary": ["usedPercent": 7, "windowDurationMins": 10_080]]]
        ]
        XCTAssertEqual(UsageParser.parse(response)?.primary?.kind, .weekly)
    }

    func testRejectsMalformedResponse() {
        XCTAssertNil(UsageParser.parse(["result": ["other": true]]))
    }

    func testResetCountdownUsesDaysAndHoursForLongWindows() {
        let now = Date(timeIntervalSince1970: 1_000)
        let reset = now.addingTimeInterval((2 * 86_400) + (3 * 3_600))
        let text = ResetCountdownFormatter.string(until: reset, now: now, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(text.contains("2"))
        XCTAssertTrue(text.contains("3"))
    }

    func testResetCountdownUsesHoursAndMinutesForShortWindows() {
        let now = Date(timeIntervalSince1970: 1_000)
        let reset = now.addingTimeInterval((5 * 3_600) + (12 * 60))
        let text = ResetCountdownFormatter.string(until: reset, now: now, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(text.contains("5"))
        XCTAssertTrue(text.contains("12"))
    }
}
