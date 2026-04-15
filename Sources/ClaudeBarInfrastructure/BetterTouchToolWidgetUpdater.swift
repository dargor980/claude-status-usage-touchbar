import Foundation
import ClaudeBarApplication
import ClaudeBarDomain

public final class BetterTouchToolWidgetUpdater {
    /// Canonical widget UUIDs embedded in `claudebar.bttpreset`.
    /// claudeBar defaults to these when the corresponding env vars are absent,
    /// so importing the preset is sufficient — no env var setup required.
    public static let canonicalTitleWidgetUUID = "CB000001-CB00-CB00-CB00-CB0000000001"
    public static let canonicalTaskWidgetUUID  = "CB000001-CB00-CB00-CB00-CB0000000002"

    private let titleWidgetUUID: String?
    private let taskWidgetUUID: String?
    private let builder: BuildTouchBarBridgePayloadUseCase

    public init(
        titleWidgetUUID: String?,
        taskWidgetUUID: String?,
        builder: BuildTouchBarBridgePayloadUseCase = .init()
    ) {
        self.titleWidgetUUID = titleWidgetUUID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.taskWidgetUUID = taskWidgetUUID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.builder = builder
    }

    public var isConfigured: Bool {
        hasValue(titleWidgetUUID) || hasValue(taskWidgetUUID)
    }

    public func refresh(snapshot: ClaudeBarSnapshot) throws {
        guard isConfigured else { return }

        let payload = builder.execute(snapshot: snapshot, now: snapshot.observedAt)

        if let titleWidgetUUID, hasValue(titleWidgetUUID) {
            try updateWidget(uuid: titleWidgetUUID, text: payload.compactTitle)
        }

        if let taskWidgetUUID, hasValue(taskWidgetUUID) {
            try updateWidget(uuid: taskWidgetUUID, text: payload.compactTask)
        }
    }

    private func updateWidget(uuid: String, text: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-l",
            "JavaScript",
            "-e",
            jxaScript(uuid: uuid, text: text),
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw BetterTouchToolWidgetUpdaterError.updateFailed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func jxaScript(uuid: String, text: String) -> String {
        """
        const BetterTouchTool = Application("BetterTouchTool");
        BetterTouchTool.update_touch_bar_widget("\(jsEscaped(uuid))", { text: "\(jsEscaped(text))" });
        """
    }

    private func jsEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func hasValue(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.isEmpty
    }
}

public enum BetterTouchToolWidgetUpdaterError: LocalizedError {
    case updateFailed(String)

    public var errorDescription: String? {
        switch self {
        case .updateFailed(let message):
            return message.isEmpty ? "BetterTouchTool no pudo actualizar el widget." : message
        }
    }
}
