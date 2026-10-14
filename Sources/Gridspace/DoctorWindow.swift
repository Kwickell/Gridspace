import AppKit
import SwiftUI

final class DoctorModel: ObservableObject {
    @Published private(set) var results: [CheckResult] = []
    private let check: () -> [CheckResult]

    init(check: @escaping () -> [CheckResult]) {
        self.check = check
        recheck()
    }

    func recheck() {
        results = check()
    }

    func apply(_ fix: Fix) {
        fix.action()
        // Dock restarts and System Settings writes land a moment later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.recheck() }
    }
}

struct DoctorView: View {
    @ObservedObject var model: DoctorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(model.results) { row($0) }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Text(summary).foregroundStyle(.secondary)
                Spacer()
                Button("Recheck") { model.recheck() }.keyboardShortcut("r")
            }
            .padding(14)
        }
        .frame(width: 520, height: 560)
    }

    private var summary: String {
        let failing = model.results.filter { $0.status == .failing }.count
        let warnings = model.results.filter { $0.status == .warning }.count
        if failing + warnings == 0 { return "Everything is set." }
        return [failing > 0 ? "\(failing) to fix" : nil, warnings > 0 ? "\(warnings) warning\(warnings == 1 ? "" : "s")" : nil]
            .compactMap { $0 }.joined(separator: ", ")
    }

    private func row(_ result: CheckResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            icon(result.status).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title).font(.headline)
                Text(result.detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if result.status != .ok && !result.fixes.isEmpty {
                    HStack {
                        ForEach(Array(result.fixes.enumerated()), id: \.offset) { _, fix in
                            Button(fix.title) { model.apply(fix) }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func icon(_ status: CheckStatus) -> some View {
        switch status {
        case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .failing: Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }
}

final class DoctorWindowController: NSWindowController {
    let model: DoctorModel

    init(check: @escaping () -> [CheckResult]) {
        model = DoctorModel(check: check)
        let window = NSWindow(contentViewController: NSHostingController(rootView: DoctorView(model: model)))
        window.title = "Gridspace Doctor"
        window.styleMask = [.titled, .closable]
        super.init(window: window)
        NotificationCenter.default.addObserver(self, selector: #selector(recheck), name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func recheck() { model.recheck() }

    func present() {
        model.recheck()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
