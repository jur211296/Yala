//
//  DateFieldButton.swift
//  Yala
//
//  Reusable date field that opens DatePickerSheet with confirm/cancel
//

import SwiftUI

struct DateFieldButton: View {
    @Binding var date: Date
    var minDate: Date = .distantPast
    var maxDate: Date? = .distantFuture
    var title: String = L10n.Common.date

    @Environment(\.yalaTheme) private var theme
    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(DS.Typography.body)
                .foregroundStyle(theme.accent)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .sheet(isPresented: $showSheet) {
            DatePickerSheet(
                selectedDate: $date,
                minDate: minDate,
                maxDate: maxDate,
                title: title
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.medium, .large]))
        }
    }
}
