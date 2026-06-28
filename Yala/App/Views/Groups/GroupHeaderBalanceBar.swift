//
//  GroupHeaderBalanceBar.swift
//  Yala
//
//  Banda de balance del usuario en el detalle de grupo: texto continuo "Te deben X" (verde) /
//  "Debes Y" (hot pink) / "Tu balance" (mixto) / "Están a mano", con chevron en círculo glass.
//  Texto suelto (sin card) — va como primer elemento del scroll del feed para scrollear junto
//  a los registros, no fijo como los chips de tabs.
//

import SwiftUI

struct GroupHeaderBalanceBar: View {

    let balance: GroupHeaderBalance
    let debtsWereConverted: Bool
    let onTap: () -> Void

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Text(headerBalanceText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Chevron en círculo glass; .center lo alinea al medio del texto (1 o 2 líneas).
                Image(systemName: "chevron.right")
                    .font(DS.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .frame(width: DS.Panel.headerAccessorySize, height: DS.Panel.headerAccessorySize)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("group_header_balance")
        .accessibilityElement(children: .combine)
    }

    private func headerBalanceLabel(_ state: GroupHeaderBalance.State) -> String {
        switch state {
        case .theyOweMe: L10n.Groups.Summary.owedToMe
        case .iOwe: L10n.Groups.Summary.iOwe
        case .mixed: L10n.Groups.Detail.yourBalance
        case .settled: L10n.Groups.Detail.settledUp
        }
    }

    /// Texto continuo: label en primary grande negrita + montos en verde (te deben) /
    /// hot pink (debes), con la jerarquía symbol/decimal de `AmountText.attributedAmount`.
    private var headerBalanceText: AttributedString {
        var result = AttributedString(headerBalanceLabel(balance.state))
        result.font = .subheadline.bold()
        result.foregroundColor = .primary

        switch balance.state {
        case .settled:
            break
        case .theyOweMe:
            result.append(AttributedString(" "))
            result.append(amountsAttributed(balance.owedToMe, color: DS.Semantic.successForeground, negate: false))
        case .iOwe:
            result.append(AttributedString(" "))
            result.append(amountsAttributed(balance.iOwe, color: .hotPink, negate: false))
        case .mixed:
            result.append(AttributedString(" "))
            result.append(amountsAttributed(balance.owedToMe, color: DS.Semantic.successForeground, negate: false))
            result.append(AttributedString("  "))
            result.append(amountsAttributed(balance.iOwe, color: .hotPink, negate: true))
        }
        return result
    }

    /// Montos de un mismo color, intercalando " + " entre monedas. Prefija "≈" cuando las
    /// deudas se consolidaron a una moneda (`debtsWereConverted`).
    private func amountsAttributed(_ amounts: [String: Double], color: Color, negate: Bool) -> AttributedString {
        let integerFont = Font.subheadline.weight(.semibold)
        let secondaryFont = Font.caption
        let sorted = amounts.sorted { $0.key < $1.key }
        var result = AttributedString()
        for (index, pair) in sorted.enumerated() {
            if index > 0 {
                var plus = AttributedString(" + ")
                plus.font = integerFont
                plus.foregroundColor = color
                result.append(plus)
            } else if debtsWereConverted {
                var approx = AttributedString("≈ ")
                approx.font = secondaryFont
                approx.foregroundColor = color.opacity(0.6)
                result.append(approx)
            }
            result.append(AmountText.attributedAmount(
                value: negate ? -pair.value : pair.value,
                currencyCode: pair.key,
                prefs: appPreferences,
                integerFont: integerFont,
                secondaryFont: secondaryFont,
                tintColor: color,
                forceFullPrecision: true
            ))
        }
        return result
    }
}
