import AppKit
import ApplicationServices
import Combine
import OSLog

private func accessibilityObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
    if Thread.isMainThread {
        tracker.handleAccessibilityNotification(element: element, notification: notification as String)
    } else {
        DispatchQueue.main.async {
            tracker.handleAccessibilityNotification(element: element, notification: notification as String)
        }
    }
}

private final class ObservedApplication {
    let pid: pid_t
    let element: AXUIElement
    let observer: AXObserver
    var windowKeys = Set<AXWindowKey>()
    var resolvedNotifications = Set<String>()

    init(pid: pid_t, element: AXUIElement, observer: AXObserver) {
        self.pid = pid
        self.element = element
        self.observer = observer
    }

    deinit {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
}

struct CGWindowRecord {
    let id: CGWindowID
    let pid: pid_t
    let layer: Int
    let bounds: CGRect
    let title: String
}

final class WindowTracker {
    private static let startupRetryDelays: [TimeInterval] = [0.4, 0.7, 1.0, 1.2, 1.5]
    private let preferences: Preferences
    private let logger = Logger(subsystem: "app.trafficlightsplus.mac", category: "window-tracker")
    private var overlays: [AXWindowKey: WindowOverlay] = [:]
    private var applications: [pid_t: ObservedApplication] = [:]
    private var pointerMonitors: [Any] = []
    private var pointerPresentationUpdateScheduled = false
    private var windowReconciliationScheduled = false
    private var pendingWindowRecalibrations = Set<AXWindowKey>()
    private var applicationRefreshScheduled = false
    private var pendingApplicationRefreshPIDs = Set<pid_t>()
    private var pendingNewWindowRetries: [AXWindowKey: Int] = [:]
    private var pendingStartupRetries: [pid_t: Int] = [:]
    private var newWindowRetryScheduled = false
    private var lastActivePID: pid_t?
    private var subscriptions = Set<AnyCancellable>()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var fullscreenRefreshScheduled = false
    private var lastFullscreenRefreshAt = 0.0
    private var lastScanSummary = ""

    init(preferences: Preferences) {
        self.preferences = preferences
        preferences.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.refreshAll() } }
            .store(in: &subscriptions)

