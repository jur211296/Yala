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

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
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
