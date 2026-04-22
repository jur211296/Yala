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
    @Environment(\.yalaTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @Environment(AppPreferences.self) private var appPreferences

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
                        currencyCode: appPreferences.defaultCurrencyCode.rawValue,
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
        .appliesPendingRemoteChanges(sessionState)
        .onAppear {
            viewModel.setContext(modelContext)
            viewModel.calculatePaymentData(payments: viewModel.allPayments)

            // Auto-open editor from setup checklist (step 4)
            if sessionState.shouldAutoOpenScheduledEditor {
                sessionState.shouldAutoOpenScheduledEditor = false
                viewModel.editingPayment = nil
                viewModel.showPaymentEditor = true
            }
        }
        .onDisappear {
            viewModel.cancelRecalculation()
        }
        .onChange(of: scenePhase) { _, phase in
            viewModel.setBackground(phase != .active)
        }
        .onChange(of: viewModel.selectedTab) { _, _ in
            viewModel.recalculateData()
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            viewModel.recalculateData()
        }
        .onChange(of: sessionState.dataVersion) { _, _ in
            refreshData()
        }
        .navigationDestination(for: PersistentIdentifier.self) { paymentID in
            ScheduledPaymentDetailDestination(paymentID: paymentID, viewModel: viewModel)
        }
        // AppRouter consumer (F2). Drain switch for .autoOpenScheduledEditor lands in F7.
        .routerConsumer(.planning) {
            _ = AppRouter.shared.drainNext(for: .planning)
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
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Accessibility.newPayment)
                .glassEffect(.regular.interactive())
                .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
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
        viewModel.reloadAndRecalculate()
    }
}

// MARK: - Detail Destination Helper

/// Helper view that resolves PersistentIdentifier to ScheduledPayment for navigation
private struct ScheduledPaymentDetailDestination: View {
    let paymentID: PersistentIdentifier
    @Bindable var viewModel: ScheduledPaymentsViewModel

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let payment = modelContext.model(for: paymentID) as? ScheduledPayment {
            ScheduledPaymentDetailView(payment: payment, viewModel: viewModel)
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
