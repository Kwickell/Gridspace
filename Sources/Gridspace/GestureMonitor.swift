import Foundation
import GridCore
import MultitouchBridge

final class GestureMonitor {
    var onSwipe: ((SwipeDirection) -> Void)?
    private(set) var deviceCount = 0

    @discardableResult
    func start(fingers: Int) -> Int {
        GSMultitouchConfigure(Int32(fingers), 0.1)
        let context = Unmanaged.passUnretained(self).toOpaque()
        deviceCount = Int(GSMultitouchStart({ direction, context in
            guard let context else { return }
            let monitor = Unmanaged<GestureMonitor>.fromOpaque(context).takeUnretainedValue()
            let swipe: SwipeDirection
            switch direction.rawValue {
            case GSSwipeLeft.rawValue: swipe = .left
            case GSSwipeRight.rawValue: swipe = .right
            case GSSwipeUp.rawValue: swipe = .up
            default: swipe = .down
            }
            DispatchQueue.main.async { monitor.onSwipe?(swipe) }
        }, context))
        return deviceCount
    }
}
