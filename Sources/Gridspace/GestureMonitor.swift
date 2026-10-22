import Foundation
import GridCore
import MultitouchBridge
import OSLog

private let log = Logger(subsystem: "com.kwickell.gridspace", category: "swipe")

final class GestureMonitor {
    var onSwipe: ((SwipeDirection) -> Void)?
    private(set) var deviceCount = 0

    /// MultitouchSupport only delivers frames from the devices registered at the last start, and it has
    /// no notification for a trackpad being plugged in, so the device count is polled.
    func restartIfDevicesChanged(fingers: Int) {
        guard Int(GSMultitouchDeviceCount()) != deviceCount else { return }
        start(fingers: fingers)
    }

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
        if deviceCount < 0 {
            log.error("MultitouchSupport could not be loaded, so no swipe will be seen")
        } else {
            log.notice("watching \(self.deviceCount, privacy: .public) trackpad(s)")
        }
        return deviceCount
    }
}
