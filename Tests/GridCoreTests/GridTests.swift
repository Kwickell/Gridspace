import GridCore
import XCTest

final class CellGridTests: XCTestCase {
    // a . c .
    // . e . .
    // g h i .
    let grid = CellGrid(rows: 3, columns: 4, cells: ["a", nil, "c", nil, nil, "e", nil, nil, "g", "h", "i", nil])

    func testHorizontalSkipsHoles() {
        XCTAssertEqual(grid.target(from: 0, swipe: .left), 2)
        XCTAssertEqual(grid.target(from: 2, swipe: .right), 0)
        XCTAssertNil(grid.target(from: 2, swipe: .left))
        XCTAssertNil(grid.target(from: 5, swipe: .left))
    }

    func testVerticalSkipsHoles() {
        XCTAssertEqual(grid.target(from: 0, swipe: .up), 8)
        XCTAssertEqual(grid.target(from: 8, swipe: .down), 0)
        XCTAssertEqual(grid.target(from: 0, swipe: .down, invertVertical: true), 8)
        XCTAssertEqual(grid.target(from: 5, swipe: .up), 9)
        XCTAssertNil(grid.target(from: 2, swipe: .down))
        XCTAssertNil(grid.target(from: 10, swipe: .up))
    }

    func testPacked() {
        let g = CellGrid.packed(["a", "b", "c", "d"], columns: 2)
        XCTAssertEqual(g.rows, 2)
        XCTAssertEqual(g.cells, ["a", "b", "c", "d"])
        XCTAssertEqual(CellGrid.packed([], columns: 3).rows, 1)
    }

    func testClosedSpaceLeavesHole() {
        let g = grid.reconciled(with: ["a", "c", "g", "h", "i"])
        XCTAssertNil(g.cells[5])
        XCTAssertEqual(g.index(of: "a"), 0)
        XCTAssertEqual(g.index(of: "i"), 10)
    }

    func testNewSpaceGoesAfterLastFilled() {
        let g = grid.reconciled(with: ["a", "c", "e", "g", "h", "i", "new"])
        XCTAssertEqual(g.index(of: "new"), 11)
    }

    func testNewSpaceFillsEarliestHoleWhenNothingAfterLast() {
        var full = CellGrid(rows: 2, columns: 2, cells: ["a", nil, "c", "d"])
        full = full.reconciled(with: ["a", "c", "d", "new"])
        XCTAssertEqual(full.index(of: "new"), 1)
    }

    func testFullGridGrowsByARow() {
        let g = CellGrid.packed(["a", "b", "c", "d"], columns: 2).reconciled(with: ["a", "b", "c", "d", "e"])
        XCTAssertEqual(g.rows, 3)
        XCTAssertEqual(g.columns, 2)
        XCTAssertEqual(g.index(of: "e"), 4)
    }

    func testDuplicatesBecomeHoles() {
        let g = CellGrid(rows: 1, columns: 3, cells: ["a", "a", nil]).reconciled(with: ["a"])
        XCTAssertEqual(g.cells, ["a", nil, nil])
    }

    func testMoveSwapsOrFillsHole() {
        var g = grid
        g.move(from: 0, to: 1)
        XCTAssertEqual(g.cells[0], nil)
        XCTAssertEqual(g.cells[1], "a")
        g.move(from: 1, to: 2)
        XCTAssertEqual(g.cells[1], "c")
        XCTAssertEqual(g.cells[2], "a")
    }

    func testResizeKeepsPositionsAndRehomesOverflow() {
        let g = grid.resized(rows: 3, columns: 3)
        XCTAssertEqual(g.index(of: "a"), 0)
        XCTAssertEqual(g.index(of: "e"), 4)
        XCTAssertEqual(g.index(of: "i"), 8)
        XCTAssertEqual(g.filledCount, 6)
    }

    func testResizeNeverDropsSpaces() {
        let g = CellGrid.packed(["a", "b", "c", "d", "e"], columns: 5).resized(rows: 1, columns: 2)
        XCTAssertEqual(g.rows, 3)
        XCTAssertEqual(g.filledCount, 5)
    }
}
