import GridCore
import XCTest

final class GridLayoutTests: XCTestCase {
    // [0] [1] [2]
    // [3] [4]
    // [5] [6] [7]   apps
    // [8]
    let layout = GridLayout(columns: 3, desktops: 5, apps: 4)

    func testPositions() {
        XCTAssertEqual(layout.rows, 4)
        XCTAssertTrue(layout.position(of: 4)! == (1, 1))
        XCTAssertTrue(layout.position(of: 5)! == (2, 0))
        XCTAssertTrue(layout.position(of: 8)! == (3, 0))
        XCTAssertNil(layout.position(of: 9))
        XCTAssertTrue(layout.isApp(5))
        XCTAssertFalse(layout.isApp(4))
    }

    func testHorizontalIsNaturalAndStopsAtEdges() {
        XCTAssertEqual(layout.target(from: 0, swipe: .left), 1)
        XCTAssertEqual(layout.target(from: 1, swipe: .right), 0)
        XCTAssertNil(layout.target(from: 2, swipe: .left))
        XCTAssertNil(layout.target(from: 4, swipe: .left))
        XCTAssertNil(layout.target(from: 5, swipe: .right))
    }

    func testVertical() {
        XCTAssertEqual(layout.target(from: 1, swipe: .up), 4)
        XCTAssertEqual(layout.target(from: 4, swipe: .down), 1)
        XCTAssertEqual(layout.target(from: 1, swipe: .down, invertVertical: true), 4)
        XCTAssertNil(layout.target(from: 0, swipe: .down))
        XCTAssertNil(layout.target(from: 8, swipe: .up))
    }

    func testVerticalIntoShorterRowClamps() {
        XCTAssertEqual(layout.target(from: 2, swipe: .up), 4)
        XCTAssertEqual(layout.target(from: 7, swipe: .up), 8)
    }

    func testDesktopsToAppsRow() {
        XCTAssertEqual(layout.target(from: 3, swipe: .up), 5)
        XCTAssertEqual(layout.target(from: 4, swipe: .up), 6)
        XCTAssertEqual(layout.target(from: 7, swipe: .down), 4)
    }

    func testAppsNeverShiftDesktops() {
        let more = GridLayout(columns: 3, desktops: 5, apps: 7)
        for d in 0..<5 { XCTAssertTrue(more.position(of: d)! == layout.position(of: d)!) }
    }

    func testNoAppsOrNoDesktops() {
        let onlyDesktops = GridLayout(columns: 2, desktops: 4, apps: 0)
        XCTAssertEqual(onlyDesktops.rows, 2)
        XCTAssertNil(onlyDesktops.target(from: 3, swipe: .up))
        let onlyApps = GridLayout(columns: 2, desktops: 0, apps: 3)
        XCTAssertEqual(onlyApps.target(from: 0, swipe: .up), 2)
        XCTAssertEqual(GridLayout(columns: 0, desktops: 0, apps: 0).rows, 0)
        XCTAssertNil(GridLayout(columns: 3, desktops: 0, apps: 0).target(from: 0, swipe: .left))
    }
}
