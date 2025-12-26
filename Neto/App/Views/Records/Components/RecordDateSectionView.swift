//
//  RecordDateSectionView.swift
//  Neto
//
//  Created by Neto - Records Feature.
//

import SwiftUI

// MARK: - Date Section Header

/// Header view for date grouping in Records list
struct RecordDateSectionView: View {
    let date: Date

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// Format: "12 de diciembre" (Spanish locale, regular case)
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        RecordDateSectionView(date: Date())
        RecordDateSectionView(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        RecordDateSectionView(date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)
    }
    .background(Color.netoBackground)
}
