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

    func show(_ layout: SpaceLayout) {
        guard let current = layout.current else { return }
        view.grid = layout.grid
        view.current = current
        view.items = layout.grid.cells.indices.map { cell in
            guard let item = layout.item(at: cell) else { return .empty }
            if case .desktop(let number) = item.kind { return .label("\(number)") }
            return item.icon.map(GridView.Cell.icon) ?? .label(String(item.name.prefix(1)))
        }
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
    enum Cell {
        case empty
        case label(String)
        case icon(NSImage)
    }

    private let cell: CGFloat = 40, gap: CGFloat = 8, padding: CGFloat = 16

    var grid = CellGrid(rows: 1, columns: 1)
    var current = 0
    var items: [Cell] = []

    var preferredSize: NSSize {
        let rows = CGFloat(grid.rows)
        return NSSize(
            width: CGFloat(grid.columns) * cell + CGFloat(grid.columns - 1) * gap + 2 * padding,
            height: rows * cell + max(0, rows - 1) * gap + 2 * padding
        )
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14).fill()

        for (index, content) in items.enumerated() {
            guard let (row, col) = grid.position(of: index) else { continue }
            let frame = NSRect(x: padding + CGFloat(col) * (cell + gap), y: padding + CGFloat(row) * (cell + gap), width: cell, height: cell)
            let selected = index == current
            let path = NSBezierPath(roundedRect: frame, xRadius: 7, yRadius: 7)
            if case .empty = content {
                NSColor.white.withAlphaComponent(0.15).setStroke()
                path.lineWidth = 1
                path.stroke()
                continue
            }
            NSColor.white.withAlphaComponent(selected ? 0.95 : 0.22).setFill()
            path.fill()

            switch content {
            case .empty:
                break
            case .icon(let icon):
                icon.draw(in: frame.insetBy(dx: 5, dy: 5), from: .zero, operation: .sourceOver, fraction: selected ? 1 : 0.7, respectFlipped: true, hints: nil)
            case .label(let label):
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
