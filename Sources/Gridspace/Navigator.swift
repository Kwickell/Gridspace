import AppKit
import GridCore

/// Moves to a grid item: desktops through their "Switch to Desktop N" shortcut, fullscreen apps by focusing their window.
enum Navigator {
    /// How long a fullscreen jump gets to land before Gridspace checks where it ended up.
    static let settleDelay: TimeInterval = 0.35
    private static let stepInterval: TimeInterval = 0.06

    @discardableResult
    static func go(to item: Int, in layout: SpaceLayout) -> Bool {
        let desktops = layout.desktopIDs.count
        if item >= 0 && item < desktops {
            return DesktopShortcuts.switchTo(desktop: layout.shortcutOffset + item + 1)
        }
        guard let target = layout.spaceID(of: item), item - desktops < layout.apps.count else { return false }
        guard AppSpaces.focus(layout.apps[item - desktops]) else { return stepToward(target) }
        // Activation can land on another Space when the app also has a window there.
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { stepToward(target) }
        return true
    }

    /// Walks the rest of the way with Control-arrow from wherever the Space currently is.
    @discardableResult
    private static func stepToward(_ target: UInt64) -> Bool {
        guard let layout = Spaces.layout(), layout.activeID != target,
              let from = layout.missionControlOrder.firstIndex(of: layout.activeID),
              let to = layout.missionControlOrder.firstIndex(of: target)
        else { return true }
        let direction: DesktopShortcuts.Step = to > from ? .right : .left
        guard DesktopShortcuts.binding(step: direction) != nil else { return false }
        for n in 0..<abs(to - from) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(n) * stepInterval) {
                DesktopShortcuts.step(direction)
            }
        }
        return true
    }
}
