//
//  RecordDateSectionView.swift
//  Yala
//
//  Created by Yala - Records Feature.
//

import SwiftUI

// MARK: - Date Section Header

/// Header view for date grouping in Records list
struct RecordDateSectionView: View {
    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f
    }()

    /// Buscar recorre todos los años: ahí un día de otro año lleva el año («14 de octubre de 2025»). Registros va
    /// por períodos y no lo necesita (UX 2.2 · L8-14).
    private static let sectionDateWithYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.setLocalizedDateFormatFromTemplate("d MMMM y")
        return f
    }()

    let date: Date
    var includesYear: Bool = false
    /// Modo selección de Registros (decisión 18 de 2.3, E2): «Seleccionar día» a la derecha de la fecha, o
    /// «Deseleccionar día» si ya están todos. `nil` fuera del modo selección y en Buscar y Grupos.
    var dayAction: DayAction? = nil

    struct DayAction {
        let isDaySelected: Bool
        let toggle: () -> Void
    }

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)

            Spacer()

            if let dayAction {
                // Sin háptico propio: ya vibra la marca de cada fila (`sensoryFeedback` de `RecordRowView`).
                Button {
                    dayAction.toggle()
                } label: {
                    Text(dayAction.isDaySelected ? L10n.RecordsBulkUndo.deselectDay : L10n.RecordsBulkUndo.selectDay)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.thAccentText)
                        // El área de toque crece hasta un dedo sin mover la cabecera (review del lote: el texto solo
                        // medía ~18 pt de alto).
                        .contentShape(Rectangle().inset(by: -DS.Spacing.md))
                }
                .buttonStyle(.plain)
                // VoiceOver dice qué día: con varias cabeceras, «Seleccionar día» a secas no se distingue.
                .accessibilityLabel(Text(verbatim: "\(dayAction.isDaySelected ? L10n.RecordsBulkUndo.deselectDay : L10n.RecordsBulkUndo.selectDay), \(formattedDate)"))
                .accessibilityIdentifier("records_select_day_button")
            }
        }
        // Más aire arriba que abajo: la fecha encabeza su día y no flota a medio camino de la tarjeta de arriba.
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xxs)
    }

    /// Format: "12 December" or "12 de diciembre" depending on locale
    private var formattedDate: String {
        (includesYear ? Self.sectionDateWithYearFormatter : Self.sectionDateFormatter).string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.none) {
        RecordDateSectionView(date: Date.now)
        RecordDateSectionView(date: Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!)
        RecordDateSectionView(date: Calendar.current.date(byAdding: .day, value: -7, to: Date.now)!)
    }
    .background(.thBackground)
}
