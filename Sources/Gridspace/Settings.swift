import Foundation
import GridCore

final class Settings {
    static let presets: [(rows: Int, cols: Int)] = [(2, 2), (2, 3), (2, 4), (3, 3)]

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            "rows": 2,
            "cols": 2,
            "fingers": 4,
            "invertVertical": false,
            "showOverlay": true,
        ])
    }

    var grid: Grid {
        get { Grid(rows: defaults.integer(forKey: "rows"), cols: defaults.integer(forKey: "cols")) }
        set {
            defaults.set(newValue.rows, forKey: "rows")
            defaults.set(newValue.cols, forKey: "cols")
        }
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
