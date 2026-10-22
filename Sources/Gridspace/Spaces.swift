import AppKit
import GridCore

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ connection: Int32) -> UInt64

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?

struct SpaceItem {
    enum Kind {
        case desktop(number: Int)
        case app(pid: pid_t)
    }

    let id: UInt64
    /// The Space's uuid, which macOS keeps for as long as the Space exists (desktops survive logins).
    let key: String
    let kind: Kind
    let name: String

    var icon: NSImage? {
        if case .app(let pid) = kind { return NSRunningApplication(processIdentifier: pid)?.icon }
        return nil
    }
}

struct SpaceLayout {
    /// Every desktop and fullscreen app on the display, in Mission Control order.
    let items: [SpaceItem]
    /// Where each Space sits in Gridspace's grid.
    let grid: CellGrid
    /// Grid cell of the display's current Space.
    let current: Int?
    /// Every Space on the display in Mission Control order, which is the index ISS switches by.
    let missionControlOrder: [UInt64]
    let displayID: String

    var desktopCount: Int { items.filter { if case .desktop = $0.kind { true } else { false } }.count }

    func item(at cell: Int) -> SpaceItem? {
        guard grid.cells.indices.contains(cell), let key = grid.cells[cell] else { return nil }
        return items.first { $0.key == key }
    }

    func missionControlIndex(of cell: Int) -> Int? {
        guard let id = item(at: cell)?.id else { return nil }
        return missionControlOrder.firstIndex(of: id)
    }
}

enum Spaces {
    private static let desktopType = 0
    private static let fullscreenType = 4

    private struct Display {
        let identifier: String
        let spaces: [[String: Any]]
        let currentID: UInt64?
    }

    private struct Snapshot {
        let active: UInt64
        let displays: [Display]
    }

    /// The display a swipe acts on.
    static func layout() -> SpaceLayout? {
        guard let snapshot = read(), let identifier = target(in: snapshot) else { return nil }
        return layout(for: identifier, in: snapshot, grid: nil)
    }

    /// The display holding the Space macOS considers active, which is the one an outside switch changed.
    static func activeLayout() -> SpaceLayout? {
        guard let snapshot = read(), let display = holder(of: snapshot.active, in: snapshot) else { return nil }
        return layout(display, in: snapshot, grid: nil)
    }

    /// Pass a grid to lay the Spaces out on it instead of the saved one.
    static func layout(for displayID: String, grid saved: CellGrid? = nil) -> SpaceLayout? {
        guard let snapshot = read() else { return nil }
        return layout(for: displayID, in: snapshot, grid: saved)
    }

    /// Every display's Spaces on its own saved grid, in the order CGS reports the displays.
    static func layouts() -> [SpaceLayout] {
        guard let snapshot = read() else { return [] }
        return snapshot.displays.compactMap { layout($0, in: snapshot, grid: nil) }
    }

    /// The display a swipe acts on, for the CLI to mark.
    static func targetDisplayID() -> String? {
        read().flatMap(target(in:))
    }

    private static func target(in snapshot: Snapshot) -> String? {
        if let cursor = Displays.underCursor, snapshot.displays.contains(where: { $0.identifier == cursor }) {
            return cursor
        }
        return holder(of: snapshot.active, in: snapshot)?.identifier
    }

    private static func holder(of space: UInt64, in snapshot: Snapshot) -> Display? {
        snapshot.displays.first { $0.spaces.compactMap(spaceID).contains(space) }
    }

    private static func layout(for displayID: String, in snapshot: Snapshot, grid saved: CellGrid?) -> SpaceLayout? {
        guard let display = snapshot.displays.first(where: { $0.identifier == displayID }) else { return nil }
        return layout(display, in: snapshot, grid: saved)
    }

    private static func layout(_ display: Display, in snapshot: Snapshot, grid saved: CellGrid?) -> SpaceLayout? {
        var desktopNumber = 0
        let found: [SpaceItem] = display.spaces.compactMap { space in
            guard let id = spaceID(space) else { return nil }
            // The first desktop has an empty uuid; its id stays put instead.
            let uuid = space["uuid"] as? String ?? ""
            let key = uuid.isEmpty ? "\(display.identifier)/\(id)" : uuid
            switch space["type"] as? Int {
            case desktopType:
                desktopNumber += 1
                return SpaceItem(id: id, key: key, kind: .desktop(number: desktopNumber), name: "Desktop \(desktopNumber)")
            case fullscreenType:
                let app = appInfo(space)
                return SpaceItem(id: id, key: key, kind: .app(pid: app?.pid ?? 0), name: app?.name ?? "App")
            default:
                return nil
            }
        }
        let keys = found.map(\.key)
        let stored = saved ?? GridStore.grid(for: display.identifier) ?? CellGrid.packed([], columns: GridStore.defaultColumns)
        let grid = stored.reconciled(with: keys)
        // ISS reads the display's own current Space and falls back to the global one; the indices only
        // agree if this does too.
        let currentKey = found.first { $0.id == (display.currentID ?? snapshot.active) }?.key
        return SpaceLayout(
            items: found,
            grid: grid,
            current: currentKey.flatMap(grid.index(of:)),
            missionControlOrder: display.spaces.compactMap(spaceID),
            displayID: display.identifier
        )
    }

    private static func read() -> Snapshot? {
        let connection = CGSMainConnectionID()
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else { return nil }
        return Snapshot(
            active: CGSGetActiveSpace(connection),
            displays: displays.compactMap { display in
                guard let identifier = display["Display Identifier"] as? String else { return nil }
                return Display(
                    identifier: identifier,
                    spaces: display["Spaces"] as? [[String: Any]] ?? [],
                    currentID: (display["Current Space"] as? [String: Any]).flatMap(spaceID)
                )
            }
        )
    }

    private static func spaceID(_ space: [String: Any]) -> UInt64? {
        // ISS counts Spaces by id64, so the indices only agree if this does too.
        space["id64"] as? UInt64
    }

    private static func appInfo(_ space: [String: Any]) -> (pid: pid_t, name: String)? {
        let tiles = (space["TileLayoutManager"] as? [String: Any])?["TileSpaces"] as? [[String: Any]]
        guard let pid = (space["pid"] as? Int32) ?? (tiles?.first?["pid"] as? Int32) else { return nil }
        let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? tiles?.first?["appName"] as? String ?? "App"
        return (pid, name)
    }
}

/// Gridspace's grid per display.
enum GridStore {
    static let defaultColumns = 3
    private static let defaultsKey = "gridByDisplay"

    private static var all: [String: [String: Any]] {
        get { UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String: Any]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static func grid(for displayID: String) -> CellGrid? {
        guard let saved = all[displayID],
              let rows = saved["rows"] as? Int, let columns = saved["columns"] as? Int,
              let cells = saved["cells"] as? [String]
        else { return nil }
        return CellGrid(rows: rows, columns: columns, cells: cells.map { $0.isEmpty ? nil : $0 })
    }

    static func save(_ grid: CellGrid, for displayID: String) {
        all[displayID] = ["rows": grid.rows, "columns": grid.columns, "cells": grid.cells.map { $0 ?? "" }]
    }

    /// Records the grid with new Spaces placed and closed ones removed, so later placements build on it.
    static func sync(_ layout: SpaceLayout) {
        if grid(for: layout.displayID) != layout.grid { save(layout.grid, for: layout.displayID) }
    }
}
