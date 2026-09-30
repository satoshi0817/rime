import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
let base = NSBezierPath(roundedRect: bounds.insetBy(dx: 58, dy: 58), xRadius: 208, yRadius: 208)
NSGradient(colors: [
    NSColor(srgbRed: 0.16, green: 0.34, blue: 0.73, alpha: 1),
    NSColor(srgbRed: 0.32, green: 0.59, blue: 0.91, alpha: 1),
])!.draw(in: base, angle: -35)

for (y, width, opacity) in [(690.0, 570.0, 0.95), (508.0, 440.0, 0.82), (326.0, 315.0, 0.68)] {
    NSColor.white.withAlphaComponent(opacity).setFill()
    NSBezierPath(roundedRect: NSRect(x: 226, y: y - 35, width: width, height: 70), xRadius: 35, yRadius: 35).fill()
}
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
let iconset = URL(fileURLWithPath: "build/Rime.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let master = iconset.appendingPathComponent("master.png")
try png.write(to: master)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (filename, pixels) in variants {
    let resized = NSImage(size: NSSize(width: pixels, height: pixels))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    resized.unlockFocus()
    guard let data = resized.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Resize failed") }
    let output = iconset.appendingPathComponent(filename)
    try png.write(to: output)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = ["-z", String(pixels), String(pixels), output.path]
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { fatalError("Resize failed") }
}
try FileManager.default.removeItem(at: master)
