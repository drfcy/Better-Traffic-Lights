import AppKit
import QuartzCore

enum WindowAction: Int, CaseIterable {
    case close
    case minimize
    case zoom
}

final class OverlayButtonView: NSView {
    private static let officialControlImages = NSCache<NSString, NSImage>()
    private static let artworkPadding: CGFloat = 8
    private static let glossyHighlightGradient: CGGradient? = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.25).cgColor,
            NSColor.white.withAlphaComponent(0.075).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor
        ] as CFArray,
        locations: [0, 0.36, 1]
    )

    let action: WindowAction
    var behavior: ButtonBehavior {
        didSet {
            guard behavior != oldValue else { return }
            updateLocalizedMetadata()
            refreshArtwork()
        }
    }
    var language: AppLanguage = .simplifiedChinese {
        didSet { if language != oldValue { updateLocalizedMetadata() } }
    }
    var style: ControlStyle = .macOS { didSet { if style != oldValue { refreshArtwork() } } }
    var controlSize: CGFloat = 28
    var isControlEnabled = true { didSet { if isControlEnabled != oldValue { refreshArtwork() } } }
    var isWindowActive = false { didSet { if isWindowActive != oldValue { refreshArtwork() } } }
    var isGroupHovered = false
    var actionHandler: ((WindowAction) -> Void)?
    var hoverHandler: ((Bool) -> Void)?
    var pressHandler: ((WindowAction) -> Void)?
    private var glossyGradients: [String: NSGradient] = [:]
    private let artworkLayer = CALayer()
    private var artworkCache: [String: CGImage] = [:]
    private var artworkSize: CGFloat = 0
    private var artworkScale: CGFloat = 2
    private var visualRect = NSRect.zero

    var isColorVisible: Bool { isWindowActive || isGroupHovered || isHovered || isPressed }
    var isPointerHighlightVisible: Bool { isGroupHovered || isHovered || isPressed }

    func setPointerInside(_ inside: Bool) {
        guard inside != isHovered else { return }
        isHovered = inside
        if !inside { isPressed = false }
        hoverHandler?(inside)
        refreshArtwork()
    }

    func resetInteractionState() {
        guard isHovered || isPressed || isGroupHovered else { return }
        let wasHovered = isHovered
        isHovered = false
        isPressed = false
        isGroupHovered = false
        if wasHovered { hoverHandler?(false) }
        refreshArtwork()
    }

    private var isHovered = false
    private var isPressed = false

    init(action: WindowAction) {
        self.action = action
        behavior = ButtonBehavior.defaultBehavior(for: action)
        super.init(frame: .zero)
        wantsLayer = true
        artworkLayer.contentsGravity = .resize
        artworkLayer.masksToBounds = false
        layer?.addSublayer(artworkLayer)
        setAccessibilityRole(.button)
        updateLocalizedMetadata()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    func configureArtwork(maximumSide: CGFloat) {
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        guard abs(artworkSize - maximumSide) > 0.01 || artworkScale != scale else { return }
        artworkSize = maximumSide
        artworkScale = scale
        artworkCache.removeAll(keepingCapacity: true)
        artworkLayer.contentsScale = scale
        refreshArtwork()
    }

    func setVisualRect(_ rect: NSRect) {
        guard visualRect != rect else { return }
        visualRect = rect
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artworkLayer.frame = rect.insetBy(
            dx: -Self.artworkPadding,
            dy: -Self.artworkPadding
        )
        CATransaction.commit()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, visualRect.contains(convert(point, from: superview)) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        pressHandler?(action)
        guard isControlEnabled else { NSSound.beep(); return }
        isPressed = true
        refreshArtwork()
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            isPressed = false
            refreshArtwork()
        }
        guard isPressed, isControlEnabled,
              visualRect.contains(convert(event.locationInWindow, from: nil)) else { return }
        // Consume the press before invoking code that can hide this panel.
        isPressed = false
        actionHandler?(action)
    }

    override func draw(_ dirtyRect: NSRect) {}

    private func paintArtwork(in rect: NSRect) {
        let actionColor = color(for: action)
        let idleColor = inactiveControlColor()
        let fillColor: NSColor

        if !isControlEnabled {
            fillColor = idleColor
        } else if isPressed {
            fillColor = actionColor.blended(withFraction: 0.16, of: .black) ?? actionColor
        } else if isHovered {
            fillColor = actionColor.blended(withFraction: 0.06, of: .black) ?? actionColor
        } else if isWindowActive || isGroupHovered {
            fillColor = actionColor
        } else {
            fillColor = actionColor
        }

        let path = style == .macOS
            ? NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            : edgeSquarePath(in: rect)
        let drewOfficialMaterial = style == .macOS && isControlEnabled && drawOfficialControl(in: rect)
        if drewOfficialMaterial {
            // Apple only provides the standard/idle component. Keep the app's
            // existing hover and press motion, while reusing this surface.
        } else if style == .macOS, isControlEnabled {
            drawNativeControl(in: rect, path: path, color: fillColor)
        } else {
            fillColor.setFill()
            path.fill()
        }

        if style == .macOS && !drewOfficialMaterial {
            (color(for: action).blended(withFraction: 0.22, of: .black) ?? color(for: action))
                .withAlphaComponent(0.38).setStroke()
            path.lineWidth = 0.65
            path.stroke()
        }

        if !drewOfficialMaterial { drawSymbol(in: rect) }
    }

    /// Draw a high-resolution render of the macOS 27 UI Kit composite SVG.
    /// AppKit's SVG renderer does not support all filters used by these assets.
    private func drawOfficialControl(in rect: NSRect) -> Bool {
        let appearanceName = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? "dark" : "light"
        let actionName: String
        switch action {
        case .close: actionName = "close"
        case .minimize: actionName = "minimize"
        case .zoom: actionName = "zoom"
        }
        let assetName = actionName
        let key = "\(appearanceName)-\(assetName)"
        let cacheKey = key as NSString
        let image: NSImage
        if let cached = Self.officialControlImages.object(forKey: cacheKey) {
            image = cached
        } else {
            guard let url = Bundle.module.url(
                forResource: assetName,
                withExtension: "png",
                subdirectory: "WindowControlsComposite/\(appearanceName)"
            ), let loaded = NSImage(contentsOf: url) else { return false }
            image = loaded
            Self.officialControlImages.setObject(loaded, forKey: cacheKey)
        }

        // The SVG viewBox is 20 pt wide, while its colored circle is 14 pt.
        // Scale that circle to the existing button bounds and center the
        // transparent shadow margin around it.
        let circleRect = rect.insetBy(dx: 1, dy: 1)
        let imageSide = min(circleRect.width, circleRect.height) * (20.0 / 14.0)
        let imageRect = NSRect(
            x: circleRect.midX - imageSide / 2,
            y: circleRect.midY - imageSide / 2,
            width: imageSide,
            height: imageSide
        )
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
        return true
    }

    private func refreshArtwork() {
        guard artworkSize > 2 else { return }
        let appearance = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])?.rawValue ?? "aqua"
        let windowState = isWindowActive ? "active" : "inactive"
        let state = isPressed ? "pressed" : (isHovered ? "hovered" : "normal")
        let key = "\(style.rawValue)|\(behavior)|\(isControlEnabled)|\(appearance)|\(windowState)|\(state)"
        let image: CGImage
        if let cached = artworkCache[key] {
            image = cached
        } else {
            guard let rendered = renderArtworkBitmap() else { return }
            artworkCache[key] = rendered
            image = rendered
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artworkLayer.contents = image
        CATransaction.commit()
    }

    private func renderArtworkBitmap() -> CGImage? {
        let canvasSize = artworkSize + Self.artworkPadding * 2
        let pixels = Int(ceil(canvasSize * artworkScale))
        guard pixels > 0,
              let bitmap = NSBitmapImageRep(
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
              ),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = NSSize(width: canvasSize, height: canvasSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cgContext = context.cgContext
        cgContext.translateBy(x: 0, y: CGFloat(pixels))
        cgContext.scaleBy(x: artworkScale, y: -artworkScale)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            paintArtwork(in: NSRect(
                x: Self.artworkPadding,
                y: Self.artworkPadding,
                width: artworkSize,
                height: artworkSize
            ))
        }
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }

    private func drawNativeControl(in rect: NSRect, path: NSBezierPath, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(0.25)
        shadow.shadowBlurRadius = max(0.9, rect.width * 0.07)
        shadow.shadowOffset = NSSize(width: 0, height: -rect.height * 0.025)
        shadow.set()
        color.setFill()
        path.fill()
        NSShadow().set()
        NSGraphicsContext.restoreGraphicsState()

        let state = isPressed ? "pressed" : (isHovered ? "hovered" : "normal")
        let gradientKey = "\(action.rawValue)-\(state)"
        let gradient: NSGradient
        if let cached = glossyGradients[gradientKey] {
            gradient = cached
        } else {
            let top = color.blended(withFraction: isPressed ? 0.04 : 0.12, of: .white) ?? color
            let bottom = color.blended(withFraction: isPressed ? 0.09 : 0.055, of: .black) ?? color
            let created = NSGradient(colors: [top, color, bottom])
                ?? NSGradient(starting: top, ending: bottom)!
            glossyGradients[gradientKey] = created
            gradient = created
        }
        gradient.draw(in: path, angle: 90)

        path.lineWidth = max(0.55, rect.width * 0.014)
        NSColor.white.withAlphaComponent(0.42).setStroke()
        path.stroke()

        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        if let context = NSGraphicsContext.current?.cgContext,
           let gradient = Self.glossyHighlightGradient {
            let center = CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.24)
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: rect.width * 0.54,
                options: []
            )
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func updateLocalizedMetadata() {
        let title = behavior.title(language: language)
        setAccessibilityLabel(title)
    }

    private func edgeSquarePath(in rect: NSRect) -> NSBezierPath {
        let radius = min(8, rect.height * 0.22)
        let path = NSBezierPath()

        switch action {
        case .close:
            path.move(to: NSPoint(x: rect.minX + radius, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX, y: rect.minY + radius))
            path.curve(
                to: NSPoint(x: rect.minX + radius, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX, y: rect.minY + radius * 0.45),
                controlPoint2: NSPoint(x: rect.minX + radius * 0.45, y: rect.minY)
            )
        case .minimize, .zoom:
            path.appendRect(rect)
        }
        path.close()
        return path
    }

    private func color(for action: WindowAction) -> NSColor {
        switch action {
        case .close:
            return NSColor(srgbRed: 1.0, green: 0.37255, blue: 0.34118, alpha: 1.0)
        case .minimize:
            return NSColor(srgbRed: 0.99608, green: 0.73725, blue: 0.18039, alpha: 1.0)
        case .zoom:
            return NSColor(srgbRed: 0.15686, green: 0.78431, blue: 0.25098, alpha: 1.0)
        }
    }

    private func inactiveControlColor() -> NSColor {
        switch effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
        case .darkAqua:
            // Sampled from the center of a native inactive traffic-light button.
            return NSColor(srgbRed: 0.37647, green: 0.37647, blue: 0.37255, alpha: 1.0)
        default:
            return NSColor(srgbRed: 0.74510, green: 0.74510, blue: 0.73725, alpha: 1.0)
        }
    }

    private func drawSymbol(in rect: NSRect) {
        guard let symbolRect = Self.symbolRect(in: rect, style: style) else { return }
        let visualSize = min(rect.width, rect.height)
        let path = NSBezierPath()
        path.lineWidth = max(1.0, visualSize * 0.073)
        path.lineCapStyle = .round

        NSColor(srgbRed: 0.16, green: 0.12, blue: 0.12, alpha: isControlEnabled ? 0.86 : 0.36).setStroke()

        switch behavior {
        case .closeWindow, .quitApplication:
            path.move(to: NSPoint(x: symbolRect.minX, y: symbolRect.minY))
            path.line(to: NSPoint(x: symbolRect.maxX, y: symbolRect.maxY))
            path.move(to: NSPoint(x: symbolRect.maxX, y: symbolRect.minY))
            path.line(to: NSPoint(x: symbolRect.minX, y: symbolRect.maxY))
        case .minimizeWindow, .hideApplication:
            path.move(to: NSPoint(x: symbolRect.minX, y: symbolRect.midY))
            path.line(to: NSPoint(x: symbolRect.maxX, y: symbolRect.midY))
        case .zoomWindow:
            let inset = min(symbolRect.width, symbolRect.height) * 0.08
            let lowerLeft = NSPoint(x: symbolRect.minX + inset, y: symbolRect.minY + inset)
            let upperRight = NSPoint(x: symbolRect.maxX - inset, y: symbolRect.maxY - inset)
            let head = min(symbolRect.width, symbolRect.height) * 0.25
            path.move(to: lowerLeft)
            path.line(to: upperRight)
            path.move(to: NSPoint(x: lowerLeft.x + head, y: lowerLeft.y))
            path.line(to: lowerLeft)
            path.line(to: NSPoint(x: lowerLeft.x, y: lowerLeft.y + head))
            path.move(to: NSPoint(x: upperRight.x - head, y: upperRight.y))
            path.line(to: upperRight)
            path.line(to: NSPoint(x: upperRight.x, y: upperRight.y - head))
        case .doNothing:
            return
        }
        path.stroke()
    }

    static func symbolRect(in rect: NSRect, style: ControlStyle) -> NSRect? {
        let visualSize = min(rect.width, rect.height)
        guard visualSize.isFinite, visualSize > 2,
              rect.minX.isFinite, rect.minY.isFinite else { return nil }
        let inset = visualSize * (style == .macOS ? 0.31 : 0.32)
        let symbolRect = rect.insetBy(dx: inset, dy: inset)
        guard !symbolRect.isNull,
              symbolRect.minX.isFinite, symbolRect.minY.isFinite,
              symbolRect.width.isFinite, symbolRect.height.isFinite,
              symbolRect.width > 0, symbolRect.height > 0 else { return nil }
        return symbolRect
    }
}

final class OverlayPanel: NSPanel {
    static func level(forTargetLayer targetLayer: Int) -> NSWindow.Level {
        let floatingLevel = NSWindow.Level.floating.rawValue
        let statusLevel = NSWindow.Level.statusBar.rawValue
        return NSWindow.Level(rawValue: min(max(floatingLevel, targetLayer + 1), statusLevel))
    }

    func setTargetLayer(_ targetLayer: Int) {
        let desiredLevel = Self.level(forTargetLayer: targetLayer)
        if level != desiredLevel { level = desiredLevel }
    }

    let overlayViews: [WindowAction: OverlayButtonView]

    init() {
        overlayViews = Dictionary(uniqueKeysWithValues: WindowAction.allCases.map {
            ($0, OverlayButtonView(action: $0))
        })
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: .zero)
        contentView = container
        for action in WindowAction.allCases {
            if let button = overlayViews[action] {
                button.isHidden = true
                container.addSubview(button)
            }
        }
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        // Pointer hover is handled by WindowTracker's coalesced global/local
        // monitors; AppKit tracking areas caused expensive enter/exit churn.
        acceptsMouseMovedEvents = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }
}
