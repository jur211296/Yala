//
//  ScheduledPaymentsListView.swift
//  Neto
//
//  List view for scheduled payments grouped by due status
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsListView: View {
    @Bindable var viewModel: ScheduledPaymentsViewModel
    let currencyCode: String
    let onRefresh: () -> Void

    var body: some View {
        if viewModel.groupedPayments.isEmpty {
            emptyState
        } else {
            paymentsList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xxl) {
            ZStack {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: emptyStateIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.electricIndigo, Color.hotPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DS.Spacing.sm) {
                Text(emptyStateTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl * 2)
    }

    private var emptyStateIcon: String {
        switch viewModel.selectedTab {
        case .recurring:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        case .subscriptions:
            return "creditcard.and.123"
        case .all:
            return "calendar.badge.clock"
        }
    }

    private var emptyStateTitle: String {
        NSLocalizedString("scheduled.empty.title", comment: "No scheduled payments")
    }

    private var emptyStateMessage: String {
        NSLocalizedString("scheduled.empty.message", comment: "Add your first scheduled payment")
    }

    // MARK: - Payments List

    private var paymentsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ForEach(viewModel.groupedPayments, id: \.status) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Section header
                    HStack(spacing: DS.Spacing.sm) {
                        Circle()
                            .fill(sectionColor(for: section.status))
                            .frame(width: 8, height: 8)

                        Text(section.status.localizedName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("(\(section.payments.count))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    // Payment cards
                    ForEach(section.payments) { summary in
                        ScheduledPaymentRowView(
                            summary: summary,
                            currencyCode: currencyCode
                        ) {
                            viewModel.editPayment(summary.payment)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                    }
                }
            }
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, 100)  // Space for FAB
    }

    private func sectionColor(for status: DueStatus) -> Color {
        switch status {
        case .past:
            return Color.hotPink
        case .today:
            return Color.orange
        case .upcoming:
            return Color.electricIndigo
        }
    }
}
