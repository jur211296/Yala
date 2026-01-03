//
//  FilterChipView.swift
//  Neto
//
//  Shared filter chip component for displaying applied filters.
//

import SwiftUI

/// Reusable filter chip showing applied filter with clear action
struct FilterChipView: View {
    let text: String
    var color: Color = .electricIndigo
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)

            Button {
                withAnimation {
                    onClear()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Helper for "First +x" Format

struct FilterChipData: Identifiable {
    let id = UUID()
    let text: String
    let onClear: () -> Void
}

extension FilterChipData {
    /// Creates chip text in "First +x" format
    /// - Parameters:
    ///   - items: Selected items with their display names
    ///   - singular: Label when single item (e.g., the item name itself)
    ///   - fallback: Fallback when items don't have names
    /// - Returns: Formatted text like "Soles +1" or "Soles" or nil if empty
    static func formattedText(
        items: [String],
        fallback: String = ""
    ) -> String? {
        guard !items.isEmpty else { return nil }
        
        let firstName = items.first ?? fallback
        if items.count == 1 {
            return firstName
        } else {
            return "\(firstName) +\(items.count - 1)"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FilterChipView(text: "Soles", onClear: {})
        FilterChipView(text: "BCP +2", onClear: {})
        FilterChipView(text: "Esencial +3", color: .hotPink, onClear: {})
    }
    .padding()
    .background(Color.netoCard)
}