        let center = NSWorkspace.shared.notificationCenter
        lastActivePID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                self?.scheduleRefreshAll()
                return
            }
            self.scheduleRefresh(for: [app.processIdentifier])
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self.removeApplication(pid: app.processIdentifier)
            self.refreshVisibility()
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                self?.scheduleRefreshAll()
                return
            }
            let newPID = app.processIdentifier
            let affectedPIDs = Set([self.lastActivePID, newPID].compactMap { $0 })
            self.lastActivePID = newPID
            self.scheduleRefresh(for: affectedPIDs)
        })

        // Pointer events wake hidden controls; there is no continuous position poll.
        let pointerEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: pointerEvents, handler: { [weak self] _ in
            self?.handlePointerMovement()
        }) { pointerMonitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: pointerEvents, handler: { [weak self] event in
            self?.handlePointerMovement()
            return event
        }) { pointerMonitors.append(monitor) }
        refreshAll()
    }

    deinit {
        pointerMonitors.forEach { NSEvent.removeMonitor($0) }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver)
    }

    func refreshAll() {
        guard preferences.enabled, AXIsProcessTrusted() else {
            reportScan("disabled or accessibility permission unavailable")
            overlays.values.forEach { $0.hide() }
            return
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            !$0.isTerminated
                && $0.processIdentifier != ownPID
                && $0.activationPolicy == .regular
                && preferences.enabled
        }
        let activePIDs = Set(runningApps.map(\.processIdentifier))
        var seenWindows = Set<AXWindowKey>()

        for app in runningApps {
            if let appWindows = refreshApplication(app) {
                seenWindows.formUnion(appWindows)
            } else {
                seenWindows.formUnion(applications[app.processIdentifier]?.windowKeys ?? [])
            }
        }

        let observedWindowKeys = applications.values.reduce(into: Set<AXWindowKey>()) {
            $0.formUnion($1.windowKeys)
        }
        let staleKeys = Set(overlays.keys).union(observedWindowKeys).filter { !seenWindows.contains($0) }
        for key in staleKeys {
            removeOverlay(for: key)
        }
        let stalePIDs = applications.keys.filter { !activePIDs.contains($0) }
        for pid in stalePIDs {
            removeApplication(pid: pid)
        }
        reportScan("apps=\(runningApps.count) windows=\(seenWindows.count) overlays=\(overlays.count)")
        if preferences.enabled { refreshVisibility() }
    }

    private func refreshApplication(
        _ app: NSRunningApplication,
        trackNewWindows: Bool = false
    ) -> Set<AXWindowKey>? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 1.0)
        ensureObservedApplication(pid: pid, element: appElement)
        guard let windows: [AXUIElement] = copyAttribute(kAXWindowsAttribute as CFString, from: appElement) else {
            return nil
        }
        if !windows.isEmpty { pendingStartupRetries.removeValue(forKey: pid) }

        var seenWindows = Set<AXWindowKey>()
        for window in windows {
            let key = AXWindowKey(pid: pid, element: window)
            seenWindows.insert(key)
            if applications[pid]?.windowKeys.contains(key) != true {
                registerWindowNotifications(for: key)
            }
            if overlays[key] == nil {
                overlays[key] = WindowOverlay(key: key)
                if trackNewWindows { pendingNewWindowRetries[key] = 0 }
            }
            if overlays[key]?.update(preferences: preferences) != true { overlays[key]?.hide() }
        }

        let staleKeys = Set(overlays.keys).union(applications[pid]?.windowKeys ?? [])
            .filter { $0.pid == pid && !seenWindows.contains($0) }
        for key in staleKeys { removeOverlay(for: key) }
        return seenWindows
    }

    fileprivate func handleAccessibilityNotification(element: AXUIElement, notification: String) {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let key = AXWindowKey(pid: pid, element: element)

        switch notification {
        case kAXMovedNotification:
            // AX window geometry trails the compositor during an interactive drag.
            // Reconcile once per frame instead of querying WindowServer per AX event.
            if preferences.enabled { scheduleWindowReconciliation() }
        case kAXResizedNotification:
            if preferences.enabled, overlays[key] != nil {
                scheduleWindowReconciliation(recalibrate: key)
            } else if preferences.enabled {
                scheduleRefresh(for: [pid])
            }
        case kAXUIElementDestroyedNotification:
            removeOverlay(for: key)
            if preferences.enabled { scheduleWindowReconciliation() }
        case kAXWindowMiniaturizedNotification:
            overlays[key]?.suppressUntilRestored()
            if preferences.enabled { scheduleWindowReconciliation() }
        case kAXWindowDeminiaturizedNotification:
            if preferences.enabled, let overlay = overlays[key] {
                overlay.restoreFromSuppression()
                scheduleWindowReconciliation(recalibrate: key)
            } else if preferences.enabled {
                scheduleRefresh(for: [pid])
            }
        case kAXWindowCreatedNotification:
            // Finder can report the final AX frame while WindowServer is still
            // animating the new window from its icon. Remember the window even
            // if AXWindows does not contain it on the first refresh.
            let role: String? = copyAttribute(kAXRoleAttribute as CFString, from: element)
            if role == kAXWindowRole as String { pendingNewWindowRetries[key] = 0 }
            scheduleRefresh(for: [pid])
        default:
            scheduleRefresh(for: [pid])
        }
    }

    static func shouldUseOverlayMinimize(overlaysEnabled: Bool, overlayAvailable: Bool) -> Bool {
        overlaysEnabled && overlayAvailable
    }

    private func ensureObservedApplication(pid: pid_t, element: AXUIElement) {
        let app: ObservedApplication
        if let existing = applications[pid] {
            app = existing
        } else {
            var observerRef: AXObserver?
            guard AXObserverCreate(pid, accessibilityObserverCallback, &observerRef) == .success,
                  let observer = observerRef else { return }
            app = ObservedApplication(pid: pid, element: element, observer: observer)
            applications[pid] = app
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        for notification in [
            kAXWindowCreatedNotification,
            kAXFocusedWindowChangedNotification,
            kAXApplicationActivatedNotification
        ] {
            let name = notification as String
            guard !app.resolvedNotifications.contains(name) else { continue }
            let status = AXObserverAddNotification(app.observer, app.element, notification as CFString, context)
            if status == .success || status == .notificationAlreadyRegistered || status == .notificationUnsupported {
                app.resolvedNotifications.insert(name)
            }
        }
    }

    private func registerWindowNotifications(for key: AXWindowKey) {
        guard let app = applications[key.pid] else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        for notification in [
            kAXMovedNotification,
            kAXResizedNotification,
            kAXUIElementDestroyedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification
        ] {
            _ = AXObserverAddNotification(app.observer, key.element, notification as CFString, context)
        }
        app.windowKeys.insert(key)
    }

    private func removeOverlay(for key: AXWindowKey) {
        pendingNewWindowRetries.removeValue(forKey: key)
        overlays.removeValue(forKey: key)?.hide()
        guard let app = applications[key.pid] else { return }
        for notification in [
            kAXMovedNotification,
            kAXResizedNotification,
            kAXUIElementDestroyedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification
        ] {
            _ = AXObserverRemoveNotification(app.observer, key.element, notification as CFString)
        }
        app.windowKeys.remove(key)
    }

    private func refreshVisibility() {
        let records = cgWindowRecords()
        let overlayWindowIDs = Set(overlays.values.flatMap(\.panelWindowIDs))
        let mouseLocation = NSEvent.mouseLocation
        var shown = 0

        for overlay in overlays.values {
            guard let targetIndex = matchingRecordIndex(for: overlay, in: records) else {
                // AX and WindowServer can report a move in different frames for one run-loop turn.
                // Keep the previous frame visible instead of flashing it out during the drag.
                continue
            }
            overlay.bind(to: records[targetIndex].id)
            overlay.syncPosition(to: records[targetIndex].bounds)
            let visibleActions = unobscuredActions(
                for: overlay,
                above: targetIndex,
                in: records,
                ignoring: overlayWindowIDs
            )
            overlay.updatePresentation(
                availableActions: visibleActions,
                mouseLocation: mouseLocation,
                hoverMagnificationEnabled: preferences.hoverMagnificationEnabled,
                permanentMagnifiedButtonsEnabled: preferences.permanentMagnifiedButtonsEnabled,
                singleButtonMagnificationEnabled: preferences.singleButtonMagnificationEnabled
            )
            if !overlay.controlFrames.isEmpty {
                pendingNewWindowRetries.removeValue(forKey: overlay.key)
            }
            if !visibleActions.isEmpty { shown += 1 }
        }
        scheduleNewWindowRetryIfNeeded()
        logger.debug("Visible overlays: \(shown, privacy: .public) / \(self.overlays.count, privacy: .public)")
    }

    private func scheduleNewWindowRetryIfNeeded() {
        guard !newWindowRetryScheduled,
              pendingNewWindowRetries.values.contains(where: { $0 < 3 }) else { return }
        newWindowRetryScheduled = true
        // Opening animations briefly give AX and WindowServer different frames.
        // Retry only the affected applications, for at most three short steps.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.newWindowRetryScheduled = false
            guard self.preferences.enabled, AXIsProcessTrusted() else {
                self.pendingNewWindowRetries.removeAll()
                return
            }
            let keys = self.pendingNewWindowRetries.keys.filter {
                (self.pendingNewWindowRetries[$0] ?? 3) < 3
            }
            guard !keys.isEmpty else { return }
            for key in keys {
                self.pendingNewWindowRetries[key, default: 0] += 1
            }
            for pid in Set(keys.map(\.pid)) {
                guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
                    self.removeApplication(pid: pid)
                    continue
                }
                _ = self.refreshApplication(app)
            }
            self.refreshVisibility()
            self.pendingNewWindowRetries = self.pendingNewWindowRetries.filter { $0.value < 3 }
        }
    }

    private func handlePointerMovement() {
        guard preferences.enabled else { return }
        let location = NSEvent.mouseLocation
        if overlays.values.contains(where: { $0.isInFullscreenRevealZone(at: location) }) {
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastFullscreenRefreshAt >= 0.35 {
                lastFullscreenRefreshAt = now
                scheduleFullscreenOverlayRefresh()
            }
        }
        guard overlays.values.contains(where: { $0.needsPointerUpdate(at: location) }) else { return }
        schedulePointerPresentationUpdate()
    }

    private func scheduleFullscreenOverlayRefresh() {
        guard !fullscreenRefreshScheduled else { return }
        fullscreenRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fullscreenRefreshScheduled = false
            guard self.preferences.enabled, AXIsProcessTrusted() else { return }

            // Revealing the menu bar can make native controls appear without
            // changing the app/window list. Refresh only known fullscreen
            // windows here; a full AX scan of every running app is unnecessary.
            let fullscreenOverlays = self.overlays.values.filter(\.isFullScreen)
            guard !fullscreenOverlays.isEmpty else { return }
            for overlay in fullscreenOverlays {
                if overlay.update(preferences: self.preferences, recalibrateNativeCenters: true) != true {
                    overlay.hide()
                }
            }
            self.refreshVisibility()
        }
    }

    private func schedulePointerPresentationUpdate() {
        guard !pointerPresentationUpdateScheduled else { return }
        pointerPresentationUpdateScheduled = true
        // Mouse movement changes hover state, not window geometry or occlusion.
        // Reuse the last accessibility/WindowServer snapshot instead of querying
        // the full on-screen window list for every pointer event.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) { [weak self] in
            guard let self else { return }
            self.pointerPresentationUpdateScheduled = false
            let currentLocation = NSEvent.mouseLocation
            for overlay in self.overlays.values where overlay.needsPointerUpdate(at: currentLocation) {
                overlay.updatePointerPresentation(mouseLocation: currentLocation, preferences: self.preferences)
            }
        }
    }

    private func scheduleWindowReconciliation(recalibrate key: AXWindowKey? = nil) {
        if let key { pendingWindowRecalibrations.insert(key) }
        guard !windowReconciliationScheduled else { return }
        windowReconciliationScheduled = true
        // Resize/move notifications can arrive continuously while a window is
        // being manipulated. Batch AX reads and the global occlusion query.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 30.0) { [weak self] in
            guard let self else { return }
            self.windowReconciliationScheduled = false
            let keys = self.pendingWindowRecalibrations
            self.pendingWindowRecalibrations.removeAll(keepingCapacity: true)
            for key in keys {
                guard let overlay = self.overlays[key] else { continue }
                _ = overlay.update(preferences: self.preferences, recalibrateNativeCenters: true)
            }
            self.refreshVisibility()
        }
    }

    private func unobscuredActions(
        for overlay: WindowOverlay,
        above targetIndex: Int,
        in records: [CGWindowRecord],
        ignoring windowIDs: Set<CGWindowID>
    ) -> Set<WindowAction> {
        if overlay.isFullScreen {
            return Set(overlay.controlFrames.keys)
        }
        let coveringFrames = Self.coveringFrames(
            above: targetIndex,
            in: records,
            ignoring: windowIDs
        )
        return ControlLayout.unobscuredActions(
            controlFrames: overlay.controlFrames,
            coveringFrames: coveringFrames
        )
    }

    static func coveringFrames(
        above targetIndex: Int,
        in records: [CGWindowRecord],
        ignoring windowIDs: Set<CGWindowID>
    ) -> [CGRect] {
        guard records.indices.contains(targetIndex) else { return [] }
        return records[..<targetIndex]
            .filter { !windowIDs.contains($0.id) }
            .map(\.bounds)
    }

    private func matchingRecordIndex(for overlay: WindowOverlay, in records: [CGWindowRecord]) -> Int? {
        // Some apps put standard traffic lights on floating windows above layer 0.
        if let windowID = overlay.cgWindowID,
           let boundIndex = records.firstIndex(where: {
               $0.id == windowID && $0.pid == overlay.key.pid
           }) {
            return boundIndex
        }
        let candidates = records.enumerated().filter {
            $0.element.pid == overlay.key.pid
        }
        return candidates.min { lhs, rhs in
            matchScore(record: lhs.element, overlay: overlay) < matchScore(record: rhs.element, overlay: overlay)
        }.flatMap { matchScore(record: $0.element, overlay: overlay) < 24 ? $0.offset : nil }
    }

    private func matchScore(record: CGWindowRecord, overlay: WindowOverlay) -> CGFloat {
        let frame = overlay.windowFrame
        var score = abs(record.bounds.minX - frame.minX)
            + abs(record.bounds.minY - frame.minY)
            + abs(record.bounds.width - frame.width)
            + abs(record.bounds.height - frame.height)
        if !overlay.title.isEmpty, !record.title.isEmpty, overlay.title != record.title { score += 100 }
        return score
    }

    private func cgWindowRecords() -> [CGWindowRecord] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue,
                  let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let dictionary = info[kCGWindowBounds as String] as? [String: NSNumber],
                  let x = dictionary["X"]?.doubleValue,
                  let y = dictionary["Y"]?.doubleValue,
                  let width = dictionary["Width"]?.doubleValue,
                  let height = dictionary["Height"]?.doubleValue,
                  case let bounds = CGRect(x: x, y: y, width: width, height: height),
                  Self.shouldIncludeWindowRecord(
                      layer: layer,
                      alpha: alpha,
                      bounds: bounds
                  ) else { return nil }
            return CGWindowRecord(
                id: id,
                pid: pid,
                layer: layer,
                bounds: bounds,
                title: info[kCGWindowName as String] as? String ?? ""
            )
        }
    }

    static func shouldIncludeWindowRecord(layer: Int, alpha: Double, bounds: CGRect) -> Bool {
        let dockWindowLevel = Int(CGWindowLevelForKey(.dockWindow))
        return layer >= 0
            && layer < dockWindowLevel
            && alpha > 0.01
            && bounds.width > 40
            && bounds.height > 40
    }

    private func scheduleRefreshAll() {
        DispatchQueue.main.async { [weak self] in self?.refreshAll() }
    }

    private func scheduleRefresh(for pids: Set<pid_t>) {
        pendingApplicationRefreshPIDs.formUnion(pids)
        guard !applicationRefreshScheduled else { return }
        applicationRefreshScheduled = true
        // Window and focus notifications can arrive in bursts. Coalesce them
        // briefly so one interaction does not trigger repeated AX window-list
        // queries and overlay updates on consecutive run-loop turns.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            self.applicationRefreshScheduled = false
            let pids = self.pendingApplicationRefreshPIDs
            self.pendingApplicationRefreshPIDs.removeAll(keepingCapacity: true)
            guard self.preferences.enabled, AXIsProcessTrusted() else { return }
            for pid in pids {
                guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
                    self.removeApplication(pid: pid)
                    continue
                }
                let windows = self.refreshApplication(app, trackNewWindows: true)
                if windows?.isEmpty != false,
                   pid == NSWorkspace.shared.frontmostApplication?.processIdentifier,
                   !self.overlays.keys.contains(where: { $0.pid == pid }) {
                    self.scheduleStartupRetry(for: pid)
                }
            }
            self.reportScan("event apps=\(pids.count) overlays=\(self.overlays.count)")
            self.refreshVisibility()
        }
    }

    private func scheduleStartupRetry(for pid: pid_t) {
        guard pendingStartupRetries[pid] == nil else { return }
        pendingStartupRetries[pid] = 0
        scheduleNextStartupRetry(for: pid)
    }

    private func scheduleNextStartupRetry(for pid: pid_t) {
        guard let attempt = pendingStartupRetries[pid],
              attempt < Self.startupRetryDelays.count else {
            pendingStartupRetries.removeValue(forKey: pid)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.startupRetryDelays[attempt]) { [weak self] in
            guard let self, self.pendingStartupRetries[pid] == attempt else { return }
            guard self.preferences.enabled, AXIsProcessTrusted(),
                  let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
                self.pendingStartupRetries.removeValue(forKey: pid)
                return
            }
            self.pendingStartupRetries[pid] = attempt + 1
            _ = self.refreshApplication(app, trackNewWindows: true)
            self.refreshVisibility()
            if self.pendingStartupRetries[pid] != nil {
                self.scheduleNextStartupRetry(for: pid)
            }
        }
    }

    private func removeApplication(pid: pid_t) {
        pendingStartupRetries.removeValue(forKey: pid)
        let keys = Set(overlays.keys.filter { $0.pid == pid })
            .union(applications[pid]?.windowKeys ?? [])
        for key in keys { removeOverlay(for: key) }
        applications.removeValue(forKey: pid)
    }

    private func reportScan(_ summary: String) {
        guard summary != lastScanSummary else { return }
        lastScanSummary = summary
        logger.notice("\(summary, privacy: .public)")
    }

    private func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? T
    }
}
