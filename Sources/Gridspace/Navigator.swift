import ISS

/// Moves to a grid item by its position in Mission Control order, using InstantSpaceSwitcher's synthetic
/// Dock swipes. Each swipe lands instantly, so a jump across several Spaces shows no hops.
enum Navigator {
    /// Sets up the event tap ISS uses to track its own in-flight swipes. Needs Accessibility access.
    static func start() -> Bool {
        iss_init()
    }

    /// Call when the Space changes for any other reason, so ISS stops trusting its own prediction.
    static func spaceChanged() {
        iss_reset_predictions()
    }

    @discardableResult
    static func go(to item: Int, in layout: SpaceLayout) -> Bool {
        guard let target = layout.spaceID(of: item),
              let index = layout.missionControlOrder.firstIndex(of: target)
        else { return false }
        return iss_switch_to_index(UInt32(index))
    }
}
