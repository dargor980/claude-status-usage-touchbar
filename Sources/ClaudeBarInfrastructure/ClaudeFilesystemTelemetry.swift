import Foundation
import ClaudeBarApplication
import ClaudeBarDomain

public struct ClaudeFilesystemPaths {
    public let root: URL
    public let historyURL: URL
    public let statsURL: URL
    public let projectsURL: URL
    public let tasksURL: URL
    public let ideURL: URL

    public init(root: URL) {
        self.root = root
        self.historyURL = root.appendingPathComponent("history.jsonl")
        self.statsURL = root.appendingPathComponent("stats-cache.json")
        self.projectsURL = root.appendingPathComponent("projects")
        self.tasksURL = root.appendingPathComponent("tasks")
        self.ideURL = root.appendingPathComponent("ide")
    }

    public static func `default`() -> ClaudeFilesystemPaths {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ClaudeFilesystemPaths(root: home.appendingPathComponent(".claude"))
    }
}

public final class JSONUsagePolicyProvider: UsagePolicyProviding {
    private let fileURL: URL
    private let fallback: UsagePolicyProviding
    private let decoder = JSONDecoder()

    public init(fileURL: URL, fallback: UsagePolicyProviding = DefaultUsagePolicyProvider()) {
        self.fileURL = fileURL
        self.fallback = fallback
    }

    public func currentPolicy(now: Date, sessionStartedAt: Date?) -> UsagePolicy {
        guard
            let data = try? Data(contentsOf: fileURL),
            let config = try? decoder.decode(UsagePolicyConfig.self, from: data)
        else {
            return fallback.currentPolicy(now: now, sessionStartedAt: sessionStartedAt)
        }

        return UsagePolicy(
            sessionTokenBudget: config.sessionTokenBudget,
            sessionWindowHours: config.sessionWindowHours,
            weeklyTokenBudget: config.weeklyTokenBudget,
            weeklyResetWeekday: config.weeklyResetWeekday
        )
    }
}

public final class ClaudeFilesystemActivityRepository: ClaudeActivityRepository {
    private let paths: ClaudeFilesystemPaths
    private let fileManager: FileManager
    private let calendar: Calendar
    private let staleSessionInterval: TimeInterval
    private let iso8601Formatter: ISO8601DateFormatter

    public init(
        paths: ClaudeFilesystemPaths = .default(),
        fileManager: FileManager = .default,
        calendar: Calendar = Calendar(identifier: .iso8601),
        staleSessionInterval: TimeInterval = 15 * 60
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.calendar = calendar
        self.staleSessionInterval = staleSessionInterval

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.iso8601Formatter = formatter
    }

    public func loadActivity(now: Date) throws -> ClaudeActivity {
        var notices: [String] = []

        guard let historyEntry = loadLatestHistoryEntry() else {
            notices.append("No se encontro una sesion reciente en ~/.claude/history.jsonl.")
            return ClaudeActivity(
                activeSession: nil,
                sessionConsumedTokens: 0,
                weeklyConsumedTokens: loadWeeklyTokens(now: now, additionalTodayTokens: 0),
                activeTask: nil,
                lastCompletedTask: nil,
                notices: notices
            )
        }

        guard let sessionFileURL = findSessionFile(sessionId: historyEntry.sessionId) else {
            notices.append("No se encontro el archivo jsonl de la sesion activa.")
            return ClaudeActivity(
                activeSession: nil,
                sessionConsumedTokens: 0,
                weeklyConsumedTokens: loadWeeklyTokens(now: now, additionalTodayTokens: 0),
                activeTask: nil,
                lastCompletedTask: nil,
                notices: notices
            )
        }

        let telemetry = try parseSessionTelemetry(
            from: sessionFileURL,
            sessionId: historyEntry.sessionId,
            projectPath: historyEntry.projectPath,
            now: now
        )

        notices.append(contentsOf: telemetry.notices)
        notices.append("Claude no expone localmente el porcentaje exacto de /usage; esta barra usa presupuestos configurables y tokens observados.")

        let weeklyTokens = loadWeeklyTokens(now: now, additionalTodayTokens: telemetry.additionalTodayTokensForWeek)
        let task = loadPlannedTask(sessionId: historyEntry.sessionId, steps: telemetry.recentSteps) ?? telemetry.runningBackgroundTask

        return ClaudeActivity(
            activeSession: telemetry.session,
            sessionConsumedTokens: telemetry.sessionTokens,
            weeklyConsumedTokens: weeklyTokens,
            activeTask: task,
            lastCompletedTask: telemetry.completedBackgroundTask,
            notices: notices
        )
    }

    private func loadLatestHistoryEntry() -> HistoryEntry? {
        guard let content = try? String(contentsOf: paths.historyURL) else {
            return nil
        }

        for line in content.split(separator: "\n").reversed() {
            guard
                let data = line.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let sessionId = object["sessionId"] as? String,
                let projectPath = object["project"] as? String
            else {
                continue
            }

            let timestampMs = object["timestamp"] as? Double ?? object["timestamp"] as? NSNumber as? Double ?? 0
            let timestamp = Date(timeIntervalSince1970: timestampMs / 1_000)
            return HistoryEntry(sessionId: sessionId, projectPath: projectPath, timestamp: timestamp)
        }

        return nil
    }

