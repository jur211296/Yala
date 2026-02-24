//
//  TransactionAssociationSheet.swift
//  Yala
//
//  Sheet for associating an existing transaction with a scheduled payment
//

import SwiftData
import SwiftUI

struct TransactionAssociationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let payment: ScheduledPayment
    let selectedMonth: Date
    @Bindable var viewModel: ScheduledPaymentsViewModel

    @State private var candidates: [TransactionItem] = []
    @State private var showConfirmation: Bool = false
    @State private var selectedTransaction: TransactionItem?

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                if candidates.isEmpty {
                    emptyState
                } else {
                    candidatesList
                }
            }
            .navigationTitle(NSLocalizedString("scheduled.associate.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                candidates = viewModel.fetchCandidateTransactions(for: payment, month: selectedMonth)
            }
            .alert(
                NSLocalizedString("scheduled.associate.confirm", comment: ""),
                isPresented: $showConfirmation
            ) {
                Button(L10n.Action.cancel, role: .cancel) {
                    selectedTransaction = nil
                }
                Button(L10n.Common.accept) {
                    if let tx = selectedTransaction {
                        viewModel.associateTransaction(tx, to: payment)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState(
            icon: "magnifyingglass",
            title: NSLocalizedString("scheduled.associate.empty", comment: "")
        )
    }

    // MARK: - Candidates List

    private var candidatesList: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.sm) {
                // Header with payment info
                paymentInfoHeader

                ForEach(candidates, id: \.persistentModelID) { transaction in
                    candidateRow(transaction)
                }
            }
            .padding(DS.Spacing.lg)
        }
    }

    private var paymentInfoHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            let color = payment.subcategory?.colorHex ?? payment.subcategory?.category?.colorHex ?? "#6366F1"
            let icon = payment.subcategory?.iconName ?? payment.subcategory?.category?.iconName ?? "calendar.badge.clock"

            ZStack {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(payment.name)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                Text(YalaFormatter.currency(value: payment.amount, currencyCode: payment.currencyCode, forceFullPrecision: true))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .padding(.bottom, DS.Spacing.sm)
    }

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func candidateRow(_ transaction: TransactionItem) -> some View {
        return Button {
            selectedTransaction = transaction
            showConfirmation = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Category icon
                if let sub = transaction.subcategory {
                    let subColor = sub.colorHex ?? sub.safeCategory.colorHex
                    let subIcon = sub.iconName ?? sub.safeCategory.iconName ?? "tag"
                    ZStack {
                        Circle()
                            .fill(Color(hex: subColor))
                            .frame(width: 32, height: 32)
                        Image(systemName: subIcon)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.white)
                    }
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "tag")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(transaction.note ?? Self.mediumDateFormatter.string(from: transaction.date))
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        Text(Self.mediumDateFormatter.string(from: transaction.date))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        if let accountName = transaction.account?.name {
                            Text("•")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text(accountName)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if transaction.currencyCode != payment.currencyCode {
                    Text(transaction.currencyCode)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            Capsule().fill(DS.Semantic.warningBackground)
                        )
                }

                Text(YalaFormatter.currency(value: transaction.amount, currencyCode: transaction.currencyCode, forceFullPrecision: true))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
            }
            .padding(DS.Spacing.md)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
