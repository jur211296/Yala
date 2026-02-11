//
//  ScheduledPaymentsView.swift
//  Yala
//
//  Main container view for scheduled payments with tab selection
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

    // ViewModel
    @State private var viewModel = ScheduledPaymentsViewModel()

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    // Tab segmented control
                    tabSelector
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.md)

                    // Content - unified view for all tabs
                    ScheduledPaymentsListView(
                        viewModel: viewModel,
                        payments: filteredPaymentsForCurrentTab,
                        tab: viewModel.selectedTab,
                        currencyCode: defaultCurrencyCode,
                        onRefresh: { refreshData() }
                    )
                }
            }

            // FAB button for new payment
            newPaymentFAB
        }
        .sheet(isPresented: $viewModel.showPaymentEditor) {
            if let payment = viewModel.editingPayment {
                ScheduledPaymentEditorView(payment: payment)
                    .onDisappear {
                        viewModel.editingPayment = nil
                        refreshData()
                    }
            } else {
                ScheduledPaymentEditorView(
                    payment: nil,
                    defaultCategory: viewModel.selectedTab.categoryFilter
                )
                    .onDisappear {
                        refreshData()
                    }
            }
        }
        .onAppear {
            viewModel.setContext(modelContext)
            refreshData()
        }
        .onChange(of: viewModel.selectedTab) { _, _ in
            refreshData()
        }
        .onChange(of: sessionState.dataVersion) { _, _ in
            refreshData()
        }
        .navigationDestination(for: PersistentIdentifier.self) { paymentID in
            ScheduledPaymentDetailDestination(paymentID: paymentID)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        Picker("Tab", selection: $viewModel.selectedTab) {
            ForEach(ScheduledPaymentsTab.allCases) { tab in
                Text(tab.localizedName).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }


    // MARK: - New Payment FAB

    private var newPaymentFAB: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    viewModel.createNewPayment()
                } label: {
                    Image(systemName: "plus")
                        .font(DS.Typography.title)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.electricIndigo)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Filtered Payments

    private var filteredPaymentsForCurrentTab: [ScheduledPayment] {
        switch viewModel.selectedTab {
        case .all:
            return viewModel.allPayments
        case .recurring:
            return viewModel.getRecurringPayments(from: viewModel.allPayments)
        case .subscriptions:
            return viewModel.getSubscriptions(from: viewModel.allPayments)
        }
    }

    // MARK: - Data Management

    private func refreshData() {
        viewModel.loadPayments()
        viewModel.calculatePaymentData(payments: viewModel.allPayments)
    }
}

// MARK: - Detail Destination Helper

/// Helper view that resolves PersistentIdentifier to ScheduledPayment for navigation
private struct ScheduledPaymentDetailDestination: View {
    let paymentID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let payment = modelContext.model(for: paymentID) as? ScheduledPayment {
            ScheduledPaymentDetailView(payment: payment)
        } else {
            ContentUnavailableView(
                NSLocalizedString("scheduled.detail.not.found", comment: "Payment not found"),
                systemImage: "exclamationmark.triangle"
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScheduledPaymentsView()
    }
}
