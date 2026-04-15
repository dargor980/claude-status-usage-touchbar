import Foundation

public enum ClaudeUsageSource: String, Equatable, Sendable {
    case statusLineCapture
    case headlessCommand

    public var displayName: String {
        switch self {
        case .statusLineCapture:
            return "captura de status line"
        case .headlessCommand:
            return "comando headless"
        }
    }
}

public struct ClaudeUsageWindowSnapshot: Equatable, Sendable {
    public let percentage: Double
    public let resetAt: Date?

    public init(percentage: Double, resetAt: Date?) {
        self.percentage = percentage
        self.resetAt = resetAt
    }

    public var clampedPercentage: Double {
        min(max(percentage, 0), 1)
    }
}

public struct ClaudeUsageSnapshot: Equatable, Sendable {
    public let currentSession: ClaudeUsageWindowSnapshot?
    public let currentWeek: ClaudeUsageWindowSnapshot?
    public let source: ClaudeUsageSource
    public let rawValue: String?

    public init(
        currentSession: ClaudeUsageWindowSnapshot?,
        currentWeek: ClaudeUsageWindowSnapshot?,
        source: ClaudeUsageSource,
        rawValue: String? = nil
    ) {
        self.currentSession = currentSession
        self.currentWeek = currentWeek
        self.source = source
        self.rawValue = rawValue
    }
}

public protocol ClaudeUsageProviding {
    func loadUsage(now: Date) throws -> ClaudeUsageSnapshot
}
