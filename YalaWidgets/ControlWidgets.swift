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

// MARK: - Voice Entry Control

@available(iOS 18.0, *)
struct VoiceEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yala.control.voiceEntry") {
            ControlWidgetButton(action: OpenVoiceEntryIntent()) {
                Label("widget.control.voiceExpense", systemImage: "mic.badge.plus")
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
                Label("widget.control.photoExpense", systemImage: "photo.badge.plus")
            }
        }
        .displayName("widget.control.photoExpense")
        .description("widget.control.photoExpense.desc")
    }
}
