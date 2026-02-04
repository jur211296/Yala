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
