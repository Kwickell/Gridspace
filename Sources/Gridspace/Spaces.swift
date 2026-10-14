import CoreGraphics

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ connection: Int32) -> UInt64

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?

struct DesktopLayout {
    /// Regular desktops on the active display, in Mission Control order. Fullscreen app spaces are left out.
    let desktopIDs: [UInt64]
    /// Index of the active desktop, nil when a fullscreen app is active.
    let currentIndex: Int?
    /// Desktops on displays before this one; "Switch to Desktop N" numbers them across all displays.
    let shortcutOffset: Int
    let displayCount: Int
}

enum Spaces {
    static func layout() -> DesktopLayout? {
        let connection = CGSMainConnectionID()
        let active = CGSGetActiveSpace(connection)
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else { return nil }

        var offset = 0
        for display in displays {
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            let desktops = spaces.filter { ($0["type"] as? Int) == 0 }.compactMap(spaceID)
            if spaces.compactMap(spaceID).contains(active) {
                return DesktopLayout(
                    desktopIDs: desktops,
                    currentIndex: desktops.firstIndex(of: active),
                    shortcutOffset: offset,
                    displayCount: displays.count
                )
            }
            offset += desktops.count
        }
        return nil
    }

    private static func spaceID(_ space: [String: Any]) -> UInt64? {
        (space["id64"] as? UInt64) ?? (space["ManagedSpaceID"] as? UInt64)
    }
}
