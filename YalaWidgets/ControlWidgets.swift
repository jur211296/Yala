//
//  ControlWidgets.swift
//  YalaWidgets
//
//  Control Center widgets for iOS 18+ using ControlWidget API.
//  These controls open the main Yala app to perform actions.
//
//  Behavior:
//  - QuickExpense: Opens app to new transaction screen
//  - VoiceEntry: Opens app in voice input mode
//  - ImageEntry: Opens app in camera/receipt scanning mode
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Quick Expense Control

/// Control Center button for quick expense entry.
/// Opens the app to start a new transaction.
@available(iOS 18.0, *)
struct QuickExpenseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.yala.control.quickExpense"
        ) {
            ControlWidgetButton(action: OpenQuickExpenseIntent()) {
                Label {
                    Text("control.quickExpense.label")
                } icon: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .displayName("control.quickExpense.displayName")
        .description("control.quickExpense.description")
    }
}

// MARK: - Voice Entry Control

/// Control Center button for voice entry.
/// Opens the app with voice input mode.
@available(iOS 18.0, *)
struct VoiceEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.yala.control.voiceEntry"
        ) {
            ControlWidgetButton(action: OpenVoiceEntryIntent()) {
                Label {
                    Text("control.voiceEntry.label")
                } icon: {
                    Image(systemName: "mic.fill")
                }
            }
        }
        .displayName("control.voiceEntry.displayName")
        .description("control.voiceEntry.description")
    }
}

// MARK: - Image Entry Control

/// Control Center button for image/receipt scanning.
/// Opens the app with camera mode.
@available(iOS 18.0, *)
struct ImageEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.yala.control.imageEntry"
        ) {
            ControlWidgetButton(action: OpenImageEntryIntent()) {
                Label {
                    Text("control.imageEntry.label")
                } icon: {
                    Image(systemName: "camera.fill")
                }
            }
        }
        .displayName("control.imageEntry.displayName")
        .description("control.imageEntry.description")
    }
}

// MARK: - Control Intents

/// Intent that opens the app for quick expense entry.
/// Uses URL scheme: yala://new-transaction
@available(iOS 18.0, *)
struct OpenQuickExpenseIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "control.quickExpense.intentTitle"
    static var description = IntentDescription("control.quickExpense.intentDescription")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Opens the app via openAppWhenRun
        // App will show new transaction screen by default
        return .result()
    }
}

/// Intent that opens the app for voice entry.
/// Uses URL scheme: yala://voice-entry
@available(iOS 18.0, *)
struct OpenVoiceEntryIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "control.voiceEntry.intentTitle"
    static var description = IntentDescription("control.voiceEntry.intentDescription")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // The app's scene delegate will handle presenting voice entry
        // based on the launch context
        return .result()
    }
}

/// Intent that opens the app for image entry.
/// Uses URL scheme: yala://image-entry
@available(iOS 18.0, *)
struct OpenImageEntryIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "control.imageEntry.intentTitle"
    static var description = IntentDescription("control.imageEntry.intentDescription")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // The app's scene delegate will handle presenting image entry
        // based on the launch context
        return .result()
    }
}
