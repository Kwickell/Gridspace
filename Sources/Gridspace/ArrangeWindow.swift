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

    @Published private(set) var grid = CellGrid(rows: 1, columns: 1)
    @Published private(set) var tiles: [String: Tile] = [:]
    /// Key of the Space being dragged; a key rather than a cell so a resize mid-drag can't retarget it.
    @Published var dragging: String?
    private(set) var displayID = ""
    private var missionControlKeys: [String] = []
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        reload()
    }

    /// Picks the display again, which `reload` then holds on to for as long as the window stays open.
    func open() {
        displayID = ""
        reload()
    }

    func reload() {
        dragging = nil
        // Holding the display keeps the pointer moving to another screen from swapping the grid mid-edit.
        guard let layout = Spaces.layout(for: displayID) ?? Spaces.activeLayout() else { return }
        displayID = layout.displayID
        missionControlKeys = layout.items.map(\.key)
        grid = layout.grid
        let currentKey = layout.current.flatMap { layout.grid.cells[$0] }
        tiles = Dictionary(layout.items.map { item in
            (item.key, Tile(key: item.key, name: item.name, icon: item.icon, isCurrent: item.key == currentKey))
        }, uniquingKeysWith: { first, _ in first })
    }

    func tile(at cell: Int) -> Tile? {
        grid.cells[cell].flatMap { tiles[$0] }
    }

    func drop(on cell: Int) {
        guard let key = dragging else { return }
        dragging = nil
        edit { grid in
            if let from = grid.index(of: key) { grid.move(from: from, to: cell) }
        }
    }

    func resize(rows: Int, columns: Int) {
        dragging = nil
        edit { $0 = $0.resized(rows: rows, columns: columns) }
    }

    /// Mission Control order, packed into the current width.
    func reset() {
        dragging = nil
        edit { $0 = CellGrid.packed(missionControlKeys, columns: $0.columns) }
    }

    /// Applies an edit to the shown grid brought up to date with the live Spaces, so Spaces that opened
    /// or closed while the window was open aren't lost or resurrected by the save.
    private func edit(_ change: (inout CellGrid) -> Void) {
        guard let layout = Spaces.layout(for: displayID, grid: grid) else { reload(); return }
        var updated = layout.grid
        change(&updated)
        GridStore.save(updated, for: displayID)
        reload()
        onChange()
    }

    /// Picks up Spaces that opened or closed, unless a drag is in progress.
    func refresh() {
        if dragging == nil { reload() }
    }
}

struct ArrangeView: View {
    @ObservedObject var model: ArrangeModel
    private let size: CGFloat = 92

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                Stepper("Rows: \(model.grid.rows)", value: Binding(
                    get: { model.grid.rows },
                    set: { model.resize(rows: $0, columns: model.grid.columns) }
                ), in: 1...8)
                Stepper("Columns: \(model.grid.columns)", value: Binding(
                    get: { model.grid.columns },
                    set: { model.resize(rows: model.grid.rows, columns: $0) }
                ), in: 1...8)
            }
            Text("Drag a Space onto any cell. Dropping it on another Space swaps them. New Spaces fill the first free cell, and a full grid grows by a row.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: max(300, CGFloat(model.grid.columns) * (size + 8)), alignment: .leading)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(0..<model.grid.rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<model.grid.columns, id: \.self) { col in
                            cell(row * model.grid.columns + col)
                        }
                    }
                }
            }
            HStack {
                Button("Reset to Mission Control order") { model.reset() }
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .fixedSize()
    }

    @ViewBuilder
    private func cell(_ index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        if let tile = model.tile(at: index) {
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
            .background(shape.fill(Color.primary.opacity(model.dragging == tile.key ? 0.18 : 0.07)))
            .overlay(shape.stroke(tile.isCurrent ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(Rectangle())
            .onDrag {
                model.dragging = tile.key
                return NSItemProvider(object: tile.key as NSString)
            }
            .onDrop(of: [.text], delegate: CellDrop(cell: index, model: model))
        } else {
            shape.strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: size, height: size - 12)
                .contentShape(Rectangle())
                .onDrop(of: [.text], delegate: CellDrop(cell: index, model: model))
        }
    }
}

private struct CellDrop: DropDelegate {
    let cell: Int
    let model: ArrangeModel

    func validateDrop(info: DropInfo) -> Bool { model.dragging != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.easeInOut(duration: 0.15)) { model.drop(on: cell) }
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
        model.open()
        updateTitle()
        window?.center()
        // Activating first so the panel is reliably key, since it closes when it stops being key.
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    func refresh() {
        guard window?.isVisible == true else { return }
        model.refresh()
        // The shown display changes under us when the pinned one is unplugged.
        updateTitle()
    }

    private func updateTitle() {
        window?.title = NSScreen.screens.count > 1 ? "Arrange Spaces on \(Displays.name(for: model.displayID))" : "Arrange Spaces"
    }

    func windowDidResignKey(_ notification: Notification) {
        model.dragging = nil
        window?.close()
    }
}
