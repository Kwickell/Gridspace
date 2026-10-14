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
    @Published var dragging: Int?
    private var displayID = ""
    private var missionControlKeys: [String] = []
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        reload()
    }

    func reload() {
        dragging = nil
        guard let layout = Spaces.layout() else { return }
        displayID = layout.displayID
        missionControlKeys = layout.items.map(\.key)
        grid = layout.grid
        let currentKey = layout.current.flatMap { layout.grid.cells[$0] }
        tiles = Dictionary(uniqueKeysWithValues: layout.items.map { item in
            (item.key, Tile(key: item.key, name: item.name, icon: item.icon, isCurrent: item.key == currentKey))
        })
    }

    func tile(at cell: Int) -> Tile? {
        grid.cells[cell].flatMap { tiles[$0] }
    }

    func drop(on cell: Int) {
        guard let from = dragging else { return }
        dragging = nil
        grid.move(from: from, to: cell)
        save()
    }

    func resize(rows: Int, columns: Int) {
        grid = grid.resized(rows: rows, columns: columns)
        save()
    }

    /// Mission Control order, packed into the current width.
    func reset() {
        grid = CellGrid.packed(missionControlKeys, columns: grid.columns)
        save()
    }

    private func save() {
        GridStore.save(grid, for: displayID)
        onChange()
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
            .background(shape.fill(Color.primary.opacity(model.dragging == index ? 0.18 : 0.07)))
            .overlay(shape.stroke(tile.isCurrent ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(Rectangle())
            .onDrag {
                model.dragging = index
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
        let window = NSWindow(contentViewController: NSHostingController(rootView: ArrangeView(model: model)))
        window.title = "Arrange Spaces"
        window.styleMask = [.titled, .closable]
        // Opening on top of a fullscreen app keeps you on that Space instead of jumping to a desktop.
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.level = .floating
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func present() {
        model.reload()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        model.dragging = nil
    }
}
