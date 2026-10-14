/// Direction the fingers moved on the trackpad.
public enum SwipeDirection: Equatable {
    case left, right, up, down
}

/// A fixed-size grid of cells, each holding a Space key or nothing. Spaces stay where they're put:
/// a closed Space leaves a hole, and a new one fills the first hole after the last filled cell,
/// then the earliest hole, and only grows the grid by a row when it's full.
public struct CellGrid: Equatable {
    public private(set) var rows: Int
    public private(set) var columns: Int
    /// Row-major, `rows * columns` long.
    public private(set) var cells: [String?]

    public init(rows: Int, columns: Int, cells: [String?] = []) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        let count = self.rows * self.columns
        self.cells = Array(cells.prefix(count)) + Array(repeating: nil, count: max(0, count - cells.count))
    }

    /// Spaces in reading order, filling `columns` wide rows.
    public static func packed(_ keys: [String], columns: Int) -> CellGrid {
        let columns = max(1, columns)
        return CellGrid(rows: max(1, (keys.count + columns - 1) / columns), columns: columns, cells: keys)
    }

    public var filledCount: Int { cells.compactMap { $0 }.count }

    public func index(of key: String) -> Int? { cells.firstIndex(of: key) }

    public func position(of index: Int) -> (row: Int, col: Int)? {
        guard cells.indices.contains(index) else { return nil }
        return (index / columns, index % columns)
    }

    /// Drops keys that are gone and places new ones; `live` is in the order new Spaces should be placed.
    public func reconciled(with live: [String]) -> CellGrid {
        var grid = self
        let alive = Set(live)
        var seen = Set<String>()
        for i in grid.cells.indices {
            // A key that is gone, or a duplicate from a corrupted save, becomes a hole.
            if let key = grid.cells[i], !alive.contains(key) || !seen.insert(key).inserted { grid.cells[i] = nil }
        }
        for key in live where !seen.contains(key) {
            grid.place(key)
            seen.insert(key)
        }
        return grid
    }

    private mutating func place(_ key: String) {
        let lastFilled = cells.lastIndex { $0 != nil } ?? -1
        if let slot = cells[(lastFilled + 1)...].firstIndex(where: { $0 == nil }) ?? cells.firstIndex(where: { $0 == nil }) {
            cells[slot] = key
            return
        }
        rows += 1
        cells += Array(repeating: nil, count: columns)
        cells[cells.count - columns] = key
    }

    /// Moves a cell's Space onto another cell, swapping with whatever is there.
    public mutating func move(from: Int, to: Int) {
        guard cells.indices.contains(from), cells.indices.contains(to) else { return }
        cells.swapAt(from, to)
    }

    /// Keeps every Space at its row and column where it still fits; the rest fill the remaining holes.
    /// Never shrinks below what's needed to hold every Space.
    public func resized(rows newRows: Int, columns newColumns: Int) -> CellGrid {
        let newColumns = max(1, newColumns)
        let needed = (filledCount + newColumns - 1) / newColumns
        var grid = CellGrid(rows: max(newRows, needed, 1), columns: newColumns)
        var overflow: [String] = []
        for (i, key) in cells.enumerated() {
            guard let key else { continue }
            let (row, col) = (i / columns, i % columns)
            if row < grid.rows && col < grid.columns {
                grid.cells[row * grid.columns + col] = key
            } else {
                overflow.append(key)
            }
        }
        for key in overflow { grid.place(key) }
        return grid
    }

    /// The filled cell a swipe lands on, skipping empty cells, or nil if nothing is filled that way.
    /// Swipes are "natural", like the system's horizontal swipe: fingers moving left reveal the cell to the right.
    public func target(from index: Int, swipe: SwipeDirection, invertVertical: Bool = false) -> Int? {
        guard let (row, col) = position(of: index) else { return nil }
        let (dr, dc): (Int, Int)
        switch swipe {
        case .left: (dr, dc) = (0, 1)
        case .right: (dr, dc) = (0, -1)
        case .up, .down:
            let down = (swipe == .up) != invertVertical
            (dr, dc) = (down ? 1 : -1, 0)
        }
        var r = row + dr, c = col + dc
        while r >= 0, r < rows, c >= 0, c < columns {
            if cells[r * columns + c] != nil { return r * columns + c }
            r += dr
            c += dc
        }
        return nil
    }
}
