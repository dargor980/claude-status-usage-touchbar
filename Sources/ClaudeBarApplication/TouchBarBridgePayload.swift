import Foundation
import ClaudeBarDomain

public struct TouchBarBridgePayload: Codable, Equatable, Sendable {
    public let updatedAt: Date
    public let compactTitle: String
    public let compactTask: String
    public let resumeAvailable: Bool
    public let resumeURL: String?
    public let session: TouchBarBridgeSessionPayload?
    public let currentSession: TouchBarBridgeGaugePayload
    public let currentWeek: TouchBarBridgeGaugePayload
    public let task: TouchBarBridgeTaskPayload?

    public init(
        updatedAt: Date,
        compactTitle: String,
        compactTask: String,
        resumeAvailable: Bool,
        resumeURL: String?,
        session: TouchBarBridgeSessionPayload?,
        currentSession: TouchBarBridgeGaugePayload,
        currentWeek: TouchBarBridgeGaugePayload,
        task: TouchBarBridgeTaskPayload?
    ) {
        self.updatedAt = updatedAt
        self.compactTitle = compactTitle
        self.compactTask = compactTask
        self.resumeAvailable = resumeAvailable
        self.resumeURL = resumeURL
        self.session = session
        self.currentSession = currentSession
        self.currentWeek = currentWeek
        self.task = task
    }
}

public struct TouchBarBridgeSessionPayload: Codable, Equatable, Sendable {
    public let projectName: String
    public let projectPath: String
    public let ideName: String?
    public let isActive: Bool

    public init(
        projectName: String,
        projectPath: String,
        ideName: String?,
        isActive: Bool
    ) {
        self.projectName = projectName
        self.projectPath = projectPath
        self.ideName = ideName
        self.isActive = isActive
    }
}

public struct TouchBarBridgeGaugePayload: Codable, Equatable, Sendable {
    public let title: String
    public let percentage: Double
    public let percentageLabel: String
    public let resetLabel: String
    public let accuracy: String

    public init(
        title: String,
        percentage: Double,
        percentageLabel: String,
        resetLabel: String,
        accuracy: String
    ) {
        self.title = title
        self.percentage = percentage
        self.percentageLabel = percentageLabel
        self.resetLabel = resetLabel
        self.accuracy = accuracy
    }
}

public struct TouchBarBridgeTaskPayload: Codable, Equatable, Sendable {
    public let title: String
    public let state: String
    public let detail: String?

    public init(title: String, state: String, detail: String?) {
        self.title = title
        self.state = state
        self.detail = detail
    }
}

public struct BuildTouchBarBridgePayloadUseCase {
    public init() {}

    public func execute(snapshot: ClaudeBarSnapshot, now: Date = Date()) -> TouchBarBridgePayload {
        let sessionPayload = snapshot.session.map { session in
            TouchBarBridgeSessionPayload(
                projectName: URL(fileURLWithPath: session.projectPath).lastPathComponent,
                projectPath: session.projectPath,
                ideName: session.ideName,
                isActive: session.isActive
            )
        }

        let sessionGauge = gaugePayload(snapshot.currentSession, now: now)
        let weekGauge = gaugePayload(snapshot.currentWeek, now: now)
        let taskPayload = snapshot.task.map {
            TouchBarBridgeTaskPayload(
                title: $0.title,
                state: $0.state.rawValue,
                detail: $0.detail
            )
        }

        return TouchBarBridgePayload(
            updatedAt: snapshot.observedAt,
            compactTitle: "claudeBar \(sessionGauge.percentageLabel) · \(weekGauge.percentageLabel)",
            compactTask: compactTask(session: sessionPayload, task: taskPayload),
            resumeAvailable: snapshot.session?.remoteURL != nil,
            resumeURL: snapshot.session?.remoteURL,
            session: sessionPayload,
            currentSession: sessionGauge,
            currentWeek: weekGauge,
            task: taskPayload
        )
    }

    private func gaugePayload(_ gauge: UsageGauge, now: Date) -> TouchBarBridgeGaugePayload {
        TouchBarBridgeGaugePayload(
            title: gauge.title,
            percentage: gauge.clampedPercentage,
            percentageLabel: "\(shortTitle(for: gauge.title)) \(formatPercent(gauge.clampedPercentage))",
            resetLabel: formatReset(gauge.resetAt, now: now),
            accuracy: gauge.accuracy.rawValue
        )
    }

    private func shortTitle(for title: String) -> String {
        switch title.lowercased() {
        case let value where value.contains("sesion"):
            return "5h"
        case let value where value.contains("semana"):
            return "7d"
        default:
            return title
        }
    }

    private func formatPercent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func formatReset(_ date: Date?, now: Date) -> String {
        guard let date else { return "Sin reset" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Reset \(formatter.localizedString(for: date, relativeTo: now))"
    }

    private func compactTask(
        session: TouchBarBridgeSessionPayload?,
        task: TouchBarBridgeTaskPayload?
    ) -> String {
        let project = session?.projectName ?? "Sin sesion"

        guard let task else {
            return "\(project) · sin tarea activa"
        }

        return "\(project) · \(task.title)"
    }
}
