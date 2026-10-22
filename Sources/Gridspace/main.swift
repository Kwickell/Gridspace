import AppKit

let arguments = CommandLine.arguments
if arguments.contains("--doctor") {
    exit(DoctorCLI.run())
}
if let flag = arguments.firstIndex(of: "--go"), flag + 1 < arguments.count, let item = Int(arguments[flag + 1]) {
    guard let layout = Spaces.layout(), Navigator.start() else { exit(1) }
    let ok = Navigator.go(to: item - 1, in: layout)
    // ISS's event tap only passes the posted swipes on while the run loop runs.
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    exit(ok ? 0 : 1)
}
if arguments.contains("--overlay") {
    guard let layout = Spaces.layout() else { exit(1) }
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.finishLaunching()
    let overlay = GridOverlay()
    overlay.show(layout)
    RunLoop.main.run(until: Date().addingTimeInterval(1.2))
    exit(0)
}
if arguments.contains("--displays") {
    let target = Spaces.targetDisplayID()
    for layout in Spaces.layouts() {
        let mark = layout.displayID == target ? "*" : " "
        let cells = layout.grid.cells.indices.map { cell -> String in
            guard let item = layout.item(at: cell) else { return "." }
            return cell == layout.current ? "[\(item.name)]" : item.name
        }
        print("\(mark) \(Displays.name(for: layout.displayID))  \(layout.grid.rows)x\(layout.grid.columns)  \(cells.joined(separator: " "))")
    }
    print("* is the display a swipe acts on, [] its current Space")
    exit(0)
}
if arguments.contains("--list") {
    guard let layout = Spaces.layout() else { exit(1) }
    for (cell, _) in layout.grid.cells.enumerated() {
        guard let item = layout.item(at: cell), let (row, col) = layout.grid.position(of: cell) else { continue }
        print("\(cell + 1)\(cell == layout.current ? "*" : " ") r\(row + 1)c\(col + 1) \(item.name)")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
