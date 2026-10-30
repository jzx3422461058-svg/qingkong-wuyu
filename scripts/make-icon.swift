import AppKit

// Render the generated portrait into standard macOS rounded-square icon sizes.
// The bundled artwork is local; packaging never calls a network service.
guard CommandLine.arguments.count == 3 else { fatalError("Usage: make-icon.swift output.iconset portrait.png") }
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
guard let portrait = NSImage(contentsOfFile: CommandLine.arguments[2]) else { fatalError("Portrait asset is missing") }
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        let factor = CGFloat(px) / 1024
        let transform = AffineTransform(scale: factor); (transform as NSAffineTransform).concat()
        let box = NSRect(x: 42, y: 42, width: 940, height: 940)
        let clip = NSBezierPath(roundedRect: box, xRadius: 210, yRadius: 210)
        NSGraphicsContext.saveGraphicsState(); clip.addClip()
        let side = min(portrait.size.width, portrait.size.height)
        let crop = NSRect(x: (portrait.size.width - side) / 2, y: (portrait.size.height - side) / 2, width: side, height: side)
        portrait.draw(in: box, from: crop, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.42).setStroke(); clip.lineWidth = 3; clip.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name))
    }
}
