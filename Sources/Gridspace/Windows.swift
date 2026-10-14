import AppKit
import SwiftUI

/// A titled window hosting a SwiftUI view, for a menu bar app with no main window.
final class HostedWindow<Content: View>: NSWindowController {
    init(title: String, @ViewBuilder content: () -> Content) {
        let host = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: host)
        // Size to the content now so center() places the finished window, not an empty one.
        window.setContentSize(host.view.fittingSize)
        window.title = title
        window.styleMask = [.titled, .closable]
        // Opening on top of a fullscreen app keeps you on that Space instead of jumping to a desktop.
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func present() {
        if window?.isVisible != true { window?.center() }
        window?.level = .floating
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
