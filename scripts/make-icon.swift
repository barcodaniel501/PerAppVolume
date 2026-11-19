// Generates AppBundle/AppIcon.icns. Run with: make icon   (or: swift scripts/make-icon.swift <iconset-dir>)
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // Design "A · Mezclador": drawn on a 100×100 grid (y grows downwards, like SVG)
    // inside the macOS icon tile, which leaves ~10% padding around it.
    let inset = s * 0.098
    let tile = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let u = tile.width / 100
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: tile.minX + x * u, y: tile.maxY - (y + h) * u, width: w * u, height: h * u)
    }

    // Flat indigo background (#534AB7).
    NSColor(srgbRed: 0x53 / 255, green: 0x4A / 255, blue: 0xB7 / 255, alpha: 1).setFill()
    NSBezierPath(roundedRect: tile, xRadius: 22 * u, yRadius: 22 * u).fill()

    // Three vertical faders at different levels.
    let faders: [(x: CGFloat, level: CGFloat)] = [(30, 0.35), (50, 0.80), (70, 0.55)]
    let top: CGFloat = 24, height: CGFloat = 52, width: CGFloat = 7, knobRadius: CGFloat = 8
    for fader in faders {
        let knobY = top + height * (1 - fader.level)
        NSColor(white: 1, alpha: 0.30).setFill()
        NSBezierPath(roundedRect: rect(fader.x - width / 2, top, width, height),
                     xRadius: width / 2 * u, yRadius: width / 2 * u).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: rect(fader.x - width / 2, knobY, width, top + height - knobY),
                     xRadius: width / 2 * u, yRadius: width / 2 * u).fill()
        NSBezierPath(ovalIn: rect(fader.x - knobRadius, knobY - knobRadius, knobRadius * 2, knobRadius * 2)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in entries {
    try! render(px).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("Wrote iconset to \(outDir)")
