import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root
    .appendingPathComponent("mac/Packages/LocalVAppShell/Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("LiveSub.iconset", isDirectory: true)
let previewPNG = resources.appendingPathComponent("LiveSubIcon.png")
let icnsURL = resources.appendingPathComponent("LiveSub.icns")

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:])
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url, options: .atomic)
}

func drawIcon(pixels: Int) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap context")
    }
    rep.size = size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(origin: .zero, size: size)
    let scale = CGFloat(pixels) / 1024
    let corner = 230 * scale

    let bg = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
    bg.addClip()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.035, green: 0.050, blue: 0.075, alpha: 1),
        NSColor(calibratedRed: 0.025, green: 0.105, blue: 0.145, alpha: 1),
        NSColor(calibratedRed: 0.070, green: 0.075, blue: 0.120, alpha: 1)
    ])?.draw(in: rect, angle: -35)

    let glowRect = NSRect(x: 92 * scale, y: 470 * scale, width: 840 * scale, height: 430 * scale)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.00, green: 0.90, blue: 0.78, alpha: 0.45),
        NSColor(calibratedRed: 0.10, green: 0.38, blue: 1.00, alpha: 0.04)
    ])?.draw(in: NSBezierPath(ovalIn: glowRect), angle: 0)

    let lensRect = NSRect(x: 217 * scale, y: 220 * scale, width: 590 * scale, height: 590 * scale)
    let lens = NSBezierPath(ovalIn: lensRect)
    NSColor(calibratedWhite: 1, alpha: 0.08).setFill()
    lens.fill()

    let ring = NSBezierPath(ovalIn: lensRect.insetBy(dx: 28 * scale, dy: 28 * scale))
    ring.lineWidth = 35 * scale
    NSColor(calibratedRed: 0.18, green: 0.96, blue: 0.86, alpha: 0.96).setStroke()
    ring.stroke()

    let inner = NSBezierPath(ovalIn: lensRect.insetBy(dx: 88 * scale, dy: 88 * scale))
    NSColor(calibratedWhite: 1, alpha: 0.06).setFill()
    inner.fill()

    let waveform = NSBezierPath()
    let midY = 515 * scale
    let points: [(CGFloat, CGFloat)] = [
        (300, 0), (340, 36), (385, -70), (430, 105),
        (482, -18), (532, 58), (584, -110), (640, 72), (716, 0)
    ]
    for (index, point) in points.enumerated() {
        let p = NSPoint(x: point.0 * scale, y: midY + point.1 * scale)
        if index == 0 {
            waveform.move(to: p)
        } else {
            waveform.line(to: p)
        }
    }
    waveform.lineCapStyle = .round
    waveform.lineJoinStyle = .round
    waveform.lineWidth = 38 * scale
    NSColor.white.withAlphaComponent(0.96).setStroke()
    waveform.stroke()

    let underline = NSBezierPath()
    underline.move(to: NSPoint(x: 355 * scale, y: 380 * scale))
    underline.curve(
        to: NSPoint(x: 670 * scale, y: 376 * scale),
        controlPoint1: NSPoint(x: 445 * scale, y: 337 * scale),
        controlPoint2: NSPoint(x: 565 * scale, y: 337 * scale)
    )
    underline.lineWidth = 24 * scale
    underline.lineCapStyle = .round
    NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.28, alpha: 0.92).setStroke()
    underline.stroke()

    let sparkle = NSBezierPath()
    sparkle.move(to: NSPoint(x: 730 * scale, y: 720 * scale))
    sparkle.line(to: NSPoint(x: 770 * scale, y: 810 * scale))
    sparkle.line(to: NSPoint(x: 810 * scale, y: 720 * scale))
    sparkle.line(to: NSPoint(x: 900 * scale, y: 680 * scale))
    sparkle.line(to: NSPoint(x: 810 * scale, y: 640 * scale))
    sparkle.line(to: NSPoint(x: 770 * scale, y: 550 * scale))
    sparkle.line(to: NSPoint(x: 730 * scale, y: 640 * scale))
    sparkle.line(to: NSPoint(x: 640 * scale, y: 680 * scale))
    sparkle.close()
    NSColor(calibratedRed: 1.00, green: 0.83, blue: 0.30, alpha: 0.95).setFill()
    sparkle.fill()

    NSColor(calibratedWhite: 1, alpha: 0.11).setStroke()
    bg.lineWidth = 8 * scale
    bg.stroke()

    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: size)
    image.addRepresentation(rep)
    return image
}

let iconEntries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in iconEntries {
    try savePNG(drawIcon(pixels: entry.1), to: iconset.appendingPathComponent(entry.0))
}

try savePNG(drawIcon(pixels: 1024), to: previewPNG)

func bigEndianUInt32(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}

func fourCharacterData(_ value: String) -> Data {
    Data(value.utf8.prefix(4))
}

let icnsEntries: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var body = Data()
for entry in icnsEntries {
    let png = try Data(contentsOf: iconset.appendingPathComponent(entry.1))
    body.append(fourCharacterData(entry.0))
    body.append(bigEndianUInt32(UInt32(png.count + 8)))
    body.append(png)
}

var icns = Data()
icns.append(fourCharacterData("icns"))
icns.append(bigEndianUInt32(UInt32(body.count + 8)))
icns.append(body)
try icns.write(to: icnsURL, options: .atomic)
