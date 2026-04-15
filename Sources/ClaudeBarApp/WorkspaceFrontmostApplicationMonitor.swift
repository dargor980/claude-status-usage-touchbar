import AppKit
import ClaudeBarApplication

final class WorkspaceFrontmostApplicationMonitor: NSObject {
    private let workspace: NSWorkspace
    private var activationObserver: NSObjectProtocol?

    private(set) var currentSnapshot: FrontmostApplicationSnapshot
    var onChange: ((FrontmostApplicationSnapshot) -> Void)?

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        self.currentSnapshot = WorkspaceFrontmostApplicationMonitor.makeSnapshot(from: workspace.frontmostApplication)
        super.init()
    }

    func start() {
        guard activationObserver == nil else { return }

        activationObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.handleActivation(for: application)
        }

        onChange?(currentSnapshot)
    }

    func stop() {
        guard let activationObserver else { return }
        workspace.notificationCenter.removeObserver(activationObserver)
        self.activationObserver = nil
    }

    private func handleActivation(for application: NSRunningApplication?) {
        let snapshot = WorkspaceFrontmostApplicationMonitor.makeSnapshot(from: application ?? workspace.frontmostApplication)
        currentSnapshot = snapshot
        onChange?(snapshot)
    }

    private static func makeSnapshot(from application: NSRunningApplication?) -> FrontmostApplicationSnapshot {
        guard let application else {
            return .unknown()
        }

        return FrontmostApplicationSnapshot(
            localizedName: application.localizedName ?? "App desconocida",
            bundleIdentifier: application.bundleIdentifier
        )
    }
}
