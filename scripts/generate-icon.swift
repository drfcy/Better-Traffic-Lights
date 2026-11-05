import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-icon.swift <iconset-directory> <icns-file>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let icnsURL = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
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

func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let s = CGFloat(size)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: s, height: s).fill()

    func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    let tileRect = NSRect(x: s * 0.025, y: s * 0.025, width: s * 0.95, height: s * 0.95)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: s * 0.22, yRadius: s * 0.22)
    NSGradient(colors: [
        color(0.72, 0.48, 1.00), color(0.39, 0.20, 0.98), color(0.16, 0.09, 0.72)
    ])!.draw(in: tile, angle: 130)

    let glowRect = NSRect(x: s * 0.04, y: s * 0.47, width: s * 0.92, height: s * 0.46)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(colors: [color(1, 1, 1, 0.30), color(0.75, 0.67, 1, 0.04), color(0.5, 0.4, 1, 0)])!
        .draw(in: NSBezierPath(ovalIn: glowRect), relativeCenterPosition: NSPoint(x: 0.35, y: -0.15))
    NSGraphicsContext.restoreGraphicsState()

    let capsuleRect = NSRect(x: s * 0.105, y: s * 0.355, width: s * 0.79, height: s * 0.29)
    let capsule = NSBezierPath(roundedRect: capsuleRect, xRadius: capsuleRect.height * 0.5, yRadius: capsuleRect.height * 0.5)
    let capsuleShadow = NSShadow()
    capsuleShadow.shadowColor = color(0.07, 0.03, 0.36, 0.62)
    capsuleShadow.shadowBlurRadius = s * 0.045
    capsuleShadow.shadowOffset = NSSize(width: 0, height: -s * 0.025)
    capsuleShadow.set()
    NSGradient(colors: [color(1, 1, 1, 0.62), color(0.88, 0.91, 1, 0.28), color(0.83, 0.82, 1, 0.22)])!
        .draw(in: capsule, angle: 90)
    NSShadow().set()
    capsule.lineWidth = max(1, s * 0.006)
    color(1, 1, 1, 0.78).setStroke()
    capsule.stroke()

    let insetCapsule = NSBezierPath(roundedRect: capsuleRect.insetBy(dx: s * 0.012, dy: s * 0.012), xRadius: capsuleRect.height * 0.46, yRadius: capsuleRect.height * 0.46)
    insetCapsule.lineWidth = max(1, s * 0.002)
    color(1, 1, 1, 0.28).setStroke()
    insetCapsule.stroke()

    let lights: [(NSColor, NSColor, NSColor, NSColor)] = [
        (color(1.00, 0.55, 0.52), color(1.00, 0.20, 0.20), color(0.73, 0.04, 0.09), color(0.40, 0.02, 0.06)),
        (color(1.00, 0.88, 0.50), color(1.00, 0.67, 0.06), color(0.82, 0.39, 0.00), color(0.43, 0.20, 0.00)),
        (color(0.67, 1.00, 0.62), color(0.22, 0.82, 0.24), color(0.04, 0.52, 0.14), color(0.02, 0.27, 0.08))
    ]
    let diameter = s * 0.176
    let gap = s * 0.045
    let totalWidth = diameter * 3 + gap * 2
    let startX = s * 0.5 - totalWidth * 0.5
    let centerY = capsuleRect.midY

    for (index, light) in lights.enumerated() {
        let rect = NSRect(x: startX + CGFloat(index) * (diameter + gap), y: centerY - diameter * 0.5, width: diameter, height: diameter)
        let circle = NSBezierPath(ovalIn: rect)
        let shadow = NSShadow()
        shadow.shadowColor = light.2.withAlphaComponent(0.78)
        shadow.shadowBlurRadius = s * 0.02
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.008)
        shadow.set()
        NSGradient(colors: [light.0, light.1, light.2])!.draw(in: circle, angle: 90)
        NSShadow().set()

        circle.lineWidth = max(1, s * 0.004)
        color(1, 1, 1, 0.82).setStroke()
        circle.stroke()

        NSGraphicsContext.saveGraphicsState()
        circle.addClip()
        let shine = NSBezierPath(ovalIn: NSRect(x: rect.minX + diameter * 0.08, y: rect.midY + diameter * 0.18, width: diameter * 0.84, height: diameter * 0.62))
        NSGradient(colors: [color(1, 1, 1, 0.68), color(1, 1, 1, 0.12), color(1, 1, 1, 0)])!
            .draw(in: shine, relativeCenterPosition: NSPoint(x: 0.5, y: -0.5))
        NSGraphicsContext.restoreGraphicsState()

        let symbol = NSBezierPath()
        symbol.lineWidth = max(1.5, s * 0.015)
        symbol.lineCapStyle = .round
        symbol.lineJoinStyle = .round
        light.3.setStroke()
        if index == 0 {
            let inset = diameter * 0.31
            symbol.move(to: NSPoint(x: rect.minX + inset, y: rect.minY + inset))
            symbol.line(to: NSPoint(x: rect.maxX - inset, y: rect.maxY - inset))
            symbol.move(to: NSPoint(x: rect.minX + inset, y: rect.maxY - inset))
            symbol.line(to: NSPoint(x: rect.maxX - inset, y: rect.minY + inset))
        } else if index == 1 {
            symbol.move(to: NSPoint(x: rect.minX + diameter * 0.29, y: centerY))
            symbol.line(to: NSPoint(x: rect.maxX - diameter * 0.29, y: centerY))
        } else {
            let inset = diameter * 0.30
            let lowerLeft = NSPoint(x: rect.minX + inset, y: rect.minY + inset)
            let upperRight = NSPoint(x: rect.maxX - inset, y: rect.maxY - inset)
            let arm = diameter * 0.17
            symbol.move(to: NSPoint(x: lowerLeft.x, y: lowerLeft.y + arm))
            symbol.line(to: lowerLeft)
            symbol.line(to: NSPoint(x: lowerLeft.x + arm, y: lowerLeft.y))
            symbol.move(to: NSPoint(x: upperRight.x - arm, y: upperRight.y))
            symbol.line(to: upperRight)
            symbol.line(to: NSPoint(x: upperRight.x, y: upperRight.y - arm))
        }
        symbol.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

var rendered: [Int: Data] = [:]
for (filename, size) in variants {
    let data = try rendered[size] ?? drawIcon(size: size)
    rendered[size] = data
    try data.write(to: outputDirectory.appendingPathComponent(filename))
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

let icnsEntries: [(String, Int)] = [
    ("icp4", 16), ("icp5", 32), ("icp6", 64),
    ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024)
]
var body = Data()
for (type, size) in icnsEntries {
    guard let png = rendered[size], let typeData = type.data(using: .ascii) else { continue }
    body.append(typeData)
    appendUInt32(UInt32(png.count + 8), to: &body)
    body.append(png)
}
var icns = Data("icns".utf8)
appendUInt32(UInt32(body.count + 8), to: &icns)
icns.append(body)
try FileManager.default.createDirectory(at: icnsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try icns.write(to: icnsURL)
