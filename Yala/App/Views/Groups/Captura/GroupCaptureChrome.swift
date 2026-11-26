//
//  GroupCaptureChrome.swift
//  Yala
//
//  Las piezas comunes de Voz y Foto de Grupos, copiadas al píxel de las hojas de personal (`VoiceRecordingView`,
//  `ImageSelectionView`): la cabecera con la X del sistema, los dos botones en cápsula, la pantalla de fallo con su disco y
//  la foto que se está leyendo. En personal son privadas de cada hoja y el encargo no deja cambiarlas: si un día pasan a
//  ser compartidas, Grupos las usa en lugar de estas.
//

import SwiftUI

// MARK: - Botones

/// El botón principal en cápsula de las hojas de voz y foto (`VoiceRecordingView.primaryButton`).
struct GroupCapturePrimaryButton: View {
    let title: String
    var isEnabled = true
    let identifier: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme
    private let buttonHeight: CGFloat = 48 // A11Y-DT: tap target de los botones de la hoja

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.body.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                // Apagado se VE apagado: con fondo explícito, `.disabled` no atenúa nada (#348).
                .foregroundStyle(isEnabled ? theme.onAccent : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: buttonHeight)
                .padding(.horizontal, DS.Spacing.sm)
                .background(
                    Capsule().fill(isEnabled ? theme.accent : DS.Semantic.disabledForeground.opacity(0.35))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }
}

/// El secundario, gris (`VoiceRecordingView.secondaryButton`).
struct GroupCaptureSecondaryButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    private let buttonHeight: CGFloat = 48 // A11Y-DT: tap target de los botones de la hoja

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.body.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.thPrimaryText)
                .frame(maxWidth: .infinity, minHeight: buttonHeight)
                .padding(.horizontal, DS.Spacing.sm)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Cabecera

/// La X del sistema arriba a la derecha (`EntrySheetCloseButton`), solo cuando no hay un Cancelar abajo, como personal. Con
/// título, va en la misma fila que la X, sin hueco arriba (encargo «X nativa en la hoja de foto», 2026-11-17).
struct GroupCaptureHeader: View {
    let showsClose: Bool
    let closeIdentifier: String
    var title: String?
    var titleIdentifier: String?
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            if let title {
                Text(title)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(titleIdentifier ?? "")
                    // Un título, una vista: al cambiar de fase no se funde con el anterior.
                    .id(title)
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
            } else {
                Spacer()
            }
            if showsClose {
                EntrySheetCloseButton(action: onClose)
                    .accessibilityIdentifier(closeIdentifier)
            }
        }
        .frame(minHeight: 44)
        .padding(.top, DS.Spacing.md)
    }
}

// MARK: - Fallo

/// Qué hacer ante un fallo: las salidas de personal, con lo de Grupos (cupo diario, Nuevo gasto a mano).
struct GroupCaptureFailureActions {
    let tryAgainTitle: String
    let onTryAgain: () -> Void
    let onClose: () -> Void
    let onManualEntry: () -> Void
    let onSeePro: () -> Void
    let onOpenSettings: () -> Void
}

/// La pantalla de fallo de personal: el icono en su disco ámbar, el título, el porqué y dos botones abajo.
struct GroupCaptureFailureView: View {
    let failure: GroupCaptureFailure
    let source: GroupCaptureSource
    let actions: GroupCaptureFailureActions

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: GroupCaptureFailureText.icon(failure))
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.warningForeground)
                .frame(width: 72, height: 72) // A11Y-DT: disco del icono del fallo
                .background(Circle().fill(DS.Semantic.warningBackground))
                .accessibilityHidden(true)
                .padding(.top, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.xs) {
                Text(GroupCaptureFailureText.title(failure))
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("receipt_split_failure")
                Text(GroupCaptureFailureText.message(failure, source: source))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: DS.Spacing.lg)

            HStack(spacing: DS.Spacing.md) {
                buttons
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_capture_failure")
    }

    @ViewBuilder
    private var buttons: some View {
        switch failure {
        case .trialPhotos, .trialVoice, .dailyLimitFree:
            GroupCaptureSecondaryButton(title: L10n.Action.close, identifier: "receipt_split_failure_close", action: actions.onClose)
            GroupCapturePrimaryButton(title: L10n.Voice.trialSeePro, identifier: "receipt_split_see_pro", action: actions.onSeePro)
        case .dailyLimit:
            GroupCaptureSecondaryButton(title: L10n.Action.close, identifier: "receipt_split_failure_close", action: actions.onClose)
            GroupCapturePrimaryButton(title: L10n.Voice.enterManually, identifier: "receipt_split_enter_manually",
                                      action: actions.onManualEntry)
        case .microphone:
            GroupCaptureSecondaryButton(title: L10n.Voice.enterManually, identifier: "receipt_split_enter_manually",
                                        action: actions.onManualEntry)
            GroupCapturePrimaryButton(title: L10n.Voice.openSettings, identifier: "receipt_split_open_settings",
                                      action: actions.onOpenSettings)
        case .camera:
            GroupCaptureSecondaryButton(title: actions.tryAgainTitle, identifier: "receipt_split_retry", action: actions.onTryAgain)
            GroupCapturePrimaryButton(title: L10n.Image.openSettings, identifier: "receipt_split_open_settings",
                                      action: actions.onOpenSettings)
        case .noLines, .noVoice, .read, .unreadableFile:
            GroupCaptureSecondaryButton(title: L10n.Voice.enterManually, identifier: "receipt_split_enter_manually",
                                        action: actions.onManualEntry)
            GroupCapturePrimaryButton(title: actions.tryAgainTitle, identifier: "receipt_split_retry", action: actions.onTryAgain)
        case .noConnection, .busy:
            GroupCapturePrimaryButton(title: actions.tryAgainTitle, identifier: "receipt_split_retry", action: actions.onTryAgain)
        }
    }
}

