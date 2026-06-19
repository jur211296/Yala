//
//  YalaWidgetsBundle.swift
//  YalaWidgets
//
//  Widget Extension for Yala - includes WidgetKit widgets and Control Center widgets (iOS 18+).
//

import SwiftUI
import WidgetKit

@main
struct YalaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Data widgets
        BalanceWidget()
        ExpenseWidget()
        CashFlowWidget()
        TopCategoriesWidget()
        TopSubcategoriesWidget()
        CategoriesPieWidget()
        SubcategoriesPieWidget()
        LatestRecordsWidget()
        ScheduledPaymentsWidget()
        BudgetsWidget()

        // Lock Screen widgets (accessory)
        AccessoryBalanceWidget()
        AccessoryExpenseWidget()
        AccessoryBudgetWidget()
        AccessoryNextPaymentWidget()

        // Quick action widgets
        QuickManualEntryWidget()
        QuickVoiceEntryWidget()
        QuickImageEntryWidget()

        // Control Center widgets (iOS 18+)
        if #available(iOS 18.0, *) {
            VoiceEntryControl()
            ImageEntryControl()
        }
    }
}
