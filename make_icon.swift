#!/usr/bin/env swift
//
// Renders an SF Symbol into a full macOS AppIcon.iconset and packs it into
// AppIcon.icns. Re-run after changing `symbolName`.
//
import AppKit

// Initialising the shared app makes AppKit's symbol/drawing APIs available
// in a plain command-line script.
_ = NSApplication.shared

let symbolName = "figure.seated.side"
let iconsetDir = "AppIcon.iconset"

let variants: [(name: String, px: Int)] = [
    ("icon_16x16",    16),  ("icon_16x16@2x",   32),
    ("icon_32x32",    32),  ("icon_32x32@2x",   64),
    ("icon_128x128", 128),  ("icon_128x128@2x", 256),
    ("icon_256x256", 256),  ("icon_256x256@2x", 512),
    ("icon_512x512", 512),  ("icon_512x512@2x", 1024),
]

func makeIcon(px: Int) -> Data? {
    let size = CGFloat(px)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = NSSize(width: size, height: size)

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Rounded-square (squircle-ish) background with transparent margin.
    let margin = size * 0.10
    let rect = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = rect.width * 0.2237
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Gentle gradient derived from the system accent (blue).
    let top = NSColor.systemBlue.blended(withFraction: 0.18, of: .white) ?? .systemBlue
    let bottom = NSColor.systemBlue.blended(withFraction: 0.14, of: .black) ?? .systemBlue
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // White symbol, centered.
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let glyph = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let gs = glyph.size
        let drawRect = NSRect(x: (size - gs.width) / 2, y: (size - gs.height) / 2,
                              width: gs.width, height: gs.height)
        glyph.draw(in: drawRect)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

for v in variants {
    guard let data = makeIcon(px: v.px) else {
        FileHandle.standardError.write("Failed to render \(v.name)\n".data(using: .utf8)!)
        exit(1)
    }
    let path = "\(iconsetDir)/\(v.name).png"
    try! data.write(to: URL(fileURLWithPath: path))
    print("rendered \(path) (\(v.px)px)")
}

print("Done. Now run: iconutil -c icns \(iconsetDir) -o AppIcon.icns")
