import GridCore
import XCTest

final class GridTests: XCTestCase {
    let grid = Grid(rows: 2, cols: 4)

    func testHorizontalIsNatural() {
        XCTAssertEqual(grid.target(from: 0, swipe: .left, available: 8), 1)
        XCTAssertEqual(grid.target(from: 1, swipe: .right, available: 8), 0)
    }

    func testVertical() {
        XCTAssertEqual(grid.target(from: 1, swipe: .up, available: 8), 5)
        XCTAssertEqual(grid.target(from: 5, swipe: .down, available: 8), 1)
        XCTAssertEqual(grid.target(from: 1, swipe: .down, available: 8, invertVertical: true), 5)
    }

    func testEdgesDoNotWrap() {
        XCTAssertNil(grid.target(from: 3, swipe: .left, available: 8))
        XCTAssertNil(grid.target(from: 4, swipe: .right, available: 8))
        XCTAssertNil(grid.target(from: 0, swipe: .down, available: 8))
        XCTAssertNil(grid.target(from: 7, swipe: .up, available: 8))
    }

    func testMissingDesktopsAreUnreachable() {
        XCTAssertNil(grid.target(from: 1, swipe: .up, available: 5))
        XCTAssertEqual(grid.target(from: 0, swipe: .up, available: 5), 4)
    }

    func testOutsideGridIsIgnored() {
        XCTAssertNil(grid.target(from: 8, swipe: .right, available: 10))
        XCTAssertNil(grid.target(from: -1, swipe: .left, available: 8))
    }

    func testDegenerateSizesClamp() {
        let g = Grid(rows: 0, cols: 0)
        XCTAssertEqual(g.cells, 1)
        XCTAssertNil(g.target(from: 0, swipe: .left, available: 1))
    }
}
