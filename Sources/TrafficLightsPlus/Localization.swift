import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static func systemDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let preferredLanguage = preferredLanguages.first?.lowercased() else { return .english }
        return preferredLanguage.hasPrefix("zh") ? .simplifiedChinese : .english
    }
}

enum AppString: String, CaseIterable {
    case settingsWindowTitle = "settings.window.title"
    case settingsSubtitle = "settings.subtitle"
    case settingsBehavior = "settings.section.behavior"
    case settingsControls = "settings.section.controls"
    case settingsGeneral = "settings.section.general"
    case settingsUpdates = "settings.section.updates"
    case languageLabel = "language.label"
    case menuBarIconVisible = "menu_bar_icon.visible"
    case menuBarIconVisibleHelp = "menu_bar_icon.visible.help"
    case menuBarIconDescription = "menu_bar_icon.description"
    case overlayEnabled = "overlay.enabled"
    case hoverMagnification = "overlay.hover_magnification"
    case permanentMagnifiedButtons = "overlay.permanent_magnified_buttons"
    case permanentMagnifiedDescription = "overlay.permanent_magnified_buttons.description"
    case singleButtonMagnification = "overlay.single_button_magnification"
    case singleButtonMagnificationHelp = "overlay.single_button_magnification.help"
    case singleButtonMagnificationDescription = "overlay.single_button_magnification.description"
    case hoverMagnificationDescription = "overlay.hover_magnification.description"
    case livePreview = "preview.title"
    case appearance = "appearance.title"
    case appearanceMacOS = "appearance.macos"
    case appearanceEdgeSquares = "appearance.edge_squares"
    case buttonSize = "button.size"
    case restoreDefault = "button.restore_default"
    case buttonSpacing = "button.spacing"
    case restoreSystemSpacing = "button.restore_system_spacing"
    case systemSpacing = "button.spacing.system"
    case hiddenTrafficLights = "hidden_traffic_lights.title"
    case revealMode = "hidden_traffic_lights.reveal_mode"
    case revealGroup = "hidden_traffic_lights.group"
    case revealSingle = "hidden_traffic_lights.single"
    case fullScreenInDevelopment = "fullscreen.in_development"
    case dockClickMinimize = "dock_click.title"
    case dockClickMinimizeHelp = "dock_click.help"
    case stageManagerCloseButtons = "stage_manager_close.title"
    case stageManagerCloseButtonsHelp = "stage_manager_close.help"
    case stageManagerCloseAction = "stage_manager_close.action"
    case softwareUpdates = "software_updates.title"
    case automaticallyCheckForUpdates = "software_updates.automatic_check"
    case automaticallyDownloadUpdates = "software_updates.automatic_download"
    case checkForUpdates = "software_updates.check_now"
    case updatesUnavailable = "software_updates.unavailable"
    case checkForUpdatesDescription = "software_updates.check.description"
    case updateAlertTitle = "software_updates.alert.title"
    case updateCheckInProgress = "software_updates.checking"
    case updateAvailable = "software_updates.available"
    case updateUpToDate = "software_updates.up_to_date"
    case updateCheckFailed = "software_updates.check_failed"
    case openRelease = "software_updates.open_release"
    case about = "about.title"
    case aboutDescription = "about.description"
    case aboutVersion = "about.version"
    case aboutGitHub = "about.github"
    case buttonActions = "button_actions.title"
    case redButton = "button.red"
    case yellowButton = "button.yellow"
    case greenButton = "button.green"
    case behaviorCloseWindow = "behavior.close_window"
    case behaviorQuitApplication = "behavior.quit_application"
    case behaviorMinimizeWindow = "behavior.minimize_window"
    case behaviorZoomWindow = "behavior.zoom_window"
    case behaviorHideApplication = "behavior.hide_application"
    case behaviorDoNothing = "behavior.do_nothing"
    case quitOnCloseEnabled = "quit_on_close.enabled"
    case quitOnCloseHelp = "quit_on_close.help"
    case quitOnCloseApplications = "quit_on_close.title"
    case addApplication = "quit_on_close.add"
    case addApplicationAccessibility = "quit_on_close.add.accessibility"
    case noApplicationsAdded = "quit_on_close.empty"
    case removeApplication = "quit_on_close.remove"
    case removeApplicationAccessibility = "quit_on_close.remove.accessibility"
    case accessibilityGranted = "accessibility.granted"
    case accessibilityRequired = "accessibility.required"
    case openAccessibilitySettings = "accessibility.open_settings"
    case accessibilityInstructions = "accessibility.instructions"
    case chooseQuitOnCloseApplication = "quit_on_close.picker.title"
    case addPickerPrompt = "quit_on_close.picker.prompt"
    case cannotAddApplication = "quit_on_close.error.title"
    case missingBundleIdentifier = "quit_on_close.error.missing_bundle_identifier"
    case ok = "common.ok"
    case menuSettings = "menu.settings"
    case menuEnableOverlays = "menu.enable_overlays"
    case menuEnableDockClick = "menu.enable_dock_click"
    case menuQuit = "menu.quit"
}

enum AppLocalization {
    static func string(
        _ key: AppString,
        language: AppLanguage,
        arguments: [CVarArg] = []
    ) -> String {
        let format = table(for: language)[key.rawValue] ?? key.rawValue
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: language.locale, arguments: arguments)
    }

    static func missingKeys(for language: AppLanguage) -> [AppString] {
        AppString.allCases.filter {
            string($0, language: language) == $0.rawValue
        }
    }

    private static let tables: [AppLanguage: [String: String]] = Dictionary(
        uniqueKeysWithValues: AppLanguage.allCases.map { language in
            (language, loadTable(for: language))
        }
    )

    private static func table(for language: AppLanguage) -> [String: String] {
        tables[language] ?? [:]
    }

    private static func loadTable(for language: AppLanguage) -> [String: String] {
        guard let url = packagedLocalizationURL(for: language) ?? Bundle.module.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: language.rawValue
        ),
        let dictionary = NSDictionary(contentsOf: url) as? [String: String] else {
            return [:]
        }
        return dictionary
    }

    private static func packagedLocalizationURL(for language: AppLanguage) -> URL? {
        guard let resourcesURL = Bundle.main.resourceURL else { return nil }
        let url = resourcesURL
            .appendingPathComponent("\(language.rawValue).lproj", isDirectory: true)
            .appendingPathComponent("Localizable.strings")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
