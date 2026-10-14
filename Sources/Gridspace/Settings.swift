import Foundation

final class Settings {
    static let columnChoices = [2, 3, 4, 5]

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            "columns": 3,
            "fingers": 4,
            "invertVertical": false,
            "showOverlay": true,
        ])
    }

    var columns: Int {
        get { max(1, defaults.integer(forKey: "columns")) }
        set { defaults.set(newValue, forKey: "columns") }
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
