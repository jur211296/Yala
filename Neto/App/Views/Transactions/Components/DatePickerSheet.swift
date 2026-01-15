//
//  DatePickerSheet.swift
//  Neto
//
//  Extracted from NewTransactionView - Date picker modal sheet
//

import SwiftUI

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            ZStack {
                Color.netoBackground.ignoresSafeArea()

                VStack {
                    DatePicker(
                        L10n.Common.date,
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle(L10n.Common.date)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton(action: { dismiss() })
                }
            }
        }
        .tint(Color.electricIndigo)
    }
}
