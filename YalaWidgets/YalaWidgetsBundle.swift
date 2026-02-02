//
//  YalaWidgetsBundle.swift
//  YalaWidgets
//
//  Widget Extension for Yala - includes Control Center widgets for iOS 18+.
//
//  NOTE: This file must be part of a Widget Extension target.
//  To set up in Xcode:
//  1. File > New > Target > Widget Extension
//  2. Name it "YalaWidgets"
//  3. Uncheck "Include Configuration App Intent" (we provide our own)
//  4. Delete the generated files and use these instead
//  5. Set minimum deployment target to iOS 18.0
//

import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
@main
struct YalaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickExpenseControl()
        VoiceEntryControl()
        ImageEntryControl()
    }
}
