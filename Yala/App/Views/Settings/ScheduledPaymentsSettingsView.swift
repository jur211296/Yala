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
    @Environment(AppPreferences.self) private var appPreferences

    @State private var viewModel = ScheduledPaymentsSettingsViewModel()

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DS.Spacing.none) {
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
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "plus", label: L10n.Action.add) {
                    viewModel.openEditor(for: nil)
                }
                .accessibilityIdentifier("scheduled_add_button")
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
        let colorHex = payment.subcategory?.colorHex ?? payment.subcategory?.category?.colorHex ?? AppConstants.defaultColorHex

        return Button {
            viewModel.openEditor(for: payment)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon from subcategory
                ZStack {
                    Circle()
                        .fill(payment.isActive ? Color(hex: colorHex).opacity(0.15) : DS.Semantic.neutralBackground)
                        .frame(width: 44, height: 44)

                    Image(systemName: iconName)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(payment.isActive ? Color(hex: colorHex) : DS.Semantic.disabledForeground)
                }

                // Info
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(payment.name)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(payment.isActive ? .primary : .secondary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.sm) {
                        // Amount
                        AmountText(
                            value: payment.amount,
                            currencyCode: payment.currencyCode,
                            font: DS.Typography.caption,
                            tint: .secondary,
                            isEstimate: payment.isVariableAmount
                        )

                        // Recurrence info
                        if payment.isRecurring {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(recurrenceDescription(payment))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Status badge
                if !payment.isActive {
                    Text(NSLocalizedString("scheduled.inactive", comment: ""))
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.indicator)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.md)
            .solidCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scheduled_row_\(payment.name)")
    }

    // MARK: - Helpers

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f
    }()

    private func formatAmount(_ amount: Double, currency: String) -> String {
        Self.amountFormatter.currencyCode = currency
        return Self.amountFormatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
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
