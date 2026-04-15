import XCTest
@testable import ClaudeBarApplication
@testable import ClaudeBarDomain

final class BuildTouchBarBridgePayloadUseCaseTests: XCTestCase {
    func testBuildsCompactPayloadForBetterTouchTool() {
        let now = ISO8601DateFormatter().date(from: "2026-04-15T03:00:00Z")!

        let snapshot = ClaudeBarSnapshot(
            observedAt: now,
            session: SessionSnapshot(
                sessionId: "session-bridge",
                projectPath: "/Users/germancontreras/claude-status-usage-touchbar",
                currentWorkingDirectory: "/Users/germancontreras/claude-status-usage-touchbar",
                startedAt: now.addingTimeInterval(-1800),
                lastActivityAt: now,
                isActive: true,
                ideName: "Visual Studio Code",
                remoteURL: "https://claude.ai/code/session-bridge"
            ),
            currentSession: UsageGauge(
                title: "Sesion actual",
                consumedTokens: 0,
                budgetTokens: 0,
                percentage: 0.42,
                resetAt: now.addingTimeInterval(3600),
                accuracy: .exact
            ),
            currentWeek: UsageGauge(
                title: "Semana",
                consumedTokens: 0,
                budgetTokens: 0,
                percentage: 0.61,
                resetAt: now.addingTimeInterval(86_400),
                accuracy: .exact
            ),
            task: TaskSnapshot(
                title: "Implementar bridge BTT",
                detail: "scripts + payload",
                state: .running,
                source: .plan,
                steps: ["Read", "Edit"],
                startedAt: now.addingTimeInterval(-600),
                finishedAt: nil
            ),
            notices: []
        )

        let payload = BuildTouchBarBridgePayloadUseCase().execute(snapshot: snapshot, now: now)

        XCTAssertEqual(payload.compactTitle, "claudeBar 5h 42% · 7d 61%")
        XCTAssertEqual(payload.compactTask, "claude-status-usage-touchbar · Implementar bridge BTT")
        XCTAssertTrue(payload.resumeAvailable)
        XCTAssertEqual(payload.resumeURL, "https://claude.ai/code/session-bridge")
        XCTAssertEqual(payload.session?.projectName, "claude-status-usage-touchbar")
    }
}
