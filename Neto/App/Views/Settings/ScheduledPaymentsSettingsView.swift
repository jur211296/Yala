//
//  ScheduledPaymentsSettingsView.swift
//  Neto
//
//  Manage scheduled/recurring payments from Profile settings.
//  Similar to FavoritesListView - create, edit, delete scheduled payments.
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ScheduledPayment.name)
    private var allPayments: [ScheduledPayment]

    @State private var showEditor = false
    @State private var paymentToEdit: ScheduledPayment?

    var body: some View {
        ZStack {
            PanelBackgroundView()

            if allPayments.isEmpty {
                emptyState
            } else {
                paymentsList
            }
        }
        .navigationTitle(NSLocalizedString("settings.scheduled.payments", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NetoToolbarButton(systemName: "plus") {
                    paymentToEdit = nil
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ScheduledPaymentEditorView(payment: paymentToEdit)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.electricIndigo, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DS.Spacing.sm) {
                Text(NSLocalizedString("scheduled.empty.title", comment: ""))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("scheduled.empty.settings.hint", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Payments List

    private var paymentsList: some View {
        List {
            ForEach(allPayments, id: \.persistentModelID) { payment in
                paymentRow(payment)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: deletePayments)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func paymentRow(_ payment: ScheduledPayment) -> some View {
        Button {
            paymentToEdit = payment
            showEditor = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(payment.isActive ? Color.electricIndigo.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: payment.isRecurring ? "repeat" : "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(payment.isActive ? Color.electricIndigo : Color.gray)
                }

                // Info
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(payment.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(payment.isActive ? .primary : .secondary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.sm) {
                        // Amount
                        Text(formatAmount(payment.amount, currency: payment.currencyCode))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Recurrence info
                        if payment.isRecurring {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(recurrenceDescription(payment))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Status badge
                if !payment.isActive {
                    Text(NSLocalizedString("scheduled.inactive", comment: ""))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.netoCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func deletePayments(at offsets: IndexSet) {
        for index in offsets {
            let payment = allPayments[index]
            modelContext.delete(payment)
        }
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }

    private func recurrenceDescription(_ payment: ScheduledPayment) -> String {
        let type = RecurrenceType(rawValue: payment.recurrenceType) ?? .monthly
        let interval = payment.recurrenceInterval

        if interval == 1 {
            return type.localizedName
        } else {
            return "\(interval) \(type.localizedNamePlural)"
        }
    }
}

#Preview {
    NavigationStack {
        ScheduledPaymentsSettingsView()
    }
}
