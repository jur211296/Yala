//
//  WidgetExtraLargePortrait.swift
//  YalaWidgets
//
//  El tamaño extragrande vertical del iPhone con iOS 27 (`systemExtraLargePortrait`: 4 × 6 casillas, una página
//  entera de la pantalla de inicio). La app es iOS 26+, así que el tamaño solo se ofrece detrás de `#available`, y
//  las vistas lo preguntan con `isExtraLargePortrait` en vez de nombrar el case (que no existe en iOS 26).
//

import SwiftUI
import WidgetKit

enum WidgetFamilies {
    /// `base` más el extragrande vertical cuando el sistema lo tiene. Lo usan Resumen del mes, Pagos planificados y
    /// Entradas y salidas (decisión de Jürgen del 2026-10-20, opción C).
    static func addingExtraLargePortrait(_ base: [WidgetFamily]) -> [WidgetFamily] {
        if #available(iOS 27.0, *) {
            return base + [.systemExtraLargePortrait]
        }
        return base
    }
}

extension WidgetFamily {
    /// `true` en el extragrande vertical de iOS 27; `false` en cualquier otro tamaño y en iOS 26.
    var isExtraLargePortrait: Bool {
        if #available(iOS 27.0, *) {
            return self == .systemExtraLargePortrait
        }
        return false
    }
}

/// Rótulo de sección dentro de un extragrande: el mismo peso que «Presupuestos» del Resumen del mes de iPad.
struct WidgetSectionTitle: View {
    let key: LocalizedStringKey

    var body: some View {
        Text(key, bundle: .main)
            .font(WDS.Typography.label)
            .foregroundStyle(.secondary)
    }
}

/// Una cifra con su rótulo encima, como las del Resumen del mes de iPad.
struct WidgetLabeledAmount: View {
    let label: LocalizedStringKey
    let value: Double
    let currencyCode: String
    let displayFormat: String
    var tint: Color = .primary
    var isEstimate: Bool = false
    var forceSign: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label, bundle: .main)
                .font(WDS.Typography.tiny)
                .foregroundStyle(.secondary)
            WidgetAmountText(
                value: value,
                currencyCode: currencyCode,
                displayFormat: displayFormat,
                font: WDS.Typography.kpiMedium,
                secondaryFont: WDS.Typography.kpiSmallSecondary,
                tint: .color(tint),
                forceSign: forceSign,
                isEstimate: isEstimate
            )
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
