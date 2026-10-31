//
//  AccountLineBalanceEditor.swift
//  Yala
//
//  Editar cuenta con varias divisas (S30, card «editar cuenta de doble línea»): lo que enseña el formulario cuando el
//  selector de moneda está en una línea. Su saldo inicial, con el signo, y «Eliminar la línea». El borrador vive en el
//  ViewModel (`LineBalanceDraft`) y se guarda con el «Guardar» del formulario; eliminar lo decide el formulario, que es
//  quien presenta la confirmación o la hoja de «¿Qué hacemos con lo que hay dentro?».
//

import SwiftUI

struct AccountLineBalanceEditor: View {
    @Bindable var draft: LineBalanceDraft
    /// La divisa de la línea (ISO), para el pie y el botón de eliminar.
    let currencyCode: String
    /// Una tarjeta de crédito rotula el signo «A favor / Consumido», como el resto del formulario.
    let isCreditCard: Bool
    let onDelete: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        // Un solo bloque: debajo va «Acciones» de la cuenta entera, y un segundo «Acciones» se leía repetido.
        SectionBox(title: L10n.Account.initialBalance) {
            VStack(spacing: DS.Spacing.none) {
                HStack(spacing: DS.Spacing.md) {
                    Text(L10n.Account.sign)
                        .font(DS.Typography.subheadline)
                    Spacer()
                    Picker(L10n.Account.sign, selection: $draft.isPositive) {
                        if isCreditCard {
                            Text(L10n.Account.Sign.inFavor).tag(true)
                            Text(L10n.Account.Sign.consumed).tag(false)
                        } else {
                            Text(L10n.Account.positive).tag(true)
                            Text(L10n.Account.negative).tag(false)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("account_line_balance_sign")
                }
                .padding()

                SubsectionDivider()

                amountField
                    .padding()

                Text(L10n.Account.Lines.lineBalanceFooter(currencyCode))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom)

                SubsectionDivider()

                Button(role: .destructive) {
                    isFocused = false
                    onDelete()
                } label: {
                    HStack {
                        Spacer()
                        Text(L10n.Account.Lines.delete(currencyCode))
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Semantic.errorForeground)
                .accessibilityIdentifier("account_line_delete")
            }
        }
    }

    private var amountField: some View {
        HStack {
            Spacer()
            ZStack(alignment: .trailing) {
                if draft.text.isEmpty {
                    Text(L10n.Onboarding.balancePlaceholder)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(DS.Semantic.disabledForeground.opacity(DS.Opacity.overlay))
                        .accessibilityHidden(true)
                }
                TextField("", text: $draft.text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(DS.Typography.largeTitle)
                    .focused($isFocused)
                    .accessibilityLabel(L10n.Account.initialBalance)
                    .accessibilityIdentifier("account_line_initial_balance_field")
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused && !draft.text.isEmpty {
                draft.text = AmountInputHelper.formatWithGrouping(AmountInputHelper.parseDecimal(draft.text))
            }
        }
        .onChange(of: draft.text) { _, newValue in
            let filtered = AmountInputHelper.filterAmountInput(newValue)
            if filtered != newValue { draft.text = filtered }
        }
    }
}
