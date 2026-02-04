//
//  ControlWidgets.swift
//  YalaWidgets
//
//  Control Center widgets for iOS 18+.
//  Opens the Yala app to perform specific actions.
//
//  Strategy: Use App Group to communicate the desired action,
//  then openAppWhenRun to launch the app which reads the action.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Manual Entry Control

@available(iOS 18.0, *)
struct ManualEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yala.control.manualEntry") {
            ControlWidgetButton(action: OpenManualEntryIntent()) {
                Label("widget.control.newExpense", systemImage: "plus.circle.fill")
            }
        }
        .displayName("widget.control.newExpense")
        .description("widget.control.newExpense.desc")
    }
}

// MARK: - Voice Entry Control

@available(iOS 18.0, *)
struct VoiceEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yala.control.voiceEntry") {
            ControlWidgetButton(action: OpenVoiceEntryIntent()) {
                Label("widget.control.voiceLabel", systemImage: "mic.fill")
            }
        }
        .displayName("widget.control.voiceExpense")
        .description("widget.control.voiceExpense.desc")
    }
}

// MARK: - Image Entry Control

@available(iOS 18.0, *)
struct ImageEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yala.control.imageEntry") {
            ControlWidgetButton(action: OpenImageEntryIntent()) {
                Label("widget.control.photoLabel", systemImage: "camera.fill")
            }
        }
        .displayName("widget.control.photoExpense")
        .description("widget.control.photoExpense.desc")
    }
}

// MARK: - Intents

@available(iOS 18.0, *)
struct OpenManualEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.control.newExpense"
    static var description = IntentDescription("widget.control.newExpense.desc")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Minimal intent - just open the app
        return .result()
    }
}

@available(iOS 18.0, *)
struct OpenVoiceEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.control.voiceExpense"
    static var description = IntentDescription("widget.control.voiceExpense.desc")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 18.0, *)
struct OpenImageEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.control.photoExpense"
    static var description = IntentDescription("widget.control.photoExpense.desc")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
