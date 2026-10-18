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
    @Environment(SceneNavigation.self) private var navigation
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @Environment(AppPreferences.self) private var appPreferences

    // ViewModel
    @State private var viewModel = ScheduledPaymentsViewModel()
    /// Sube al cerrarse el editor: es cuando se pregunta «¿era de prueba?» (UX 2.2 · L5-5).
    @State private var paymentEditorClosedToken = 0
    /// El pago recién creado, para avisar al cerrar el editor cuándo es su primer pago (UX 2.2 · L10-5).
    @State private var newlySavedPaymentID: UUID?

    var body: some View {
        ZStack {
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
        .yalaScreenBackground(.panel)
        .sheet(isPresented: $viewModel.showPaymentEditor, onDismiss: {
            paymentEditorClosedToken += 1
            announceFirstPaymentIfNew()
        }) {
            if let payment = viewModel.editingPayment {
                ScheduledPaymentEditorView(payment: payment)
                    .onDisappear {
                        viewModel.editingPayment = nil
                        refreshData()
                    }
            } else {
                ScheduledPaymentEditorView(
                    payment: nil,
                    defaultCategory: viewModel.selectedTab.categoryFilter,
                    onSaved: { newlySavedPaymentID = $0 }
                )
                    .onDisappear {
                        refreshData()
                    }
            }
        }
        // «¿Era de prueba?» del primer pago, al cerrar el editor y aquí mismo (UX 2.2 · L5-5).
        .practiceCleanupPrompt(for: [.scheduledPayment], editorClosedToken: paymentEditorClosedToken) { refreshData() }
        .appliesPendingRemoteChanges(sessionState)
        .onAppear {
            viewModel.setContext(modelContext)
            viewModel.calculatePaymentData(payments: viewModel.allPayments)

            // Auto-open editor from setup checklist — routed via AppRouter now.
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
        .modifier(ScheduledPaymentAlertOpening(viewModel: viewModel))
        .navigationDestination(for: PersistentIdentifier.self) { paymentID in
            ScheduledPaymentDetailDestination(paymentID: paymentID, viewModel: viewModel)
                .announcesShownInDetailColumn()
        }
        // Peek first so we only drain intents this view handles —
        // BudgetsListView shares the .planning consumer.
        .routerConsumer(.planning) {
            if case .autoOpenScheduledEditor = AppRouter.shared.peekNext(for: .planning, in: navigation.id) {
                _ = AppRouter.shared.drainNext(for: .planning, in: navigation.id)
                viewModel.editingPayment = nil
                viewModel.showPaymentEditor = true
            }
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

                CircularPlusFAB(
                    tint: theme.accent,
                    accessibilityLabel: L10n.Accessibility.newPayment,
                    accessibilityIdentifier: "scheduled_payments_create_fab"
                ) {
                    viewModel.createNewPayment()
                }
                .dsFloatingShadow()
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

    /// «Listo. Primer pago: 1 de noviembre · Ver» (UX 2.2 · L10-5, opción B). Si el primer pago cae otro mes, la lista de
    /// este no cambia y la persona creía que no se había guardado; «Ver» la lleva a ese mes.
    private func announceFirstPaymentIfNew() {
        guard let id = newlySavedPaymentID else { return }
        newlySavedPaymentID = nil
        let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        let payment: ScheduledPayment
        do {
            guard let found = try modelContext.fetch(descriptor).first else { return }
            payment = found
        } catch {
            #if DEBUG
            print("ScheduledPaymentsView: Error: \(error)")
            #endif
            return
        }
        let firstDate = payment.nextDueDate
        DraftDiscardUndoNotice.show(
            message: L10n.UXL10.savedFirstPayment(ScheduledPaymentDateText.dayMonthLong(firstDate)),
            systemImage: "checkmark.circle",
            undoTitle: L10n.UXL10.savedView,
            noticeIdentifier: "scheduled_saved_notice",
            undoIdentifier: "scheduled_saved_view"
        ) {
            viewModel.selectedMonth = firstDate
            viewModel.recalculateData()
        }
    }
}

/// Abre el pago de un recordatorio tocado (`SceneNavigation.pendingScheduledPaymentID`, UX 2.2 · L10-13): vuelve al mes
/// en curso y empuja su detalle. Prepara él mismo el contexto del ViewModel: su `onAppear` puede correr antes que el de
/// la lista (la trampa que midió el lote 9 con las alertas de presupuesto).
private struct ScheduledPaymentAlertOpening: ViewModifier {
    @Bindable var viewModel: ScheduledPaymentsViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(SceneNavigation.self) private var navigation
    @State private var openedPayment: ScheduledPaymentNavigationID?

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $openedPayment) { navID in
                ScheduledPaymentDetailDestination(paymentID: navID.id, viewModel: viewModel)
                    .announcesShownInDetailColumn()
            }
            .onAppear { openPendingIfAny() }
            .onChange(of: navigation.pendingScheduledPaymentID) { _, _ in openPendingIfAny() }
    }

    private func openPendingIfAny() {
        guard let paymentID = navigation.pendingScheduledPaymentID else { return }
        navigation.pendingScheduledPaymentID = nil
        viewModel.setContext(modelContext)
        viewModel.loadPayments()
        guard let payment = viewModel.allPayments.first(where: { $0.id == paymentID }) else { return }
        viewModel.selectedMonth = Date.now
        // Una vuelta del main actor después: el recordatorio llega con la pestaña de Pagos montándose en ese mismo
        // instante (cambia el chip de Planificación), y un empuje pedido en su primer `onAppear` se perdía sin aviso
        // (medido con `-uitest-scheduled-alert-tap`).
        let navID = ScheduledPaymentNavigationID(id: payment.persistentModelID)
        Task { @MainActor in
            openedPayment = navID
        }
    }
}

/// Identidad del pago abierto desde un recordatorio, para `navigationDestination(item:)`.
struct ScheduledPaymentNavigationID: Hashable, Identifiable {
    let id: PersistentIdentifier
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
                // Mismo caso que el presupuesto: en la columna de detalle la vista se reutiliza al abrir otro pago, y
                // sus `@State` (los registros enlazados de la `.task`, la ocurrencia elegida) serían del anterior.
                .id(paymentID)
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
    .environment(SceneNavigation())
}
