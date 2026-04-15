import Foundation
import ClaudeBarDomain

public final class ObserveClaudeBarSnapshotUseCase {
    private let repository: ClaudeActivityRepository
    private let usagePolicyProvider: UsagePolicyProviding
    private let usageProvider: ClaudeUsageProviding?
    private var calendar: Calendar

    public init(
        repository: ClaudeActivityRepository,
        usagePolicyProvider: UsagePolicyProviding,
        usageProvider: ClaudeUsageProviding? = nil,
        calendar: Calendar = Calendar(identifier: .iso8601)
    ) {
        self.repository = repository
        self.usagePolicyProvider = usagePolicyProvider
        self.usageProvider = usageProvider
        self.calendar = calendar
    }

    public func execute(now: Date = Date()) throws -> ClaudeBarSnapshot {
        let activity = try repository.loadActivity(now: now)
        let policy = usagePolicyProvider.currentPolicy(now: now, sessionStartedAt: activity.activeSession?.startedAt)
        let (exactUsage, usageNotice) = loadExactUsage(now: now)

        let sessionResetAt = activity.activeSession?.startedAt.addingTimeInterval(TimeInterval(policy.sessionWindowHours * 3_600))
        let weeklyResetAt = nextWeeklyReset(from: now, weekday: policy.weeklyResetWeekday)
        let usageNotices = usageNotice.map { [$0] } ?? []
        let notices = activity.notices + usageNotices

        return ClaudeBarSnapshot(
            observedAt: now,
            session: activity.activeSession,
            currentSession: UsageGauge(
                title: "Sesion actual",
                consumedTokens: activity.sessionConsumedTokens,
                budgetTokens: exactUsage?.currentSession == nil ? policy.sessionTokenBudget : 0,
                percentage: exactUsage?.currentSession?.clampedPercentage
                    ?? percentage(consumed: activity.sessionConsumedTokens, budget: policy.sessionTokenBudget),
                resetAt: exactUsage?.currentSession?.resetAt ?? sessionResetAt,
                accuracy: accuracy(
                    exactWindow: exactUsage?.currentSession,
                    fallbackBudget: policy.sessionTokenBudget
                )
            ),
            currentWeek: UsageGauge(
                title: "Semana",
                consumedTokens: activity.weeklyConsumedTokens,
                budgetTokens: exactUsage?.currentWeek == nil ? policy.weeklyTokenBudget : 0,
                percentage: exactUsage?.currentWeek?.clampedPercentage
                    ?? percentage(consumed: activity.weeklyConsumedTokens, budget: policy.weeklyTokenBudget),
                resetAt: exactUsage?.currentWeek?.resetAt ?? weeklyResetAt,
                accuracy: accuracy(
                    exactWindow: exactUsage?.currentWeek,
                    fallbackBudget: policy.weeklyTokenBudget
                )
            ),
            task: activity.activeTask ?? activity.lastCompletedTask,
            notices: notices
        )
    }

    private func loadExactUsage(now: Date) -> (ClaudeUsageSnapshot?, String?) {
        guard let usageProvider else { return (nil, nil) }

        do {
            let usage = try usageProvider.loadUsage(now: now)
            return (
                usage,
                "Uso exacto activo desde \(usage.source.displayName). Si falta alguna ventana, esa barra sigue en modo estimado."
            )
        } catch {
            return (
                nil,
                "Se usa porcentaje estimado porque no se pudo leer usage exacto: \(error.localizedDescription)"
            )
        }
    }

    private func accuracy(exactWindow: ClaudeUsageWindowSnapshot?, fallbackBudget: Int) -> UsageAccuracy {
        if exactWindow != nil {
            return .exact
        }

        return fallbackBudget > 0 ? .estimated : .unavailable
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
