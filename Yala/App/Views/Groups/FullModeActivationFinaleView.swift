//
//  FullModeActivationFinaleView.swift
//  Yala
//
//  Paso 8 del rediseño de sesiones · lo que TAPA el onboarding cuando [P] termina —la pregunta del historial
//  de grupos, la promoción de la cuenta en la nube y sus desenlaces— y el aviso de reinstalar.
//
//  **Tapa y no sustituye, y no es estética.** `OnboardingView` entrega un `commit` que lee su propio `@State`;
//  si esta pantalla lo reemplazara, el onboarding se desmontaría con las respuestas dentro y el `commit` ya no
//  tendría qué escribir. Por eso vive encima, en el `ZStack` de `FullModeActivationView`, con fondo opaco.
//
//  **Con scroll**, como los diez pasos del onboarding: con el texto grande de accesibilidad un aviso largo
//  (el alemán, sobre todo) empujaba el único botón fuera de la pantalla, y aquí no hay deslizar para cerrar
//  ni X del onboarding que valga — la capa las tapa a propósito.
//

import SwiftUI

enum FullModeActivationFinale: Equatable {
    /// «¿Traemos tus gastos de grupo?».
    case history
    /// El claim en vuelo.
    case promoting
    /// No se puede promocionar y reintentar no lo cambia. No se ha escrito nada.
    case blocked(FullModeActivationFlowLogic.PromotionBlock)
    /// Falló la red o el servidor. Aquí no se ha escrito nada, y reintentar no daña nada. Si el servidor llegó a
    /// promocionar y se perdió la respuesta, el reintento de este teléfono vuelve a recibir `created` y termina
    /// (`qa/cloud/g16_01_…`, ticket `claim-promotion-lost-response-blocks-the-retry`); si otro teléfono entró
    /// entretanto en la cuenta, el reintento bloquea (`qa/cloud/g16_02_…`).
    case failed
    /// Una instalación solo-grupos anterior al paso 5: hay que reinstalar antes de elegir.
    case reinstallRequired
}

struct FullModeActivationFinaleView: View {
    let finale: FullModeActivationFinale
    var onShowHistory: () -> Void
    var onKeepHistoryInGroups: () -> Void
    var onRetry: () -> Void
    /// Cerrar la activación sin terminarla. Desde aquí nunca deja nada a medias: lo que se escribe, se escribe
    /// después de la promoción.
    var onLeave: () -> Void

    var body: some View {
        OnboardingFlowScreen(style: .themedPanel) { logoTopSpacing in
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    content
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, logoTopSpacing)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch finale {
        case .history:
            history
        case .promoting:
            VStack(spacing: DS.Spacing.lg) {
                ProgressView()
                    .controlSize(.large)
                Text(L10n.Groups.FullActivation.promoting)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("full_activation_promoting")
        case .blocked(let block):
            notice(icon: Self.icon(for: block),
                   title: Self.title(for: block),
                   body: Self.body(for: block),
                   identifier: "full_activation_blocked") {
                YalaPrimaryButton(L10n.Action.close) { onLeave() }
                    .accessibilityIdentifier("full_activation_blocked_close")
            }
        case .failed:
            notice(icon: "wifi.exclamationmark",
                   title: L10n.Groups.FullActivation.failedTitle,
                   body: L10n.Groups.FullActivation.failedBody,
                   identifier: "full_activation_failed") {
                VStack(spacing: DS.Spacing.sm) {
                    YalaPrimaryButton(L10n.Action.retry) { onRetry() }
                        .accessibilityIdentifier("full_activation_failed_retry")
                    secondaryButton(L10n.Common.cancel, identifier: "full_activation_failed_cancel") {
                        onLeave()
                    }
                }
            }
        case .reinstallRequired:
            notice(icon: "arrow.down.app",
                   title: L10n.Groups.FullActivation.reinstallTitle,
                   body: L10n.Groups.FullActivation.reinstallBody,
                   identifier: "full_activation_reinstall") {
                YalaPrimaryButton(L10n.Action.close) { onLeave() }
                    .accessibilityIdentifier("full_activation_reinstall_close")
            }
        }
    }

    /// Las dos salidas pesan lo mismo a propósito: ninguna se recomienda, y el orden va con la pregunta —«¿los
    /// traemos?», primero el «sí»—. Las dos se pueden deshacer, y el pie dice dónde y que la respuesta vale
    /// también para lo que venga después.
    private var history: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flow)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.FullActivation.historyTitle)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(L10n.Groups.FullActivation.historyBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("full_activation_history")

            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Groups.FullActivation.historyShow) { onShowHistory() }
                    .accessibilityIdentifier("full_activation_history_show")
                YalaPrimaryButton(L10n.Groups.FullActivation.historyKeepInGroups) { onKeepHistoryInGroups() }
                    .accessibilityIdentifier("full_activation_history_keep")
            }

            Text(L10n.Groups.FullActivation.historyFootnote)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func notice<Actions: View>(
        icon: String, title: String, body: String, identifier: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flow)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)

            actions()
        }
    }

    private func secondaryButton(_ title: String, identifier: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Copy de los bloqueos

    private static func icon(for block: FullModeActivationFlowLogic.PromotionBlock) -> String {
        switch block {
        case .accountAlreadyHasPersonalData: "person.crop.circle.badge.exclamationmark"
        case .anotherDeviceIsMoving: "arrow.triangle.2.circlepath"
        case .sessionExpired: "person.crop.circle.badge.xmark"
        case .accountUnavailable: "exclamationmark.triangle"
        }
    }

    private static func title(for block: FullModeActivationFlowLogic.PromotionBlock) -> String {
        switch block {
        case .accountAlreadyHasPersonalData: L10n.Groups.FullActivation.blockedPersonalDataTitle
        case .anotherDeviceIsMoving: L10n.Groups.FullActivation.blockedBusyTitle
        case .sessionExpired: L10n.Groups.FullActivation.blockedSessionTitle
        case .accountUnavailable: L10n.Groups.FullActivation.failedTitle
        }
    }

    private static func body(for block: FullModeActivationFlowLogic.PromotionBlock) -> String {
        switch block {
        case .accountAlreadyHasPersonalData: L10n.Groups.FullActivation.blockedPersonalDataBody
        case .anotherDeviceIsMoving: L10n.Groups.FullActivation.blockedBusyBody
        case .sessionExpired: L10n.Groups.FullActivation.blockedSessionBody
        case .accountUnavailable: L10n.Groups.FullActivation.unavailableBody
        }
    }
}
