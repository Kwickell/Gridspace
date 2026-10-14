import AppKit
import GridCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private let gestures = GestureMonitor()
    private let overlay = GridOverlay()
    private var statusItem: NSStatusItem!
    private var doctor: DoctorWindowController?
    private var arrange: ArrangeWindowController?
    private var arrangeHotkey: Hotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        Navigator.start()
        gestures.onSwipe = { [weak self] in self?.handle($0) }
        gestures.start(fingers: settings.fingers)

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        // MultitouchSupport stops delivering frames after sleep.
        workspace.addObserver(self, selector: #selector(restartGestures), name: NSWorkspace.didWakeNotification, object: nil)

        arrangeHotkey = Hotkey.arrange { [weak self] in self?.showArrange() }
        syncOrder()
        // Spaces can open or close without the active Space changing, e.g. closing one from Mission Control.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.syncOrder() }
        updateIcon()
        if checks().contains(where: { $0.status == .failing }) { showDoctor() }
    }

    private func checks() -> [CheckResult] {
        Doctor.run(settings: settings, deviceCount: gestures.deviceCount)
    }

    private func handle(_ swipe: SwipeDirection) {
        // While macOS owns these swipes too, acting on them would switch Spaces twice.
        guard SystemGestures.conflicts(fingers: settings.fingers).isEmpty else { return }
        guard let layout = Spaces.layout(), let current = Navigator.current(in: layout) else { return }
        let grid = layout.grid(columns: settings.columns)
        guard let target = grid.target(from: current, swipe: swipe, invertVertical: settings.invertVertical) else {
            if settings.showOverlay { overlay.show(layout, columns: settings.columns) }
            return
        }
        if !Navigator.go(to: target, in: layout) {
            NSSound.beep()
        }
    }

    private func syncOrder() {
        guard let layout = Spaces.layout() else { return }
        SpaceOrder.sync(layout)
    }

    @objc private func spaceChanged() {
        Navigator.spaceChanged()
        guard let layout = Spaces.layout() else { return }
        SpaceOrder.sync(layout)
        updateIcon()
        if settings.showOverlay { overlay.show(layout, columns: settings.columns) }
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
        guard let layout = Spaces.layout() else { return }
        statusItem.button?.image = Self.icon(grid: layout.grid(columns: settings.columns), current: layout.current)
    }

    private static func icon(grid: GridLayout, current: Int?) -> NSImage {
        let gap: CGFloat = 1.5, height: CGFloat = 16
        let rows = max(1, grid.rows)
        let cell = min(6, (height - CGFloat(rows - 1) * gap) / CGFloat(rows))
        let width = CGFloat(grid.columns) * cell + CGFloat(grid.columns - 1) * gap
        let top = (height - (CGFloat(rows) * cell + CGFloat(rows - 1) * gap)) / 2
        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            NSColor.black.set()
            for item in 0..<grid.items {
                guard let (row, col) = grid.position(of: item) else { continue }
                let rect = NSRect(x: CGFloat(col) * (cell + gap), y: top + CGFloat(row) * (cell + gap), width: cell, height: cell)
                let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 1.2, yRadius: 1.2)
                if item == current { path.fill() } else { path.lineWidth = 1; path.stroke() }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func showArrange() {
        if arrange == nil {
            arrange = ArrangeWindowController(columns: settings.columns) { [weak self] in self?.updateIcon() }
        }
        arrange?.present(columns: settings.columns)
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
        let layout = Spaces.layout()

        if let layout, let current = layout.current {
            menu.addItem(.info("\(layout.items[current].name), \(current + 1) of \(layout.items.count)"))
        } else {
            menu.addItem(.info("Current Space is unknown"))
        }
        menu.addItem(.separator())

        let arrangeItem = ActionItem("Arrange Spaces…") { [weak self] in self?.showArrange() }
        arrangeItem.keyEquivalent = "g"
        arrangeItem.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(arrangeItem)

        let columnMenu = NSMenu()
        for count in Settings.columnChoices {
            let item = ActionItem("\(count)") { [weak self] in
                self?.settings.columns = count
                self?.updateIcon()
            }
            item.state = settings.columns == count ? .on : .off
            columnMenu.addItem(item)
        }
        menu.addItem(.submenu("Columns", columnMenu))

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

        let fingers = settings.fingers
        let gridspaceOwnsSwipes = SystemGestures.conflicts(fingers: fingers).isEmpty
        menu.addItem(toggle("Gridspace swipes (macOS \(fingers)-finger swipes off)", gridspaceOwnsSwipes) {
            if gridspaceOwnsSwipes { SystemGestures.restore(fingers: fingers) } else { SystemGestures.disable(fingers: fingers) }
        })

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
