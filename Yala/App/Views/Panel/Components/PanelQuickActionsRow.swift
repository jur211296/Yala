//
//  PanelQuickActionsRow.swift
//  Yala
//
//  Fila de acciones rápidas bajo la cifra del hero (sesión de diseño 2026-09-02).
//  Sustituye a los botones flotantes MIENTRAS la fila está a la vista: `PanelView`
//  vuelve a mostrar `FABStackView` en cuanto el scroll se la lleva, con el mismo
//  molde de histéresis que usa para el título de la barra. Así el Panel arranca
//  limpio —los flotantes tapaban cifras en 3 de 4 capturas— sin perder el acceso
//  rápido desde media pantalla, que en un Panel de cuatro pantallas de scroll es
//  lo que se juega.
//
//  PURAMENTE PRESENTACIONAL, y eso es deliberado: NO monta alerta de
//  consentimiento ni resuelve gates. `FABStackView` sí monta la suya
//  (`.aiConsentAlert`), y dos anchors presentando ante el mismo estado es
//  exactamente el bug que prohíbe la regla 4 de presentaciones —UIKit no presenta
//  dos veces y puede tumbar ambas cadenas dejando los flags en `true` sin que
//  corra ningún `onDismiss`—. Aquí sólo se pinta y se llama al closure; quien
//  decide es `PanelView`, que ya tiene ese reparto hecho en `handleSetupStep`.
//

import SwiftUI

struct PanelQuickActionsRow: View {

    /// Gate de "ya hay una cuenta creada". Con `false` el Panel no ofrece
    /// registrar nada, igual que `FABStackView` cae a su estado deshabilitado.
    let canCreateRecords: Bool
    /// Sin ninguna cuenta activa, la fila apagada se sustituye por la salida (UX 2.2 · L3-10, variante 2): un botón
    /// rosa relleno «Crea tu primera cuenta». Con cuentas pero sin subcategorías visibles la fila sigue apagada.
    var hasAccounts: Bool = true
    var onCreateFirstAccount: () -> Void = {}
    let isVoiceLocked: Bool
    let isImageLocked: Bool
    let isChatLocked: Bool
    /// Espeja `appPreferences.chatFABVisible`: si el usuario escondió el chat,
    /// tampoco aparece aquí.
    let isChatVisible: Bool

    let onManualTap: () -> Void
    let onVoiceTap: () -> Void
    let onImageTap: () -> Void
    let onChatTap: () -> Void

    @Environment(\.yalaTheme) private var theme

    /// 44 pt es el mínimo táctil de las HIG. No bajar aunque la fila apriete:
    /// antes se recorta texto o se deja que el scroll horizontal haga su trabajo.
    private static let pillHeight: CGFloat = 44

    var body: some View {
        if hasAccounts {
            actionsRow
        } else {
            createFirstAccount
        }
    }

    // MARK: - Sin cuentas (UX 2.2 · L3-10)

