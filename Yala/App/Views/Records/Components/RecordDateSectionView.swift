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

    /// Buscar recorre todos los años: ahí un día de otro año lleva el año («14 de octubre de 2025»). Registros lo
    /// lleva también desde la revisión 2.3 (decisión 17, reabre L8-14), con su propio formato («vie 4 jul 2025»).
    private static let sectionDateWithYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.setLocalizedDateFormatFromTemplate("d MMMM y")
        return f
    }()

    let date: Date
    var includesYear: Bool = false
    /// Registros (revisión 2.3, decisión 17, T1): lo gastado ese día, a la derecha («S/ -231.40»). `nil` en Buscar y
    /// Grupos, y en un día sin gasto.
    var spentText: String? = nil
    /// Registros (decisión 17, T1): «vie 17 oct», con el día de la semana. Buscar y Grupos siguen con «17 de octubre».
    var showsWeekday: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(formattedDate)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)

            Spacer()

            if let spentText {
                Text(spentText)
                    .font(DS.Typography.labelSmall.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        // Más aire arriba que abajo: la fecha encabeza su día y no flota a medio camino de la tarjeta de arriba.
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(showsWeekday ? "records_day_header" : "")
    }

    /// Format: "12 December" or "12 de diciembre" depending on locale; en Registros, «vie 17 oct» («vie 4 jul 2025»).
    private var formattedDate: String {
        guard showsWeekday else {
            return (includesYear ? Self.sectionDateWithYearFormatter : Self.sectionDateFormatter).string(from: date)
        }
        // Por llamada y no `static let`: el idioma se cambia en caliente dentro de la app (molde del calendario).
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate(includesYear ? "EEEdMMMy" : "EEEdMMM")
        return formatter.string(from: date)
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
