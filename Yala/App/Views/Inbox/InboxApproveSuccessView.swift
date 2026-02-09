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
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 36

    let data: InboxApproveSuccessData
    let hasNextDraft: Bool
    let onEdit: () -> Void
    let onAccept: () -> Void
    let onApproveNext: () -> Void

    var body: some View {
        ZStack {
            Color.yalaBackground.ignoresSafeArea()

            VStack(spacing: DS.Spacing.none) {
                // Edit button at top right
                HStack {
                    Spacer()
                    Button(L10n.Action.edit, action: onEdit)
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)

                Spacer()

                // Success icon and title
                VStack(spacing: DS.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.electricIndigo.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "checkmark")
                            .font(.system(size: heroIconSize, weight: .semibold))
                            .foregroundStyle(Color.electricIndigo)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }

                    Text(L10n.Inbox.approveSuccess)
                        .font(DS.Typography.title)
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, DS.Spacing.xxxl)

                // Transaction details
                detailsSection
                    .padding(.horizontal, DS.Spacing.xl)

                Spacer()

                // Action buttons
                actionButtons
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxxl)
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: DS.Spacing.none) {
            // Amount (prominent)
            amountRow

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
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color.yalaCard)
        )
    }

    private var amountRow: some View {
        HStack {
            Text(L10n.Transaction.total)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(YalaFormatter.currency(value: data.amount, currencyCode: data.currencyCode, forceFullPrecision: true))
                .font(DS.Typography.largeTitle)
                .foregroundStyle(data.isExpense ? Color.hotPink : Color.electricIndigo)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.lg)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = AppLocale.current
        return formatter.string(from: data.date)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

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

            Text(L10n.Transaction.account)
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

    private var categoryRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "tag")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(L10n.Transaction.category)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: data.categoryColorHex))
                        .frame(width: 8, height: 8)
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
            .tint(Color.electricIndigo)
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
                .tint(Color.electricIndigo)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    InboxApproveSuccessView(
        data: InboxApproveSuccessData(
            date: Date(),
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
