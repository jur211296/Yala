//
//  ScheduledPaymentPeriodSelectorSheet.swift
//  Yala
//
//  Elegir el mes que enseña Pagos planificados. La rueda es la nativa de iOS, la misma de Presupuestos
//  (`BudgetPeriodWheelSheet`, UX 2.2 · L9-8). La rueda propia de antes vivía en un `ScrollView` dentro de una hoja a
//  media altura: arrastrarla hacia abajo cerraba la hoja y sus franjas de degradado se veían como bandas oscuras.
//

import SwiftUI

struct ScheduledPaymentPeriodSelectorSheet: View {
    @Bindable var viewModel: ScheduledPaymentsViewModel
    var payments: [ScheduledPayment]
    var onPeriodChange: () -> Void

    var body: some View {
        BudgetPeriodWheelSheet(
            periodType: .monthly,
            initialWeek: viewModel.selectedMonth,
            initialMonth: viewModel.selectedMonth,
            initialYear: Calendar.current.component(.year, from: viewModel.selectedMonth),
            // La rueda empieza en el mes del pago más antiguo y llega a un año vista, como antes.
            oldestRecordDate: payments.map(\.createdAt).min(),
            title: NSLocalizedString("scheduled.period.selector.title", comment: "")
        ) { _, month, _ in
            viewModel.selectedMonth = month
            onPeriodChange()
        }
    }
}
