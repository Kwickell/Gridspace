// Renders Resources/AppIcon.icns. Run with: swift scripts/make-icon.swift
import AppKit

func render(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let s = size / 1024
        // Apple's macOS icon template puts an 824pt body in the middle of a 1024pt canvas.
        let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let shape = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
        shadow.shadowBlurRadius = 24 * s
        shadow.set()
        NSColor.black.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(colors: [
            NSColor(srgbRed: 0.36, green: 0.27, blue: 0.93, alpha: 1),
            NSColor(srgbRed: 0.13, green: 0.10, blue: 0.38, alpha: 1),
        ])!.draw(in: shape, angle: -70)

        let tile: CGFloat = 196 * s, gap: CGFloat = 46 * s
        let origin = NSPoint(x: body.midX - (3 * tile + 2 * gap) / 2, y: body.midY - (3 * tile + 2 * gap) / 2)
        for row in 0..<3 {
            for col in 0..<3 {
                let rect = NSRect(
                    x: origin.x + CGFloat(col) * (tile + gap),
                    y: origin.y + CGFloat(2 - row) * (tile + gap),
                    width: tile, height: tile
                )
                let path = NSBezierPath(roundedRect: rect, xRadius: 44 * s, yRadius: 44 * s)
                switch (row, col) {
                case (1, 1):
                    NSColor.white.setFill()
                    path.fill()
                case (2, 2):
                    NSColor.white.withAlphaComponent(0.35).setStroke()
                    path.lineWidth = 10 * s
                    let dash: [CGFloat] = [28 * s, 18 * s]
                    path.setLineDash(dash, count: 2, phase: 0)
                    path.stroke()
                default:
                    NSColor.white.withAlphaComponent(0.26).setFill()
                    path.fill()
                }
            }
        }
        return true
    }
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = CGFloat(base * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels), pixelsHigh: Int(pixels), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        render(size: pixels).draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try process.run()
process.waitUntilExit()
print(process.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
