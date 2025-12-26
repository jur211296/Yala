//
//  TopSubcategoriesCardView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

struct TopSubcategoriesCardView: View {
    let subcategories: [SubcategorySpendingSummary]
    let currencyCode: String

    // Filter State
    // "Global" category filter (from Top Spending widget)
    let globalCategoryFilterID: PersistentIdentifier?

    // "Local" widget filter (controlled by this widget's dropdown)
    @Binding var localCategoryFilterID: PersistentIdentifier?

    // Action when a subcategory is tapped
    var onSelectSubcategory: ((String) -> Void)?

    // Selected Subcategory ID (for dimming others)
    var selectedSubcategoryID: String?

    // Size config
    var size: TopSpendingCardView.CardSize = .large

    // Fetch all categories for the dropdown
    @Query(sort: \Category.name) private var allCategories: [Category]

    var body: some View {
        VStack(alignment: .leading, spacing: size == .small ? 12 : 16) {
            headerSection

            if subcategories.isEmpty {
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Title + Chevron
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if size == .small {
                        Text("Subcategorías")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text("Subcategorías principales")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(Color.gray.opacity(0.7))
                    .padding(.leading, 4)
            }

            // Row 2: Selector (Only Medium/Large)
            if size != .small {
                categorySelector
            }
        }
    }

    private var categorySelector: some View {
        Group {
            if let globalID = globalCategoryFilterID,
                let category = allCategories.first(where: { $0.persistentModelID == globalID })
            {
                // Locked State (Global Filter Active)
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: category.colorHex))

                    Text(category.name)
                        .font(.caption.weight(.medium))

                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .clipShape(Capsule())
            } else {
                // Interactive State (Local Filter)
                // Interactive State (Local Filter)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "Todas" Chip
                        Button {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                localCategoryFilterID = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                    .font(.caption2)
                                Text("Todas")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(localCategoryFilterID == nil ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        localCategoryFilterID == nil
                                            ? Color.electricIndigo : Color.gray.opacity(0.1))
                            )
                        }

                        // Category Chips
                        ForEach(allCategories) { category in
                            let isSelected = localCategoryFilterID == category.persistentModelID
                            Button {
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    localCategoryFilterID = category.persistentModelID
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption2)
                                    Text(category.name)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(isSelected ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            isSelected
                                                ? Color(hex: category.colorHex)
                                                : Color.gray.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 1)  // Tiny padding for shadow/clip safety
                }
            }
        }
    }

    private var currentFilterName: String {
        if let localID = localCategoryFilterID,
            let category = allCategories.first(where: { $0.persistentModelID == localID })
        {
            return category.name
        }
        return "Todas"
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForSize: some View {
        switch size {
        case .large:
            subcategoriesList(limit: 5)
        case .medium:
            subcategoriesList(limit: 3)
        case .small:
            smallCardContent
        }
    }

    // MARK: - Lists

    private func subcategoriesList(limit: Int) -> some View {
        VStack(spacing: 16) {
            // Find max amount for bar scaling
            if let maxAmount = subcategories.first?.amount {
                let displayed = Array(subcategories.prefix(limit))
                ForEach(displayed) { summary in
                    let isSelected = selectedSubcategoryID == summary.subcategoryName
                    let isDimmed = selectedSubcategoryID != nil && !isSelected

                    SubcategoryRow(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode
                    )
                    .opacity(isDimmed ? 0.3 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectSubcategory?(summary.subcategoryName)
                    }
                }
            }
        }
    }

    // MARK: - Small Content

    private var smallCardContent: some View {
        Group {
            if let top = subcategories.first {
                VStack(alignment: .leading, spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: top.colorHex ?? "#888888").opacity(0.1))
                            .frame(width: 48, height: 48)

                        Image(systemName: "list.bullet.indent")
                            .font(.headline)
                            .foregroundStyle(Color(hex: top.colorHex ?? "#888888"))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(top.subcategoryName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(formattedAmount(top.amount))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        // % of Category (Most relevant context for subcats)
                        HStack(spacing: 4) {
                            Text(
                                "\(formattedPercentage(top.percentageOfCategory)) de \(top.category?.name ?? "Categ.")"
                            )
                            .font(.caption2.bold())
                            .foregroundStyle(Color(hex: top.colorHex ?? "#888888"))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: top.colorHex ?? "#888888").opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectSubcategory?(top.subcategoryName)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            if size == .small {
                Spacer()  // Push down
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("Sin gastos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()  // Push up
            } else {
                Image(systemName: "list.bullet.rectangle.portrait")
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

    // MARK: - Formatters

    private func formattedAmount(_ value: Double) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Subcategory Row

private struct SubcategoryRow: View {
    let summary: SubcategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Name + Amount
                HStack(spacing: 12) {
                    // Icon (Default placeholder as requested)
                    ZStack {
                        Circle()
                            .fill(Color(hex: summary.colorHex ?? "#888888").opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: "tag.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(hex: summary.colorHex ?? "#888888"))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(summary.subcategoryName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(
                                NetoFormatter.currency(
                                    value: summary.amount, currencyCode: currencyCode)
                            )
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        }

                        // Percentages logic
                        HStack(spacing: 8) {
                            Text(
                                "\(formattedPercentage(summary.percentageOfCategory)) de \(summary.category?.name ?? "Categ.")"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.5))

                            Text("\(formattedPercentage(summary.percentageOfTotal)) del total")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        // Bar
                        GeometryReader { geo in
                            let width =
                                maxAmount > 0 ? (summary.amount / maxAmount) * geo.size.width : 0
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.1)).frame(height: 6)
                                Capsule().fill(Color(hex: summary.colorHex ?? "#888888")).frame(
                                    width: width, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }

    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