/// Los textos de cada fallo. Los de personal donde dicen lo mismo; los de Grupos donde el motivo es suyo.
enum GroupCaptureFailureText {
    static func icon(_ failure: GroupCaptureFailure) -> String {
        switch failure {
        case .noConnection: "wifi.slash"
        case .microphone: "mic.slash"
        case .noVoice: "waveform.slash"
        case .noLines: "questionmark"
        case .trialPhotos, .trialVoice, .dailyLimitFree: "sparkles"
        case .busy: "hourglass"
        case .dailyLimit: "calendar"
        case .camera: "camera"
        case .unreadableFile: "doc"
        case .read: "exclamationmark"
        }
    }

    static func title(_ failure: GroupCaptureFailure) -> String {
        switch failure {
        case .read: L10n.ReceiptSplit.failureReadTitle
        case .noLines: L10n.ReceiptSplit.failureNoLinesTitle
        case .noConnection: L10n.Voice.failureNoConnectionTitle
        case .trialPhotos: L10n.Image.Entry.failureTrialUsedUpTitle
        case .trialVoice: L10n.Voice.failureTrialUsedUpTitle
        case .busy: L10n.Image.Entry.failureBusyTitle
        case .dailyLimit: L10n.ReceiptSplit.failureDailyLimitTitle
        case .dailyLimitFree: L10n.ReceiptSplit.failureDailyLimitFreeTitle
        case .camera: L10n.Image.Entry.failureCameraTitle
        case .microphone: L10n.Voice.failureMicTitle
        case .noVoice: L10n.Voice.failureNoVoiceTitle
        case .unreadableFile: L10n.Image.Entry.failureUnreadableFileTitle
        }
    }

    static func message(_ failure: GroupCaptureFailure, source: GroupCaptureSource) -> String {
        switch failure {
        case .read: L10n.ReceiptSplit.failureReadMessage
        case .noLines: source == .text ? L10n.ReceiptSplit.failureNoLinesTextMessage : L10n.ReceiptSplit.failureNoLinesMessage
        case .noConnection: L10n.ReceiptSplit.failureNoConnectionMessage
        case .trialPhotos: L10n.Image.Entry.failureTrialUsedUpMessage
        case .trialVoice: L10n.Voice.failureTrialUsedUpMessage
        case .busy: L10n.Image.Entry.failureBusyMessage
        case .dailyLimit: L10n.ReceiptSplit.failureDailyLimitMessage
        case .dailyLimitFree: L10n.ReceiptSplit.failureDailyLimitFreeMessage
        case .camera: L10n.Image.Entry.failureCameraMessage
        case .microphone: L10n.ReceiptSplit.failureMicMessage
        case .noVoice: L10n.Voice.failureNoVoiceMessage
        case .unreadableFile: L10n.Image.Entry.failureUnreadableFileMessage
        }
    }

    /// Lo que VoiceOver oye al llegar a un fallo (decisión 62 de la revisión 2.3).
    static func announcement(_ failure: GroupCaptureFailure, source: GroupCaptureSource) -> String {
        EntryPhaseFeedbackLogic.announcement(title: title(failure), detail: message(failure, source: source))
    }
}

// MARK: - Foto leyéndose

/// La foto que se está leyendo, con la línea de luz que la recorre (`ImageSelectionView.ImageReadingPhoto`).
struct GroupCaptureReadingPhoto: View {
    let image: UIImage
    let accent: Color
    let reduceMotion: Bool

    @State private var sweepDown = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 190) // A11Y-DT: la foto que se está leyendo
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(accent)
                            .frame(height: 3)
                            .shadow(color: accent.opacity(0.8), radius: 8)
                            .offset(y: sweepDown ? proxy.size.height - 3 : 0)
                    }
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            // La línea recorre la foto solo con la app activa (lote 2 de eficiencia, 26-nov-2026).
            .animation(sweepDown ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : nil, value: sweepDown)
            .animaSoloVisible($sweepDown, si: !reduceMotion)
            .accessibilityHidden(true)
    }
}
