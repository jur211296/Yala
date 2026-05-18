//
//  DatePickerSheet.swift
//  Yala
//

import SwiftUI

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    var minDate: Date = .distantPast
    var maxDate: Date? = nil         // nil = Date.now at runtime (avoids stale capture)
    var title: String = L10n.Common.date

    @State private var workingDate: Date = .now
    @State private var selectedDetent: PresentationDetent = .medium

    private let detents = DS.Adaptive.sheetDetents([.medium, .large])

    /// Computed range: nil maxDate means "up to today" at render time
    private var dateRange: ClosedRange<Date> {
        let upper = maxDate ?? Date.now
        return minDate...upper
    }

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            ZStack {
                if isLargeDetent {
                    PanelBackgroundView()
                }
                VStack {
                    DatePicker(
                        title,
                        selection: $workingDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding(DS.Spacing.md)

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
        .presentationDetents(detents, selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }
}