    /// Es el paso donde la persona se atasca: antes veía la fila en gris sin ninguna explicación y «Nueva cuenta»
    /// solo aparecía al desplegar «Tus finanzas». Relleno rosa de marca (`emphasisPinkFill`, AA con blanco), sin
    /// degradado ni brillo, y una línea de invitación debajo.
    private var createFirstAccount: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Button(action: onCreateFirstAccount) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "creditcard.fill")
                        .font(DS.Typography.label)
                        .accessibilityHidden(true)
                    Text(L10n.Panel.createFirstAccount)
                        .font(DS.Typography.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: Self.pillHeight)
                .background(Capsule().fill(Color.emphasisPinkFill))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.Panel.createFirstAccountHint)
            .accessibilityIdentifier("panel_create_first_account")

            Text(L10n.Panel.createFirstAccountHint)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Fila de acciones

    private var actionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                pill(
                    text: L10n.Accessibility.newRecord,
                    icon: "plus",
                    isPrimary: true,
                    isLocked: false,
                    identifier: "panel_action_new",
                    action: onManualTap
                )
                // Voz y foto llevan su palabra DEBAJO del icono, dentro del mismo
                // botón (UX 2.2 · L4-1, variante elegida por Jürgen el 2026-10-14).
                // No al lado: medido en el simulador el 2026-09-02, con texto al
                // lado en todas, «Nuevo registro» + «Voz» + «Imagen» ya dejaban la
                // cuarta píldora cortada contra el borde en un iPhone 17 Pro EN
                // ESPAÑOL —y el alemán es más largo—. Debajo, la palabra no ensancha
                // el botón más que el icono con su margen.
                // Voz y Foto van juntas en un ancla: el tour Pro las señala a la vez (UX 2.2 · L5-12).
                HStack(spacing: DS.Spacing.sm) {
                    pill(
                        text: nil,
                        caption: L10n.Panel.voiceShort,
                        icon: "waveform",
                        isLocked: isVoiceLocked,
                        identifier: "panel_action_voice",
                        action: onVoiceTap
                    )
                    pill(
                        text: nil,
                        caption: L10n.Panel.photoShort,
                        icon: "photo",
                        isLocked: isImageLocked,
                        identifier: "panel_action_image",
                        action: onImageTap
                    )
                }
                .coachMarkAnchor(ProTourSteps.panelVoiceImageAnchor)
                if isChatVisible {
                    // Dorado como el FAB de IA (`DS.Gradients.proBadge`), y con
                    // texto: es la única de las tres asistidas que se anuncia,
                    // porque es la que no se adivina por el icono. El label
                    // accesible sigue siendo el nombre largo del chat.
                    pill(
                        text: L10n.Panel.aiPill,
                        icon: "sparkles",
                        isLocked: isChatLocked,
                        accessibilityLabel: L10n.Chat.title,
                        isGold: true,
                        identifier: "panel_action_ai",
                        action: onChatTap
                    )
                    .coachMarkAnchor(ProTourSteps.panelAssistantAnchor)
                }
            }
        }
        .scrollDisabled(!canCreateRecords)
        .opacity(canCreateRecords ? 1 : DS.Opacity.disabled)
        .disabled(!canCreateRecords)
        .accessibilityLabel(L10n.Accessibility.newRecord)
        .accessibilityIdentifier("panel_quick_actions")
    }

    // MARK: - Píldora

    @ViewBuilder
    private func pill(
        text: String?,
        caption: String? = nil,
        icon: String,
        isPrimary: Bool = false,
        isLocked: Bool,
        accessibilityLabel: String? = nil,
        isGold: Bool = false,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        // Bloqueada, el dorado se apaga: un candado sobre un acabado premium es
        // justo la señal contraria a la que hay que dar.
        let usaDorado = isGold && !isLocked
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            Group {
                if let caption {
                    // Icono arriba y su palabra debajo. `minHeight` y no alto fijo: con
                    // texto grande la palabra no cabe en 44 pt y el botón crece en vez
                    // de cortarla.
                    VStack(spacing: DS.Spacing.xxs) {
                        pillIcon(icon, isPrimary: isPrimary, usaDorado: usaDorado, isLocked: isLocked)
                        Text(caption)
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(iconStyle(isPrimary: isPrimary, usaDorado: usaDorado))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xxs)
                } else {
                    HStack(spacing: DS.Spacing.xs) {
                        pillIcon(icon, isPrimary: isPrimary, usaDorado: usaDorado, isLocked: isLocked)
                        if let text {
                            Text(text)
                                .font(DS.Typography.label)
                                .foregroundStyle(iconStyle(isPrimary: isPrimary, usaDorado: usaDorado))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, text == nil ? DS.Spacing.md : DS.Spacing.lg)
                }
            }
            .frame(minHeight: Self.pillHeight)
            .background {
                if isPrimary {
                    Capsule().fill(theme.accent)
                } else {
                    Capsule()
                        .fill(theme.card)
                        .overlay {
                            if usaDorado {
                                Capsule().strokeBorder(
                                    LinearGradient(
                                        colors: DS.Gradients.proBadge,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                            }
                        }
                }
            }
            // El contentShape va DENTRO del label y tras el padding: es la regla
            // medida el 2026-08-07 sobre la fila de divisa de GroupFormView.
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadow(
            color: DS.Shadow.small.color,
            radius: DS.Shadow.small.radius,
            x: DS.Shadow.small.x,
            y: DS.Shadow.small.y
        )
        // VoiceOver lee lo mismo que se ve: «Voz», «Foto» (el nombre accesible contiene la etiqueta visible).
        .accessibilityLabel(accessibilityLabel ?? text ?? caption ?? "")
        .accessibilityIdentifier(identifier)
    }

    /// El icono de la píldora, con el candado encima si la acción es Pro y no lo tienes.
    private func pillIcon(_ icon: String, isPrimary: Bool, usaDorado: Bool, isLocked: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: icon)
                .font(DS.Typography.label)
                .foregroundStyle(iconStyle(isPrimary: isPrimary, usaDorado: usaDorado))
            if isLocked {
                Image(systemName: "lock.fill")
                    // A11Y-DT: candado decorativo sobre el icono, como en FABStackView
                    .font(.system(size: 8))
                    .foregroundStyle(DS.Semantic.disabledForeground)
                    .offset(x: 6, y: 4)
            }
        }
    }

    /// Blanco sobre la píldora principal, degradado `proBadge` en la de IA —el
    /// mismo del FAB, para que se lean como el mismo botón— y tinta en el resto.
    private func iconStyle(isPrimary: Bool, usaDorado: Bool) -> AnyShapeStyle {
        if isPrimary { return AnyShapeStyle(Color.white) }
        if usaDorado {
            return AnyShapeStyle(
                LinearGradient(
                    colors: DS.Gradients.proBadge,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.primary)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Acciones rápidas") {
    ZStack {
        PanelBackgroundView()
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            PanelQuickActionsRow(
                canCreateRecords: true,
                isVoiceLocked: false,
                isImageLocked: false,
                isChatLocked: false,
                isChatVisible: true,
                onManualTap: {}, onVoiceTap: {}, onImageTap: {}, onChatTap: {}
            )
            PanelQuickActionsRow(
                canCreateRecords: true,
                isVoiceLocked: true,
                isImageLocked: true,
                isChatLocked: true,
                isChatVisible: true,
                onManualTap: {}, onVoiceTap: {}, onImageTap: {}, onChatTap: {}
            )
        }
        .padding(.horizontal, DS.Spacing.lg)
    }
    .environment(\.yalaTheme, .light)
}
#endif
