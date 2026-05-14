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
//  - NewTransactionView (centralContent amount — Bool focus)
//  - GroupExpenseFormView (amountDisplay con currency Button — enum focus via
//    AmountInputFieldEnumFocus)
//  - SettlementFormView (amountSection compact — Bool focus)
//

import SwiftUI
import UIKit

// MARK: - Bool focus variant (NTV, Settlement)

struct AmountInputField<Leading: View>: View {

    @Binding var amountString: String
    let color: Color
    @FocusState.Binding var isFocused: Bool
    var compact: Bool = false
    var accessibilityID: String? = nil
    var onAmountChange: ((Double) -> Void)? = nil
    @ViewBuilder let leadingContent: () -> Leading

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
            .onChange(of: isFocused) { _, focused in
                AmountInputFieldLogic.handleFocusChange(
                    focused: focused,
                    amountString: $amountString
                )
            }
            .onChange(of: amountString) { _, new in
                AmountInputFieldLogic.handleAmountChange(
                    newValue: new,
                    amountString: $amountString,
                    onAmountChange: onAmountChange
                )
            }

        if let id = accessibilityID {
            field.accessibilityIdentifier(id)
        } else {
            field
        }
    }

    /// Tamaño del leadingContent que matchea el peso visual del amount.
    /// Usar: `.font(.system(size: AmountInputField<Text>.leadingFontSize(compact: false), weight: .medium, design: .rounded))`.
    static func leadingFontSize(compact: Bool) -> CGFloat {
        let textStyle: UIFont.TextStyle = compact ? .title1 : .largeTitle
        return UIFont.preferredFont(forTextStyle: textStyle).pointSize * 0.44
    }
}

// MARK: - Enum focus variant (GroupExpense)

/// Variant para vistas que ya tienen un `@FocusState<Field>` enum-based.
/// El callsite pasa el FocusState + el valor del enum que representa "este campo".
struct AmountInputFieldEnumFocus<Leading: View, Field: Hashable>: View {

    @Binding var amountString: String
    let color: Color
    @FocusState.Binding var focusedField: Field?
    let fieldValue: Field
    var compact: Bool = false
    var accessibilityID: String? = nil
    var onAmountChange: ((Double) -> Void)? = nil
    @ViewBuilder let leadingContent: () -> Leading

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
            .focused($focusedField, equals: fieldValue)
            .fixedSize(horizontal: true, vertical: false)
            .onChange(of: focusedField) { _, new in
                AmountInputFieldLogic.handleFocusChange(
                    focused: new == fieldValue,
                    amountString: $amountString
                )
            }
            .onChange(of: amountString) { _, new in
                AmountInputFieldLogic.handleAmountChange(
                    newValue: new,
                    amountString: $amountString,
                    onAmountChange: onAmountChange
                )
            }

        if let id = accessibilityID {
            field.accessibilityIdentifier(id)
        } else {
            field
        }
    }
}

// MARK: - Shared logic

enum AmountInputFieldLogic {
    static func handleFocusChange(focused: Bool, amountString: Binding<String>) {
        if focused, amountString.wrappedValue == "0"
            || amountString.wrappedValue == "0.00"
            || amountString.wrappedValue == "0,00" {
            amountString.wrappedValue = ""
        }
        if !focused {
            if amountString.wrappedValue.isEmpty {
                amountString.wrappedValue = "0.00"
            } else {
                let amt = AmountInputHelper.parseDecimal(amountString.wrappedValue)
                amountString.wrappedValue = AmountInputHelper.formatWithGrouping(abs(amt))
            }
        }
    }

    static func handleAmountChange(
        newValue: String,
        amountString: Binding<String>,
        onAmountChange: ((Double) -> Void)?
    ) {
        let filtered = AmountInputHelper.filterAmountInput(newValue)
        if filtered != newValue {
            amountString.wrappedValue = filtered
        }
        onAmountChange?(AmountInputHelper.parseDecimal(filtered))
    }
}
