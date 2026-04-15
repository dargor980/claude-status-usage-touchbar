import AppKit
import Combine
import SwiftUI
import ClaudeBarApplication
import ClaudeBarInfrastructure
import ClaudeBarPresentation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTouchBarProvider {
    private let isCISmokeRunEnabled: Bool
    private let shouldOpenDashboardOnLaunch: Bool
    private let viewModel: ClaudeBarViewModel
    private let touchBarController: TouchBarController
    private let touchBarBridgeWriter: TouchBarBridgeFileWriter
    private let betterTouchToolWidgetUpdater: BetterTouchToolWidgetUpdater?
    private let frontmostApplicationMonitor: WorkspaceFrontmostApplicationMonitor
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellables: Set<AnyCancellable> = []
    private var dashboardWindow: NSWindow?
    var touchBar: NSTouchBar? { touchBarController.touchBar }

    override init() {
        let environment = ProcessInfo.processInfo.environment
        self.isCISmokeRunEnabled = environment["CLAUDEBAR_CI_SMOKE_RUN"] == "1"
        self.shouldOpenDashboardOnLaunch = environment["CLAUDEBAR_OPEN_DASHBOARD_ON_LAUNCH"] == "1"

        let repository = ClaudeFilesystemActivityRepository()
        let policyProvider = JSONUsagePolicyProvider(
            fileURL: AppDelegate.resolveConfigurationURL(),
            fallback: DefaultUsagePolicyProvider()
        )
        let usageProvider = CompositeClaudeUsageProvider(
            providers: [
                ClaudeStatusLineUsageProvider(fileURL: AppDelegate.resolveStatusLineCaptureURL()),
                ClaudeHeadlessCLIUsageProvider(),
            ]
        )
        let useCase = ObserveClaudeBarSnapshotUseCase(
            repository: repository,
            usagePolicyProvider: policyProvider,
            usageProvider: usageProvider
        )
        let viewModel = ClaudeBarViewModel(useCase: useCase)

        self.viewModel = viewModel
        self.touchBarController = TouchBarController(initialSnapshot: viewModel.snapshot)
        self.touchBarBridgeWriter = TouchBarBridgeFileWriter(
            fileURL: AppDelegate.resolveTouchBarBridgeURL()
        )
        self.betterTouchToolWidgetUpdater = AppDelegate.makeBetterTouchToolWidgetUpdater()
        self.frontmostApplicationMonitor = WorkspaceFrontmostApplicationMonitor()

        super.init()

        viewModel.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.touchBarController.update(snapshot: snapshot)
                try? self?.touchBarBridgeWriter.write(snapshot: snapshot)
                try? self?.betterTouchToolWidgetUpdater?.refresh(snapshot: snapshot)
            }
            .store(in: &cancellables)

        frontmostApplicationMonitor.onChange = { [weak self] snapshot in
            self?.viewModel.updateTouchBarExperience(frontmostApplication: snapshot)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isCISmokeRunEnabled else {
            Task {
                await viewModel.refresh()
                NSApp.terminate(nil)
            }
            return
        }

        NSApp.setActivationPolicy(.accessory)

        configureStatusItem()
        configureDashboardWindow()
        touchBarController.configure(onResume: { [weak self] in
            self?.resumeCurrentSession()
        })
        frontmostApplicationMonitor.start()

        if shouldOpenDashboardOnLaunch {
            dashboardWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        Task {
            await viewModel.refresh()
            viewModel.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        frontmostApplicationMonitor.stop()
        viewModel.stop()
    }

    private func configureStatusItem() {
        statusItem.button?.title = "claudeBar"
        statusItem.button?.font = .systemFont(ofSize: 12, weight: .semibold)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Resume Current Session", action: #selector(resumeAction), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func configureDashboardWindow() {
        let rootView = ClaudeBarDashboardView(
            viewModel: viewModel,
            onRefresh: { [viewModel] in
                Task { await viewModel.refresh() }
            },
            onResume: { [weak self] in
                self?.resumeCurrentSession()
            }
        )

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "claudeBar"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        self.dashboardWindow = window
    }

    @objc private func openDashboard() {
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func resumeAction() {
        resumeCurrentSession()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func resumeCurrentSession() {
        guard
            let remoteURL = viewModel.snapshot.session?.remoteURL,
            let url = URL(string: remoteURL)
        else {
            openDashboard()
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static func resolveConfigurationURL() -> URL {
        let environment = ProcessInfo.processInfo.environment

        if let overriddenPath = environment["CLAUDEBAR_CONFIG_PATH"], !overriddenPath.isEmpty {
            return URL(fileURLWithPath: overriddenPath)
        }

        if
            let bundledURL = Bundle.main.resourceURL?.appendingPathComponent("claudebar.config.json"),
            FileManager.default.fileExists(atPath: bundledURL.path)
        {
            return bundledURL
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return currentDirectory.appendingPathComponent("claudebar.config.json")
    }

    private static func resolveStatusLineCaptureURL() -> URL {
        let environment = ProcessInfo.processInfo.environment

        if let overriddenPath = environment["CLAUDEBAR_STATUSLINE_CAPTURE_PATH"], !overriddenPath.isEmpty {
            return URL(fileURLWithPath: overriddenPath)
        }

        return ClaudeFilesystemPaths.default().statusLineCaptureURL
    }

    private static func resolveTouchBarBridgeURL() -> URL {
        let environment = ProcessInfo.processInfo.environment

        if let overriddenPath = environment["CLAUDEBAR_TOUCHBAR_BRIDGE_PATH"], !overriddenPath.isEmpty {
            return URL(fileURLWithPath: overriddenPath)
        }

        return ClaudeFilesystemPaths.default().touchBarBridgeURL
    }

    private static func makeBetterTouchToolWidgetUpdater() -> BetterTouchToolWidgetUpdater? {
        let environment = ProcessInfo.processInfo.environment

        // Fall back to the canonical preset UUIDs so that importing
        // claudebar.bttpreset is sufficient — no env var config required.
        let titleUUID = environment["CLAUDEBAR_BTT_TITLE_WIDGET_UUID"]
            ?? BetterTouchToolWidgetUpdater.canonicalTitleWidgetUUID
        let taskUUID = environment["CLAUDEBAR_BTT_TASK_WIDGET_UUID"]
            ?? BetterTouchToolWidgetUpdater.canonicalTaskWidgetUUID

        return BetterTouchToolWidgetUpdater(
            titleWidgetUUID: titleUUID,
            taskWidgetUUID: taskUUID
        )
    }
}
