import Foundation

public enum UsageAccuracy: String, Sendable {
    case exact
    case estimated
    case unavailable
}

public enum TaskLifecycleState: String, Sendable {
    case idle
    case running
    case completed
}

public enum TaskSource: String, Sendable {
    case plan
    case background
    case telemetry
}

public struct UsageGauge: Equatable, Sendable {
    public let title: String
    public let consumedTokens: Int
    public let budgetTokens: Int
    public let percentage: Double
    public let resetAt: Date?
    public let accuracy: UsageAccuracy

    public init(
        title: String,
        consumedTokens: Int,
        budgetTokens: Int,
        percentage: Double,
        resetAt: Date?,
        accuracy: UsageAccuracy
    ) {
        self.title = title
        self.consumedTokens = consumedTokens
        self.budgetTokens = budgetTokens
        self.percentage = percentage
        self.resetAt = resetAt
        self.accuracy = accuracy
    }

    public var clampedPercentage: Double {
        min(max(percentage, 0), 1)
    }
}

public struct TaskSnapshot: Equatable, Sendable {
    public let title: String
    public let detail: String?
    public let state: TaskLifecycleState
    public let source: TaskSource
    public let steps: [String]
    public let startedAt: Date?
    public let finishedAt: Date?

    public init(
        title: String,
        detail: String?,
        state: TaskLifecycleState,
        source: TaskSource,
        steps: [String],
        startedAt: Date?,
        finishedAt: Date?
    ) {
        self.title = title
        self.detail = detail
        self.state = state
        self.source = source
        self.steps = steps
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public struct SessionSnapshot: Equatable, Sendable {
    public let sessionId: String
    public let projectPath: String
    public let currentWorkingDirectory: String
    public let startedAt: Date
    public let lastActivityAt: Date
    public let isActive: Bool
    public let ideName: String?
    public let remoteURL: String?

    public init(
        sessionId: String,
        projectPath: String,
        currentWorkingDirectory: String,
        startedAt: Date,
        lastActivityAt: Date,
        isActive: Bool,
        ideName: String?,
        remoteURL: String?
    ) {
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.currentWorkingDirectory = currentWorkingDirectory
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.isActive = isActive
        self.ideName = ideName
        self.remoteURL = remoteURL
    }
}

public struct ClaudeBarSnapshot: Equatable, Sendable {
    public let observedAt: Date
    public let session: SessionSnapshot?
    public let currentSession: UsageGauge
    public let currentWeek: UsageGauge
    public let task: TaskSnapshot?
    public let notices: [String]

    public init(
        observedAt: Date,
        session: SessionSnapshot?,
        currentSession: UsageGauge,
        currentWeek: UsageGauge,
        task: TaskSnapshot?,
        notices: [String]
    ) {
        self.observedAt = observedAt
        self.session = session
        self.currentSession = currentSession
        self.currentWeek = currentWeek
        self.task = task
        self.notices = notices
    }

    public static func empty(observedAt: Date = Date()) -> ClaudeBarSnapshot {
        ClaudeBarSnapshot(
            observedAt: observedAt,
            session: nil,
            currentSession: UsageGauge(
                title: "Sesion actual",
                consumedTokens: 0,
                budgetTokens: 0,
                percentage: 0,
                resetAt: nil,
                accuracy: .unavailable
            ),
            currentWeek: UsageGauge(
                title: "Semana",
                consumedTokens: 0,
                budgetTokens: 0,
                percentage: 0,
                resetAt: nil,
                accuracy: .unavailable
            ),
            task: nil,
            notices: []
        )
    }
}
