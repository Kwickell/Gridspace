import AppKit
import GridCore
import SwiftUI
import UniformTypeIdentifiers

final class ArrangeModel: ObservableObject {
    struct Tile: Equatable {
        let key: String
        let name: String
        let icon: NSImage?
        let isCurrent: Bool
    }

    struct Display: Identifiable {
        let id: String
        let name: String
        /// Where the screen sits, so the panels can be laid out the way the screens are.
        let frame: CGRect
        let grid: CellGrid
        let tiles: [String: Tile]
        let missionControlKeys: [String]

        func tile(at cell: Int) -> Tile? {
            grid.cells[cell].flatMap { tiles[$0] }
        }
    }

    /// A Space being dragged, carried as a key so a resize mid-drag can't retarget it, and with the
    /// display it came from so a drop on another display's grid can be refused.
    struct Drag {
        let key: String
        let displayID: String
    }

    @Published private(set) var displays: [Display] = []
    @Published var dragging: Drag?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        reload()
    }

    func reload() {
        dragging = nil
        displays = Spaces.layouts().map { layout in
            let currentKey = layout.current.flatMap { layout.grid.cells[$0] }
            return Display(
                id: layout.displayID,
                name: Displays.name(for: layout.displayID),
                frame: Displays.screen(for: layout.displayID)?.frame ?? .zero,
                grid: layout.grid,
                tiles: Dictionary(layout.items.map { item in
                    (item.key, Tile(key: item.key, name: item.name, icon: item.icon, isCurrent: item.key == currentKey))
                }, uniquingKeysWith: { first, _ in first }),
                missionControlKeys: layout.items.map(\.key)
            )
        }
        .sorted { $0.frame.minX < $1.frame.minX }
    }

    func drop(on cell: Int, of displayID: String) {
        guard let dragging, dragging.displayID == displayID else { return }
        let key = dragging.key
        self.dragging = nil
        edit(displayID) { grid in
            if let from = grid.index(of: key) { grid.move(from: from, to: cell) }
        }
    }

    func resize(_ displayID: String, rows: Int, columns: Int) {
        dragging = nil
        edit(displayID) { $0 = $0.resized(rows: rows, columns: columns) }
    }

    /// Mission Control order, packed into the current width.
    func reset(_ displayID: String) {
        dragging = nil
        guard let keys = displays.first(where: { $0.id == displayID })?.missionControlKeys else { return }
        edit(displayID) { $0 = CellGrid.packed(keys, columns: $0.columns) }
    }

    /// Applies an edit to the shown grid brought up to date with the live Spaces, so Spaces that opened
    /// or closed while the window was open aren't lost or resurrected by the save.
    private func edit(_ displayID: String, _ change: (inout CellGrid) -> Void) {
        guard let shown = displays.first(where: { $0.id == displayID }),
              let layout = Spaces.layout(for: displayID, grid: shown.grid)
        else { reload(); return }
        var updated = layout.grid
        change(&updated)
        GridStore.save(updated, for: layout.storageKey)
        reload()
        onChange()
    }

    /// Picks up Spaces that opened or closed, unless a drag is in progress. A drop that was refused
    /// leaves the drag set with nothing to clear it, so a released mouse button also counts as over.
    func refresh() {
        if dragging == nil || NSEvent.pressedMouseButtons == 0 { reload() }
    }
}

struct ArrangeView: View {
    @ObservedObject var model: ArrangeModel
    private let size: CGFloat = 92

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Drag a Space onto any cell, or onto another Space to swap them. A Space cannot move between displays, and Reset order puts a display back in Mission Control order.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520, alignment: .leading)
            HStack(alignment: .top, spacing: 20) {
                ForEach(model.displays) { display in
                    panel(display)
                }
            }
            HStack {
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .fixedSize()
    }

    @ViewBuilder
    private func panel(_ display: ArrangeModel.Display) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(display.name).font(.headline)
            HStack(spacing: 12) {
                Stepper("Rows: \(display.grid.rows)", value: Binding(
                    get: { display.grid.rows },
                    set: { model.resize(display.id, rows: $0, columns: display.grid.columns) }
                ), in: 1...8)
                Stepper("Columns: \(display.grid.columns)", value: Binding(
                    get: { display.grid.columns },
                    set: { model.resize(display.id, rows: display.grid.rows, columns: $0) }
                ), in: 1...8)
            }
            .fixedSize()
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(0..<display.grid.rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<display.grid.columns, id: \.self) { col in
                            cell(row * display.grid.columns + col, of: display)
                        }
                    }
                }
            }
            // Pushes every panel's reset to the bottom of the tallest one, so the rows line up.
            Spacer(minLength: 12)
            Button("Reset order") { model.reset(display.id) }
                .controlSize(.small)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
    }

    @ViewBuilder
    private func cell(_ index: Int, of display: ArrangeModel.Display) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        let drop = CellDrop(cell: index, displayID: display.id, model: model)
        if let tile = display.tile(at: index) {
            VStack(spacing: 6) {
                Group {
                    if let icon = tile.icon {
                        Image(nsImage: icon).resizable().frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "menubar.dock.rectangle").font(.system(size: 28)).frame(width: 40, height: 40)
                    }
                }
                Text(tile.name).font(.caption).lineLimit(1).truncationMode(.tail)
            }
            .frame(width: size, height: size - 12)
            .background(shape.fill(Color.primary.opacity(model.dragging?.key == tile.key ? 0.22 : 0.10)))
            .overlay(shape.stroke(tile.isCurrent ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(Rectangle())
            .onDrag {
                model.dragging = ArrangeModel.Drag(key: tile.key, displayID: display.id)
                return NSItemProvider(object: tile.key as NSString)
            }
            .onDrop(of: [.text], delegate: drop)
        } else {
            shape.strokeBorder(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: size, height: size - 12)
                .contentShape(Rectangle())
                .onDrop(of: [.text], delegate: drop)
        }
    }
}

private struct CellDrop: DropDelegate {
    let cell: Int
    let displayID: String
    let model: ArrangeModel

    func validateDrop(info: DropInfo) -> Bool { model.dragging?.displayID == displayID }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.easeInOut(duration: 0.15)) { model.drop(on: cell, of: displayID) }
        return true
    }
}

final class ArrangeWindowController: NSWindowController, NSWindowDelegate {
    private let model: ArrangeModel

    init(onChange: @escaping () -> Void) {
        model = ArrangeModel(onChange: onChange)
        let panel = NSPanel(contentViewController: NSHostingController(rootView: ArrangeView(model: model)))
        panel.title = "Arrange Spaces"
        panel.styleMask = [.titled, .closable, .utilityWindow]
        panel.isFloatingPanel = true
        // Closing on resign is this window's job, so don't let AppKit hide it behind our back.
        panel.hidesOnDeactivate = false
        // Opening on top of a fullscreen app keeps you on that Space instead of jumping to a desktop.
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.level = .floating
        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func present() {
        model.reload()
        window?.center()
        // Activating first so the panel is reliably key, since it closes when it stops being key.
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    func refresh() {
        guard window?.isVisible == true else { return }
        model.refresh()
    }

    func windowDidResignKey(_ notification: Notification) {
        model.dragging = nil
        window?.close()
    }
}
