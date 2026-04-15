import AppKit

let application = NSApplication.shared
let delegate = await MainActor.run { AppDelegate() }

await MainActor.run {
    application.delegate = delegate
    application.run()
}
