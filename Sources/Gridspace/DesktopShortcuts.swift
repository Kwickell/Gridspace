import CoreGraphics

/// The Mission Control "Switch to Desktop N" shortcuts, which is how Gridspace changes desktop.
enum DesktopShortcuts {
    static let maxDesktops = 9

    private static let domain = "com.apple.symbolichotkeys"
    private static let key = "AppleSymbolicHotKeys"
    private static let controlMask = 262_144
    private static let digitKeyCodes = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    struct Binding {
        let keyCode: CGKeyCode
        let flags: CGEventFlags
    }

    private static func hotkeyID(desktop: Int) -> String { String(117 + desktop) }

    static func binding(desktop: Int) -> Binding? {
        guard let all = SystemPrefs.value(key, in: domain) as? [String: Any],
              let entry = all[hotkeyID(desktop: desktop)] as? [String: Any],
              entry["enabled"] as? Bool == true,
              let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Int], params.count == 3,
              params[1] != 65535
        else { return nil }
        return Binding(keyCode: CGKeyCode(params[1]), flags: CGEventFlags(rawValue: UInt64(params[2])))
    }

    static func missing(upTo count: Int) -> [Int] {
        guard count > 0 else { return [] }
        return (1...min(count, maxDesktops)).filter { binding(desktop: $0) == nil }
    }

    /// Turns on Control-1...Control-N, keeping any key the user already assigned.
    static func enable(upTo count: Int) {
        var all = SystemPrefs.value(key, in: domain) as? [String: Any] ?? [:]
        for desktop in 1...min(count, maxDesktops) where binding(desktop: desktop) == nil {
            let id = hotkeyID(desktop: desktop)
            var entry = all[id] as? [String: Any] ?? [:]
            let value = entry["value"] as? [String: Any]
            let params = value?["parameters"] as? [Int]
            if params == nil || params?.count != 3 || params?[1] == 65535 {
                entry["value"] = [
                    "type": "standard",
                    "parameters": [48 + desktop, digitKeyCodes[desktop - 1], controlMask],
                ] as [String: Any]
            }
            entry["enabled"] = true
            all[id] = entry
        }
        SystemPrefs.set(key, all, in: domain)
        SystemPrefs.activate()
    }

    @discardableResult
    static func switchTo(desktop: Int) -> Bool {
        guard let binding = binding(desktop: desktop) else { return false }
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: binding.keyCode, keyDown: keyDown)
            event?.flags = binding.flags
            event?.post(tap: .cghidEventTap)
        }
        return true
    }
}
