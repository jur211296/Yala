//
//  InboxApproveSuccessView.swift
//  Yala
//
//  Success screen after approving a draft from Inbox.
//  Shows transaction details with options: Edit, Accept, Approve Next.
//

import SwiftUI

/// Data for displaying approved transaction details
struct InboxApproveSuccessData {
    let date: Date
    let accountName: String
    let accountColorHex: String
    let note: String
    let amount: Double
    let currencyCode: String
    let subcategoryName: String
    let categoryName: String
    let categoryColorHex: String
    let isExpense: Bool
}

struct InboxApproveSuccessView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    let data: InboxApproveSuccessData
    let hasNextDraft: Bool
    let onEdit: () -> Void
    let onAccept: () -> Void
    let onApproveNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showHero = false
    @State private var showCheckmark = false
    @State private var showAmount = false
    @State private var showDetails = false
    @State private var showActions = false

    private var typeColor: Color { data.isExpense ? Color.hotPink : Color.electricIndigo }

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
                // Edit button at top right
                HStack {
                    Spacer()
                    Button(L10n.Action.edit, action: onEdit)
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
                .opacity(showActions ? 1.0 : 0.0)

                Spacer()

                // Hero area
                VStack(spacing: DS.Spacing.lg) {
                    // Title above circle
                    Text(L10n.Inbox.approveSuccess)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.secondary)
                        .opacity(showHero ? 1.0 : 0.0)

                    // Layered circle (shared component with internal cascade hero → checkmark)
                    SuccessHeroView(
                        icon: "checkmark",
                        gradientColors: [typeColor, typeColor.opacity(0.7)],
                        glowColor: typeColor.opacity(0.25),
                        iconSize: heroIconSize,
                        appeared: showHero,
                        reduceMotion: reduceMotion
                    )
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityHidden(true)

                    // Promoted amount
                    Text(appPreferences.currency(data.amount, currencyCode: data.currencyCode, forceFullPrecision: true))
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(typeColor)
                        .scaleEffect(showAmount ? 1.0 : 0.8)
                        .opacity(showAmount ? 1.0 : 0.0)
                }
                .padding(.bottom, DS.Spacing.xxxl)

                // Transaction details
                detailsSection
                    .padding(.horizontal, DS.Spacing.xl)
                    .opacity(showDetails ? 1.0 : 0.0)
                    .offset(y: showDetails ? 0 : 15)

                Spacer()

                // Action buttons
                actionButtons
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
                    do {
                        // 0ms — hero circle + glow
                        withAnimation(.spring(response: 0.5, dampingFraction: DS.Animation.springBouncy)) {
                            showHero = true
                        }

                        // 150ms — checkmark
                        try await Task.sleep(for: .milliseconds(150))
                        withAnimation(.spring(response: 0.4, dampingFraction: DS.Animation.springBouncy)) {
                            showCheckmark = true
                        }

                        // 300ms — amount
                        try await Task.sleep(for: .milliseconds(150))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showAmount = true
                        }

                        // 500ms — details card
                        try await Task.sleep(for: .milliseconds(200))
                        withAnimation(.easeOut(duration: 0.35)) {
                            showDetails = true
                        }

                        // 700ms — action buttons
                        try await Task.sleep(for: .milliseconds(200))
                        withAnimation(.easeOut(duration: 0.3)) {
                            showActions = true
                        }
                    } catch {
                        // Task cancelled — stop animation sequence
                        return
                    }
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: DS.Spacing.none) {
            // Date
            detailRow(
                icon: "calendar",
                label: L10n.Transaction.date,
                value: formattedDate
            )

            // Account
            accountRow

            // Category/Subcategory
            categoryRow

            // Note
            if !data.note.isEmpty {
                detailRow(
                    icon: "text.alignleft",
                    label: L10n.Transaction.note,
                    value: data.note
                )
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .panelCard()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = AppLocale.current
        return formatter
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: data.date)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: DS.Icon.sizeLarge)
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
                .frame(width: DS.Icon.sizeLarge)
                .accessibilityHidden(true)

            Text(L10n.Transaction.account)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color(hex: data.accountColorHex))
                    .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
                Text(data.accountName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var categoryRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "tag")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: DS.Icon.sizeLarge)
                .accessibilityHidden(true)

            Text(L10n.Transaction.category)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: data.categoryColorHex))
                        .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
                    Text(data.subcategoryName)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                }
                Text(data.categoryName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.md) {
            // Primary: Accept (go back to inbox)
            Button(action: onAccept) {
                Text(L10n.Common.accept)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            .controlSize(.large)

            // Secondary: Approve next (if available)
            if hasNextDraft {
                Button(action: onApproveNext) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text(L10n.Inbox.approveNext)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                .controlSize(.large)
            }
        }
    }
}

#Preview {
    InboxApproveSuccessView(
        data: InboxApproveSuccessData(
            date: Date.now,
            accountName: "Efectivo",
            accountColorHex: "4CAF50",
            note: "Almuerzo con amigos",
            amount: -45.50,
            currencyCode: "PEN",
            subcategoryName: "Restaurantes",
            categoryName: "Alimentación",
            categoryColorHex: "FF9800",
            isExpense: true
        ),
        hasNextDraft: true,
        onEdit: {},
        onAccept: {},
        onApproveNext: {}
    )
}
