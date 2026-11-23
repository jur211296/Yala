//
//  ConectaTuIAInboxCard.swift
//  Yala
//
//  La puerta de «Conecta tu IA» en la Bandeja vacía (decisión D8 del encargo del 23-nov): «Apunta desde tu IA» y
//  «Conectar», que abre la misma página de Ajustes › Tu IA en una hoja. Sale mientras ninguna IA haya apuntado nada
//  (`ConectaTuIALogic.showsInboxDoor`).
//

import SwiftUI

struct ConectaTuIAInboxCard: View {
    let onConnect: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.title3.weight(.semibold))
                    .foregroundStyle(theme.onAccent)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(theme.accent))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.ConectaTuIA.inboxTitle)
                        .font(DS.Typography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.ConectaTuIA.inboxMessage)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            // El id va en el texto y no en la tarjeta: en el contenedor tapaba el de «Conectar».
            .accessibilityIdentifier("inbox_conecta_ia_card")
            YalaSecondaryButton(L10n.ConectaTuIA.inboxButton, icon: "link", action: onConnect)
                .accessibilityIdentifier("inbox_conecta_ia_connect")
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard()
    }
}