    private func findSessionFile(sessionId: String) -> URL? {
        guard let enumerator = fileManager.enumerator(at: paths.projectsURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        for case let url as URL in enumerator {
            if url.lastPathComponent == "\(sessionId).jsonl" {
                return url
            }
        }

        return nil
    }

    private func parseSessionTelemetry(
        from url: URL,
        sessionId: String,
        projectPath: String,
        now: Date
    ) throws -> SessionTelemetry {
        let content = try String(contentsOf: url)
        let lines = content.split(separator: "\n")

        var startedAt: Date?
        var lastActivityAt: Date?
        var currentWorkingDirectory = projectPath
        var remoteURL: String?
        var sessionTokens = 0
        var recentSteps: [String] = []
        var runningBackgroundTasks: [String: TaskSnapshot] = [:]
        var completedBackgroundTask: TaskSnapshot?
        var notices: [String] = []

        for line in lines {
            guard
                let data = line.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }

            if let timestamp = extractDate(from: object) {
                if startedAt == nil {
                    startedAt = timestamp
                }
                lastActivityAt = timestamp
            }

            if let cwd = object["cwd"] as? String {
                currentWorkingDirectory = cwd
            }

            if remoteURL == nil, let candidateURL = object["url"] as? String {
                remoteURL = candidateURL
            }

            sessionTokens += extractUsageTokens(from: object)

            let steps = extractToolUseSteps(from: object)
            if !steps.isEmpty {
                recentSteps = steps
            }

            if
                let type = object["type"] as? String,
                type == "queue-operation",
                let operation = object["operation"] as? String,
                operation == "enqueue",
                let rawContent = object["content"] as? String,
                let summary = extractTagValue("summary", from: rawContent)
            {
                let identifier = extractTagValue("task-id", from: rawContent) ?? UUID().uuidString
                let detail = extractTagValue("event", from: rawContent)
                runningBackgroundTasks[identifier] = TaskSnapshot(
                    title: summary,
                    detail: detail,
                    state: .running,
                    source: .background,
                    steps: recentSteps,
                    startedAt: extractDate(from: object),
                    finishedAt: nil
                )
            }

            if
                let rawNotification = extractTaskNotification(from: object),
                let taskId = extractTagValue("task-id", from: rawNotification),
                let summary = extractTagValue("summary", from: rawNotification)
            {
                let status = extractTagValue("status", from: rawNotification)
                if status == "completed" {
                    runningBackgroundTasks.removeValue(forKey: taskId)
                    completedBackgroundTask = TaskSnapshot(
                        title: summary,
                        detail: extractTagValue("event", from: rawNotification),
                        state: .completed,
                        source: .background,
                        steps: recentSteps,
                        startedAt: nil,
                        finishedAt: extractDate(from: object)
                    )
                }
            }
        }

        let ideName = loadConnectedIDEName()
        guard let startedAt, let lastActivityAt else {
            notices.append("No fue posible calcular el inicio o la ultima actividad de la sesion.")
            return SessionTelemetry(
                session: nil,
                sessionTokens: sessionTokens,
                recentSteps: recentSteps,
                runningBackgroundTask: runningBackgroundTasks.values.sorted(by: byMostRecentTask).first,
                completedBackgroundTask: completedBackgroundTask,
                additionalTodayTokensForWeek: additionalTokensForToday(now: now, lastComputedDate: loadStatsCacheLastComputedDate(), sessionStartedAt: nil, sessionTokens: sessionTokens),
                notices: notices
            )
        }

        let session = SessionSnapshot(
            sessionId: sessionId,
            projectPath: projectPath,
            currentWorkingDirectory: currentWorkingDirectory,
            startedAt: startedAt,
            lastActivityAt: lastActivityAt,
            isActive: now.timeIntervalSince(lastActivityAt) <= staleSessionInterval,
            ideName: ideName,
            remoteURL: remoteURL
        )

        return SessionTelemetry(
            session: session,
            sessionTokens: sessionTokens,
            recentSteps: recentSteps,
            runningBackgroundTask: runningBackgroundTasks.values.sorted(by: byMostRecentTask).first,
            completedBackgroundTask: completedBackgroundTask,
            additionalTodayTokensForWeek: additionalTokensForToday(
                now: now,
                lastComputedDate: loadStatsCacheLastComputedDate(),
                sessionStartedAt: startedAt,
                sessionTokens: sessionTokens
            ),
            notices: notices
        )
    }

    private func loadPlannedTask(sessionId: String, steps: [String]) -> TaskSnapshot? {
        let folder = paths.tasksURL.appendingPathComponent(sessionId)
        guard let entries = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return nil
        }

        let decoder = JSONDecoder()
        for fileURL in entries where fileURL.pathExtension == "json" {
            guard
                let data = try? Data(contentsOf: fileURL),
                let task = try? decoder.decode(PlannedTaskDTO.self, from: data),
                task.status == "in_progress"
            else {
                continue
            }

            return TaskSnapshot(
                title: task.activeForm ?? task.subject,
                detail: task.description,
                state: .running,
                source: .plan,
                steps: steps,
                startedAt: nil,
                finishedAt: nil
            )
        }

