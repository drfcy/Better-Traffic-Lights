import AppKit
import SwiftUI
import OSLog
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum MenuTag {
        static let settings = 99
        static let quit = 103
    }

    private let logger = Logger(subsystem: "app.trafficlightsplus.mac", category: "lifecycle")
    private let preferences = Preferences()
    private var tracker: WindowTracker?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var menuBarPreferenceObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("Application finished launching")
        NSApp.setActivationPolicy(.accessory)
        tracker = WindowTracker(preferences: preferences)
        menuBarPreferenceObserver = preferences.$menuBarIconVisible
            .removeDuplicates()
            .sink { [weak self] isVisible in
                self?.setStatusItemVisible(isVisible)
            }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func setStatusItemVisible(_ isVisible: Bool) {
        guard isVisible else {
            if let statusItem {
                statusItem.isVisible = false
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = Self.menuBarTrafficLightImage()
        image.isTemplate = true
        image.accessibilityDescription = "Better Traffic Lights"
        item.button?.image = image
        item.button?.setAccessibilityLabel("Better Traffic Lights")
        item.isVisible = true

        let menu = NSMenu()
        menu.delegate = self
        let settingsItem = menu.addItem(
            withTitle: localized(.menuSettings),
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.tag = MenuTag.settings
        settingsItem.target = self
        menu.addItem(NSMenuItem.separator())
        let quitItem = menu.addItem(
            withTitle: localized(.menuQuit),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.tag = MenuTag.quit
        quitItem.target = self
        item.menu = menu
        statusItem = item
    }

    private static func menuBarTrafficLightImage() -> NSImage {
        NSImage(size: NSSize(width: 18, height: 22), flipped: false) { rect in
            let housing = NSRect(x: 5.1, y: 3.25, width: 7.8, height: 15.5)
            let body = NSBezierPath(roundedRect: housing, xRadius: 3.9, yRadius: 3.9)
            NSColor.black.setStroke()
            body.lineWidth = 0.7
            body.stroke()

            let lampSize: CGFloat = 3.6
            for offset: CGFloat in [10.9, 6.05, 1.2] {
                let lamp = NSRect(
                    x: housing.midX - lampSize / 2,
                    y: housing.minY + offset,
                    width: lampSize,
                    height: lampSize
                )
                NSColor.black.setFill()
                NSBezierPath(ovalIn: lamp).fill()
            }
            return true
        }
    }

    @objc private func showSettings() {
        logger.notice("Showing settings window")
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(preferences: preferences))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 470, height: 650),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = controller
            window.setContentSize(NSSize(width: 470, height: 650))
            window.title = localized(.settingsWindowTitle)
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        let changedPolicy = NSApp.setActivationPolicy(.regular)
        logger.notice("Regular activation policy result: \(changedPolicy, privacy: .public)")
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func localized(_ key: AppString, language: AppLanguage? = nil) -> String {
        AppLocalization.string(key, language: language ?? preferences.language)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: MenuTag.settings)?.title = localized(.menuSettings)
        menu.item(withTag: MenuTag.quit)?.title = localized(.menuQuit)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else { return }
        logger.notice("Settings window closed; returning to menu bar mode")
        NSApp.setActivationPolicy(.accessory)
    }
}
