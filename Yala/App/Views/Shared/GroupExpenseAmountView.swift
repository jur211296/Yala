//
//  GroupExpenseAmountView.swift
//  Yala
//
//  Componente que muestra el monto de un gasto compartido desde la perspectiva
//  personal del current user (.youAreOwed / .youOwe / .notIncluded): cifra y pastilla, como Registros.
//

import SwiftUI

struct GroupExpenseAmountView: View {

    let status: PersonalShareStatus
    let currencyCode: String

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Como la columna derecha de una fila de Registros (lienzo «Una sola Yala», 1A): la cifra arriba —en el color
        // del texto, te deban o debas: en Grupos los montos no llevan color (Jürgen, 2026-10-30)— y la relación en la
        // pastilla de debajo, donde Registros pone la necesidad. Al final de la fila en horizontal; al inicio cuando se apila.
        VStack(alignment: .trailingUnlessStacked(dynamicTypeSize), spacing: DS.Spacing.xs) {
            switch status {
            case .youAreOwed(let amount):
                AmountText(
                    value: amount,
                    currencyCode: currencyCode,
                    font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                    tint: .primary,
                    forceFullPrecision: true
                )
                relationPill(L10n.Groups.Summary.owedToMe, dot: Color.priorityNeed)
            case .youOwe(let amount):
                AmountText(
                    value: amount,
                    currencyCode: currencyCode,
                    font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                    tint: .primary,
                    forceFullPrecision: true
                )
                relationPill(L10n.Groups.Summary.iOwe, dot: Color.secondary)
            case .notIncluded:
                relationPill(L10n.Groups.Expense.notIncluded, dot: nil)
            case .identityUnresolved:
                // Sin identidad resuelta no se afirma nada sobre la participación: ni cifra ni pastilla.
                EmptyView()
            }
        }
    }

    /// La pastilla de la necesidad de `RecordRowView`, con la relación en vez de la necesidad.
    private func relationPill(_ text: String, dot: Color?) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            if let dot {
                Circle()
                    .fill(dot)
                    .frame(width: DS.Chip.dotSize - 2, height: DS.Chip.dotSize - 2)
            }
            Text(text)
                .font(DS.Typography.labelTiny)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Chip.paddingV)
        .padding(.vertical, DS.Spacing.xxs)
        .background(Capsule().fill((dot ?? Color.secondary).opacity(0.1)))
    }
}
