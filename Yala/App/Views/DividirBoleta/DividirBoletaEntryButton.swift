//
//  DividirBoletaEntryButton.swift
//  Yala
//
//  El botón largo «Dividir una boleta» de la maqueta 1A: bajo Cámara, Fotos y Archivo de la hoja de foto personal, y
//  bajo la fila de acciones de Grupos. Tarjeta con el contorno del acento, el ícono en un cuadrado de acento y el
//  chevron, para que se lea como un camino aparte y no como una cuarta ficha.
//

import SwiftUI

struct DividirBoletaEntryButton: View {
    /// La línea de ayuda de debajo (solo en la hoja de foto personal). `nil` en Grupos.
    var hint: String?
    let identifier: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Button {
                DS.Haptic.selection()
                action()
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "divide")
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(theme.onAccent)
                        .frame(width: iconSide, height: iconSide)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).fill(theme.accent))
                        .accessibilityHidden(true)
                    Text(L10n.DividirBoleta.entryTitle)
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: DS.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .strokeBorder(theme.accent, lineWidth: 1.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(hint ?? L10n.DividirBoleta.entryHintGroups)
            .accessibilityIdentifier(identifier)

            if let hint {
                Text(hint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.xs)
                    .accessibilityHidden(true)
            }
        }
    }
}
