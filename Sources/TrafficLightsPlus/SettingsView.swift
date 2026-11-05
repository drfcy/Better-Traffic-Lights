import AppKit
import ApplicationServices
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @State private var accessibilityGranted = AXIsProcessTrusted()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                header
                magnificationSection
                controlsSection
                generalSection
                updatesAboutSection
                permissionStatus
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .frame(width: 490, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Better Traffic Lights")
                    .font(.system(size: 19, weight: .semibold))
                Text(localized(.settingsSubtitle))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 1)
    }

    private var magnificationSection: some View {
        settingsSection(.settingsBehavior) {
            VStack(spacing: 0) {
                toggleRow(
                    .permanentMagnifiedButtons,
                    detail: .permanentMagnifiedDescription,
                    isOn: $preferences.permanentMagnifiedButtonsEnabled
                )
                rowDivider
                toggleRow(
                    .hoverMagnification,
                    detail: .hoverMagnificationDescription,
                    isOn: $preferences.hoverMagnificationEnabled
                )
                rowDivider
                toggleRow(
                    .singleButtonMagnification,
                    detail: .singleButtonMagnificationDescription,
                    isOn: $preferences.singleButtonMagnificationEnabled,
                    help: localized(.singleButtonMagnificationHelp),
                    disabled: !preferences.hoverMagnificationEnabled,
                    indented: true
                )
            }
            .padding(.horizontal, 14)
        }
    }

    private var controlsSection: some View {
        settingsSection(.settingsControls) {
            VStack(spacing: 0) {
                sliderControl(
                    .buttonSize,
                    symbol: "circle.circle",
                    valueText: "\(Int(preferences.size)) pt",
                    value: $preferences.size,
                    range: ControlLayout.sizeRange,
                    step: 1,
                    resetTitle: .restoreDefault,
                    resetValue: ControlLayout.defaultSize
                )
                rowDivider
                sliderControl(
                    .buttonSpacing,
                    symbol: "arrow.left.and.right",
                    valueText: spacingDescription,
                    value: $preferences.spacing,
                    range: ControlLayout.spacingAdjustmentRange,
                    step: 1,
                    resetTitle: .restoreSystemSpacing,
                    resetValue: ControlLayout.defaultSpacingAdjustment
                )
            }
            .padding(.horizontal, 14)
        }
    }

    private var generalSection: some View {
        settingsSection(.settingsGeneral) {
            toggleRow(
                .menuBarIconVisible,
                detail: .menuBarIconDescription,
                isOn: $preferences.menuBarIconVisible,
                help: localized(.menuBarIconVisibleHelp)
            )
            .padding(.horizontal, 14)
        }
    }

    private var updatesAboutSection: some View {
        settingsSection(.settingsUpdates) {
            VStack(spacing: 0) {
                settingsActionRow(
                    .checkForUpdates,
                    detail: .checkForUpdatesDescription,
                    symbol: "arrow.clockwise.circle",
                    action: checkForUpdates
                )
                rowDivider
                settingsActionRow(
                    .about,
                    detail: .aboutDescription,
                    symbol: "info.circle",
                    action: showAbout
                )
            }
            .padding(.horizontal, 14)
        }
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 1)
            .opacity(0.7)
    }

    private func settingsSection<Content: View>(
        _ title: AppString,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(localized(title))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 3)

            VStack(alignment: .leading, spacing: 0, content: content)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.primary.opacity(0.055), lineWidth: 1)
                }
        }
    }

    private func toggleRow(
        _ title: AppString,
        detail: AppString,
        isOn: Binding<Bool>,
        help: String? = nil,
        disabled: Bool = false,
        indented: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            if indented {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 2, height: 28)
                    .padding(.leading, 5)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(title))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(disabled ? .secondary : .primary)
                Text(localized(detail))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(disabled)
                .help(help ?? localized(title))
                .accessibilityLabel(localized(title))
        }
        .frame(minHeight: indented ? 47 : 51)
        .padding(.leading, indented ? 7 : 0)
    }

    private func sliderControl(
        _ title: AppString,
        symbol: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        resetTitle: AppString,
        resetValue: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 17)
                Text(localized(title))
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 6)
                Text(valueText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
                Button {
                    value.wrappedValue = resetValue
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(localized(resetTitle))
                .accessibilityLabel(localized(resetTitle))
            }
            SettingsSlider(value: value, range: range, step: step)
                .accessibilityLabel(localized(title))
                .accessibilityValue(valueText)
        }
        .padding(.vertical, 10)
    }

    private func settingsActionRow(
        _ title: AppString,
        detail: AppString,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 17)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(title))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(localized(detail))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized(title))
    }

    private func checkForUpdates() {
        guard let url = URL(string: "https://github.com/drfcy/better-traffic-lights/releases/latest") else { return }
        NSWorkspace.shared.open(url)
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    private var permissionStatus: some View {
        HStack(spacing: 9) {
            Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(accessibilityGranted ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(accessibilityGranted ? .accessibilityGranted : .accessibilityRequired))
                    .font(.system(size: 12, weight: .medium))
                if !accessibilityGranted {
                    Text(localized(.accessibilityInstructions))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            if !accessibilityGranted {
                Button(localized(.openAccessibilitySettings)) { requestAccessibility() }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, accessibilityGranted ? 10 : 12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var spacingDescription: String {
        let spacing = Int(preferences.spacing)
        if spacing == 0 { return localized(.systemSpacing) }
        return spacing > 0 ? "+\(spacing) pt" : "\(spacing) pt"
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func localized(_ key: AppString) -> String {
        AppLocalization.string(key, language: preferences.language)
    }
}

private struct SettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private let thumbWidth: CGFloat = 24
    private let thumbHeight: CGFloat = 16
    private let trackHeight: CGFloat = 4

    private var fraction: CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        return CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        GeometryReader { geometry in
            let usableWidth = max(0, geometry.size.width - thumbWidth)
            let normalizedFraction = min(max(fraction, 0), 1)
            let thumbX = thumbWidth / 2 + usableWidth * normalizedFraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.19))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbWidth / 2)

                Capsule()
                    .fill(Color.accentColor.opacity(0.78))
                    .frame(width: usableWidth * normalizedFraction, height: trackHeight)
                    .padding(.leading, thumbWidth / 2)

                sliderThumb
                    .position(x: thumbX, y: geometry.size.height / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let progress = min(max((gesture.location.x - thumbWidth / 2) / max(usableWidth, 1), 0), 1)
                        let rawValue = range.lowerBound + Double(progress) * (range.upperBound - range.lowerBound)
                        value = range.lowerBound + ((rawValue - range.lowerBound) / step).rounded() * step
                        value = min(max(value, range.lowerBound), range.upperBound)
                    }
            )
        }
        .frame(height: 30)
        .accessibilityElement()
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }

    private var sliderThumb: some View {
        Capsule()
            .fill(.white.opacity(0.12))
            .frame(width: thumbWidth, height: thumbHeight)
            .glassEffect(.regular.interactive(), in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.62), lineWidth: 0.8)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.60))
                    .frame(width: thumbWidth * 0.48, height: 1)
                    .padding(.top, 2)
            }
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}
