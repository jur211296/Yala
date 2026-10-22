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
                // Sólo la acción principal lleva texto; las tres de entrada
                // asistida van con icono. Medido en el simulador el 2026-09-02:
                // con texto en todas, «Nuevo registro» + «Voz» + «Imagen» ya
                // dejaban la cuarta píldora cortada contra el borde en un
                // iPhone 17 Pro EN ESPAÑOL — y el alemán es más largo. Un texto
                // recortado parece un fallo, no una invitación a deslizar.
                pill(
                    text: nil,
                    icon: "waveform",
                    isLocked: isVoiceLocked,
                    accessibilityLabel: L10n.Panel.fabVoice,
                    identifier: "panel_action_voice",
                    action: onVoiceTap
                )
                pill(
                    text: nil,
                    icon: "photo",
                    isLocked: isImageLocked,
                    accessibilityLabel: L10n.Panel.fabImage,
                    identifier: "panel_action_image",
                    action: onImageTap
                )
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
            HStack(spacing: DS.Spacing.xs) {
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
                if let text {
                    Text(text)
                        .font(DS.Typography.label)
                        .foregroundStyle(iconStyle(isPrimary: isPrimary, usaDorado: usaDorado))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, text == nil ? DS.Spacing.md : DS.Spacing.lg)
            .frame(height: Self.pillHeight)
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
        .accessibilityLabel(accessibilityLabel ?? text ?? "")
        .accessibilityIdentifier(identifier)
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
