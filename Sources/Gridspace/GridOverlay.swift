import AppKit
import GridCore

/// A brief HUD showing where you are in the grid after each switch.
final class GridOverlay {
    private let panel: NSPanel
    private let view = GridView()
    private var hide: DispatchWorkItem?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = view
    }

    func show(grid: Grid, current: Int, available: Int) {
        view.grid = grid
        view.current = current
        view.available = available
        let size = GridView.size(for: grid)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}

private final class GridView: NSView {
    static let cell: CGFloat = 34, gap: CGFloat = 8, padding: CGFloat = 16

    var grid = Grid(rows: 2, cols: 2)
    var current = 0
    var available = 0

    static func size(for grid: Grid) -> NSSize {
        NSSize(
            width: CGFloat(grid.cols) * cell + CGFloat(grid.cols - 1) * gap + 2 * padding,
            height: CGFloat(grid.rows) * cell + CGFloat(grid.rows - 1) * gap + 2 * padding
        )
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14).fill()
        for index in 0..<grid.cells {
            guard let (row, col) = grid.position(of: index) else { continue }
            let rect = NSRect(
                x: Self.padding + CGFloat(col) * (Self.cell + Self.gap),
                y: Self.padding + CGFloat(row) * (Self.cell + Self.gap),
                width: Self.cell, height: Self.cell
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            if index == current {
                NSColor.white.withAlphaComponent(0.95).setFill()
                path.fill()
            } else if index < available {
                NSColor.white.withAlphaComponent(0.25).setFill()
                path.fill()
            } else {
                NSColor.white.withAlphaComponent(0.25).setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
        }
    }
}
