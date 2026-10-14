/// Direction the fingers moved on the trackpad.
public enum SwipeDirection: Equatable {
    case left, right, up, down
}

/// Items fill rows of a fixed width, left to right, top to bottom.
public struct GridLayout: Equatable {
    public let columns: Int
    public let items: Int

    public init(columns: Int, items: Int) {
        self.columns = max(1, columns)
        self.items = max(0, items)
    }

    public var rows: Int { (items + columns - 1) / columns }

    public func position(of item: Int) -> (row: Int, col: Int)? {
        guard item >= 0, item < items else { return nil }
        return (item / columns, item % columns)
    }

    public func item(row: Int, col: Int) -> Int? {
        guard row >= 0, col >= 0, col < columns else { return nil }
        let item = row * columns + col
        return item < items ? item : nil
    }

    /// The item a swipe lands on, or nil at the edge of the grid.
    /// Swipes are "natural", like the system's horizontal swipe: fingers moving left reveal the item to the right.
    /// Moving down into the shorter last row lands on its last item.
    public func target(from item: Int, swipe: SwipeDirection, invertVertical: Bool = false) -> Int? {
        guard let (row, col) = position(of: item) else { return nil }
        switch swipe {
        case .left: return self.item(row: row, col: col + 1)
        case .right: return self.item(row: row, col: col - 1)
        case .up, .down:
            let down = (swipe == .up) != invertVertical
            let next = row + (down ? 1 : -1)
            guard next >= 0, next < rows else { return nil }
            return self.item(row: next, col: col) ?? min(items - 1, next * columns + columns - 1)
        }
    }
}

/// Puts items in a saved order: known keys first in their saved order, then new ones in their original order.
public func ordered<T>(_ items: [T], key: (T) -> String, saved: [String]) -> [T] {
    let rank = Dictionary(saved.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
    return items.enumerated()
        .sorted { a, b in
            switch (rank[key(a.element)], rank[key(b.element)]) {
            case let (x?, y?): return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return a.offset < b.offset
            }
        }
        .map(\.element)
}
