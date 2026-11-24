//
//  CashFlowTableView.swift
//  Yala
//
//  Main cash flow view: horizontal month strip + full-width month detail.
//  Strip shows capsules for each month; detail shows lines, progress, summary.
//

import SwiftUI
import SwiftData

struct CashFlowTableView: View {

    // MARK: - Properties

    @Bindable var viewModel: CashFlowPlanViewModel
    let transactions: [TransactionItem]
    let categories: [Category]
    let scheduledPayments: [ScheduledPayment]
    let accounts: [Account]
    let currencyCode: String

    // Tour
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showTour = false
    @State private var tourIndex = 0
    @State private var scrollProxy: ScrollViewProxy?

    @Environment(\.yalaTheme) private var theme

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // La barra «Comparativa / Flujo de caja», fija dentro del scroll (`ReportChipsHeaderStack`).
                ReportChipsHeaderStack {
                    if let projection = viewModel.projection {
                        VStack(spacing: DS.Spacing.none) {
                            // Month strip
                            CashFlowMonthStrip(
                                months: projection.months,
                                selectedMonthKey: $viewModel.selectedMonthKey,
                                currencyCode: currencyCode
                            )

                            // Month detail for selected month
                            if let month = projection.months.first(where: { $0.monthKey == viewModel.selectedMonthKey }) {
                                CashFlowMonthDetailView(
                                    month: month,
                                    viewModel: viewModel,
                                    currencyCode: currencyCode,
                                    transactions: transactions,
                                    onCellDetailDismiss: { recalculate() }
                                )
                                // Deslizar cambia de mes sin quitarle el arrastre vertical al scroll. Un `DragGesture`
                                // aquí —con `.gesture` y también con `.simultaneousGesture`— dejaba la lista del mes sin
                                // desplazarse: solo se movía arrastrando desde la tira de meses (lote 18, medido).
                                .gesture(HorizontalSwipeGesture { towardsNext in
                                    navigateMonth(in: projection.months, forward: towardsNext)
                                })
                                .accessibilityAdjustableAction { direction in
                                    navigateMonth(in: projection.months, forward: direction == .increment)
                                }
                            }
                        }
                        // Ventana ancha: la tira de meses y el mes a 700 pt, centrados (decisión 7 de la revisión 2.3).
                        .readableColumn()
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .scrollDisabled(showTour)
            .onAppear { scrollProxy = proxy }
        }
        .coachMarkOverlay(
            steps: CashFlowTableTourSteps.steps,
            isPresented: $showTour,
            currentIndex: $tourIndex,
            scrollProxy: scrollProxy
        ) {
            appPreferences.hasSeenCashFlowTableTour = true
        }
        .onAppear {
            recalculate()
        }
        .onChange(of: viewModel.planRevision) { _, _ in recalculate() }
        .task {
            do {
                try await Task.sleep(for: .seconds(0.5))
            } catch {
                return
            }
            // UX 2.2 · L18-6: la guía de 3 pasos solo sale justo después de crear el plan, una vez. Abrir un plan que ya
            // existía (o que llegó de otro teléfono) no la enseña.
            if viewModel.projection != nil && viewModel.planJustCreated && !appPreferences.hasSeenCashFlowTableTour {
                showTour = true
            }
            viewModel.planJustCreated = false
        }
        .sheet(isPresented: $viewModel.showOthersBreakdown, onDismiss: { recalculate() }) {
            CashFlowOthersSheet(
                viewModel: viewModel,
                currencyCode: currencyCode
            )
        }
        .sheet(isPresented: $viewModel.showOthersIncomeBreakdown, onDismiss: { recalculate() }) {
            CashFlowOthersSheet(
                viewModel: viewModel,
                currencyCode: currencyCode,
                isIncome: true
            )
        }
        .sheet(isPresented: $viewModel.showAddLine, onDismiss: { recalculate() }) {
            CashFlowAddLineSheet(
                viewModel: viewModel,
                currencyCode: currencyCode,
                transactions: transactions
            )
        }
    }

    // MARK: - Navigation

    private func navigateMonth(in months: [CashFlowMonth], forward: Bool) {
        guard let idx = months.firstIndex(where: { $0.monthKey == viewModel.selectedMonthKey }) else { return }
        let next = forward ? idx + 1 : idx - 1
        guard months.indices.contains(next) else { return }
        // La tira lo anima con su implícita; el detalle del mes cambia en seco (card oxyr).
        viewModel.selectedMonthKey = months[next].monthKey
    }

    // MARK: - Recalculate

    /// Recalcula solo si cambió algo de lo que lee la proyección (`FlujoRecalculoFirma`): volver a la pestaña, cerrar la
    /// hoja de una línea que solo se miró o volver de Registros ya no repiten el cálculo entero (encargo de fluidez del
    /// 20-nov-2026). Un cambio del plan sube `planRevision` o guarda, y los dos entran en la firma.
    private func recalculate() {
        let firma = FlujoRecalculoFirma(
            planRevision: viewModel.planRevision,
            dataVersion: SessionState.shared.dataVersion,
            storeSaves: StoreSaveCounter.shared.count,
            transacciones: transactions.count,
            pagosProgramados: scheduledPayments.count,
            cuentas: accounts.count,
            categorias: categories.count,
            currencyCode: currencyCode,
            includeGroups: appPreferences.includeGroupsInPanelTotal,
            dia: Calendar.current.startOfDay(for: .now)
        )
        FlujoFluidezMedida.medir(.flujoRecalcular) {
            viewModel.recalculate(
                transactions: transactions,
                allExpenseCategories: categories.filter { !$0.isIncome },
                allIncomeCategories: categories.filter { $0.isIncome },
                scheduledPayments: scheduledPayments,
                currencyCode: currencyCode,
                converter: CurrencyConverter.shared,
                accounts: accounts,
                includeGroups: appPreferences.includeGroupsInPanelTotal,
                firma: firma
            )
        }
    }
}
