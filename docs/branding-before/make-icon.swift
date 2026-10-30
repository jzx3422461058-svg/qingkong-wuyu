import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let factor = CGFloat(px) / 1024
        let transform = AffineTransform(scale: factor); (transform as NSAffineTransform).concat()
        let box = NSRect(x: 42, y: 42, width: 940, height: 940)
        let path = NSBezierPath(roundedRect: box, xRadius: 220, yRadius: 220)
        NSGradient(colors: [NSColor(red: 0.12, green: 0.29, blue: 0.48, alpha: 1), NSColor(red: 0.37, green: 0.70, blue: 0.84, alpha: 1)])!.draw(in: path, angle: 70)
        NSColor.white.withAlphaComponent(0.22).setStroke(); path.lineWidth = 4; path.stroke()
        let sun = NSBezierPath(ovalIn: NSRect(x: 485, y: 465, width: 250, height: 250))
        NSGradient(colors: [NSColor(red: 1, green: 0.84, blue: 0.50, alpha: 1), .white])!.draw(in: sun, angle: 90)
        NSColor.white.withAlphaComponent(0.94).setFill()
        let cloud = NSBezierPath(roundedRect: NSRect(x: 245, y: 330, width: 530, height: 185), xRadius: 92, yRadius: 92); cloud.fill()
        NSBezierPath(ovalIn: NSRect(x: 325, y: 405, width: 230, height: 230)).fill()
        NSBezierPath(ovalIn: NSRect(x: 485, y: 390, width: 180, height: 180)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name))
    }
}
