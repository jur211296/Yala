//
//  AdjustmentModeSelectorView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftUI

struct AdjustmentModeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAdjustmentMode: AdjustmentMode

    var body: some View {
        List {
            ForEach(AdjustmentMode.allCases) { mode in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .font(.body)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if mode == selectedAdjustmentMode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedAdjustmentMode = mode
                    dismiss()
                }
            }
        }
        .navigationTitle("Ajuste")
    }
}
