import AppKit
import GridCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private let gestures = GestureMonitor()
    private let overlay = GridOverlay()
    private var statusItem: NSStatusItem!
    private var doctor: DoctorWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        gestures.onSwipe = { [weak self] in self?.handle($0) }
        gestures.start(fingers: settings.fingers)

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        // MultitouchSupport stops delivering frames after sleep.
        workspace.addObserver(self, selector: #selector(restartGestures), name: NSWorkspace.didWakeNotification, object: nil)

        updateIcon()
        if checks().contains(where: { $0.status == .failing }) { showDoctor() }
    }

    private func checks() -> [CheckResult] {
        Doctor.run(settings: settings, deviceCount: gestures.deviceCount)
    }

    private func handle(_ swipe: SwipeDirection) {
        guard let layout = Spaces.layout(), let index = layout.currentIndex else { return }
        let grid = settings.grid
        guard let target = grid.target(from: index, swipe: swipe, available: layout.desktopIDs.count, invertVertical: settings.invertVertical) else {
            if settings.showOverlay, index < grid.cells {
                overlay.show(grid: grid, current: index, available: layout.desktopIDs.count)
            }
            return
        }
        if !DesktopShortcuts.switchTo(desktop: layout.shortcutOffset + target + 1) {
            NSSound.beep()
        }
    }

    @objc private func spaceChanged() {
        updateIcon()
        guard settings.showOverlay, let layout = Spaces.layout(), let index = layout.currentIndex, index < settings.grid.cells else { return }
        overlay.show(grid: settings.grid, current: index, available: layout.desktopIDs.count)
    }

    @objc private func restartGestures() {
        gestures.start(fingers: settings.fingers)
        // Devices can still be missing right after wake.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            self.gestures.start(fingers: self.settings.fingers)
        }
    }

    private func updateIcon() {
        let layout = Spaces.layout()
        statusItem.button?.image = Self.icon(grid: settings.grid, current: layout?.currentIndex)
    }

    private static func icon(grid: Grid, current: Int?) -> NSImage {
        let gap: CGFloat = 1.5, height: CGFloat = 14
        let cell = (height - CGFloat(grid.rows - 1) * gap) / CGFloat(grid.rows)
        let width = CGFloat(grid.cols) * cell + CGFloat(grid.cols - 1) * gap
        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            for index in 0..<grid.cells {
                guard let (row, col) = grid.position(of: index) else { continue }
                let rect = NSRect(x: CGFloat(col) * (cell + gap), y: CGFloat(row) * (cell + gap), width: cell, height: cell)
                let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 1.5, yRadius: 1.5)
                NSColor.black.set()
                if index == current { path.fill() } else { path.lineWidth = 1; path.stroke() }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func showDoctor() {
        if doctor == nil {
            doctor = DoctorWindowController { [weak self] in self?.checks() ?? [] }
        }
        doctor?.present()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let grid = settings.grid
        let layout = Spaces.layout()

        if let index = layout?.currentIndex, let (row, col) = grid.position(of: index) {
            menu.addItem(.info("Desktop \(index + 1): row \(row + 1), column \(col + 1)"))
        } else {
            menu.addItem(.info("Current space is outside the grid"))
        }
        menu.addItem(.separator())

        let gridMenu = NSMenu()
        for preset in Settings.presets {
            let item = ActionItem("\(preset.rows) × \(preset.cols)") { [weak self] in
                self?.settings.grid = Grid(rows: preset.rows, cols: preset.cols)
                self?.updateIcon()
            }
            item.state = grid == Grid(rows: preset.rows, cols: preset.cols) ? .on : .off
            gridMenu.addItem(item)
        }
        menu.addItem(.submenu("Grid", gridMenu))

        let fingerMenu = NSMenu()
        for count in [3, 4] {
            let item = ActionItem("\(count) fingers") { [weak self] in
                self?.settings.fingers = count
                self?.restartGestures()
            }
            item.state = settings.fingers == count ? .on : .off
            fingerMenu.addItem(item)
        }
        menu.addItem(.submenu("Swipe with", fingerMenu))

        menu.addItem(toggle("Invert vertical swipe", settings.invertVertical) { [weak self] in self?.settings.invertVertical.toggle() })
        menu.addItem(toggle("Show grid on switch", settings.showOverlay) { [weak self] in self?.settings.showOverlay.toggle() })
        menu.addItem(.separator())

        let problems = checks().filter { $0.status != .ok }.count
        menu.addItem(ActionItem(problems == 0 ? "Doctor…" : "Doctor… (\(problems) to check)") { [weak self] in self?.showDoctor() })
        let login = SMAppService.mainApp
        menu.addItem(toggle("Launch at login", login.status == .enabled) {
            if login.status == .enabled { try? login.unregister() } else { try? login.register() }
        })
        menu.addItem(.separator())
        menu.addItem(ActionItem("Quit Gridspace") { NSApp.terminate(nil) })
    }

    private func toggle(_ title: String, _ on: Bool, _ action: @escaping () -> Void) -> NSMenuItem {
        let item = ActionItem(title, action)
        item.state = on ? .on : .off
        return item
    }
}

private final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { handler() }
}

private extension NSMenuItem {
    static func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    static func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
