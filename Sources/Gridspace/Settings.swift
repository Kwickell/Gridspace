import Foundation

final class Settings {
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            "fingers": 4,
            "invertVertical": false,
            "showOverlay": true,
        ])
    }

    var fingers: Int {
        get { defaults.integer(forKey: "fingers") == 3 ? 3 : 4 }
        set { defaults.set(newValue, forKey: "fingers") }
    }

    var invertVertical: Bool {
        get { defaults.bool(forKey: "invertVertical") }
        set { defaults.set(newValue, forKey: "invertVertical") }
    }

    var showOverlay: Bool {
        get { defaults.bool(forKey: "showOverlay") }
        set { defaults.set(newValue, forKey: "showOverlay") }
    }
}
