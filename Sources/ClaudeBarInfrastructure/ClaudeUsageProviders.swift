import Foundation
import ClaudeBarApplication

public struct CompositeClaudeUsageProvider: ClaudeUsageProviding {
    private let providers: [ClaudeUsageProviding]

    public init(providers: [ClaudeUsageProviding]) {
        self.providers = providers
    }

    public func loadUsage(now: Date) throws -> ClaudeUsageSnapshot {
        var failures: [String] = []

        for provider in providers {
            do {
                return try provider.loadUsage(now: now)
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        throw ClaudeUsageProviderError.unavailable(
            failures.isEmpty
                ? "No hay proveedores exactos configurados."
                : failures.joined(separator: " | ")
        )
    }
}

public final class ClaudeStatusLineUsageProvider: ClaudeUsageProviding {
    private let fileURL: URL
    private let decoder = JSONDecoder()

    public init(fileURL: URL = ClaudeFilesystemPaths.default().statusLineCaptureURL) {
        self.fileURL = fileURL
    }

    public func loadUsage(now _: Date) throws -> ClaudeUsageSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ClaudeUsageProviderError.unavailable(
                "No existe captura de status line en \(fileURL.path)."
            )
        }

        let data = try Data(contentsOf: fileURL)
        let payload = try decoder.decode(StatusLineCapturePayload.self, from: data)
        let rawValue = String(data: data, encoding: .utf8)

        let session = payload.rateLimits.fiveHour?.usageWindow
        let week = payload.rateLimits.sevenDay?.usageWindow

        guard session != nil || week != nil else {
            throw ClaudeUsageProviderError.unparseable(
                "La captura de status line no contiene ventanas five_hour o seven_day."
            )
        }

        return ClaudeUsageSnapshot(
            currentSession: session,
            currentWeek: week,
            source: .statusLineCapture,
            rawValue: rawValue
        )
    }
}

public final class ClaudeHeadlessCLIUsageProvider: ClaudeUsageProviding {
    private let executableName: String
    private let runner: CommandRunning

    public init(
        executableName: String = ProcessInfo.processInfo.environment["CLAUDEBAR_CLAUDE_EXECUTABLE"] ?? "claude"
    ) {
        self.executableName = executableName
        self.runner = ProcessRunner()
    }

    fileprivate init(
        executableName: String,
        runner: CommandRunning
    ) {
        self.executableName = executableName
        self.runner = runner
    }

    public func loadUsage(now: Date) throws -> ClaudeUsageSnapshot {
        let result = try runner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [executableName, "-p", "/usage"],
            currentDirectoryURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )

        let stdout = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedOutput = [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard result.terminationStatus == 0 else {
            throw ClaudeUsageProviderError.commandFailed(combinedOutput)
        }

        if combinedOutput.localizedCaseInsensitiveContains("Unknown command: /usage") {
            throw ClaudeUsageProviderError.unsupportedCommand(
                "La CLI actual no acepta /usage en modo headless."
            )
        }

        if let usage = parseJSONUsage(from: stdout) ?? parseTextUsage(from: combinedOutput) {
            return usage
        }

        throw ClaudeUsageProviderError.unparseable(
            combinedOutput.isEmpty
                ? "La CLI no devolvio salida para /usage."
                : combinedOutput
        )
    }

    private func parseJSONUsage(from text: String) -> ClaudeUsageSnapshot? {
        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let session = windowSnapshot(
            percentage: object["sessionPercentage"],
            resetAt: object["sessionResetAt"]
        )
        let week = windowSnapshot(
            percentage: object["weeklyPercentage"] ?? object["weekPercentage"],
            resetAt: object["weeklyResetAt"] ?? object["weekResetAt"]
        )

        guard session != nil || week != nil else { return nil }

        return ClaudeUsageSnapshot(
            currentSession: session,
            currentWeek: week,
            source: .headlessCommand,
            rawValue: text
        )
    }

    private func parseTextUsage(from text: String) -> ClaudeUsageSnapshot? {
        let session = parseWindow(
            in: text,
            labels: ["session", "5h", "5-hour", "five hour"]
        )
        let week = parseWindow(
            in: text,
            labels: ["week", "weekly", "7d", "7-day", "seven day"]
        )

        guard session != nil || week != nil else { return nil }

        return ClaudeUsageSnapshot(
            currentSession: session,
            currentWeek: week,
            source: .headlessCommand,
            rawValue: text
        )
    }

