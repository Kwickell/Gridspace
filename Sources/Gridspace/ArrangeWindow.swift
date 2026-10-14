import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class ArrangeModel: ObservableObject {
    struct Tile: Identifiable, Equatable {
        let id: String
        let name: String
        let icon: NSImage?
        let isCurrent: Bool
    }

    @Published var tiles: [Tile] = []
    @Published var columns: Int
    @Published var dragging: Tile?

    init(columns: Int) {
        self.columns = columns
        reload()
    }

    func reload() {
        guard let layout = Spaces.layout() else { tiles = []; return }
        tiles = layout.items.enumerated().map { index, item in
            Tile(id: item.key, name: item.name, icon: item.icon, isCurrent: index == layout.current)
        }
    }

    func move(_ tile: Tile, to target: Tile) {
        guard let from = tiles.firstIndex(of: tile), let to = tiles.firstIndex(of: target), from != to else { return }
        tiles.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func save() {
        SpaceOrder.saved = tiles.map(\.id)
    }

    func resetToMissionControl() {
        guard let layout = Spaces.layout(order: []) else { return }
        SpaceOrder.saved = layout.items.map(\.key)
        reload()
    }
}

struct ArrangeView: View {
    @ObservedObject var model: ArrangeModel
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Drag Spaces into the order you want. New Spaces are added at the end.")
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(96), spacing: 10), count: model.columns), alignment: .leading, spacing: 10) {
                ForEach(model.tiles) { tile in
                    tileView(tile)
                        .onDrag {
                            model.dragging = tile
                            return NSItemProvider(object: tile.id as NSString)
                        }
                        .onDrop(of: [.text], delegate: TileDrop(target: tile, model: model, onChange: onChange))
                }
            }
            HStack {
                Button("Reset to Mission Control order") { model.resetToMissionControl(); onChange() }
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .fixedSize()
    }

    private func tileView(_ tile: ArrangeModel.Tile) -> some View {
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
        .frame(width: 96, height: 80)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(model.dragging == tile ? 0.15 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tile.isCurrent ? Color.accentColor : .clear, lineWidth: 2))
        .contentShape(Rectangle())
    }
}

private struct TileDrop: DropDelegate {
    let target: ArrangeModel.Tile
    let model: ArrangeModel
    let onChange: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging = model.dragging else { return }
        withAnimation(.easeInOut(duration: 0.15)) { model.move(dragging, to: target) }
        model.save()
        onChange()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        model.dragging = nil
        return true
    }
}

final class ArrangeWindowController: NSWindowController {
    private let model: ArrangeModel

    init(columns: Int, onChange: @escaping () -> Void) {
        model = ArrangeModel(columns: columns)
        let window = NSWindow(contentViewController: NSHostingController(rootView: ArrangeView(model: model, onChange: onChange)))
        window.title = "Arrange Spaces"
        window.styleMask = [.titled, .closable]
        // Opening on top of a fullscreen app keeps you on that Space instead of jumping to a desktop.
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.level = .floating
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func present(columns: Int) {
        model.columns = columns
        model.reload()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