        return nil
    }

    private func loadWeeklyTokens(now: Date, additionalTodayTokens: Int) -> Int {
        guard
            let data = try? Data(contentsOf: paths.statsURL),
            let cache = try? JSONDecoder().decode(StatsCacheDTO.self, from: data)
        else {
            return additionalTodayTokens
        }

        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return additionalTodayTokens
        }

        let start = interval.start
        let end = interval.end

        let cachedTotal = cache.dailyModelTokens.reduce(into: 0) { partialResult, day in
            guard
                let date = dateOnly(day.date),
                date >= start,
                date < end
            else {
                return
            }

            partialResult += day.tokensByModel.values.reduce(0, +)
        }

        return cachedTotal + additionalTodayTokens
    }

    private func loadStatsCacheLastComputedDate() -> Date? {
        guard
            let data = try? Data(contentsOf: paths.statsURL),
            let cache = try? JSONDecoder().decode(StatsCacheDTO.self, from: data)
        else {
            return nil
        }

        return dateOnly(cache.lastComputedDate)
    }

    private func additionalTokensForToday(
        now: Date,
        lastComputedDate: Date?,
        sessionStartedAt: Date?,
        sessionTokens: Int
    ) -> Int {
        guard let sessionStartedAt else { return 0 }
        guard calendar.isDate(sessionStartedAt, inSameDayAs: now) else { return 0 }
        guard let lastComputedDate else { return sessionTokens }
        return calendar.isDate(lastComputedDate, inSameDayAs: now) ? 0 : sessionTokens
    }

    private func loadConnectedIDEName() -> String? {
        guard let entries = try? fileManager.contentsOfDirectory(at: paths.ideURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        for fileURL in entries where fileURL.pathExtension == "lock" {
            guard
                let data = try? Data(contentsOf: fileURL),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let ideName = object["ideName"] as? String
            else {
                continue
            }

            return ideName
        }

        return nil
    }

    private func extractDate(from object: [String: Any]) -> Date? {
        if let timestamp = object["timestamp"] as? String {
            return iso8601Formatter.date(from: timestamp)
        }

        return nil
    }

    private func extractUsageTokens(from object: [String: Any]) -> Int {
        guard
            let message = object["message"] as? [String: Any],
            let usage = message["usage"] as? [String: Any]
        else {
            return 0
        }

        let keys = [
            "input_tokens",
            "output_tokens",
            "cache_read_input_tokens",
            "cache_creation_input_tokens",
        ]

        return keys.reduce(into: 0) { partialResult, key in
            partialResult += integerValue(usage[key])
        }
    }

    private func extractToolUseSteps(from object: [String: Any]) -> [String] {
        guard
            let message = object["message"] as? [String: Any],
            let content = message["content"] as? [[String: Any]]
        else {
            return []
        }

        return content.compactMap { element in
            guard element["type"] as? String == "tool_use" else {
                return nil
            }

            return element["name"] as? String
        }
    }

    private func extractTaskNotification(from object: [String: Any]) -> String? {
        if let message = object["message"] as? [String: Any], let raw = message["content"] as? String, raw.contains("<task-notification>") {
            return raw
        }

        if let attachment = object["attachment"] as? [String: Any], let prompt = attachment["prompt"] as? String, prompt.contains("<task-notification>") {
            return prompt
        }

        return nil
    }

    private func extractTagValue(_ tag: String, from text: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func dateOnly(_ rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: rawValue)
    }

    private func integerValue(_ rawValue: Any?) -> Int {
        if let integer = rawValue as? Int {
            return integer
        }

        if let number = rawValue as? NSNumber {
            return number.intValue
        }

        if let string = rawValue as? String, let integer = Int(string) {
            return integer
        }

        return 0
    }

    private func byMostRecentTask(_ lhs: TaskSnapshot, _ rhs: TaskSnapshot) -> Bool {
        (lhs.startedAt ?? .distantPast) > (rhs.startedAt ?? .distantPast)
    }
}

private struct HistoryEntry {
    let sessionId: String
    let projectPath: String
    let timestamp: Date
}

private struct SessionTelemetry {
    let session: SessionSnapshot?
    let sessionTokens: Int
    let recentSteps: [String]
    let runningBackgroundTask: TaskSnapshot?
    let completedBackgroundTask: TaskSnapshot?
    let additionalTodayTokensForWeek: Int
    let notices: [String]
}

private struct UsagePolicyConfig: Decodable {
    let sessionTokenBudget: Int
    let sessionWindowHours: Int
    let weeklyTokenBudget: Int
    let weeklyResetWeekday: Int
}

private struct StatsCacheDTO: Decodable {
    let lastComputedDate: String?
    let dailyModelTokens: [DayTokens]

    struct DayTokens: Decodable {
        let date: String
        let tokensByModel: [String: Int]
    }
}

private struct PlannedTaskDTO: Decodable {
    let id: String
    let subject: String
    let description: String?
    let activeForm: String?
    let status: String
}
