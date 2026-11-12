//
//  BudgetChartsPeriodSelector.swift
//  Yala
//
//  Selector de período de las gráficas de un presupuesto. Trabaja con `@Binding`, sin tocar el ViewModel: el período de
//  la lista no cambia. La rueda es la nativa de iOS (`BudgetPeriodWheelSheet`, UX 2.2 · L9-8).
//

import SwiftUI

struct BudgetChartsPeriodSelector: View {
    let periodType: BudgetPeriodType
    @Binding var selectedWeek: Date
    @Binding var selectedMonth: Date
    @Binding var selectedYear: Int
    /// El movimiento más antiguo guardado: la rueda empieza en su período.
    var oldestRecordDate: Date?

    var body: some View {
        BudgetPeriodWheelSheet(
            periodType: periodType,
            initialWeek: selectedWeek,
            initialMonth: selectedMonth,
            initialYear: selectedYear,
            oldestRecordDate: oldestRecordDate
        ) { week, month, year in
            switch periodType {
            case .weekly: selectedWeek = week
            case .monthly: selectedMonth = month
            case .yearly: selectedYear = year
            case .unique: break
            }
        }
    }
}
