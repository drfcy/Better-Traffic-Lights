import Foundation

enum ControlStyle: String, CaseIterable {
    case macOS
    case edgeSquares

    func title(language: AppLanguage) -> String {
        switch self {
        case .macOS: return AppLocalization.string(.appearanceMacOS, language: language)
        case .edgeSquares: return AppLocalization.string(.appearanceEdgeSquares, language: language)
        }
    }
}

enum HiddenTrafficLightRevealMode: String, CaseIterable {
    case group
    case nearest

    func title(language: AppLanguage) -> String {
        switch self {
        case .group: return AppLocalization.string(.revealGroup, language: language)
        case .nearest: return AppLocalization.string(.revealSingle, language: language)
        }
    }
}

final class Preferences: ObservableObject {
    private enum Key {
        static let menuBarIconVisible = "menuBarIconVisible"
        static let hoverMagnificationEnabled = "hoverMagnificationEnabled"
        static let permanentMagnifiedButtonsEnabled = "permanentMagnifiedButtonsEnabled"
        static let singleButtonMagnificationEnabled = "singleButtonMagnificationEnabled"
        static let size = "controlSize"
        static let spacing = "controlSpacingAdjustment"
    }

    private let defaults: UserDefaults

    @Published var language: AppLanguage

    @Published var menuBarIconVisible: Bool {
        didSet { defaults.set(menuBarIconVisible, forKey: Key.menuBarIconVisible) }
    }

    @Published var hoverMagnificationEnabled: Bool {
        didSet { defaults.set(hoverMagnificationEnabled, forKey: Key.hoverMagnificationEnabled) }
    }

    @Published var permanentMagnifiedButtonsEnabled: Bool {
        didSet { defaults.set(permanentMagnifiedButtonsEnabled, forKey: Key.permanentMagnifiedButtonsEnabled) }
    }

    @Published var singleButtonMagnificationEnabled: Bool {
        didSet { defaults.set(singleButtonMagnificationEnabled, forKey: Key.singleButtonMagnificationEnabled) }
    }

    var enabled: Bool { hoverMagnificationEnabled || permanentMagnifiedButtonsEnabled }

    @Published var size: Double {
        didSet { defaults.set(size, forKey: Key.size) }
    }

    @Published var spacing: Double {
        didSet { defaults.set(spacing, forKey: Key.spacing) }
    }

    init(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        self.defaults = defaults
        let systemLanguage = AppLanguage.systemDefault(preferredLanguages: preferredLanguages)
        let initialLanguage = systemLanguage
        defaults.register(defaults: [
            Key.menuBarIconVisible: true,
            Key.hoverMagnificationEnabled: true,
            Key.permanentMagnifiedButtonsEnabled: false,
            Key.singleButtonMagnificationEnabled: false,
            Key.size: ControlLayout.defaultSize,
            Key.spacing: ControlLayout.defaultSpacingAdjustment
        ])
        language = initialLanguage
        defaults.removeObject(forKey: "appLanguage")
        menuBarIconVisible = defaults.bool(forKey: Key.menuBarIconVisible)
        hoverMagnificationEnabled = defaults.bool(forKey: Key.hoverMagnificationEnabled)
        permanentMagnifiedButtonsEnabled = defaults.bool(forKey: Key.permanentMagnifiedButtonsEnabled)
        singleButtonMagnificationEnabled = defaults.bool(forKey: Key.singleButtonMagnificationEnabled)
        let savedSize = defaults.double(forKey: Key.size)
        let preferredSize = abs(savedSize - 28.0) < 0.01 ? ControlLayout.defaultSize : savedSize
        let normalizedSize = Double(ControlLayout.effectiveSize(preferred: preferredSize))
        size = normalizedSize
        defaults.set(normalizedSize, forKey: Key.size)
        spacing = Double(ControlLayout.effectiveSpacingAdjustment(preferred: defaults.double(forKey: Key.spacing)))
    }
}
