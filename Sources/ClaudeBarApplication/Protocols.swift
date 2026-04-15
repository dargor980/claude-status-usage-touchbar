import Foundation
import ClaudeBarDomain

public struct ClaudeActivity: Sendable {
    public let activeSession: SessionSnapshot?
    public let sessionConsumedTokens: Int
    public let weeklyConsumedTokens: Int
    public let activeTask: TaskSnapshot?
    public let lastCompletedTask: TaskSnapshot?
    public let notices: [String]

    public init(
        activeSession: SessionSnapshot?,
        sessionConsumedTokens: Int,
        weeklyConsumedTokens: Int,
        activeTask: TaskSnapshot?,
        lastCompletedTask: TaskSnapshot?,
        notices: [String]
    ) {
        self.activeSession = activeSession
        self.sessionConsumedTokens = sessionConsumedTokens
        self.weeklyConsumedTokens = weeklyConsumedTokens
        self.activeTask = activeTask
        self.lastCompletedTask = lastCompletedTask
        self.notices = notices
    }
}

public struct UsagePolicy: Sendable {
    public let sessionTokenBudget: Int
    public let sessionWindowHours: Int
    public let weeklyTokenBudget: Int
    public let weeklyResetWeekday: Int

    public init(
        sessionTokenBudget: Int,
        sessionWindowHours: Int,
        weeklyTokenBudget: Int,
        weeklyResetWeekday: Int
    ) {
        self.sessionTokenBudget = sessionTokenBudget
        self.sessionWindowHours = sessionWindowHours
        self.weeklyTokenBudget = weeklyTokenBudget
        self.weeklyResetWeekday = weeklyResetWeekday
    }
}

public protocol ClaudeActivityRepository {
    func loadActivity(now: Date) throws -> ClaudeActivity
}

public protocol UsagePolicyProviding {
    func currentPolicy(now: Date, sessionStartedAt: Date?) -> UsagePolicy
}

public struct DefaultUsagePolicyProvider: UsagePolicyProviding {
    public let policy: UsagePolicy

    public init(
        sessionTokenBudget: Int = 2_000_000,
        sessionWindowHours: Int = 5,
        weeklyTokenBudget: Int = 12_000_000,
        weeklyResetWeekday: Int = 2
    ) {
        self.policy = UsagePolicy(
            sessionTokenBudget: sessionTokenBudget,
            sessionWindowHours: sessionWindowHours,
            weeklyTokenBudget: weeklyTokenBudget,
            weeklyResetWeekday: weeklyResetWeekday
        )
    }

    public init(policy: UsagePolicy) {
        self.policy = policy
    }

    public func currentPolicy(now: Date, sessionStartedAt: Date?) -> UsagePolicy {
        policy
    }
}