    private func parseWindow(in text: String, labels: [String]) -> ClaudeUsageWindowSnapshot? {
        guard let percentage = extractPercentage(in: text, labels: labels) else {
            return nil
        }

        return ClaudeUsageWindowSnapshot(
            percentage: percentage,
            resetAt: extractResetDate(in: text, labels: labels)
        )
    }

    private func extractPercentage(in text: String, labels: [String]) -> Double? {
        let alternation = labels.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let patterns = [
            "(?i)(?:\(alternation))[^\\n\\d]{0,30}(\\d+(?:\\.\\d+)?)%",
            "(?i)(\\d+(?:\\.\\d+)?)%[^\\n]{0,30}(?:\(alternation))",
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, options: [], range: range),
                let capture = Range(match.range(at: 1), in: text),
                let value = Double(text[capture])
            else {
                continue
            }

            return value > 1 ? value / 100 : value
        }

        return nil
    }

    private func extractResetDate(in text: String, labels: [String]) -> Date? {
        let alternation = labels.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let patterns = [
            "(?i)(?:\(alternation)).{0,80}?(?:reset(?:s| at)?|renews?(?: at)?)[^\\n]*?(\\d{4}-\\d{2}-\\d{2}[^\\n,;]*)",
            "(?i)(?:\(alternation)).{0,80}?(?:reset(?:s| at)?|renews?(?: at)?)[^\\n]*?(\\d{10})",
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
                continue
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, options: [], range: range),
                let capture = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            let rawValue = String(text[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let timestamp = Double(rawValue) {
                return Date(timeIntervalSince1970: timestamp)
            }

            if let date = parseDate(rawValue) {
                return date
            }
        }

        return nil
    }

    private func parseDate(_ rawValue: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: rawValue) {
            return date
        }

        let fallbackISOFormatter = ISO8601DateFormatter()
        fallbackISOFormatter.formatOptions = [.withInternetDateTime]
        if let date = fallbackISOFormatter.date(from: rawValue) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        for format in [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd h:mm a",
            "MMM d, yyyy h:mm a",
            "MMM d yyyy h:mm a",
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }

        return nil
    }

    private func windowSnapshot(percentage: Any?, resetAt: Any?) -> ClaudeUsageWindowSnapshot? {
        guard let value = doubleValue(percentage) else { return nil }

        return ClaudeUsageWindowSnapshot(
            percentage: value > 1 ? value / 100 : value,
            resetAt: decodeDate(resetAt)
        )
    }

    private func decodeDate(_ value: Any?) -> Date? {
        if let unixSeconds = doubleValue(value) {
            return Date(timeIntervalSince1970: unixSeconds)
        }

        if let string = value as? String {
            return parseDate(string)
        }

        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String {
            return Double(string)
        }

        return nil
    }
}

public enum ClaudeUsageProviderError: LocalizedError {
    case unavailable(String)
    case unsupportedCommand(String)
    case commandFailed(String)
    case unparseable(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let message),
             .unsupportedCommand(let message),
             .commandFailed(let message),
             .unparseable(let message):
            return message
        }
    }
}

private protocol CommandRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL?
    ) throws -> CommandResult
}

private struct CommandResult {
    let standardOutput: String
    let standardError: String
    let terminationStatus: Int32
}

private struct ProcessRunner: CommandRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL?
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            standardOutput: String(decoding: stdoutData, as: UTF8.self),
            standardError: String(decoding: stderrData, as: UTF8.self),
            terminationStatus: process.terminationStatus
        )
    }
}

private struct StatusLineCapturePayload: Decodable {
    let rateLimits: RateLimitsPayload

    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
    }
}

private struct RateLimitsPayload: Decodable {
    let fiveHour: RateLimitWindowPayload?
    let sevenDay: RateLimitWindowPayload?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

private struct RateLimitWindowPayload: Decodable {
    let usedPercentage: Double?
    let resetsAt: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }

    var usageWindow: ClaudeUsageWindowSnapshot? {
        guard let usedPercentage else { return nil }
        return ClaudeUsageWindowSnapshot(
            percentage: usedPercentage > 1 ? usedPercentage / 100 : usedPercentage,
            resetAt: resetsAt.map { Date(timeIntervalSince1970: $0) }
        )
    }
}
