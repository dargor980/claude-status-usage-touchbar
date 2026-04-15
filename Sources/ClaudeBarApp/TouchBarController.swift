import AppKit
import SwiftUI
import ClaudeBarDomain
import ClaudeBarPresentation

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let itemIdentifier = NSTouchBarItem.Identifier("com.germancontreras.claudebar.strip")

    private var currentSnapshot: ClaudeBarSnapshot
    private var onResume: (() -> Void)?
    private var customItem: NSCustomTouchBarItem?
    let touchBar: NSTouchBar

    init(initialSnapshot: ClaudeBarSnapshot) {
        self.currentSnapshot = initialSnapshot
        self.touchBar = NSTouchBar()
        super.init()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [itemIdentifier]
    }

    func configure(onResume: @escaping () -> Void) {
        self.onResume = onResume
    }

    func update(snapshot: ClaudeBarSnapshot) {
        currentSnapshot = snapshot
        guard let customItem else { return }
        customItem.view = makeHostingView()
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == itemIdentifier else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = makeHostingView()
        customItem = item
        return item
    }

    private func makeHostingView() -> NSView {
        let view = TouchBarStripView(snapshot: currentSnapshot) { [weak self] in
            self?.onResume?()
        }

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 30)
        return hostingView
    }
}
