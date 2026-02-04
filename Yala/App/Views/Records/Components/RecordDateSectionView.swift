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
    let date: Date

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    /// Format: "12 December" or "12 de diciembre" depending on locale
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
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
    .background(Color.yalaBackground)
}
