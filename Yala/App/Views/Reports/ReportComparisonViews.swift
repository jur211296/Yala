//
//  ReportComparisonViews.swift
//  Yala
//
//  Auditoría UX 2.2 · lote 18 decidido.
//  - L18-3 (opción D, variante 3): arriba de la tabla, «Octubre comparado con setiembre» y dos chips en palabras
//    («Con el mes anterior», «Con octubre de 2025») en lugar de «P-1» y «A-1».
//  - L18-2 (opción C): en «Todo el tiempo» no hay período anterior; una tarjeta «Para comparar, elige un mes o un año»
//    con «Este mes» y «Mes pasado» lleva a una comparación en un toque, sin cambiar el período a escondidas.
//

import SwiftUI

/// La frase de qué se compara con qué y los dos chips para elegirlo.
struct ReportComparisonHeader: View {
    let heading: String
    /// Los chips solo salen donde hay dos maneras de comparar (`PreviousPeriodHelper.isSelectorVisible`).
    let showsChips: Bool
    let previousTitle: String
    let yearAgoTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(heading)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("report_comparison_heading")

            if showsChips {
                ComparisonModeChips(
                    previousTitle: previousTitle,
                    yearAgoTitle: yearAgoTitle,
                    identifierPrefix: "report_comparison_chip"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Los dos chips de «con qué comparar» («Con el mes anterior» / «Con octubre de 2025»). Es el MISMO control en la
/// Comparativa de Reportes y en Estadísticas (decisión de Jürgen del 2026-10-23): los dos escriben
/// `SessionState.comparisonMode`, así que elegir en una pantalla deja elegido en la otra.
struct ComparisonModeChips: View {
    let previousTitle: String
    let yearAgoTitle: String
    /// Cada pantalla conserva sus identificadores: `<prefijo>_month` y `<prefijo>_year`.
    let identifierPrefix: String

    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                chip(.month, title: previousTitle)
                chip(.year, title: yearAgoTitle)
            }
        }
        .fadesTowardVerticalBar()
        .scrollClipDisabled()
    }

    private func chip(_ mode: ComparisonMode, title: String) -> some View {
        let isSelected = sessionState.comparisonMode == mode
        return Button {
            dsWithAnimation(reduceMotion) {
                sessionState.comparisonMode = mode
            }
        } label: {
            ReportChoiceChip(title: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("\(identifierPrefix)_\(mode.rawValue)")
    }
}

/// «Para comparar, elige un mes o un año» con «Este mes» y «Mes pasado».
struct ReportAllTimeCompareCard: View {
    let onSelect: (DetailPeriod) -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.accentText)
                    .frame(width: 36, height: 36)
                    .background(theme.accent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                Text(L10n.UXL18.allTimeCardTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: DS.Spacing.sm) {
                periodButton(.thisMonth)
                periodButton(.lastMonth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("report_all_time_card")
    }

    private func periodButton(_ period: DetailPeriod) -> some View {
        Button {
            onSelect(period)
        } label: {
            ReportChoiceChip(title: period.displayName, isSelected: false)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("report_all_time_\(period.rawValue)")
    }
}

/// La cápsula de una elección: rellena en el acento si está elegida, en cristal si no (el mismo aspecto que los chips de
/// Comparativa · Flujo de caja de arriba).
struct ReportChoiceChip: View {
    let title: String
    let isSelected: Bool

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Text(title)
            .font(DS.Typography.labelSmall.weight(.semibold))
            .foregroundStyle(isSelected ? theme.onAccent : Color.primary)
            .lineLimit(1)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.clear)))
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
            .contentShape(Capsule())
    }
}
