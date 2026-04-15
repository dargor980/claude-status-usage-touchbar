import XCTest
@testable import ClaudeBarApplication
@testable import ClaudeBarDomain

final class ObserveClaudeBarSnapshotUseCaseExactUsageTests: XCTestCase {
    func testPrefersExactUsageWhenProviderReturnsWindows() throws {
        let now = ISO8601DateFormatter().date(from: "2026-04-15T12:00:00Z")!
        let sessionStart = ISO8601DateFormatter().date(from: "2026-04-15T09:00:00Z")!
        let exactSessionReset = ISO8601DateFormatter().date(from: "2026-04-15T14:00:00Z")!
        let exactWeekReset = ISO8601DateFormatter().date(from: "2026-04-20T03:00:00Z")!

        let repository = ExactUsageStubRepository(
            result: ClaudeActivity(
                activeSession: SessionSnapshot(
                    sessionId: "session-2",
                    projectPath: "/tmp/demo",
                    currentWorkingDirectory: "/tmp/demo",
                    startedAt: sessionStart,
                    lastActivityAt: now,
                    isActive: true,
                    ideName: "Visual Studio Code",
                    remoteURL: nil
                ),
                sessionConsumedTokens: 900_000,
                weeklyConsumedTokens: 4_200_000,
                activeTask: nil,
                lastCompletedTask: nil,
                notices: []
            )
        )

        let useCase = ObserveClaudeBarSnapshotUseCase(
            repository: repository,
            usagePolicyProvider: DefaultUsagePolicyProvider(),
            usageProvider: ExactUsageStubProvider(
                result: ClaudeUsageSnapshot(
                    currentSession: ClaudeUsageWindowSnapshot(percentage: 0.42, resetAt: exactSessionReset),
                    currentWeek: ClaudeUsageWindowSnapshot(percentage: 0.61, resetAt: exactWeekReset),
                    source: .statusLineCapture
                )
            )
        )

        let snapshot = try useCase.execute(now: now)

        XCTAssertEqual(snapshot.currentSession.accuracy, .exact)
        XCTAssertEqual(snapshot.currentWeek.accuracy, .exact)
        XCTAssertEqual(snapshot.currentSession.percentage, 0.42, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentWeek.percentage, 0.61, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentSession.resetAt, exactSessionReset)
        XCTAssertEqual(snapshot.currentWeek.resetAt, exactWeekReset)
        XCTAssertEqual(snapshot.currentSession.budgetTokens, 0)
        XCTAssertEqual(snapshot.currentWeek.budgetTokens, 0)
        XCTAssertTrue(snapshot.notices.contains { $0.contains("Uso exacto activo desde captura de status line") })
    }

    func testFallsBackToEstimatedUsageWhenExactProviderFails() throws {
        let now = ISO8601DateFormatter().date(from: "2026-04-15T12:00:00Z")!
        let sessionStart = ISO8601DateFormatter().date(from: "2026-04-15T10:00:00Z")!

        let repository = ExactUsageStubRepository(
            result: ClaudeActivity(
                activeSession: SessionSnapshot(
                    sessionId: "session-3",
                    projectPath: "/tmp/demo",
                    currentWorkingDirectory: "/tmp/demo",
                    startedAt: sessionStart,
                    lastActivityAt: now,
                    isActive: true,
                    ideName: nil,
                    remoteURL: nil
                ),
                sessionConsumedTokens: 1_000_000,
                weeklyConsumedTokens: 3_000_000,
                activeTask: nil,
                lastCompletedTask: nil,
                notices: []
            )
        )

        let useCase = ObserveClaudeBarSnapshotUseCase(
            repository: repository,
            usagePolicyProvider: DefaultUsagePolicyProvider(
                sessionTokenBudget: 2_000_000,
                sessionWindowHours: 5,
                weeklyTokenBudget: 12_000_000,
                weeklyResetWeekday: 2
            ),
            usageProvider: FailingUsageProvider()
        )

        let snapshot = try useCase.execute(now: now)

        XCTAssertEqual(snapshot.currentSession.accuracy, .estimated)
        XCTAssertEqual(snapshot.currentWeek.accuracy, .estimated)
        XCTAssertEqual(snapshot.currentSession.percentage, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentWeek.percentage, 0.25, accuracy: 0.0001)
        XCTAssertTrue(snapshot.notices.contains { $0.contains("Se usa porcentaje estimado porque no se pudo leer usage exacto") })
    }
}

private struct ExactUsageStubRepository: ClaudeActivityRepository {
    let result: ClaudeActivity

    func loadActivity(now: Date) throws -> ClaudeActivity {
        result
    }
}

private struct ExactUsageStubProvider: ClaudeUsageProviding {
    let result: ClaudeUsageSnapshot

    func loadUsage(now: Date) throws -> ClaudeUsageSnapshot {
        result
    }
}

private struct FailingUsageProvider: ClaudeUsageProviding {
    func loadUsage(now: Date) throws -> ClaudeUsageSnapshot {
        throw ExactUsageProviderTestError.notAvailable
    }
}

private enum ExactUsageProviderTestError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        "sin datos exactos"
    }
}
