import AppKit
import CoreGraphics
import Testing
@testable import TrafficLightsPlus

@Test func finderQuickLookWindowParticipatesInOcclusion() {
    let quickLookFrame = CGRect(x: 250, y: 80, width: 1_080, height: 720)
    let controlFrame = CGRect(x: 400, y: 240, width: 28, height: 28)
    let records = [
        CGWindowRecord(id: 10, pid: 100, layer: 3, bounds: quickLookFrame, title: ""),
        CGWindowRecord(
            id: 11,
            pid: 200,
            layer: 0,
            bounds: CGRect(x: 200, y: 150, width: 680, height: 720),
            title: "Background"
        )
    ]

    #expect(WindowTracker.shouldIncludeWindowRecord(
        layer: 3,
        alpha: 1,
        bounds: quickLookFrame
    ))
    let coveringFrames = WindowTracker.coveringFrames(
        above: 1,
        in: records,
        ignoring: []
    )
    #expect(ControlLayout.unobscuredActions(
        controlFrames: [.close: controlFrame],
        coveringFrames: coveringFrames
    ).isEmpty)
}

@Test func trafficLightPanelsDoNotOccludeTheirOwnTargetWindow() {
    let panelFrame = CGRect(x: 400, y: 240, width: 48, height: 48)
    let records = [
        CGWindowRecord(id: 20, pid: 300, layer: 3, bounds: panelFrame, title: ""),
        CGWindowRecord(
            id: 21,
            pid: 200,
            layer: 0,
            bounds: CGRect(x: 200, y: 150, width: 680, height: 720),
            title: "Target"
        )
    ]

    #expect(WindowTracker.coveringFrames(
        above: 1,
        in: records,
        ignoring: [20]
    ).isEmpty)
}

@Test func systemLayersAndTransparentWindowsAreExcludedFromOcclusion() {
    let regularBounds = CGRect(x: 100, y: 100, width: 500, height: 400)
    let dockWindowLevel = Int(CGWindowLevelForKey(.dockWindow))

    #expect(!WindowTracker.shouldIncludeWindowRecord(
        layer: dockWindowLevel,
        alpha: 1,
        bounds: regularBounds
    ))
    #expect(!WindowTracker.shouldIncludeWindowRecord(
        layer: 3,
        alpha: 0,
        bounds: regularBounds
    ))
}

@Test func elevatedWindowWithStandardControlsCanParticipate() {
    let bounds = CGRect(x: 763, y: 309, width: 657, height: 579)
    let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))

    #expect(!WindowTracker.shouldIncludeWindowRecord(layer: menuLevel, alpha: 1, bounds: bounds))
    #expect(WindowTracker.shouldIncludeWindowRecord(
        layer: menuLevel,
        alpha: 1,
        bounds: bounds,
        allowElevated: true
    ))
    #expect(!WindowTracker.shouldIncludeWindowRecord(
        layer: menuLevel + 1,
        alpha: 1,
        bounds: bounds,
        allowElevated: true
    ))
    #expect(OverlayPanel.level(forTargetLayer: menuLevel).rawValue > menuLevel)
    #expect(OverlayPanel.level(forTargetLayer: 0) == .floating)
}

@Test func differentWindowTitlesNeedOneExactGeometryMatch() {
    let bounds = CGRect(x: 763, y: 309, width: 657, height: 579)
    let clipboard = CGWindowRecord(id: 10, pid: 100, layer: 24, bounds: bounds, title: "剪贴板")
    let other = CGWindowRecord(
        id: 11,
        pid: 100,
        layer: 24,
        bounds: CGRect(x: 300, y: 200, width: 400, height: 300),
        title: "Other"
    )

    #expect(WindowTracker.matchingRecordIndex(
        pid: 100,
        windowID: nil,
        frame: bounds,
        title: "BTT Clipboard Manager",
        records: [clipboard, other]
    ) == 0)
    #expect(WindowTracker.matchingRecordIndex(
        pid: 100,
        windowID: nil,
        frame: bounds,
        title: "BTT Clipboard Manager",
        records: [clipboard, clipboard]
    ) == nil)
    #expect(WindowTracker.matchingRecordIndex(
        pid: 100,
        windowID: nil,
        frame: bounds.offsetBy(dx: 10, dy: 0),
        title: "BTT Clipboard Manager",
        records: [clipboard]
    ) == nil)
}
