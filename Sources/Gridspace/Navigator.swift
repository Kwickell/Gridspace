import Foundation
import ISS

/// Moves to a grid item by its position in Mission Control order, using InstantSpaceSwitcher's synthetic
/// Dock swipes. Each swipe lands instantly, so a jump across several Spaces shows no hops.
enum Navigator {
    /// ISS trusts its own prediction over live Space data for this long after posting swipes (kPredictionTTL in ISS.c).
    private static let predictionWindow: TimeInterval = 1.0
    private static var started = false
    private static var lastJump: (item: Int, at: Date)?

    /// Sets up the event tap ISS uses to track its own swipes. Fails without Accessibility and Input Monitoring,
    /// so it's retried before every jump.
    @discardableResult
    static func start() -> Bool {
        if !started { started = iss_init() }
        return started
    }

    /// Call when the Space changes for any other reason, so ISS stops trusting its own prediction.
    static func spaceChanged() {
        iss_reset_predictions()
    }

    /// The item to swipe from: right after a jump, live Space data still shows the old Space.
    static func current(in layout: SpaceLayout) -> Int? {
        if let lastJump, Date().timeIntervalSince(lastJump.at) < predictionWindow { return lastJump.item }
        return layout.current
    }

    @discardableResult
    static func go(to item: Int, in layout: SpaceLayout) -> Bool {
        guard start(),
              let target = layout.spaceID(of: item),
              let index = layout.missionControlOrder.firstIndex(of: target)
        else { return false }

        // ISS switches the display under the cursor; refuse rather than move a different display's Spaces.
        var info = ISSSpaceInfo()
        guard iss_get_space_info(&info) else { return false }
        let issDisplay = withUnsafeBytes(of: info.displayID) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        guard issDisplay == layout.displayID, Int(info.spaceCount) == layout.missionControlOrder.count else { return false }

        guard iss_switch_to_index(UInt32(index)) else { return false }
        lastJump = (item, Date())
        return true
    }
}
