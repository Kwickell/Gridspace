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
    /// Every desktop and fullscreen app on the active display, in Gridspace's order.
    let items: [SpaceItem]
    /// Index into `items` of the active Space.
    let current: Int?
    /// Every Space on the active display in Mission Control order, which is the index ISS switches by.
    let missionControlOrder: [UInt64]
    let activeID: UInt64
    let displayID: String

    var desktopCount: Int { items.filter { if case .desktop = $0.kind { true } else { false } }.count }

    func grid(columns: Int) -> GridLayout {
        GridLayout(columns: columns, items: items.count)
    }
}

enum Spaces {
    private static let desktopType = 0
    private static let fullscreenType = 4

    /// Pass `order: []` for Mission Control order.
    static func layout(order: [String]? = nil) -> SpaceLayout? {
        let connection = CGSMainConnectionID()
        let active = CGSGetActiveSpace(connection)
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else { return nil }

        for display in displays {
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            guard spaces.compactMap(spaceID).contains(active) else { continue }

            let displayID = display["Display Identifier"] as? String ?? ""
            var desktopNumber = 0
            let found: [SpaceItem] = spaces.compactMap { space in
                guard let id = spaceID(space) else { return nil }
                // The first desktop has an empty uuid; its id stays put instead.
                let uuid = space["uuid"] as? String ?? ""
                let key = uuid.isEmpty ? "\(displayID)/\(id)" : uuid
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
            let items = ordered(found, key: \.key, saved: order ?? SpaceOrder.saved(for: displayID))
            return SpaceLayout(
                items: items,
                current: items.firstIndex { $0.id == active },
                missionControlOrder: spaces.compactMap(spaceID),
                activeID: active,
                displayID: displayID
            )
        }
        return nil
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

/// Gridspace's own order of Spaces per display, by key. Spaces it hasn't seen go last.
enum SpaceOrder {
    private static let defaultsKey = "spaceOrderByDisplay"

    private static var all: [String: [String]] {
        get { UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static func saved(for displayID: String) -> [String] {
        all[displayID] ?? []
    }

    static func save(_ keys: [String], for displayID: String) {
        all[displayID] = keys
    }

    /// Records the current order, so a new Space stays last wherever macOS put it and a closed one drops out.
    static func sync(_ layout: SpaceLayout) {
        let keys = layout.items.map(\.key)
        if keys != saved(for: layout.displayID) { save(keys, for: layout.displayID) }
    }
}
