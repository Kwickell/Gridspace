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
    let windowID: CGWindowID
    let name: String
}

struct SpaceLayout {
    /// Regular desktops on the active display, in Mission Control order.
    let desktopIDs: [UInt64]
    /// Fullscreen apps on the active display, oldest first so a new one always lands at the end.
    let apps: [AppSpace]
    /// Grid item of the active Space, desktops first, then apps.
    let current: Int?
    /// Every Space on the active display in Mission Control order, which is what Control-arrow steps through.
    let missionControlOrder: [UInt64]
    let activeID: UInt64
    /// Desktops on displays before this one; "Switch to Desktop N" numbers them across all displays.
    let shortcutOffset: Int
    let displayCount: Int

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

        var offset = 0
        for display in displays {
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            let desktops = spaces.filter { $0["type"] as? Int == desktopType }.compactMap(spaceID)
            if spaces.compactMap(spaceID).contains(active) {
                let apps = spaces.filter { $0["type"] as? Int == fullscreenType }.compactMap(appSpace).sorted { $0.id < $1.id }
                let current = desktops.firstIndex(of: active) ?? apps.firstIndex { $0.id == active }.map { desktops.count + $0 }
                return SpaceLayout(
                    desktopIDs: desktops, apps: apps, current: current,
                    missionControlOrder: spaces.compactMap(spaceID), activeID: active,
                    shortcutOffset: offset, displayCount: displays.count
                )
            }
            offset += desktops.count
        }
        return nil
    }

    private static func spaceID(_ space: [String: Any]) -> UInt64? {
        (space["id64"] as? UInt64) ?? (space["ManagedSpaceID"] as? UInt64)
    }

    private static func appSpace(_ space: [String: Any]) -> AppSpace? {
        let tiles = (space["TileLayoutManager"] as? [String: Any])?["TileSpaces"] as? [[String: Any]]
        guard let id = spaceID(space), let pid = (space["pid"] as? Int32) ?? (tiles?.first?["pid"] as? Int32) else { return nil }
        return AppSpace(
            id: id,
            pid: pid,
            windowID: CGWindowID((space["fs_wid"] as? UInt32) ?? (tiles?.first?["TileWindowID"] as? UInt32) ?? 0),
            name: NSRunningApplication(processIdentifier: pid)?.localizedName ?? tiles?.first?["appName"] as? String ?? "App"
        )
    }
}
