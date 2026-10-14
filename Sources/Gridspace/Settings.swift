import Carbon.HIToolbox
import Foundation

extension Notification.Name {
    static let gridspaceSettingsChanged = Notification.Name("GridspaceSettingsChanged")
}

final class Settings {
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            "fingers": 4,
            "invertVertical": false,
            "showOverlay": true,
            "arrangeKeyCode": kVK_ANSI_G,
            "arrangeModifiers": controlKey | optionKey | cmdKey,
            "onboarded": false,
        ])
    }

    private func changed() {
        NotificationCenter.default.post(name: .gridspaceSettingsChanged, object: nil)
    }

    /// The Arrange Spaces shortcut as a Carbon key code and modifier mask; no modifiers means no shortcut.
    var arrangeShortcut: (keyCode: UInt32, modifiers: UInt32) {
        get { (UInt32(defaults.integer(forKey: "arrangeKeyCode")), UInt32(defaults.integer(forKey: "arrangeModifiers"))) }
        set {
            defaults.set(Int(newValue.keyCode), forKey: "arrangeKeyCode")
            defaults.set(Int(newValue.modifiers), forKey: "arrangeModifiers")
            changed()
        }
    }

    var onboarded: Bool {
        get { defaults.bool(forKey: "onboarded") }
        set { defaults.set(newValue, forKey: "onboarded") }
    }

    var fingers: Int {
        get { defaults.integer(forKey: "fingers") == 3 ? 3 : 4 }
        set { defaults.set(newValue, forKey: "fingers"); changed() }
    }

    var invertVertical: Bool {
        get { defaults.bool(forKey: "invertVertical") }
        set { defaults.set(newValue, forKey: "invertVertical"); changed() }
    }

    var showOverlay: Bool {
        get { defaults.bool(forKey: "showOverlay") }
        set { defaults.set(newValue, forKey: "showOverlay"); changed() }
    }
}
