/// Direction the fingers moved on the trackpad.
public enum SwipeDirection: Equatable {
    case left, right, up, down
}

public struct Grid: Equatable {
    public let rows: Int
    public let cols: Int

    public init(rows: Int, cols: Int) {
        self.rows = max(1, rows)
        self.cols = max(1, cols)
    }

    public var cells: Int { rows * cols }

    public func position(of index: Int) -> (row: Int, col: Int)? {
        guard index >= 0, index < cells else { return nil }
        return (index / cols, index % cols)
    }

    /// The desktop index a swipe lands on, or nil at the edge of the grid or past the last existing desktop.
    /// Swipes are "natural", like the system's horizontal swipe: fingers moving left reveal the desktop to the right.
    public func target(from index: Int, swipe: SwipeDirection, available: Int, invertVertical: Bool = false) -> Int? {
        guard let (row, col) = position(of: index) else { return nil }
        var r = row, c = col
        switch swipe {
        case .left: c += 1
        case .right: c -= 1
        case .up: r += invertVertical ? -1 : 1
        case .down: r += invertVertical ? 1 : -1
        }
        guard r >= 0, r < rows, c >= 0, c < cols else { return nil }
        let target = r * cols + c
        return target < available ? target : nil
    }
}
