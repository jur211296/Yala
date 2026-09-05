//
//  GroupExpenseAmountView.swift
//  Yala
//
//  Componente que muestra el monto de un gasto compartido desde la perspectiva
//  personal del current user (.youAreOwed / .youOwe / .notIncluded).
//

import SwiftUI

struct GroupExpenseAmountView: View {

    let status: PersonalShareStatus
    let currencyCode: String

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
            Text(captionText)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)

            switch status {
            case .youAreOwed(let amount):
                AmountText(
                    value: amount,
                    currencyCode: currencyCode,
                    font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                    tint: .color(DS.Semantic.successForeground)
                )
            case .youOwe(let amount):
                AmountText(
                    value: amount,
                    currencyCode: currencyCode,
                    font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                    tint: .color(Color.hotPink)
                )
            case .notIncluded, .identityUnresolved:
                // `identityUnresolved`: sin identidad resuelta no se afirma nada sobre la
                // participación. Comparte el EmptyView con `notIncluded`, pero por un motivo
                // distinto — aquí no es que no participe, es que aún no se sabe.
                EmptyView()
            }
        }
    }

    private var captionText: String {
        switch status {
        case .youAreOwed: return L10n.Groups.Expense.youAreOwed
        case .youOwe: return L10n.Groups.Expense.youOwe
        case .notIncluded: return L10n.Groups.Expense.notIncluded
        // Sin caption: la fila no pinta texto de perspectiva mientras no se sepa quién soy.
        case .identityUnresolved: return ""
        }
    }
}
