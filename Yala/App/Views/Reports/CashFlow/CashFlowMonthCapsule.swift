//
//  CashFlowMonthCapsule.swift
//  Yala
//
//  Individual month capsule in the horizontal strip.
//
//  UX 2.2 · L18-11 (opción C, variante 2): UN número por cápsula —lo que sobra (o falta) ese mes—, sin el acumulado
//  arriba ni la mini gráfica. Lienzo «Una sola Yala» (5A): el mes elegido va relleno en el acento, como un chip elegido.
//  El saldo que se tendría lo dice la frase del resumen, debajo.
//

import SwiftUI

struct CashFlowMonthCapsule: View {
    let month: CashFlowMonth
    let isSelected: Bool
    let currencyCode: String

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            // Month label (OCT. 26)
            Text(month.date.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                .font(DS.Typography.captionSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? theme.onAccent : Color.secondary)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(netFlowText)
                .font(DS.Typography.label.weight(.bold))
                .foregroundStyle(isSelected ? theme.onAccent : Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 72)
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.clear))
        )
        .glassEffect(isSelected ? .clear : .regular, in: .rect(cornerRadius: DS.Radius.md))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// «+3,283»: con signo, sin divisa (la cápsula es estrecha; el resumen de debajo la dice entera).
    private var netFlowText: String {
        let compact = YalaFormatter.amountCompactTable(value: abs(month.netFlow))
        return (month.netFlow >= 0 ? "+" : "-") + compact
    }

    /// «octubre de 2026, te sobran S/ 3,283.23».
    private var accessibilityText: String {
        let amount = appPreferences.currency(abs(month.netFlow), currencyCode: currencyCode)
        let monthName = month.date.formatted(.dateTime.month(.wide).year())
        let summary = CashFlowMonthSummaryLogic.heroLabel(for: month)
        return "\(monthName), \(summary) \(amount)"
    }
}
