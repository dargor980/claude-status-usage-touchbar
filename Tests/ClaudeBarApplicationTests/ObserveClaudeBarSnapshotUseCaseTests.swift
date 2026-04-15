import XCTest
@testable import ClaudeBarApplication
@testable import ClaudeBarDomain

final class ObserveClaudeBarSnapshotUseCaseTests: XCTestCase {
    func testBuildsEstimatedGaugesAndUsesCompletedTaskFallback() throws {
        let now = ISO8601DateFormatter().date(from: "2026-04-14T15:00:00Z")!
        let sessionStart = ISO8601DateFormatter().date(from: "2026-04-14T12:00:00Z")!

        let session = SessionSnapshot(
            sessionId: "session-1",
            projectPath: "/tmp/demo",
            currentWorkingDirectory: "/tmp/demo",
            startedAt: sessionStart,
            lastActivityAt: now,
            isActive: true,
            ideName: "Visual Studio Code",
            remoteURL: nil
        )

        let completedTask = TaskSnapshot(
            title: "Run tests foreground",
            detail: "Exit code 0",
            state: .completed,
            source: .background,
            steps: ["Bash"],
            startedAt: nil,
            finishedAt: now
        )

        let repository = StubRepository(
            result: ClaudeActivity(
                activeSession: session,
                sessionConsumedTokens: 600_000,
                weeklyConsumedTokens: 3_000_000,
                activeTask: nil,
                lastCompletedTask: completedTask,
                notices: []
            )
        )

        let policyProvider = DefaultUsagePolicyProvider(
            sessionTokenBudget: 2_000_000,
            sessionWindowHours: 5,
            weeklyTokenBudget: 12_000_000,
            weeklyResetWeekday: 2
        )

        let useCase = ObserveClaudeBarSnapshotUseCase(repository: repository, usagePolicyProvider: policyProvider)
        let snapshot = try useCase.execute(now: now)

        XCTAssertEqual(snapshot.currentSession.accuracy, .estimated)
        XCTAssertEqual(snapshot.currentSession.percentage, 0.3, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentWeek.percentage, 0.25, accuracy: 0.0001)
        XCTAssertEqual(snapshot.task?.state, .completed)
        XCTAssertEqual(snapshot.task?.title, "Run tests foreground")
        XCTAssertEqual(snapshot.currentSession.resetAt, sessionStart.addingTimeInterval(18_000))
    }
}

private struct StubRepository: ClaudeActivityRepository {
    let result: ClaudeActivity

    func loadActivity(now: Date) throws -> ClaudeActivity {
        result
    }
}
