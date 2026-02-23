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

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                VStack {
                    DatePicker(
                        L10n.Common.date,
                        selection: $selectedDate,
                        in: ...Date(),
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
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Resign first responder to ensure DatePicker commits its selection
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(DS.Typography.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.borderedProminent)

                    .buttonBorderShape(.circle)
                }
            }
        }

    }
}
