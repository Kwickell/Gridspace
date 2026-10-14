import AppKit

let arguments = CommandLine.arguments
if arguments.contains("--doctor") {
    exit(DoctorCLI.run())
}
if let flag = arguments.firstIndex(of: "--go"), flag + 1 < arguments.count, let item = Int(arguments[flag + 1]) {
    guard let layout = Spaces.layout() else { exit(1) }
    let ok = Navigator.go(to: item - 1, in: layout)
    RunLoop.main.run(until: Date().addingTimeInterval(Navigator.settleDelay + 0.6))
    exit(ok ? 0 : 1)
}
if arguments.contains("--list") {
    guard let layout = Spaces.layout() else { exit(1) }
    let names = layout.desktopIDs.indices.map { "Desktop \($0 + 1)" } + layout.apps.map(\.name)
    for (item, name) in names.enumerated() {
        print("\(item + 1)\(item == layout.current ? "*" : " ") \(name)")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
