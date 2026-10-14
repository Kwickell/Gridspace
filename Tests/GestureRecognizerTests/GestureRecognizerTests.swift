import MultitouchBridge
import XCTest

final class GestureRecognizerTests: XCTestCase {
    private var recognizer = GSRecognizer()
    private var time = 0.0

    override func setUp() {
        GSRecognizerInit(&recognizer, 4, 0.1)
        time = 0
    }

    /// Feeds one frame of fingers given as (id, x, y) and returns the direction, or nil.
    @discardableResult
    private func feed(_ fingers: [(Int32, Float, Float)]) -> GSSwipeDirection? {
        time += 0.008
        let contacts = fingers.map { GSContact(identifier: $0.0, x: $0.1, y: $0.2) }
        let result = contacts.withUnsafeBufferPointer { GSRecognizerFeed(&recognizer, $0.baseAddress, Int32($0.count), time) }
        return result < 0 ? nil : GSSwipeDirection(rawValue: UInt32(result))
    }

    private func hand(dx: Float = 0, dy: Float = 0, ids: [Int32] = [1, 2, 3, 4]) -> [(Int32, Float, Float)] {
        ids.map { ($0, 0.3 + Float($0) * 0.1 + dx, 0.5 + dy) }
    }

    func testCleanSwipe() {
        feed(hand())
        XCTAssertNil(feed(hand(dx: 0.05)))
        XCTAssertEqual(feed(hand(dx: 0.11)), GSSwipeRight)
    }

    func testVertical() {
        feed(hand())
        XCTAssertEqual(feed(hand(dy: 0.12)), GSSwipeUp)
        feed([])
        feed(hand())
        XCTAssertEqual(feed(hand(dy: -0.12)), GSSwipeDown)
    }

    func testFingersLandingAtDifferentTimes() {
        feed(hand(ids: [1, 2]))
        feed(hand(dx: -0.02, ids: [1, 2, 3]))
        feed(hand(dx: -0.04))
        XCTAssertEqual(feed(hand(dx: -0.15)), GSSwipeLeft)
    }

    func testOneFingerFlickeringDoesNotRestart() {
        feed(hand())
        feed(hand(dx: 0.05))
        feed(hand(dx: 0.07, ids: [1, 2, 3]))
        XCTAssertEqual(feed(hand(dx: 0.11)), GSSwipeRight)
    }

    func testOnlyOneSwipePerTouch() {
        feed(hand())
        XCTAssertEqual(feed(hand(dx: 0.11)), GSSwipeRight)
        XCTAssertNil(feed(hand(dx: 0.3)))
        feed([])
        feed(hand())
        XCTAssertEqual(feed(hand(dx: 0.11)), GSSwipeRight)
    }

    func testFiveFingersNeverSwipe() {
        feed(hand(ids: [1, 2, 3, 4, 5]))
        XCTAssertNil(feed(hand(dx: 0.2)))
        XCTAssertNil(feed(hand(dx: 0.3)))
    }

    func testTwoFingersLeftDoNotSwipe() {
        feed(hand())
        XCTAssertNil(feed(hand(dx: 0.2, ids: [1, 2])))
    }

    func testMissingEmptyFrameResetsAfterGap() {
        feed(hand())
        XCTAssertEqual(feed(hand(dx: 0.11)), GSSwipeRight)
        time += 1
        feed(hand())
        XCTAssertEqual(feed(hand(dx: 0.11)), GSSwipeRight)
    }
}
