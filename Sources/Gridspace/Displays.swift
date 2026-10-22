import AppKit

/// Translates between the displays AppKit knows about and the "Display Identifier" strings CGS keys
/// its Space lists by, which are display UUIDs.
enum Displays {
    /// The display under the pointer, which is the one a Dock swipe switches regardless of which
    /// display has focus. Nil when the pointer sits between displays or on one CGS doesn't report.
    static var underCursor: String? {
        var display = CGDirectDisplayID()
        var count = UInt32()
        guard CGGetDisplaysWithPoint(cursorLocation, 1, &display, &count) == .success, count > 0 else { return nil }
        return identifier(of: display)
    }

    static func identifier(of display: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(display) else { return nil }
        return CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
    }

    static func screen(for identifier: String) -> NSScreen? {
        NSScreen.screens.first { Self.identifier(of: $0) == identifier }
    }

    static func name(for identifier: String) -> String {
        screen(for: identifier)?.localizedName ?? "a disconnected display"
    }

    private static func identifier(of screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return identifier(of: CGDirectDisplayID(number.uint32Value))
    }

    /// The same reading ISS takes, so a swipe is aimed at the display ISS will actually switch.
    private static var cursorLocation: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }
}
