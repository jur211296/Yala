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
        // WidgetKit widgets (iOS 17+)
        BalanceWidget()
        LatestRecordsWidget()
        ScheduledPaymentsWidget()
        BudgetsWidget()
        YalaWidgetsControl()

        // Control Center widgets (iOS 18+)
        if #available(iOS 18.0, *) {
            QuickExpenseControl()
            VoiceEntryControl()
            ImageEntryControl()
        }
    }
}
