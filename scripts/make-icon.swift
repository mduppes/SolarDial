// Renders Resources/AppIcon.icns: a dusk-gradient rounded square with a setting sun.
// Usage: swift scripts/make-icon.swift   (needs /usr/bin/iconutil)
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: the shape fills ~80% of the canvas.
    let inset = size * 0.1
    let tile = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
    shadow.shadowBlurRadius = size * 0.02
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    let sky = NSGradient(colors: [
        NSColor(srgbRed: 0.10, green: 0.11, blue: 0.30, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.24, blue: 0.45, alpha: 1),
        NSColor(srgbRed: 0.99, green: 0.55, blue: 0.25, alpha: 1),
    ], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
    sky.draw(in: tile, angle: -90)

    let horizon = tile.minY + tile.height * 0.34
    let radius = tile.width * 0.24
    let sunCenter = NSPoint(x: tile.midX, y: horizon)
    let glow = NSGradient(colors: [
        NSColor(srgbRed: 1, green: 0.85, blue: 0.45, alpha: 0.55),
        NSColor(srgbRed: 1, green: 0.6, blue: 0.3, alpha: 0),
    ])!
    glow.draw(fromCenter: sunCenter, radius: 0, toCenter: sunCenter, radius: radius * 2.1, options: [])
    let sun = NSGradient(colors: [
        NSColor(srgbRed: 1, green: 0.95, blue: 0.70, alpha: 1),
        NSColor(srgbRed: 1, green: 0.70, blue: 0.30, alpha: 1),
    ])!
    sun.draw(in: NSBezierPath(ovalIn: NSRect(
        x: sunCenter.x - radius, y: sunCenter.y - radius, width: 2 * radius, height: 2 * radius)), angle: -90)

    let ground = NSRect(x: tile.minX, y: tile.minY, width: tile.width, height: horizon - tile.minY)
    NSGradient(colors: [
        NSColor(srgbRed: 0.08, green: 0.07, blue: 0.18, alpha: 1),
        NSColor(srgbRed: 0.20, green: 0.12, blue: 0.28, alpha: 1),
    ])!.draw(in: ground, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}

let output = root.appendingPathComponent("Resources/AppIcon.icns")
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
