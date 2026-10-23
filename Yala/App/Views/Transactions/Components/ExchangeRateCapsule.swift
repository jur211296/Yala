//
//  ExchangeRateCapsule.swift
//  Yala
//
//  El tipo de cambio del formulario de registro (UX 2.2 · L2-11 y L2-18, decididos por Jürgen el 14 y el 21-oct): una
//  cápsula con lápiz que se toca para cambiar la tasa. En un gasto en otra divisa el rótulo va dentro
//  («Tipo de cambio de hoy: 1 US$ = S/ 3.55 ✎», o «del 19 oct» si el registro es de otro día); en una transferencia va
//  encima («Tipo de cambio de hoy · tócalo si tu banco usó otro») y la cápsula dice «1 US$ = S/ 3.55 ✎». Antes la tasa de la transferencia era un campo que parecía texto («3.5500») y la de
//  un gasto en dólares solo salía al editar, como «(TC: 3.55)».
//

import SwiftUI

struct ExchangeRateCapsule: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    let caption: String
    /// El rótulo dentro de la cápsula, delante de la tasa (gasto en otra divisa, L2-11), o encima (transferencia, L2-18).
    var captionInside: Bool = false
    /// Una unidad de esta divisa…
    let fromCurrency: String
    /// …vale `rate` de esta.
    let toCurrency: String
    let rate: Double
    /// La tasa nueva (siempre `to` por `from`), mientras se escribe.
    let onRateChange: (Double) -> Void

    @State private var isEditing = false
    @State private var text = ""
    @FocusState private var isFocused: Bool

    /// Una tasa menor que 1 se enseña al revés («1 US$ = S/ 3.55» y no «1 S/ = 0.28 US$»), como hacía la transferencia.
    private var isInverted: Bool { rate > 0 && rate < 1 }
    private var shownRate: Double { isInverted ? 1 / rate : rate }
    private var leftCode: String { isInverted ? toCurrency : fromCurrency }
    private var rightCode: String { isInverted ? fromCurrency : toCurrency }

    private var rateLine: String {
        let left = appPreferences.currencyIdentifier(for: leftCode)
        let right = appPreferences.currencyIdentifier(for: rightCode)
        return "1 \(left) = \(right) \(ExchangeRateDisplayFormatter.string(shownRate))"
    }

    /// Lo que dice la cápsula sin editar: con el rótulo delante si va dentro.
    private var capsuleText: String {
        captionInside ? "\(caption): \(rateLine)" : rateLine
    }

    var body: some View {
        // Lee el formato de moneda aquí: `currencyIdentifier` no es observable por sí solo.
        let _ = appPreferences.currencyDisplayFormat
        VStack(spacing: DS.Spacing.xs) {
            if !captionInside {
                Text(caption)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: startEditing) {
                HStack(spacing: DS.Spacing.xs) {
                    if isEditing {
                        Text("1 \(appPreferences.currencyIdentifier(for: leftCode)) = \(appPreferences.currencyIdentifier(for: rightCode))")
                            .foregroundStyle(.secondary)
                        TextField("", text: $text)
                            .keyboardType(.decimalPad)
                            .focused($isFocused)
                            .fixedSize()
                            .foregroundStyle(.primary)
                            .accessibilityLabel(L10n.Accessibility.exchangeRate)
                            .accessibilityIdentifier("exchange_rate_field")
                    } else {
                        Text(capsuleText)
                            .foregroundStyle(.primary)
                    }
                    Image(systemName: "pencil")
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
                .font(DS.Typography.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(theme.accent.opacity(0.12)))
                .overlay(Capsule().stroke(theme.accent.opacity(0.35), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(captionInside ? capsuleText : "\(caption). \(rateLine)")
            .accessibilityHint(L10n.UXL2B.rateEditHint)
            .accessibilityIdentifier("exchange_rate_capsule")
        }
        // Tope con motivo (2026-09-28, la fila de la transferencia): a AX5 en un iPhone SE la tasa se cortaba.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onChange(of: text) { _, newValue in
            guard isEditing else { return }
            let filtered = AmountInputHelper.filterAmountInput(newValue)
            if filtered != newValue {
                text = filtered
                return
            }
            let typed = AmountInputHelper.parseDecimal(filtered)
            guard typed > 0 else { return }
            onRateChange(isInverted ? 1 / typed : typed)
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { isEditing = false }
        }
    }

    private func startEditing() {
        text = ExchangeRateDisplayFormatter.string(shownRate)
        isEditing = true
        isFocused = true
    }
}

/// El rótulo de encima de la cápsula. Lógica pura para fijarla con tests.
enum ExchangeRateCaptionLogic {
    /// «Tipo de cambio de hoy» o «Tipo de cambio del 19 oct».
    static func caption(for date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = AppLocale.current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return L10n.UXL2B.rateToday
        }
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar)
        style = style.day().month(.abbreviated)
        return L10n.UXL2B.rateOnDate(date.formatted(style))
    }
}
