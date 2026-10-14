import AppKit

/// Reads and writes other apps' preference domains, which is how System Settings stores these options.
enum SystemPrefs {
    static func value(_ key: String, in domain: String) -> Any? {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    static func set(_ key: String, _ value: Any, in domain: String) {
        CFPreferencesSetAppValue(key as CFString, value as AnyObject, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    static func global(_ key: String) -> Any? {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        return CFPreferencesCopyAppValue(key as CFString, kCFPreferencesAnyApplication)
    }

    static func setGlobal(_ key: String, _ value: Any) {
        CFPreferencesSetAppValue(key as CFString, value as AnyObject, kCFPreferencesAnyApplication)
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
    }

    static func setCurrentHostGlobal(_ key: String, _ value: Any) {
        CFPreferencesSetValue(key as CFString, value as AnyObject, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    /// Asks the system to pick up changed keyboard and trackpad preferences without logging out.
    static func activate() {
        run("/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", "-u")
    }

    static func restartDock() {
        run("/usr/bin/killall", "Dock")
    }

    static func open(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }

    private static func run(_ path: String, _ args: String...) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        try? process.run()
        process.waitUntilExit()
    }
}
