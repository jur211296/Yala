//
//  FilterChipsSection.swift
//  Yala
//
//  Reusable component for filter sections with chips.
//

import SwiftUI

/// A reusable filter section with header and chip-style selection buttons.
/// Encapsulates the common pattern used in RecordsFiltersView for
/// accounts, tags, and natures sections.
struct FilterChipsSection<Item: Identifiable, ChipContent: View>: View {

    // MARK: - Properties

    /// SF Symbol name for the header icon
    let icon: String

    /// Section title
    let title: String

    /// Status text (e.g., "Todas" or "3/5")
    let status: String

    /// Items to display as chips
    let items: [Item]

    /// Whether to show an empty state placeholder when items is empty
    var showEmptyPlaceholder: Bool = true

    /// Builder for individual chip content
    @ViewBuilder let chipContent: (Item) -> ChipContent

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: icon,
                title: title,
                status: status
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            // Chips
            if !items.isEmpty {
                FlowLayout(spacing: DS.Spacing.sm) {
                    ForEach(items) { item in
                        chipContent(item)
                    }
                }
                .padding(.leading, 52)
                .padding(.trailing, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            } else if showEmptyPlaceholder {
                // Minimal spacer to maintain layout consistency
                Color.clear.frame(height: 12)
            }
        }
    }
}

// MARK: - Standard Chip Button

/// A standard styled chip button for filter selection.
/// Used for consistent appearance across filter sections.
struct FilterChipButton: View {
    let title: String
    let isSelected: Bool
    var selectedColor: Color = .brandPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? selectedColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chip with Color Indicator

/// A chip button with a leading color indicator dot.
/// Used for tags and other colored items.
struct FilterChipWithIndicator: View {
    let title: String
    let indicatorColor: Color
    let isSelected: Bool
    var selectedColor: Color = .brandPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(isSelected ? Color.white : indicatorColor)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? selectedColor : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }
}
