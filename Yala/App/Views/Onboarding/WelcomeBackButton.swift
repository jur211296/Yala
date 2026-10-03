//
//  WelcomeBackButton.swift
//  Yala
//
//  «Volver» reusado por las pantallas del flow Welcome — descarta la pantalla actual sin alterar
//  flags persistentes y vuelve a la anterior.
//
//  **Píldora con icono y palabra, no un chevron suelto** (rasgo 7 de la referencia del 15-sep,
//  `WelcomeForm.swift`): un chevron solo, blanco sobre el degradado, no se leía como botón. La píldora es
//  de Liquid Glass porque flota: con Dynamic Type grande el contenido hace scroll por debajo y el vidrio
//  lo mantiene legible, cosa que un borde fino sobre transparente no hacía.
//

import SwiftUI

extension View {
    /// `nil` deja la vista intacta — útil para callbacks opcionales que solo
    /// se setean cuando la pantalla viene del flow Welcome.
    func welcomeBackButton(tint: Color, action: (() -> Void)?) -> some View {
        overlay(alignment: .topLeading) {
            if let action {
                Button {
                    DS.Haptic.selection()
                    action()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "chevron.backward")
                            .font(DS.Typography.subheadlineEmphasized)
                            .accessibilityHidden(true)
                        Text(L10n.Welcome.Invite.back)
                            .font(DS.Typography.subheadlineEmphasized)
                            .lineLimit(1)
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    // El vidrio mide ~36 pt; el área de toque llega a los 44 del HIG sin agrandar la píldora.
                    .frame(minHeight: DS.Button.actionSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Como el «Atrás» de una barra de navegación: no crece con los tamaños de accesibilidad
                // —a AX5 medía ~80 pt y tapaba el titular y el logo de las puertas— y quien los usa lo
                // lee ampliado manteniendo el dedo encima (Large Content Viewer).
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityShowsLargeContentViewer()
                .padding(.leading, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .accessibilityLabel(L10n.Welcome.Invite.back)
                .accessibilityIdentifier("welcome_back_button")
            }
        }
    }
}
