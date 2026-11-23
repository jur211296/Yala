//
//  ConectaTuIAPuerta.swift
//  Yala
//
//  La puerta de «Conecta tu IA» en Primeros pasos (decisión D7 del encargo del 23-nov): la sexta manera del paso 7,
//  «Tu IA», con su historia (lo que le dices a tu IA y lo que llega a la Bandeja) y su mini tutorial, que es la misma guía
//  de Ajustes › Tu IA (`ConectaTuIAGuide`). Solo sale con los datos en la cuenta de Yala, así que los pasos van encendidos.
//

import SwiftUI

/// La historia: «Apunta 25 de almuerzo» a Claude, y el borrador que llega a la Bandeja con su nombre.
struct ConectaTuIAStory: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private var amount: String {
        appPreferences.currency(25, currencyCode: appPreferences.defaultCurrencyCode.rawValue)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                Spacer(minLength: DS.Spacing.xxl)
                Text(L10n.ConectaTuIA.paso7Example)
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.onAccent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.accent))
            }
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "tray.full.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thAccentText)
                    .frame(width: 44, height: 36)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(theme.accent.opacity(0.15)))
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Inbox.title)
                        .font(DS.Typography.subheadline.weight(.semibold))
                    Label {
                        Text(verbatim: ConectaTuIALogic.Provider.claude.displayName)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(amount)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .padding(DS.Spacing.md)
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        }
        .accessibilityHidden(true)
    }
}

/// El mini tutorial: la guía de Ajustes, con su propio selector de IA.
struct ConectaTuIAPuertaGuide: View {
    @State private var provider: ConectaTuIALogic.Provider = .claude

    var body: some View {
        ConectaTuIAGuide(provider: $provider, stepsOnCards: true)
    }
}
