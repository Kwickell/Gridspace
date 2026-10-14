import AppKit
import GridCore

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ connection: Int32) -> UInt64

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?

struct AppSpace {
    let id: UInt64
    let pid: pid_t
    let name: String
}

struct SpaceLayout {
    /// Regular desktops on the active display, in Mission Control order.
    let desktopIDs: [UInt64]
    /// Fullscreen apps on the active display, oldest first so a new one always lands at the end.
    let apps: [AppSpace]
    /// Grid item of the active Space, desktops first, then apps.
    let current: Int?
    /// Every Space on the active display in Mission Control order, which is the index ISS switches by.
    let missionControlOrder: [UInt64]
    let activeID: UInt64
    let displayID: String

    func spaceID(of item: Int) -> UInt64? {
        if item >= 0 && item < desktopIDs.count { return desktopIDs[item] }
        let app = item - desktopIDs.count
        return app >= 0 && app < apps.count ? apps[app].id : nil
    }

    func grid(columns: Int) -> GridLayout {
        GridLayout(columns: columns, desktops: desktopIDs.count, apps: apps.count)
    }
}

enum Spaces {
    private static let desktopType = 0
    private static let fullscreenType = 4

    static func layout() -> SpaceLayout? {
        let connection = CGSMainConnectionID()
        let active = CGSGetActiveSpace(connection)
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else { return nil }

        for display in displays {
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            guard spaces.compactMap(spaceID).contains(active) else { continue }
            let desktops = spaces.filter { $0["type"] as? Int == desktopType }.compactMap(spaceID)
            let apps = spaces.filter { $0["type"] as? Int == fullscreenType }.compactMap(appSpace).sorted { $0.id < $1.id }
            let current = desktops.firstIndex(of: active) ?? apps.firstIndex { $0.id == active }.map { desktops.count + $0 }
            return SpaceLayout(
                desktopIDs: desktops, apps: apps, current: current,
                missionControlOrder: spaces.compactMap(spaceID), activeID: active,
                displayID: display["Display Identifier"] as? String ?? ""
            )
        }
        return nil
    }

    private static func spaceID(_ space: [String: Any]) -> UInt64? {
        // ISS counts Spaces by id64, so the indices only agree if this does too.
        space["id64"] as? UInt64
    }

    private static func appSpace(_ space: [String: Any]) -> AppSpace? {
        let tiles = (space["TileLayoutManager"] as? [String: Any])?["TileSpaces"] as? [[String: Any]]
        guard let id = spaceID(space), let pid = (space["pid"] as? Int32) ?? (tiles?.first?["pid"] as? Int32) else { return nil }
        return AppSpace(
            id: id,
            pid: pid,
            name: NSRunningApplication(processIdentifier: pid)?.localizedName ?? tiles?.first?["appName"] as? String ?? "App"
        )
    }
}
