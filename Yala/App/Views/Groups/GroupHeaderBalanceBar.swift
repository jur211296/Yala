//
//  GroupHeaderBalanceBar.swift
//  Yala
//
//  Banda de balance inline: texto continuo "Te deben X" (verde) / "Debes Y" (hot pink) /
//  "Te deben X · Debes Y" (ambos lados) / "Están a mano" (saldado).
//  Texto suelto (sin card). Lo usa tanto el detalle de un grupo (con chevron + tap a
//  Balances) como el resumen global de la lista (sin chevron, no interactivo).
//
//  El inset horizontal lo da el `.contentMargins` del ScrollView contenedor — la banda
//  NO añade padding horizontal propio, para que el texto se alinee con el borde de las
//  cards (no con su texto interno).
//

import SwiftUI

struct GroupHeaderBalanceBar: View {

    let balance: GroupHeaderBalance
    let debtsWereConverted: Bool
    /// Tap a la pestaña Balances. `nil` → banda no interactiva, sin chevron (resumen global).
    let onTap: (() -> Void)?

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
                .accessibilityIdentifier("group_header_balance")
                .accessibilityElement(children: .combine)
        } else {
            content
                .accessibilityElement(children: .combine)
        }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: DS.Spacing.xs) {
            Text(headerBalanceText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Chevron pegado al texto (no al borde derecho); el Spacer empuja el bloque
            // a la izquierda y deja el resto del ancho libre.
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .frame(width: DS.Panel.headerAccessorySize, height: DS.Panel.headerAccessorySize)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
    }

    /// Texto continuo en una línea: label en primary bold + montos verde (te deben) / hot pink
    /// (debes), con la jerarquía symbol/decimal de `AmountText.attributedAmount`. En el caso de
    /// ambos lados, "Te deben X · Debes Y" separados por " · ".
    private var headerBalanceText: AttributedString {
        switch balance.state {
        case .settled:
            return label(L10n.Groups.Detail.settledUp)
        case .theyOweMe:
            return labeledAmounts(L10n.Groups.Summary.owedToMe, balance.owedToMe, color: DS.Semantic.successForeground)
        case .iOwe:
            return labeledAmounts(L10n.Groups.Summary.iOwe, balance.iOwe, color: .hotPink)
        case .mixed:
            var result = labeledAmounts(L10n.Groups.Summary.owedToMe, balance.owedToMe, color: DS.Semantic.successForeground)
            var separator = AttributedString("  ·  ")
            separator.font = .subheadline.bold()
            separator.foregroundColor = .secondary
            result.append(separator)
            result.append(labeledAmounts(L10n.Groups.Summary.iOwe, balance.iOwe, color: .hotPink))
            return result
        }
    }

    /// Solo el label en primary bold (caso saldado).
    private func label(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .subheadline.bold()
        result.foregroundColor = .primary
        return result
    }

    /// Label en primary bold + " " + montos coloreados.
    private func labeledAmounts(_ text: String, _ amounts: [String: Double], color: Color) -> AttributedString {
        var result = label(text)
        result.append(AttributedString(" "))
        result.append(amountsAttributed(amounts, color: color))
        return result
    }

    /// Montos de un mismo color, intercalando " + " entre monedas. Prefija "≈" cuando las
    /// deudas se consolidaron a una moneda (`debtsWereConverted`).
    private func amountsAttributed(_ amounts: [String: Double], color: Color) -> AttributedString {
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
                value: pair.value,
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
