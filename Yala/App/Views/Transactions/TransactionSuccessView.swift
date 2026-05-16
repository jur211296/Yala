//
//  TransactionSuccessView.swift
//  Yala
//
//  Created by Yala - Success confirmation screen after transaction registration.
//

import SwiftUI

// MARK: - Transaction Success Data

/// Data structure holding the saved transaction details for display
struct TransactionSuccessData {
    let transactionType: TransactionType
    let date: Date
    let accountName: String
    let accountColorHex: String
    let note: String
    let amount: Decimal
    let currencyCode: String
    let subcategoryName: String?
    let subcategoryColorHex: String?
    let categoryName: String?
    let categoryColorHex: String?
    let tags: [(name: String, colorHex: String)]
    let need: SubcategoryNeed?

    // For transfers
    let isTransfer: Bool
    let destinationAccountName: String?
    let destinationAccountColorHex: String?
    let destinationAmount: Decimal?
    let destinationCurrencyCode: String?
}

// MARK: - Transaction Success View

struct TransactionSuccessView: View {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = AppLocale.current
        return f
    }()

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    let data: TransactionSuccessData
    let onAccept: () -> Void
    let onCreateAnother: () -> Void
    let onEdit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showHero = false
    @State private var showCheckmark = false
    @State private var showAmount = false
    @State private var showDetails = false
    @State private var showActions = false

    private var typeColor: Color { data.transactionType.color }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            // Subtle background glow
            RadialGradient(
                colors: [typeColor.opacity(0.06), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
            .frame(height: 300)
            .blur(radius: 40)
            .offset(y: -60)

            VStack(spacing: DS.Spacing.none) {
                // Edit button at top right - native iOS style (inverted)
                HStack {
                    Spacer()
                    Button(L10n.Action.edit, action: onEdit)
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)

                Spacer()

                // Hero area
                VStack(spacing: DS.Spacing.lg) {
                    // Title above circle
                    Text(L10n.Transaction.successTitle)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.secondary)
                        .opacity(showHero ? 1.0 : 0.0)

                    // Layered circle
                    ZStack {
                        // Radiant glow
                        RadialGradient(
                            colors: [typeColor.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 12)
                        .opacity(showHero ? 1.0 : 0.0)

                        // Main gradient circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [typeColor, typeColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: typeColor.opacity(0.4), radius: 20, y: 8)
                            .scaleEffect(showHero ? 1.0 : 0.3)
                            .opacity(showHero ? 1.0 : 0.0)

                        // Glass overlay
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .mask(
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .opacity(showHero ? 1.0 : 0.0)

                        // White checkmark
                        Image(systemName: "checkmark")
                            .font(.system(size: heroIconSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .scaleEffect(showCheckmark ? 1.0 : 0.0)
                            .opacity(showCheckmark ? 1.0 : 0.0)
                            .accessibilityHidden(true)
                    }

                    // Promoted amount
                    if data.isTransfer,
                       let destAmount = data.destinationAmount,
                       let destCurrency = data.destinationCurrencyCode,
                       destCurrency != data.currencyCode
                    {
                        Text(
                            appPreferences.currency(Double(truncating: data.amount as NSDecimalNumber),
                                currencyCode: data.currencyCode,
                                forceFullPrecision: true)
                            + " → "
                            + appPreferences.currency(Double(truncating: destAmount as NSDecimalNumber),
                                currencyCode: destCurrency,
                                forceFullPrecision: true)
                        )
                        .font(DS.Typography.title2)
                        .foregroundStyle(typeColor)
                        .scaleEffect(showAmount ? 1.0 : 0.8)
                        .opacity(showAmount ? 1.0 : 0.0)
                    } else {
                        AmountText(
                            value: Double(truncating: data.amount as NSDecimalNumber),
                            currencyCode: data.currencyCode,
                            size: .hero,
                            tint: .color(typeColor),
                            forceFullPrecision: true
                        )
                        .scaleEffect(showAmount ? 1.0 : 0.8)
                        .opacity(showAmount ? 1.0 : 0.0)
                    }
                }
                .padding(.bottom, DS.Spacing.xxxl)

                // Transaction details
                detailsSection
                    .padding(.horizontal, DS.Spacing.xl)
                    .opacity(showDetails ? 1.0 : 0.0)
                    .offset(y: showDetails ? 0 : 15)

                Spacer()

                // Action buttons - native iOS style
                VStack(spacing: DS.Spacing.md) {
                    // Primary: Accept
                    Button(action: onAccept) {
                        Text(L10n.Common.accept)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    .controlSize(.large)

                    // Secondary: Create another
                    Button(action: onCreateAnother) {
                        Text(L10n.Transaction.createAnother)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    .controlSize(.large)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
                .opacity(showActions ? 1.0 : 0.0)
                .offset(y: showActions ? 0 : 10)
            }
        }
        .onAppear {
            if reduceMotion {
                showHero = true
                showCheckmark = true
                showAmount = true
                showDetails = true
                showActions = true
            } else {
                Task {
                    // 0ms — hero circle + glow
                    withAnimation(.spring(response: 0.5, dampingFraction: DS.Animation.springBouncy)) {
                        showHero = true
                    }

                    // 150ms — checkmark
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.spring(response: 0.4, dampingFraction: DS.Animation.springBouncy)) {
                        showCheckmark = true
                    }

                    // 300ms — amount
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showAmount = true
                    }

                    // 500ms — details card
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.easeOut(duration: 0.35)) {
                        showDetails = true
                    }

                    // 700ms — action buttons
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.easeOut(duration: 0.3)) {
                        showActions = true
                    }
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: DS.Spacing.none) {
            // Transaction type
            typeRow

            // Date
            detailRow(
                icon: "calendar",
                label: L10n.Transaction.date,
                value: formattedDate
            )

            // Account(s)
            if data.isTransfer {
                transferAccountsRow
            } else {
                accountRow
            }

            // Subcategory & Category (only for non-transfers)
            if !data.isTransfer {
                if data.subcategoryName != nil || data.categoryName != nil {
                    categoryRow
                }

                // Nature (only for non-transfers)
                if let need = data.need {
                    needRow(need: need)
                }
            }

            // Note
            if !data.note.isEmpty {
                detailRow(
                    icon: "text.alignleft",
                    label: L10n.Transaction.note,
                    value: data.note
                )
            }

            // Tags
            if !data.tags.isEmpty {
                tagsRow
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }

    // MARK: - Row Components

    private var typeRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: data.transactionType.iconName)
                .font(DS.Typography.subheadline)
                .foregroundStyle(data.transactionType.color)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(L10n.Transaction.type)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(data.transactionType.displayName)
                .font(DS.Typography.label)
                .foregroundStyle(data.transactionType.color)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: data.date)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var accountRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "creditcard")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(L10n.Account.selectAccount)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color(hex: data.accountColorHex))
                    .frame(width: 8, height: 8)
                Text(data.accountName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var transferAccountsRow: some View {
        VStack(spacing: DS.Spacing.none) {
            // Source account
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.up.circle")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(Color.hotPink)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text(L10n.Transaction.origin)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: data.accountColorHex))
                        .frame(width: 8, height: 8)
                    Text(data.accountName)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)

            // Destination account
            if let destName = data.destinationAccountName,
                let destColor = data.destinationAccountColorHex
            {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "arrow.down.circle")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thAccent)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Text(L10n.Transaction.destination)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(Color(hex: destColor))
                            .frame(width: 8, height: 8)
                        Text(destName)
                            .font(DS.Typography.label)
                            .foregroundStyle(.primary)

                        if let destAmount = data.destinationAmount,
                            let destCurrency = data.destinationCurrencyCode,
                            destCurrency != data.currencyCode
                        {
                            Text(
                                "(\(appPreferences.currency(Double(truncating: destAmount as NSDecimalNumber), currencyCode: destCurrency, forceFullPrecision: true)))"
                            )
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.FormRow.paddingV)
            }
        }
    }

    private var categoryRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "tag")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(L10n.Transaction.category)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                if let subcatName = data.subcategoryName {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(
                                Color(
                                    hex: data.subcategoryColorHex ?? data.categoryColorHex
                                        ?? AppConstants.defaultColorHex)
                            )
                            .frame(width: 8, height: 8)
                        Text(subcatName)
                            .font(DS.Typography.label)
                            .foregroundStyle(.primary)
                    }
                }
                if let catName = data.categoryName {
                    Text(catName)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private func needRow(need: SubcategoryNeed) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "leaf")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(L10n.Category.need)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(need.color)
                    .frame(width: 6, height: 6)

                Text(need.displayName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule().fill(need.color.opacity(0.1))
            )
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var tagsRow: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            Image(systemName: "number")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(L10n.Transaction.tags)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Tags as chips - right aligned
            HStack(spacing: DS.Spacing.xs) {
                ForEach(data.tags, id: \.name) { tag in
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(Color(hex: tag.colorHex))
                            .frame(width: 6, height: 6)
                        Text(tag.name)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                    )
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }
}

#Preview {
    TransactionSuccessView(
        data: TransactionSuccessData(
            transactionType: .expense,
            date: Date.now,
            accountName: "Soles",
            accountColorHex: "FF6B6B",
            note: "Compra en supermercado",
            amount: 125.50,
            currencyCode: "PEN",
            subcategoryName: "Alimentación",
            subcategoryColorHex: "4CAF50",
            categoryName: "Hogar",
            categoryColorHex: "4CAF50",
            tags: [
                (name: "Necesario", colorHex: "2196F3"),
                (name: "Mensual", colorHex: "9C27B0"),
            ],
            need: .essential,
            isTransfer: false,
            destinationAccountName: nil,
            destinationAccountColorHex: nil,
            destinationAmount: nil,
            destinationCurrencyCode: nil
        ),
        onAccept: {},
        onCreateAnother: {},
        onEdit: {}
    )
}
