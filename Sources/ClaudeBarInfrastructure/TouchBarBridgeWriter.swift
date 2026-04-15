import Foundation
import ClaudeBarApplication
import ClaudeBarDomain

public final class TouchBarBridgeFileWriter {
    private let fileURL: URL
    private let builder: BuildTouchBarBridgePayloadUseCase
    private let encoder: JSONEncoder

    public init(
        fileURL: URL = ClaudeFilesystemPaths.default().touchBarBridgeURL,
        builder: BuildTouchBarBridgePayloadUseCase = .init()
    ) {
        self.fileURL = fileURL
        self.builder = builder

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func write(snapshot: ClaudeBarSnapshot) throws {
        let payload = builder.execute(snapshot: snapshot, now: snapshot.observedAt)
        let data = try encoder.encode(payload)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
