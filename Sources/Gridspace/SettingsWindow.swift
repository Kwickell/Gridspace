import AppKit
import ServiceManagement
import SwiftUI

final class SettingsModel: ObservableObject {
    let settings: Settings
    let openArrange: () -> Void
    let openDoctor: () -> Void

    @Published var fingers: Int { didSet { if fingers != settings.fingers { settings.fingers = fingers } } }
    @Published var invertVertical: Bool { didSet { settings.invertVertical = invertVertical } }
    @Published var showOverlay: Bool { didSet { settings.showOverlay = showOverlay } }
    @Published private(set) var gridspaceOwnsSwipes = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var shortcut: String = ""
    @Published var recording = false
    private var monitor: Any?

    init(settings: Settings, openArrange: @escaping () -> Void, openDoctor: @escaping () -> Void) {
        self.settings = settings
        self.openArrange = openArrange
        self.openDoctor = openDoctor
        fingers = settings.fingers
        invertVertical = settings.invertVertical
        showOverlay = settings.showOverlay
        refresh()
    }

    func refresh() {
        fingers = settings.fingers
        gridspaceOwnsSwipes = SystemGestures.conflicts(fingers: settings.fingers).isEmpty
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let current = settings.arrangeShortcut
        shortcut = Shortcut.display(keyCode: current.keyCode, modifiers: current.modifiers)
    }

    func setGridspaceOwnsSwipes(_ on: Bool) {
        if on { SystemGestures.disable(fingers: settings.fingers) } else { SystemGestures.restore(fingers: settings.fingers) }
        refresh()
    }

    func setLaunchAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        if on { try? service.register() } else { try? service.unregister() }
        refresh()
    }

    func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch Int(event.keyCode) {
            case 53:
                self.stopRecording()
            case 51, 117:
                self.settings.arrangeShortcut = (0, 0)
                self.stopRecording()
            default:
                let modifiers = Shortcut.carbonModifiers(event.modifierFlags)
                // Without Control, Option or Command the shortcut would swallow ordinary typing.
                guard event.modifierFlags.intersection([.control, .option, .command]).isEmpty == false else { return nil }
                self.settings.arrangeShortcut = (UInt32(event.keyCode), modifiers)
                self.stopRecording()
            }
            return nil
        }
    }

    func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        refresh()
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Swipes") {
                Picker("Swipe with", selection: $model.fingers) {
                    Text("3 fingers").tag(3)
                    Text("4 fingers").tag(4)
                }
                .onChange(of: model.fingers) { _ in model.refresh() }
                Toggle("Gridspace handles \(model.fingers)-finger swipes", isOn: Binding(
                    get: { model.gridspaceOwnsSwipes },
                    set: { model.setGridspaceOwnsSwipes($0) }
                ))
                Text("Turns off the macOS \(model.fingers)-finger gestures while on, and restores them when off.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Invert vertical swipe", isOn: $model.invertVertical)
                Toggle("Show the grid when switching", isOn: $model.showOverlay)
            }
            Section("Grid") {
                HStack {
                    Text("Arrange Spaces shortcut")
                    Spacer()
                    Button(model.recording ? "Press keys… (⎋ cancel, ⌫ clear)" : model.shortcut) {
                        model.recording ? model.stopRecording() : model.startRecording()
                    }
                }
                Button("Arrange Spaces…") { model.openArrange() }
            }
            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                Button("Run Doctor…") { model.openDoctor() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
    }
}
