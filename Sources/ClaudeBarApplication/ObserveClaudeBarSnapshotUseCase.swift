import Foundation
import ClaudeBarDomain

public final class ObserveClaudeBarSnapshotUseCase {
    private let repository: ClaudeActivityRepository
    private let usagePolicyProvider: UsagePolicyProviding
    private var calendar: Calendar

    public init(
        repository: ClaudeActivityRepository,
        usagePolicyProvider: UsagePolicyProviding,
        calendar: Calendar = Calendar(identifier: .iso8601)
    ) {
        self.repository = repository
        self.usagePolicyProvider = usagePolicyProvider
        self.calendar = calendar
    }

    public func execute(now: Date = Date()) throws -> ClaudeBarSnapshot {
        let activity = try repository.loadActivity(now: now)
        let policy = usagePolicyProvider.currentPolicy(now: now, sessionStartedAt: activity.activeSession?.startedAt)

        let accuracy: UsageAccuracy = policy.sessionTokenBudget > 0 && policy.weeklyTokenBudget > 0 ? .estimated : .unavailable

        let sessionResetAt = activity.activeSession?.startedAt.addingTimeInterval(TimeInterval(policy.sessionWindowHours * 3_600))
        let weeklyResetAt = nextWeeklyReset(from: now, weekday: policy.weeklyResetWeekday)

        return ClaudeBarSnapshot(
            observedAt: now,
            session: activity.activeSession,
            currentSession: UsageGauge(
                title: "Sesion actual",
                consumedTokens: activity.sessionConsumedTokens,
                budgetTokens: policy.sessionTokenBudget,
                percentage: percentage(consumed: activity.sessionConsumedTokens, budget: policy.sessionTokenBudget),
                resetAt: sessionResetAt,
                accuracy: accuracy
            ),
            currentWeek: UsageGauge(
                title: "Semana",
                consumedTokens: activity.weeklyConsumedTokens,
                budgetTokens: policy.weeklyTokenBudget,
                percentage: percentage(consumed: activity.weeklyConsumedTokens, budget: policy.weeklyTokenBudget),
                resetAt: weeklyResetAt,
                accuracy: accuracy
            ),
            task: activity.activeTask ?? activity.lastCompletedTask,
            notices: activity.notices
        )
    }

    private func percentage(consumed: Int, budget: Int) -> Double {
        guard budget > 0 else { return 0 }
        return min(Double(consumed) / Double(budget), 1)
    }

    private func nextWeeklyReset(from now: Date, weekday: Int) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = 0
        components.minute = 0
        components.second = 0

        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }
}
