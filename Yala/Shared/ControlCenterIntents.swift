//
//  ControlCenterIntents.swift
//  Shared
//
//  App Intents for Control Center widgets (Voice + Image entry).
//  Target membership: YalaWidgetsExtension only (excluded from Yala main).
//

import AppIntents
import Foundation

struct OpenVoiceEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.control.voiceExpense"
    static var description = IntentDescription("widget.control.voiceExpense.desc")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        guard let appGroupID = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String else {
            #if DEBUG
            print("🎯 ERROR: APP_GROUP_IDENTIFIER not found in Info.plist")
            #endif
            return .result()
        }

        #if DEBUG
        print("🎯 OpenVoiceEntryIntent.perform() EXECUTED")
        #endif
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set("voice-entry", forKey: "pendingControlAction")
            defaults.synchronize()
            #if DEBUG
            print("🎯 Wrote 'voice-entry' to App Group: \(appGroupID)")
            #endif
        }
        return .result()
    }
}

struct OpenImageEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.control.photoExpense"
    static var description = IntentDescription("widget.control.photoExpense.desc")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        guard let appGroupID = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String else {
            #if DEBUG
            print("🎯 ERROR: APP_GROUP_IDENTIFIER not found in Info.plist")
            #endif
            return .result()
        }

        #if DEBUG
        print("🎯 OpenImageEntryIntent.perform() EXECUTED")
        #endif
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set("image-entry", forKey: "pendingControlAction")
            defaults.synchronize()
            #if DEBUG
            print("🎯 Wrote 'image-entry' to App Group: \(appGroupID)")
            #endif
        }
        return .result()
    }
}
