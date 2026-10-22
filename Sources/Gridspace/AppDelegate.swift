import AppKit
import Carbon.HIToolbox
import GridCore
import OSLog

private let log = Logger(subsystem: "com.kwickell.gridspace", category: "swipe")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private let gestures = GestureMonitor()
    private let overlay = GridOverlay()
    private var statusItem: NSStatusItem!
    private var doctor: DoctorWindowController?
    private var arrange: ArrangeWindowController?
    private var arrangeHotkey: Hotkey?
    private var settingsWindow: HostedWindow<SettingsView>?
    private var settingsModel: SettingsModel?
    private var onboarding: HostedWindow<OnboardingView>?

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

        registerHotkey()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .gridspaceSettingsChanged, object: nil)
        syncOrder()
        // Spaces can open or close without the active Space changing, e.g. closing one from Mission
        // Control, and a trackpad can be connected at any time.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.gestures.restartIfDevicesChanged(fingers: self.settings.fingers)
            self.syncOrder()
        }
        updateIcon()
        if !settings.onboarded {
            showOnboarding()
        } else if checks().contains(where: { $0.status == .failing }) {
            showDoctor()
        }
    }

    private func registerHotkey() {
        arrangeHotkey = nil
        let shortcut = settings.arrangeShortcut
        guard shortcut.modifiers != 0 else { return }
        arrangeHotkey = Hotkey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in self?.showArrange() }
    }

    @objc private func settingsChanged() {
        registerHotkey()
        restartGestures()
        updateIcon()
        settingsModel?.refresh()
    }

    private func checks() -> [CheckResult] {
        Doctor.run(settings: settings, deviceCount: gestures.deviceCount)
    }

    private func handle(_ swipe: SwipeDirection) {
        // While macOS owns these swipes too, acting on them would switch Spaces twice.
        guard SystemGestures.conflicts(fingers: settings.fingers).isEmpty else {
            log.info("swipe \(String(describing: swipe)) ignored: macOS owns these swipes")
            return
        }
        guard let layout = Spaces.layout(), let current = Navigator.current(in: layout) else {
            log.info("swipe \(String(describing: swipe)) ignored: current Space not in the grid")
            return
        }
        guard let target = layout.grid.target(from: current, swipe: swipe, invertVertical: settings.invertVertical) else {
            log.info("swipe \(String(describing: swipe)) from cell \(current): edge of the grid")
            if settings.showOverlay { overlay.show(layout) }
            return
        }
        let switched = Navigator.go(to: target, in: layout)
        log.info("swipe \(String(describing: swipe)) from cell \(current) to \(target): \(switched ? "switched" : "refused")")
        if !switched { NSSound.beep() }
    }

    private func syncOrder() {
        guard let layout = Spaces.layout() else { return }
        GridStore.sync(layout)
        arrange?.refresh()
    }

    @objc private func spaceChanged() {
        Navigator.spaceChanged()
        guard let layout = Spaces.layout() else { return }
        GridStore.sync(layout)
        arrange?.refresh()
        updateIcon()
        if settings.showOverlay { overlay.show(layout) }
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
        statusItem.button?.image = Self.icon(grid: layout.grid, current: layout.current)
    }

    private static func icon(grid: CellGrid, current: Int?) -> NSImage {
        let gap: CGFloat = 1.5, height: CGFloat = 16
        let rows = max(1, grid.rows)
        let cell = max(1, min(6, (height - CGFloat(rows - 1) * gap) / CGFloat(rows)))
        let width = CGFloat(grid.columns) * cell + CGFloat(grid.columns - 1) * gap
        let top = (height - (CGFloat(rows) * cell + CGFloat(rows - 1) * gap)) / 2
        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            NSColor.black.set()
            for (index, key) in grid.cells.enumerated() {
                guard let (row, col) = grid.position(of: index) else { continue }
                let rect = NSRect(x: CGFloat(col) * (cell + gap), y: top + CGFloat(row) * (cell + gap), width: cell, height: cell)
                if key == nil {
                    NSBezierPath(ovalIn: NSRect(x: rect.midX - 0.75, y: rect.midY - 0.75, width: 1.5, height: 1.5)).fill()
                    continue
                }
                let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 1.2, yRadius: 1.2)
                if index == current { path.fill() } else { path.lineWidth = 1; path.stroke() }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func showArrange() {
        if arrange == nil {
            arrange = ArrangeWindowController { [weak self] in self?.updateIcon() }
        }
        arrange?.present()
    }

    private func showSettings() {
        if settingsWindow == nil {
            let model = SettingsModel(
                settings: settings,
                openArrange: { [weak self] in self?.showArrange() },
                openDoctor: { [weak self] in self?.showDoctor() }
            )
            settingsModel = model
            settingsWindow = HostedWindow(title: "Gridspace Settings", onClose: { model.stopRecording() }) { SettingsView(model: model) }
        }
        settingsModel?.refresh()
        settingsWindow?.present()
    }

    private func showOnboarding() {
        if onboarding == nil {
            let model = OnboardingModel(
                settings: settings,
                openArrange: { [weak self] in self?.showArrange() },
                finish: { [weak self] in
                    self?.settings.onboarded = true
                    self?.onboarding?.close()
                }
            )
            onboarding = HostedWindow(title: "Welcome to Gridspace", onClose: { [weak self] in
                model.stop()
                self?.onboarding = nil
            }) { OnboardingView(model: model) }
        }
        onboarding?.present()
    }

    private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "Instant switching uses InstantSpaceSwitcher by jurplel (MIT).\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        credits.append(NSAttributedString(
            string: "github.com/jurplel/InstantSpaceSwitcher",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: URL(string: "https://github.com/jurplel/InstantSpaceSwitcher")!]
        ))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
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

        if let layout, let current = layout.current, let item = layout.item(at: current), let (row, col) = layout.grid.position(of: current) {
            menu.addItem(.info("\(item.name): row \(row + 1), column \(col + 1)"))
        } else {
            menu.addItem(.info("Current Space is unknown"))
        }
        menu.addItem(.separator())

        let arrangeItem = ActionItem("Arrange Spaces…") { [weak self] in self?.showArrange() }
        let shortcut = settings.arrangeShortcut
        if shortcut.modifiers != 0, let key = Self.menuKeyEquivalent(shortcut.keyCode) {
            arrangeItem.keyEquivalent = key
            arrangeItem.keyEquivalentModifierMask = Self.menuModifiers(shortcut.modifiers)
        }
        menu.addItem(arrangeItem)

        let fingers = settings.fingers
        let gridspaceOwnsSwipes = SystemGestures.conflicts(fingers: fingers).isEmpty
        menu.addItem(toggle("Gridspace handles \(fingers)-finger swipes", gridspaceOwnsSwipes) { [weak self] in
            if gridspaceOwnsSwipes { SystemGestures.restore(fingers: fingers) } else { SystemGestures.disable(fingers: fingers) }
            self?.settingsModel?.refresh()
        })
        menu.addItem(.separator())

        let settingsItem = ActionItem("Settings…") { [weak self] in self?.showSettings() }
        settingsItem.keyEquivalent = ","
        menu.addItem(settingsItem)
        let problems = checks().filter { $0.status != .ok }.count
        menu.addItem(ActionItem(problems == 0 ? "Doctor…" : "Doctor… (\(problems) to check)") { [weak self] in self?.showDoctor() })
        menu.addItem(ActionItem("About Gridspace") { [weak self] in self?.showAbout() })
        menu.addItem(.separator())
        menu.addItem(ActionItem("Quit Gridspace") { NSApp.terminate(nil) })
    }

    private static func menuKeyEquivalent(_ keyCode: UInt32) -> String? {
        let name = Shortcut.display(keyCode: keyCode, modifiers: 0)
        return name.count == 1 ? name.lowercased() : nil
    }

    private static func menuModifiers(_ carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbon & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbon & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbon & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
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
