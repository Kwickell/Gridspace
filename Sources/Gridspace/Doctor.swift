import AppKit
import ApplicationServices
import MultitouchBridge

enum CheckStatus: Int, Comparable {
    case ok, warning, failing
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

struct Fix {
    let title: String
    let action: () -> Void
}

struct CheckResult: Identifiable {
    let id: String
    let title: String
    let status: CheckStatus
    let detail: String
    var fixes: [Fix] = []
}

enum Doctor {
    private static let trackpadDomains = ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]

    static func run(settings: Settings, deviceCount: Int) -> [CheckResult] {
        [
            accessibility(),
            trackpad(deviceCount: deviceCount),
            systemGestures(fingers: settings.fingers),
            reduceMotion(),
            rearrangeSpaces(),
            desktopCount(cells: settings.grid.cells),
            shortcuts(cells: settings.grid.cells),
            displays(),
        ]
    }

    private static func accessibility() -> CheckResult {
        if AXIsProcessTrusted() {
            return CheckResult(id: "accessibility", title: "Accessibility access", status: .ok, detail: "Gridspace can send the desktop-switch shortcuts.")
        }
        return CheckResult(
            id: "accessibility", title: "Accessibility access", status: .failing,
            detail: "Needed to send the \"Switch to Desktop N\" shortcuts. Turn Gridspace on under Privacy & Security > Accessibility.",
            fixes: [Fix(title: "Request access") {
                let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
                SystemPrefs.open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }]
        )
    }

    private static func trackpad(deviceCount: Int) -> CheckResult {
        switch deviceCount {
        case ..<0:
            return CheckResult(id: "trackpad", title: "Trackpad", status: .failing, detail: "MultitouchSupport could not be loaded, so swipes can't be read on this macOS version.")
        case 0:
            return CheckResult(id: "trackpad", title: "Trackpad", status: .failing, detail: "No trackpad found. Connect one, then recheck.")
        default:
            return CheckResult(id: "trackpad", title: "Trackpad", status: .ok, detail: "\(deviceCount) multitouch device\(deviceCount == 1 ? "" : "s") found.")
        }
    }

    private static func gestureKeys(fingers: Int) -> [String] {
        fingers == 3
            ? ["TrackpadThreeFingerHorizSwipeGesture", "TrackpadThreeFingerVertSwipeGesture", "TrackpadThreeFingerDrag"]
            : ["TrackpadFourFingerHorizSwipeGesture", "TrackpadFourFingerVertSwipeGesture"]
    }

    private static func systemGestures(fingers: Int) -> CheckResult {
        let names = [
            "TrackpadThreeFingerHorizSwipeGesture": "swipe between full-screen apps",
            "TrackpadFourFingerHorizSwipeGesture": "swipe between full-screen apps",
            "TrackpadThreeFingerVertSwipeGesture": "Mission Control / App Exposé",
            "TrackpadFourFingerVertSwipeGesture": "Mission Control / App Exposé",
            "TrackpadThreeFingerDrag": "three-finger drag",
        ]
        let conflicts = gestureKeys(fingers: fingers).filter { key in
            let value = SystemPrefs.value(key, in: trackpadDomains[0])
            if key == "TrackpadThreeFingerDrag" { return value as? Bool ?? false }
            return (value as? Int ?? 2) != 0
        }
        let title = "System \(fingers)-finger gestures"
        if conflicts.isEmpty {
            return CheckResult(id: "gestures", title: title, status: .ok, detail: "No system gesture competes with Gridspace's \(fingers)-finger swipes.")
        }
        let list = Array(Set(conflicts.compactMap { names[$0] })).sorted().joined(separator: ", ")
        return CheckResult(
            id: "gestures", title: title, status: .failing,
            detail: "macOS also uses \(fingers) fingers for: \(list). Both would fire on every swipe. If the fix doesn't take, toggle them off in Trackpad settings or log out and back in.",
            fixes: [
                Fix(title: "Turn them off") { disableSystemGestures(fingers: fingers) },
                Fix(title: "Open Trackpad settings") { SystemPrefs.open("x-apple.systempreferences:com.apple.Trackpad-Settings.extension") },
            ]
        )
    }

    private static func disableSystemGestures(fingers: Int) {
        let word = fingers == 3 ? "three" : "four"
        let verticalKey = fingers == 3 ? "TrackpadThreeFingerVertSwipeGesture" : "TrackpadFourFingerVertSwipeGesture"
        // The Dock keys switch Mission Control and App Exposé off at every finger count, so only touch them when they use ours.
        let ownsMissionControl = (SystemPrefs.value(verticalKey, in: trackpadDomains[0]) as? Int ?? 2) != 0
        for domain in trackpadDomains {
            for key in gestureKeys(fingers: fingers) {
                SystemPrefs.set(key, key.hasSuffix("Drag") ? false as Any : 0 as Any, in: domain)
            }
        }
        SystemPrefs.setCurrentHostGlobal("com.apple.trackpad.\(word)FingerHorizSwipeGesture", 0)
        SystemPrefs.setCurrentHostGlobal("com.apple.trackpad.\(word)FingerVertSwipeGesture", 0)
        if ownsMissionControl {
            SystemPrefs.set("showMissionControlGestureEnabled", false, in: "com.apple.dock")
            SystemPrefs.set("showAppExposeGestureEnabled", false, in: "com.apple.dock")
        }
        SystemPrefs.activate()
        SystemPrefs.restartDock()
    }

