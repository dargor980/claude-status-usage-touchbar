import AppKit
import Combine
import SwiftUI
import ClaudeBarApplication
import ClaudeBarInfrastructure
import ClaudeBarPresentation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTouchBarProvider {
    private let isCISmokeRunEnabled: Bool
    private let viewModel: ClaudeBarViewModel
    private let touchBarController: TouchBarController
    private let frontmostApplicationMonitor: WorkspaceFrontmostApplicationMonitor
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellables: Set<AnyCancellable> = []
    private var dashboardWindow: NSWindow?
    var touchBar: NSTouchBar? { touchBarController.touchBar }

    override init() {
        self.isCISmokeRunEnabled = ProcessInfo.processInfo.environment["CLAUDEBAR_CI_SMOKE_RUN"] == "1"

        let repository = ClaudeFilesystemActivityRepository()
        let policyProvider = JSONUsagePolicyProvider(
            fileURL: AppDelegate.resolveConfigurationURL(),
            fallback: DefaultUsagePolicyProvider()
        )
        let useCase = ObserveClaudeBarSnapshotUseCase(repository: repository, usagePolicyProvider: policyProvider)
        let viewModel = ClaudeBarViewModel(useCase: useCase)

        self.viewModel = viewModel
        self.touchBarController = TouchBarController(initialSnapshot: viewModel.snapshot)
        self.frontmostApplicationMonitor = WorkspaceFrontmostApplicationMonitor()

        super.init()

        viewModel.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.touchBarController.update(snapshot: snapshot)
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

        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

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
}
