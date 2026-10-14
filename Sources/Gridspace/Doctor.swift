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
    static func run(settings: Settings, deviceCount: Int) -> [CheckResult] {
        [
            accessibility(),
            trackpad(deviceCount: deviceCount),
            systemGestures(fingers: settings.fingers),
            reduceMotion(),
            rearrangeSpaces(),
            desktopCount(),
            shortcuts(),
            switchOnActivate(),
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

    private static func systemGestures(fingers: Int) -> CheckResult {
        let conflicts = SystemGestures.conflicts(fingers: fingers)
        let title = "System \(fingers)-finger gestures"
        if conflicts.isEmpty {
            return CheckResult(id: "gestures", title: title, status: .ok, detail: "No system gesture competes with Gridspace's \(fingers)-finger swipes.")
        }
        let list = Array(Set(conflicts.compactMap { SystemGestures.names[$0] })).sorted().joined(separator: ", ")
        return CheckResult(
            id: "gestures", title: title, status: .failing,
            detail: "macOS uses \(fingers) fingers for: \(list). Gridspace ignores swipes until they're off. The menu's \"Gridspace swipes\" toggle switches between the two. If the fix doesn't take, toggle them off in Trackpad settings or log out and back in.",
            fixes: [
                Fix(title: "Turn them off") { SystemGestures.disable(fingers: fingers) },
                Fix(title: "Open Trackpad settings") { SystemPrefs.open("x-apple.systempreferences:com.apple.Trackpad-Settings.extension") },
            ]
        )
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

    private static func desktopCount() -> CheckResult {
        guard let layout = Spaces.layout() else {
            return CheckResult(id: "desktops", title: "Spaces", status: .failing, detail: "Could not read the Space list.")
        }
        let desktops = layout.desktopIDs.count, apps = layout.apps.count
        let summary = "\(desktops) desktop\(desktops == 1 ? "" : "s") and \(apps) fullscreen app\(apps == 1 ? "" : "s")."
        if desktops > DesktopShortcuts.maxDesktops {
            return CheckResult(id: "desktops", title: "Spaces", status: .warning, detail: "\(summary) Desktops past \(DesktopShortcuts.maxDesktops) have no shortcut, so swipes can't reach them.")
        }
        if desktops + apps < 2 {
            return CheckResult(
                id: "desktops", title: "Spaces", status: .warning,
                detail: "\(summary) Add desktops in Mission Control with the + at the top right.",
                fixes: [Fix(title: "Open Mission Control") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
                }]
            )
        }
        return CheckResult(id: "desktops", title: "Spaces", status: .ok, detail: summary)
    }

    private static func shortcuts() -> CheckResult {
        let desktops = min(Spaces.layout()?.desktopIDs.count ?? 0, DesktopShortcuts.maxDesktops)
        let missing = DesktopShortcuts.missing(upTo: desktops)
        let steps = [DesktopShortcuts.Step.left, .right].filter { DesktopShortcuts.binding(step: $0) == nil }
        if !steps.isEmpty {
            return CheckResult(
                id: "shortcuts", title: "Desktop shortcuts", status: .failing,
                detail: "\"Move left/right a space\" \(steps.count == 1 ? "is" : "are") off. Gridspace uses them when a fullscreen app opens on the wrong Space.",
                fixes: [Fix(title: "Open Keyboard settings") { SystemPrefs.open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension") }]
            )
        }
        if missing.isEmpty {
            return CheckResult(id: "shortcuts", title: "Desktop shortcuts", status: .ok, detail: desktops > 1 ? "\"Switch to Desktop 1-\(desktops)\" are on." : "\"Switch to Desktop 1\" is on.")
        }
        return CheckResult(
            id: "shortcuts", title: "Desktop shortcuts", status: .failing,
            detail: "\"Switch to Desktop \(missing.map(String.init).joined(separator: ", "))\" \(missing.count == 1 ? "is" : "are") off. Gridspace switches desktops through these. They only appear in Keyboard Shortcuts once the desktop exists.",
            fixes: [
                Fix(title: "Turn on Control-1...\(desktops)") { DesktopShortcuts.enable(upTo: desktops) },
                Fix(title: "Open Keyboard settings") { SystemPrefs.open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension") },
            ]
        )
    }

    private static func switchOnActivate() -> CheckResult {
        let on = SystemPrefs.global("AppleSpacesSwitchOnActivate") as? Bool ?? true
        if on {
            return CheckResult(id: "activate", title: "Switch to an app's Space", status: .ok, detail: "Focusing a fullscreen app takes you to its Space.")
        }
        return CheckResult(
            id: "activate", title: "Switch to an app's Space", status: .failing,
            detail: "\"When switching to an application, switch to a Space with open windows\" is off, so swipes can't reach fullscreen apps.",
            fixes: [Fix(title: "Turn it on") {
                SystemPrefs.setGlobal("AppleSpacesSwitchOnActivate", true)
                SystemPrefs.restartDock()
            }]
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
