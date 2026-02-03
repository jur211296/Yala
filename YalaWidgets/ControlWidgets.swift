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
                Label("Nuevo gasto", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Nuevo gasto")
        .description("Abre Yala para registrar un gasto")
    }
}

// MARK: - Voice Entry Control

@available(iOS 18.0, *)
struct VoiceEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yala.control.voiceEntry") {
            ControlWidgetButton(action: OpenVoiceEntryIntent()) {
                Label("Por voz", systemImage: "mic.fill")
            }
        }
        .displayName("Gasto por voz")
        .description("Dicta tu gasto a Yala")
    }
}

// MARK: - Image Entry Control

@available(iOS 18.0, *)
struct ImageEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yala.control.imageEntry") {
            ControlWidgetButton(action: OpenImageEntryIntent()) {
                Label("Por foto", systemImage: "camera.fill")
            }
        }
        .displayName("Gasto por foto")
        .description("Escanea un recibo con Yala")
    }
}

// MARK: - Intents

@available(iOS 18.0, *)
struct OpenManualEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Nuevo gasto"
    static var description = IntentDescription("Abre Yala para registrar un gasto")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Minimal intent - just open the app
        return .result()
    }
}

@available(iOS 18.0, *)
struct OpenVoiceEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Gasto por voz"
    static var description = IntentDescription("Dicta tu gasto a Yala")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 18.0, *)
struct OpenImageEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Gasto por foto"
    static var description = IntentDescription("Escanea un recibo con Yala")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
