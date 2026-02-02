//
//  YalaWidgetsBundle.swift
//  YalaWidgets
//
//  Created by jur on 2/02/26.
//

import WidgetKit
import SwiftUI

@main
struct YalaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        LatestRecordsWidget()
        ScheduledPaymentsWidget()
        BudgetsWidget()
        YalaWidgetsControl()
    }
}
