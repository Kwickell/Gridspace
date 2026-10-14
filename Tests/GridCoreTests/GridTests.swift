import GridCore
import XCTest

final class GridLayoutTests: XCTestCase {
    // [0] [1] [2]
    // [3] [4] [5]
    // [6] [7]
    let layout = GridLayout(columns: 3, items: 8)

    func testPositions() {
        XCTAssertEqual(layout.rows, 3)
        XCTAssertTrue(layout.position(of: 4)! == (1, 1))
        XCTAssertTrue(layout.position(of: 7)! == (2, 1))
        XCTAssertNil(layout.position(of: 8))
        XCTAssertNil(layout.position(of: -1))
    }

    func testHorizontalIsNaturalAndStopsAtEdges() {
        XCTAssertEqual(layout.target(from: 0, swipe: .left), 1)
        XCTAssertEqual(layout.target(from: 1, swipe: .right), 0)
        XCTAssertNil(layout.target(from: 2, swipe: .left))
        XCTAssertNil(layout.target(from: 3, swipe: .right))
        XCTAssertNil(layout.target(from: 7, swipe: .left))
    }

    func testVertical() {
        XCTAssertEqual(layout.target(from: 1, swipe: .up), 4)
        XCTAssertEqual(layout.target(from: 4, swipe: .down), 1)
        XCTAssertEqual(layout.target(from: 1, swipe: .down, invertVertical: true), 4)
        XCTAssertNil(layout.target(from: 0, swipe: .down))
        XCTAssertNil(layout.target(from: 6, swipe: .up))
    }

    func testIntoShorterLastRowClamps() {
        XCTAssertEqual(layout.target(from: 5, swipe: .up), 7)
        XCTAssertEqual(layout.target(from: 7, swipe: .down), 4)
    }

    func testEmptyAndSingle() {
        XCTAssertEqual(GridLayout(columns: 3, items: 0).rows, 0)
        XCTAssertNil(GridLayout(columns: 3, items: 0).target(from: 0, swipe: .left))
        XCTAssertNil(GridLayout(columns: 3, items: 1).target(from: 0, swipe: .up))
        XCTAssertEqual(GridLayout(columns: 0, items: 2).columns, 1)
    }
}

final class OrderingTests: XCTestCase {
    func testSavedOrderWinsAndNewItemsGoLast() {
        let items = ["desk", "orca", "ghostty", "spotify", "new"]
        let saved = ["spotify", "desk", "gone", "orca", "ghostty"]
        XCTAssertEqual(ordered(items, key: { $0 }, saved: saved), ["spotify", "desk", "orca", "ghostty", "new"])
    }

    func testNoSavedOrderKeepsOriginal() {
        XCTAssertEqual(ordered(["b", "a", "c"], key: { $0 }, saved: []), ["b", "a", "c"])
    }

    func testNewItemsKeepTheirRelativeOrder() {
        XCTAssertEqual(ordered(["x", "a", "y", "b"], key: { $0 }, saved: ["b", "a"]), ["b", "a", "x", "y"])
    }
}