    private static func reduceMotion() -> CheckResult {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return CheckResult(id: "motion", title: "Reduce motion", status: .ok, detail: "Desktops fade instead of sliding.")
        }
        return CheckResult(
            id: "motion", title: "Reduce motion", status: .warning,
            detail: "Off, so every switch slides sideways, even for vertical swipes. Turn on Accessibility > Display > Reduce motion to get a fade.",
            fixes: [Fix(title: "Open Display settings") { SystemPrefs.open("x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display") }]
        )
    }

    private static func rearrangeSpaces() -> CheckResult {
        let on = SystemPrefs.value("mru-spaces", in: "com.apple.dock") as? Bool ?? true
        if !on {
            return CheckResult(id: "mru", title: "Fixed desktop order", status: .ok, detail: "Desktops stay where you put them.")
        }
        return CheckResult(
            id: "mru", title: "Fixed desktop order", status: .failing,
            detail: "\"Automatically rearrange Spaces based on most recent use\" is on, so desktops move around the grid by themselves.",
            fixes: [Fix(title: "Turn it off") {
                SystemPrefs.set("mru-spaces", false, in: "com.apple.dock")
                SystemPrefs.restartDock()
            }]
        )
    }

    private static func desktopCount(cells: Int) -> CheckResult {
        guard let layout = Spaces.layout() else {
            return CheckResult(id: "desktops", title: "Desktops", status: .failing, detail: "Could not read the desktop list.")
        }
        let have = layout.desktopIDs.count
        if have >= cells {
            let extra = have > cells ? " Desktops past \(cells) are outside the grid and can't be reached by swiping." : ""
            return CheckResult(id: "desktops", title: "Desktops", status: have > cells ? .warning : .ok, detail: "\(have) desktops for a \(cells)-cell grid.\(extra)")
        }
        return CheckResult(
            id: "desktops", title: "Desktops", status: .failing,
            detail: "\(have) desktops, the grid needs \(cells). Open Mission Control and add \(cells - have) with the + at the top right.",
            fixes: [Fix(title: "Open Mission Control") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
            }]
        )
    }

    private static func shortcuts(cells: Int) -> CheckResult {
        if cells > DesktopShortcuts.maxDesktops {
            return CheckResult(id: "shortcuts", title: "Desktop shortcuts", status: .failing, detail: "Grids above \(DesktopShortcuts.maxDesktops) cells aren't supported.")
        }
        let missing = DesktopShortcuts.missing(upTo: cells)
        if missing.isEmpty {
            return CheckResult(id: "shortcuts", title: "Desktop shortcuts", status: .ok, detail: "\"Switch to Desktop 1-\(cells)\" are on.")
        }
        return CheckResult(
            id: "shortcuts", title: "Desktop shortcuts", status: .failing,
            detail: "\"Switch to Desktop \(missing.map(String.init).joined(separator: ", "))\" \(missing.count == 1 ? "is" : "are") off. Gridspace switches desktops through these. They only appear in Keyboard Shortcuts once the desktop exists.",
            fixes: [
                Fix(title: "Turn on Control-1...\(cells)") { DesktopShortcuts.enable(upTo: cells) },
                Fix(title: "Open Keyboard settings") { SystemPrefs.open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension") },
            ]
        )
    }

    private static func displays() -> CheckResult {
        let separate = !(SystemPrefs.value("spans-displays", in: "com.apple.spaces") as? Bool ?? false)
        if NSScreen.screens.count > 1 && separate {
            return CheckResult(id: "displays", title: "Displays", status: .warning, detail: "Several displays with separate Spaces. The grid follows whichever display is active, and this setup is untested.")
        }
        return CheckResult(id: "displays", title: "Displays", status: .ok, detail: NSScreen.screens.count > 1 ? "Displays share one set of Spaces." : "One display.")
    }
}

enum DoctorCLI {
    static func run() -> Int32 {
        let results = Doctor.run(settings: Settings(), deviceCount: Int(GSMultitouchDeviceCount()))
        for result in results {
            let mark = ["ok", "warn", "FAIL"][result.status.rawValue]
            print("[\(mark)] \(result.title): \(result.detail)")
        }
        return results.contains { $0.status == .failing } ? 1 : 0
    }
}
