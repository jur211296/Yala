//
//  AmountInputField.swift
//  Yala
//
//  Shared amount input field. Patrón Inbox (DS.Typography.largeTitle + fixedSize,
//  sin scaling dinámico). El callsite pasa `leadingContent` (Text simple o Button
//  con currency picker) — el HStack interno garantiza baseline alignment.
//
//  Variant `compact: true` usa `DS.Typography.amountMedium` (36pt) para Settlement.
//
//  Used by:
//  - NewTransactionView (centralContent amount)
//  - GroupExpenseFormView (amountDisplay con currency Button)
//  - SettlementFormView (amountSection compact)
//

import SwiftUI
import UIKit

struct AmountInputField<Leading: View>: View {

    // MARK: - Properties

    @Binding var amountString: String
    let color: Color
    @FocusState.Binding var isFocused: Bool
    var compact: Bool = false
    var accessibilityID: String? = nil
    var onAmountChange: ((Double) -> Void)? = nil
    @ViewBuilder let leadingContent: () -> Leading

    // MARK: - Body

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            leadingContent()

            textField
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .contentTransition(.numericText())
    }

    @ViewBuilder
    private var textField: some View {
        let field = TextField("0.00", text: $amountString)
            .font(compact ? DS.Typography.amountMedium : DS.Typography.largeTitle)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .keyboardType(.decimalPad)
            .focused($isFocused)
            .fixedSize(horizontal: true, vertical: false)
            .onChange(of: isFocused) { _, focused in handleFocusChange(focused) }
            .onChange(of: amountString) { _, new in handleAmountChange(new) }

        if let id = accessibilityID {
            field.accessibilityIdentifier(id)
        } else {
            field
        }
    }

    // MARK: - Helpers

    /// Tamaño del leadingContent que matchea el peso visual del amount.
    /// Usar desde el callsite: `.font(.system(size: AmountInputField<Text>.leadingFontSize(compact: false), weight: .medium, design: .rounded))`.
    static func leadingFontSize(compact: Bool) -> CGFloat {
        let textStyle: UIFont.TextStyle = compact ? .title1 : .largeTitle
        return UIFont.preferredFont(forTextStyle: textStyle).pointSize * 0.44
    }

    private func handleFocusChange(_ focused: Bool) {
        if focused, amountString == "0" || amountString == "0.00" || amountString == "0,00" {
            amountString = ""
        }
        if !focused {
            if amountString.isEmpty {
                amountString = "0.00"
            } else {
                let amt = AmountInputHelper.parseDecimal(amountString)
                amountString = AmountInputHelper.formatWithGrouping(abs(amt))
            }
        }
    }

    private func handleAmountChange(_ newValue: String) {
        let filtered = AmountInputHelper.filterAmountInput(newValue)
        if filtered != newValue {
            amountString = filtered
        }
        onAmountChange?(AmountInputHelper.parseDecimal(filtered))
    }
}
