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
                Text(appPreferences.currency(amount, currencyCode: currencyCode))
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Semantic.successForeground)
            case .youOwe(let amount):
                Text(appPreferences.currency(amount, currencyCode: currencyCode))
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Semantic.errorForeground)
            case .notIncluded:
                EmptyView()
            }
        }
    }

    private var captionText: String {
        switch status {
        case .youAreOwed: return L10n.Groups.Expense.youAreOwed
        case .youOwe: return L10n.Groups.Expense.youOwe
        case .notIncluded: return L10n.Groups.Expense.notIncluded
        }
    }
}
