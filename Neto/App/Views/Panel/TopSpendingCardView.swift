//
//  TopSpendingCardView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

struct TopSpendingCardView: View {
    let categories: [CategorySpendingSummary]
    let currencyCode: String

    // Filter State
    var selectedCategoryID: PersistentIdentifier?
    var onSelectCategory: ((PersistentIdentifier) -> Void)?

    // Placeholder for future navigation
    var onShowMore: (() -> Void)? = nil

    // MARK: - Layout Variants

    enum CardSize {
        case large
        case medium
        case small
    }

    var size: CardSize = .large

    var body: some View {
        VStack(alignment: .leading, spacing: size == .small ? 12 : 16) {
            headerSection

            if categories.isEmpty {
                emptyState
            } else {
                contentForSize
            }
        }
        .padding(size == .small ? DesignSystem.Spacing.large : DesignSystem.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Content Switcher

    @ViewBuilder
    private var contentForSize: some View {
        switch size {
        case .large:
            categoriesList(limit: 5)
        case .medium:
            categoriesList(limit: 3)
        case .small:
            smallCardContent
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(size == .small ? "Principal" : "Categorías principales")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            // Chevron for Detail View
            if onShowMore != nil {
                Button {
                    onShowMore?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.leading, 4)
                }
            }
        }
    }

    // MARK: - Lists (Large & Medium)

    private func categoriesList(limit: Int) -> some View {
        VStack(spacing: 16) {
            if let maxAmount = categories.first?.amount {
                let displayedCategories = Array(categories.prefix(limit))
                ForEach(displayedCategories) { summary in
                    let isSelected = selectedCategoryID == summary.category.persistentModelID
                    let isAnySelected = selectedCategoryID != nil
                    let shouldDim = isAnySelected && !isSelected

                    CategoryRow(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode
                    )
                    .opacity(shouldDim ? 0.3 : 1.0)  // Dimming effect
                    .contentShape(Rectangle())  // Make entire row tappable
                    .onTapGesture {
                        if isSelected {
                            // Deselect if already selected?
                            // Requirements "filter that category". Maybe tap again to deselect is good UX.
                            // But usually close chip to deselect. Let's strictly follow "filter that category".
                            // If I tap again, I might want to do nothing or re-select.
                            // Let's assume onSelectCategory handles the toggle or just sets it.
                            onSelectCategory?(summary.category.persistentModelID)
                        } else {
                            onSelectCategory?(summary.category.persistentModelID)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Small Card Content

    private var smallCardContent: some View {
        // Show only the top 1 category in a focused way
        Group {
            if let topCategory = categories.first {
                VStack(alignment: .leading, spacing: 12) {
                    // Large Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: topCategory.category.colorHex).opacity(0.1))
                            .frame(width: 48, height: 48)  // Slightly smaller for dense layout

                        Image(systemName: "tag.fill")
                            .font(.headline)
                            .foregroundStyle(Color(hex: topCategory.category.colorHex))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(topCategory.category.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("\(currencyCode) \(formattedAmount(topCategory.amount))")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        Text("\(formattedPercentage(topCategory.percentage)) del total")
                            .font(.caption2.bold())
                            .foregroundStyle(Color(hex: topCategory.category.colorHex))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: topCategory.category.colorHex).opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectCategory?(topCategory.category.persistentModelID)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            if size == .small {
                Spacer()  // Push down
                Image(systemName: "creditcard")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("Sin gastos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()  // Push up
            } else {
                Image(systemName: "creditcard")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.bottom, 4)

                Text("Aún no tienes gastos en este periodo.")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text("Cuando registres movimientos, verás aquí tus categorías principales.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill available space
        .padding(.vertical, size == .small ? 0 : 24)
    }

    // Helpers (moved inside View to be accessible)
    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Category Row Component

private struct CategoryRow: View {
    let summary: CategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: summary.category.colorHex).opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: "tag.fill")  // Default icon
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: summary.category.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                // Name and Amount
                HStack {
                    Text(summary.category.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(currencyCode) \(formattedAmount(summary.amount))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: 4) {
                    // Percentage Text
                    Text("\(formattedPercentage(summary.percentage)) del gasto")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // Bar
                    GeometryReader { geo in
                        let width =
                            maxAmount > 0 ? (summary.amount / maxAmount) * geo.size.width : 0

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color(hex: summary.category.colorHex))
                                .frame(width: width, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
