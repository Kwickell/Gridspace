import AppKit
import GridCore

/// A brief HUD showing where you are in the grid after each switch, on desktops and fullscreen apps alike.
final class GridOverlay {
    private let panel: NSPanel
    private let view = GridView()
    private var hide: DispatchWorkItem?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = view
    }

    func show(_ layout: SpaceLayout, columns: Int) {
        guard let current = layout.current else { return }
        view.grid = layout.grid(columns: columns)
        view.current = current
        view.icons = layout.apps.map { NSRunningApplication(processIdentifier: $0.pid)?.icon }
        let size = view.preferredSize
        let screen = NSScreen.main?.frame ?? .zero
        panel.setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height), display: true)
        view.needsDisplay = true

        hide?.cancel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        let work = DispatchWorkItem { [panel] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel.animator().alphaValue = 0 }) {
                if panel.alphaValue == 0 { panel.orderOut(nil) }
            }
        }
        hide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }
}

private final class GridView: NSView {
    private let cell: CGFloat = 40, gap: CGFloat = 8, padding: CGFloat = 16, sectionGap: CGFloat = 18

    var grid = GridLayout(columns: 1, desktops: 0, apps: 0)
    var current = 0
    var icons: [NSImage?] = []

    private var hasSections: Bool { grid.desktops > 0 && grid.apps > 0 }

    var preferredSize: NSSize {
        let rows = CGFloat(grid.rows)
        return NSSize(
            width: CGFloat(grid.columns) * cell + CGFloat(grid.columns - 1) * gap + 2 * padding,
            height: rows * cell + max(0, rows - 1) * gap + (hasSections ? sectionGap - gap : 0) + 2 * padding
        )
    }

    override var isFlipped: Bool { true }

    private func rect(row: Int, col: Int) -> NSRect {
        let sectionShift = hasSections && row >= grid.desktopRows ? sectionGap - gap : 0
        return NSRect(
            x: padding + CGFloat(col) * (cell + gap),
            y: padding + CGFloat(row) * (cell + gap) + sectionShift,
            width: cell, height: cell
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14).fill()

        if hasSections {
            let y = rect(row: grid.desktopRows, col: 0).minY - sectionGap / 2
            NSColor.white.withAlphaComponent(0.2).setFill()
            NSRect(x: padding, y: y - 0.5, width: bounds.width - 2 * padding, height: 1).fill()
        }

        for item in 0..<grid.items {
            guard let (row, col) = grid.position(of: item) else { continue }
            let frame = rect(row: row, col: col)
            let selected = item == current
            let path = NSBezierPath(roundedRect: frame, xRadius: 7, yRadius: 7)
            NSColor.white.withAlphaComponent(selected ? 0.95 : 0.22).setFill()
            path.fill()

            if grid.isApp(item), let icon = icons[safe: item - grid.desktops] ?? nil {
                icon.draw(in: frame.insetBy(dx: 5, dy: 5), from: .zero, operation: .sourceOver, fraction: selected ? 1 : 0.7, respectFlipped: true, hints: nil)
            } else {
                let label = grid.isApp(item) ? "•" : "\(item + 1)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                    .foregroundColor: selected ? NSColor.black : NSColor.white.withAlphaComponent(0.85),
                ]
                let size = label.size(withAttributes: attributes)
                label.draw(at: NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2), withAttributes: attributes)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
