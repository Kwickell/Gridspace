import AppKit
import ApplicationServices
import SwiftUI

final class OnboardingModel: ObservableObject {
    let settings: Settings
    let openArrange: () -> Void
    let finish: () -> Void

    @Published private(set) var accessibility = false
    @Published private(set) var inputMonitoring = false
    @Published private(set) var swipes = false
    private var timer: Timer?

    init(settings: Settings, openArrange: @escaping () -> Void, finish: @escaping () -> Void) {
        self.settings = settings
        self.openArrange = openArrange
        self.finish = finish
        refresh()
        // Permissions are granted in System Settings, so watch for them instead of waiting for a click here.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    deinit { stop() }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        accessibility = AXIsProcessTrusted()
        inputMonitoring = CGPreflightListenEventAccess() && Navigator.start()
        swipes = SystemGestures.conflicts(fingers: settings.fingers).isEmpty
    }

    func requestAccessibility() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        SystemPrefs.open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func requestInputMonitoring() {
        if !CGRequestListenEventAccess() {
            SystemPrefs.open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
    }

    func takeOverSwipes() {
        SystemGestures.disable(fingers: settings.fingers)
        refresh()
    }
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Gridspace").font(.title2.bold())
                    Text("Your Spaces as a grid, one swipe away in every direction.").foregroundStyle(.secondary)
                }
            }
            step(1, "Allow Accessibility", "Lets Gridspace switch Spaces for you.", done: model.accessibility) {
                Button("Open Settings") { model.requestAccessibility() }
            }
            step(2, "Allow Input Monitoring", "Lets Gridspace keep track of the switches it makes.", done: model.inputMonitoring) {
                Button("Open Settings") { model.requestInputMonitoring() }
            }
            step(3, "Hand \(model.settings.fingers)-finger swipes to Gridspace", "Turns off the macOS \(model.settings.fingers)-finger gestures so they don't fire as well. You can switch back in Settings.", done: model.swipes) {
                Button("Take over swipes") { model.takeOverSwipes() }
            }
            step(4, "Arrange your grid", "Set the grid size and drag your desktops and fullscreen apps into place. Open it any time with \(shortcut).", done: false) {
                Button("Arrange Spaces…") { model.openArrange() }
            }
            HStack {
                Text("If a permission doesn't show as done, quit and reopen Gridspace.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { model.finish() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private var shortcut: String {
        let current = model.settings.arrangeShortcut
        return current.modifiers == 0 ? "the menu" : Shortcut.display(keyCode: current.keyCode, modifiers: current.modifiers)
    }

    private func step<Action: View>(_ number: Int, _ title: String, _ detail: String, done: Bool, @ViewBuilder action: () -> Action) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green : Color.secondary.opacity(0.2)).frame(width: 26, height: 26)
                if done {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.callout.bold())
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !done { action() }
        }
    }
}
