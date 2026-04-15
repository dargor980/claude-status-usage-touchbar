import AppKit
import Combine
import SwiftUI
import ClaudeBarApplication
import ClaudeBarInfrastructure
import ClaudeBarPresentation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTouchBarProvider {
    private let viewModel: ClaudeBarViewModel
    private let touchBarController: TouchBarController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellables: Set<AnyCancellable> = []
    private var dashboardWindow: NSWindow?
    var touchBar: NSTouchBar? { touchBarController.touchBar }

    override init() {
        let repository = ClaudeFilesystemActivityRepository()
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let policyProvider = JSONUsagePolicyProvider(
            fileURL: root.appendingPathComponent("claudebar.config.json"),
            fallback: DefaultUsagePolicyProvider()
        )
        let useCase = ObserveClaudeBarSnapshotUseCase(repository: repository, usagePolicyProvider: policyProvider)
        let viewModel = ClaudeBarViewModel(useCase: useCase)

        self.viewModel = viewModel
        self.touchBarController = TouchBarController(initialSnapshot: viewModel.snapshot)

        super.init()

        viewModel.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.touchBarController.update(snapshot: snapshot)
            }
            .store(in: &cancellables)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        configureStatusItem()
        configureDashboardWindow()
        touchBarController.configure(onResume: { [weak self] in
            self?.resumeCurrentSession()
        })

        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Task {
            await viewModel.refresh()
            viewModel.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
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
}
