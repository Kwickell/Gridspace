import Foundation

/// The macOS trackpad gestures that use the same finger count as Gridspace. Turning them off saves their
/// values so turning them back on restores exactly what was there.
enum SystemGestures {
    static let trackpadDomains = ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]
    private static let dockKeys = ["showMissionControlGestureEnabled", "showAppExposeGestureEnabled"]

    static let names = [
        "TrackpadThreeFingerHorizSwipeGesture": "swipe between full-screen apps",
        "TrackpadFourFingerHorizSwipeGesture": "swipe between full-screen apps",
        "TrackpadThreeFingerVertSwipeGesture": "Mission Control / App Exposé",
        "TrackpadFourFingerVertSwipeGesture": "Mission Control / App Exposé",
        "TrackpadThreeFingerDrag": "three-finger drag",
    ]

    static func keys(fingers: Int) -> [String] {
        fingers == 3
            ? ["TrackpadThreeFingerHorizSwipeGesture", "TrackpadThreeFingerVertSwipeGesture", "TrackpadThreeFingerDrag"]
            : ["TrackpadFourFingerHorizSwipeGesture", "TrackpadFourFingerVertSwipeGesture"]
    }

    private static func horizontalKey(fingers: Int) -> String { keys(fingers: fingers)[0] }
    private static func verticalKey(fingers: Int) -> String { keys(fingers: fingers)[1] }
    private static func word(fingers: Int) -> String { fingers == 3 ? "three" : "four" }
    private static func savedKey(fingers: Int) -> String { "savedSystemGestures.\(fingers)" }

    private static func value(_ key: String) -> Any? {
        SystemPrefs.value(key, in: trackpadDomains[0])
    }

    private static func isOn(_ key: String) -> Bool {
        if key.hasSuffix("Drag") { return value(key) as? Bool ?? false }
        return (value(key) as? Int ?? 2) != 0
    }

    static func conflicts(fingers: Int) -> [String] {
        keys(fingers: fingers).filter(isOn)
    }

    static func disable(fingers: Int) {
        // The Dock keys switch Mission Control and App Exposé off at every finger count, so only touch them when they use ours.
        let ownsMissionControl = isOn(verticalKey(fingers: fingers))
        var saved: [String: Any] = [:]
        for key in keys(fingers: fingers) {
            saved[key] = key.hasSuffix("Drag") ? isOn(key) : (value(key) as? Int ?? 2)
        }
        if ownsMissionControl {
            for key in dockKeys { saved[key] = SystemPrefs.value(key, in: "com.apple.dock") as? Bool ?? true }
        }
        UserDefaults.standard.set(saved, forKey: savedKey(fingers: fingers))

        write(keys(fingers: fingers).map { ($0, $0.hasSuffix("Drag") ? false as Any : 0 as Any) }, fingers: fingers)
        if ownsMissionControl {
            for key in dockKeys { SystemPrefs.set(key, false, in: "com.apple.dock") }
        }
        apply()
    }

    /// Puts back what `disable` saved, or just the sideways swipe between Spaces if nothing was saved.
    static func restore(fingers: Int) {
        let saved = UserDefaults.standard.dictionary(forKey: savedKey(fingers: fingers))
            ?? [horizontalKey(fingers: fingers): 2]
        write(keys(fingers: fingers).compactMap { key in saved[key].map { (key, $0) } }, fingers: fingers)
        for key in dockKeys {
            if let value = saved[key] { SystemPrefs.set(key, value, in: "com.apple.dock") }
        }
        UserDefaults.standard.removeObject(forKey: savedKey(fingers: fingers))
        apply()
    }

    private static func write(_ values: [(String, Any)], fingers: Int) {
        for domain in trackpadDomains {
            for (key, value) in values { SystemPrefs.set(key, value, in: domain) }
        }
        for (key, value) in values where !key.hasSuffix("Drag") {
            let axis = key == horizontalKey(fingers: fingers) ? "Horiz" : "Vert"
            SystemPrefs.setCurrentHostGlobal("com.apple.trackpad.\(word(fingers: fingers))Finger\(axis)SwipeGesture", value)
        }
    }

    private static func apply() {
        SystemPrefs.activate()
        SystemPrefs.restartDock()
    }
}
