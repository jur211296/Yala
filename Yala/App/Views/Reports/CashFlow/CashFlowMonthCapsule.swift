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
//  S2 del replanteo (18-nov-2026): el número de la cápsula es el de la cifra grande del mes, con cuánto terminas («≈» si
//  aún no ha cerrado). Sin cuentas que sumen, lo que queda, como antes.
//

import SwiftUI

struct CashFlowMonthCapsule: View {
    let month: CashFlowMonth
    let isSelected: Bool
    let currencyCode: String

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        // Con texto de accesibilidad la cápsula crece con su cifra: a 72 pt salía «66.…» (S2 del replanteo).
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 72)
        .frame(minWidth: 72)
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

    private var historia: FlujoDetalleMesLogica.Historia { FlujoDetalleMesLogica.historia(month) }

    /// «12.4k», «≈ 9,820»; sin cuentas, «+3,283». Sin divisa (la cápsula es estrecha; el detalle la dice entera).
    private var netFlowText: String {
        FlujoDetalleMesLogica.textoCapsula(historia)
    }

    /// «octubre de 2026, terminaste con S/ 12,403.20»; si no ha cerrado, «…, estimado».
    private var accessibilityText: String {
        let historia = historia
        let monthName = month.date.formatted(.dateTime.month(.wide).year())
        guard let terminas = historia.terminas else {
            let amount = appPreferences.currency(abs(month.netFlow), currencyCode: currencyCode)
            return "\(monthName), \(CashFlowMonthSummaryLogic.netLabel(for: month)) \(amount)"
        }
        let amount = appPreferences.currency(terminas, currencyCode: currencyCode)
        let label = L10n.FlujoDetalleMes.terminas(historia.tiempo)
        let text = "\(monthName), \(label) \(amount)"
        return historia.esEstimada ? "\(text), \(L10n.FlujoDetalleMes.estimado)" : text
    }
}
