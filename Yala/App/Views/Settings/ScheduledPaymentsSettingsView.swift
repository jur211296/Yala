//
//  ScheduledPaymentsSettingsView.swift
//  Yala
//
//  Manage scheduled/recurring payments from Profile settings.
//  Similar to FavoritesListView - create, edit, delete scheduled payments.
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ScheduledPaymentsSettingsViewModel()

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 0) {
                // Tab selector
                Picker("Tab", selection: $viewModel.selectedTab) {
                    ForEach(ScheduledPaymentsTab.allCases) { tab in
                        Text(tab.localizedName).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)

                // Content
                if viewModel.isEmpty {
                    emptyState
                } else {
                    paymentsList
                }
            }
        }
        .navigationTitle(NSLocalizedString("settings.plannedPayments", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "plus", label: "Agregar") {
                    viewModel.openEditor(for: nil)
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditor, onDismiss: { viewModel.closeEditor() }) {
            ScheduledPaymentEditorView(
                payment: viewModel.paymentToEdit,
                defaultCategory: viewModel.selectedTab.categoryFilter
            )
        }
        .alert(
            L10n.Common.error,
            isPresented: $viewModel.showDeleteError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(L10n.Common.deleteError)
            }
        )
        .onAppear {
            viewModel.setContext(modelContext)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            YalaEmptyState.noScheduledPayments()
            Spacer()
        }
    }

    // MARK: - Payments List

    private var paymentsList: some View {
        List {
            ForEach(viewModel.filteredPayments, id: \.persistentModelID) { payment in
                paymentRow(payment)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: viewModel.deletePayments)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func paymentRow(_ payment: ScheduledPayment) -> some View {
        // Get icon and color from subcategory
        let iconName = payment.subcategory?.iconName ?? payment.subcategory?.category?.iconName ?? "creditcard.fill"
        let colorHex = payment.subcategory?.colorHex ?? payment.subcategory?.category?.colorHex ?? "#6366F1"

        return Button {
            viewModel.openEditor(for: payment)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon from subcategory
                ZStack {
                    Circle()
                        .fill(payment.isActive ? Color(hex: colorHex).opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(payment.isActive ? Color(hex: colorHex) : Color.gray)
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
                    .fill(Color.yalaCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
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
