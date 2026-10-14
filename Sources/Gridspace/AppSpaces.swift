import AppKit
import ApplicationServices

/// Brings a fullscreen app's Space forward: make its fullscreen window the app's key window (the way window
/// switchers like AltTab do), then activate the app so macOS switches to that window's Space. Activating
/// alone lets macOS pick any of the app's windows, which can land on another Space.
enum AppSpaces {
    private typealias GetProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias SetFrontProcess = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    private typealias PostEventRecord = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError

    private static let userGenerated: UInt32 = 0x200

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
    private static let getProcessForPID = symbol("GetProcessForPID", in: dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW), as: GetProcessForPID.self)
    private static let setFrontProcess = symbol("_SLPSSetFrontProcessWithOptions", in: skyLight, as: SetFrontProcess.self)
    private static let postEventRecord = symbol("SLPSPostEventRecordTo", in: skyLight, as: PostEventRecord.self)

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?, as type: T.Type) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }

    @discardableResult
    static func focus(_ space: AppSpace) -> Bool {
        if space.windowID != 0 { _ = focusWindow(pid: space.pid, windowID: space.windowID) }
        guard let app = NSRunningApplication(processIdentifier: space.pid), let url = app.bundleURL else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        return true
    }

    private static func focusWindow(pid: pid_t, windowID: CGWindowID) -> Bool {
        guard let getProcessForPID, let setFrontProcess, let postEventRecord else { return false }
        var psn = ProcessSerialNumber()
        guard getProcessForPID(pid, &psn) == noErr,
              setFrontProcess(&psn, windowID, userGenerated) == .success
        else { return false }

        // Synthetic "make key window" event records; the byte offsets are SkyLight's private event layout.
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        withUnsafeBytes(of: windowID) { id in
            for (offset, byte) in id.enumerated() { bytes[0x3c + offset] = byte }
        }
        for offset in 0x20..<0x30 { bytes[offset] = 0xff }
        for kind: UInt8 in [0x01, 0x02] {
            bytes[0x08] = kind
            _ = bytes.withUnsafeMutableBufferPointer { postEventRecord(&psn, $0.baseAddress!) }
        }
        return true
    }
}
