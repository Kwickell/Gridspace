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
            eventTap(),
            trackpad(deviceCount: deviceCount),
            systemGestures(fingers: settings.fingers),
            desktopCount(),
            displays(),
        ]
    }

    private static func accessibility() -> CheckResult {
        if AXIsProcessTrusted() {
            return CheckResult(id: "accessibility", title: "Accessibility access", status: .ok, detail: "Gridspace can post the swipes that switch Spaces.")
        }
        return CheckResult(
            id: "accessibility", title: "Accessibility access", status: .failing,
            detail: "Needed to post the swipes that switch Spaces. Turn Gridspace on under Privacy & Security > Accessibility.",
            fixes: [Fix(title: "Request access") {
                let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
                SystemPrefs.open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }]
        )
    }

    private static func eventTap() -> CheckResult {
        if Navigator.start() {
            return CheckResult(id: "tap", title: "Input Monitoring", status: .ok, detail: "Gridspace can watch the swipes it posts.")
        }
        return CheckResult(
            id: "tap", title: "Input Monitoring", status: .failing,
            detail: "Gridspace couldn't install its event tap, so it can't switch Spaces. Turn Gridspace on under Privacy & Security > Input Monitoring (and Accessibility), then recheck.",
            fixes: [Fix(title: "Open Input Monitoring") { SystemPrefs.open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") }]
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

    private static func desktopCount() -> CheckResult {
        guard let layout = Spaces.layout() else {
            return CheckResult(id: "desktops", title: "Spaces", status: .failing, detail: "Could not read the Space list.")
        }
        let desktops = layout.desktopCount, apps = layout.items.count - layout.desktopCount
        let summary = "\(desktops) desktop\(desktops == 1 ? "" : "s") and \(apps) fullscreen app\(apps == 1 ? "" : "s")."
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
