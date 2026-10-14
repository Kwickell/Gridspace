/// Direction the fingers moved on the trackpad.
public enum SwipeDirection: Equatable {
    case left, right, up, down
}

/// Desktops fill rows of a fixed width, and fullscreen apps start on their own row below them,
/// so opening or closing an app never moves a desktop.
/// Items are numbered desktops first, then apps.
public struct GridLayout: Equatable {
    public let columns: Int
    public let desktops: Int
    public let apps: Int

    public init(columns: Int, desktops: Int, apps: Int) {
        self.columns = max(1, columns)
        self.desktops = max(0, desktops)
        self.apps = max(0, apps)
    }

    public var items: Int { desktops + apps }
    public var desktopRows: Int { rowCount(desktops) }
    public var rows: Int { desktopRows + rowCount(apps) }

    public func isApp(_ item: Int) -> Bool { item >= desktops && item < items }

    public func position(of item: Int) -> (row: Int, col: Int)? {
        guard item >= 0, item < items else { return nil }
        if item < desktops { return (item / columns, item % columns) }
        let app = item - desktops
        return (desktopRows + app / columns, app % columns)
    }

    public func item(row: Int, col: Int) -> Int? {
        guard col >= 0, col < columns, row >= 0, row < rows else { return nil }
        let item = row < desktopRows
            ? row * columns + col
            : desktops + (row - desktopRows) * columns + col
        let sectionEnd = row < desktopRows ? desktops : items
        return item < sectionEnd ? item : nil
    }

    /// The item a swipe lands on, or nil at the edge of the grid.
    /// Swipes are "natural", like the system's horizontal swipe: fingers moving left reveal the item to the right.
    /// Moving vertically into a shorter row lands on that row's last item.
    public func target(from item: Int, swipe: SwipeDirection, invertVertical: Bool = false) -> Int? {
        guard let (row, col) = position(of: item) else { return nil }
        switch swipe {
        case .left: return self.item(row: row, col: col + 1)
        case .right: return self.item(row: row, col: col - 1)
        case .up, .down:
            let down = (swipe == .up) != invertVertical
            let next = row + (down ? 1 : -1)
            guard next >= 0, next < rows else { return nil }
            for c in stride(from: col, through: 0, by: -1) {
                if let found = self.item(row: next, col: c) { return found }
            }
            return nil
        }
    }

    private func rowCount(_ n: Int) -> Int { (n + columns - 1) / columns }
}
