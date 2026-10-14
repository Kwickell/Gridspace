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
    /// Survives logins and app relaunches: the desktop's uuid, or the app's bundle id.
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

    static func layout(order: [String] = SpaceOrder.saved) -> SpaceLayout? {
        let connection = CGSMainConnectionID()
        let active = CGSGetActiveSpace(connection)
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else { return nil }

        for display in displays {
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            guard spaces.compactMap(spaceID).contains(active) else { continue }

            var desktopNumber = 0
            var appCopies: [String: Int] = [:]
            let found: [SpaceItem] = spaces.compactMap { space in
                guard let id = spaceID(space) else { return nil }
                switch space["type"] as? Int {
                case desktopType:
                    desktopNumber += 1
                    return SpaceItem(id: id, key: "desktop:\(space["uuid"] as? String ?? "")", kind: .desktop(number: desktopNumber), name: "Desktop \(desktopNumber)")
                case fullscreenType:
                    guard let app = appInfo(space) else { return nil }
                    let copy = appCopies[app.bundle, default: 0]
                    appCopies[app.bundle] = copy + 1
                    return SpaceItem(id: id, key: "app:\(app.bundle)#\(copy)", kind: .app(pid: app.pid), name: app.name)
                default:
                    return nil
                }
            }
            let items = ordered(found, key: \.key, saved: order)
            return SpaceLayout(
                items: items,
                current: items.firstIndex { $0.id == active },
                missionControlOrder: spaces.compactMap(spaceID),
                activeID: active,
                displayID: display["Display Identifier"] as? String ?? ""
            )
        }
        return nil
    }

    private static func spaceID(_ space: [String: Any]) -> UInt64? {
        // ISS counts Spaces by id64, so the indices only agree if this does too.
        space["id64"] as? UInt64
    }

    private static func appInfo(_ space: [String: Any]) -> (pid: pid_t, bundle: String, name: String)? {
        let tiles = (space["TileLayoutManager"] as? [String: Any])?["TileSpaces"] as? [[String: Any]]
        guard let pid = (space["pid"] as? Int32) ?? (tiles?.first?["pid"] as? Int32) else { return nil }
        let app = NSRunningApplication(processIdentifier: pid)
        let name = app?.localizedName ?? tiles?.first?["appName"] as? String ?? "App"
        return (pid, app?.bundleIdentifier ?? name, name)
    }
}

/// Gridspace's own order of Spaces, by key. Spaces it hasn't seen go last.
enum SpaceOrder {
    private static let defaultsKey = "spaceOrder"

    static var saved: [String] {
        get { UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// Records the current order, so a new Space stays last wherever macOS put it and a closed one drops out.
    static func sync(_ layout: SpaceLayout) {
        let keys = layout.items.map(\.key)
        if keys != saved { saved = keys }
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
