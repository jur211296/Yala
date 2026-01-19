//
//  ScheduledPaymentsView.swift
//  Neto
//
//  Main container view for scheduled payments with tab selection
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsView: View {
    @Environment(\.modelContext) private var modelContext

    // Data Queries
    @Query(sort: \ScheduledPayment.nextDueDate)
    private var allPayments: [ScheduledPayment]

    @Query(sort: \Account.name)
    private var accounts: [Account]

    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    @Query(filter: #Predicate<Tag> { $0.isActive })
    private var tags: [Tag]

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

    // ViewModel
    @State private var viewModel = ScheduledPaymentsViewModel()

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 0) {
                    // Tab segmented control
                    tabSelector
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.md)

                    // Content based on selected tab
                    if viewModel.selectedTab == .subscriptions {
                        // Subscriptions tab has its own custom view
                        SubscriptionsContentView(
                            viewModel: viewModel,
                            subscriptions: viewModel.getSubscriptions(from: allPayments),
                            currencyCode: defaultCurrencyCode
                        )
                    } else {
                        // Recurring and All tabs use the standard list view
                        ScheduledPaymentsListView(
                            viewModel: viewModel,
                            currencyCode: defaultCurrencyCode,
                            onRefresh: { refreshData() }
                        )
                    }
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
            refreshData()
        }
        .onChange(of: viewModel.selectedTab) { _, _ in
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
                        .font(.system(size: 24, weight: .bold))
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

    // MARK: - Data Management

    private func refreshData() {
        viewModel.calculatePaymentData(payments: allPayments)
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
