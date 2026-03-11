//
//  DatePickerSheet.swift
//  Yala
//
//  Extracted from NewTransactionView - Date picker modal sheet
//

import SwiftUI

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Binding var selectedDate: Date
    var minDate: Date = .distantPast
    var maxDate: Date? = nil         // nil = Date() at runtime (avoids stale capture)
    var title: String = L10n.Common.date

    @State private var workingDate: Date = .now

    /// Computed range: nil maxDate means "up to today" at render time
    private var dateRange: ClosedRange<Date> {
        let upper = maxDate ?? Date()
        return minDate...upper
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                VStack {
                    DatePicker(
                        title,
                        selection: $workingDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: {
                        selectedDate = workingDate
                        dismiss()
                    })
                }
            }
            .onAppear {
                workingDate = selectedDate
            }
        }

    }
}
