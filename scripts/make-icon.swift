import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let rect = NSRect(x: 48, y: 48, width: 928, height: 928)
let path = NSBezierPath(roundedRect: rect, xRadius: 208, yRadius: 208)
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.28, green: 0.70, blue: 1, alpha: 1), ending: NSColor(calibratedRed: 0.08, green: 0.34, blue: 0.83, alpha: 1))!
gradient.draw(in: path, angle: -60)
let card = NSBezierPath(roundedRect: NSRect(x: 198, y: 216, width: 628, height: 592), xRadius: 54, yRadius: 54)
NSColor.white.withAlphaComponent(0.94).setFill(); card.fill()
NSColor(calibratedRed: 0.75, green: 0.87, blue: 1, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 220, y: 238, width: 156, height: 548), xRadius: 34, yRadius: 34).fill()
for y in [650, 508, 366] {
    NSColor(calibratedRed: 0.13, green: 0.46, blue: 0.91, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 254, y: y, width: 88, height: 88), xRadius: 23, yRadius: 23).fill()
    NSColor(calibratedRed: 0.66, green: 0.73, blue: 0.83, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 424, y: y + 28, width: 286, height: 24), xRadius: 12, yRadius: 12).fill()
}
image.unlockFocus()
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for n in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = n * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(output)/icon_\(n)x\(n)\(suffix).png"))
    }
}
