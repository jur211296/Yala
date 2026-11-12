//
//  BudgetPeriodSelectorSheet.swift
//  Yala
//
//  Elegir la semana, el mes o el año que enseña la lista de Presupuestos. La rueda es la nativa de iOS
//  (`BudgetPeriodWheelSheet`, UX 2.2 · L9-8).
//

import SwiftUI

struct BudgetPeriodSelectorSheet: View {
    @Bindable var viewModel: BudgetsViewModel
    /// El movimiento más antiguo guardado: la rueda empieza en su período.
    var oldestRecordDate: Date?
    var onPeriodChange: () -> Void

    var body: some View {
        BudgetPeriodWheelSheet(
            periodType: viewModel.selectedPeriodType,
            initialWeek: viewModel.selectedWeek,
            initialMonth: viewModel.selectedMonth,
            initialYear: viewModel.selectedYear,
            oldestRecordDate: oldestRecordDate
        ) { week, month, year in
            switch viewModel.selectedPeriodType {
            case .weekly: viewModel.selectedWeek = week
            case .monthly: viewModel.selectedMonth = month
            case .yearly: viewModel.selectedYear = year
            case .unique: break
            }
            onPeriodChange()
        }
    }
}
