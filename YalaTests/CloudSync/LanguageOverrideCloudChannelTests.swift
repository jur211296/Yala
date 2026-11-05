//
//  LanguageOverrideCloudChannelTests.swift
//  YalaTests
//
//  Card p9wf (2026-11-05), ticket `language-override-bypasses-the-cloud-prefs-channel`. En una cuenta en la nube el idioma
//  de la app va al outbox de preferencias —y de ahí a los otros dispositivos de la cuenta—, no al iCloud-KV del Apple ID
//  del teléfono. En `.icloud`, como siempre.
//

import Foundation
import Testing
@testable import Yala

private final class LanguageSpyStore: OwnerKeyValueWriting {
    var values: [String: Any] = [:]
    var touched: [String] = []
    var synchronizeCount = 0
    func setBool(_ value: Bool, forKey key: String) { values[key] = value; touched.append(key) }
    func setString(_ value: String, forKey key: String) { values[key] = value; touched.append(key) }
    func setDouble(_ value: Double, forKey key: String) { values[key] = value; touched.append(key) }
    func setInt(_ value: Int, forKey key: String) { values[key] = Int64(value); touched.append(key) }
    func removeObject(forKey key: String) { values[key] = nil; touched.append(key) }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func longLong(forKey key: String) -> Int64 { values[key] as? Int64 ?? 0 }
    func object(forKey key: String) -> Any? { values[key] }
    @discardableResult func synchronize() -> Bool { synchronizeCount += 1; return true }
}

@MainActor
@Suite("Idioma de la app · por el canal de preferencias de la sesión")
struct LanguageOverrideCloudChannelTests {

    private func route(_ value: String?, _ behavior: PrefsSyncBehavior) -> (store: LanguageSpyStore, enqueued: [PrefValue]) {
        let store = LanguageSpyStore()
        var enqueued: [PrefValue] = []
        PreferenceSyncService.routeLanguageOverride(value, behavior: behavior, store: store) { enqueued.append($0) }
        return (store, enqueued)
    }

    @Test("en la nube, cambiar el idioma lo encola y NO escribe el iCloud-KV del Apple ID")
    func cloud_enqueuesAndLeavesTheAppleIDAlone() {
        let (store, enqueued) = route("pt-BR", .cloudOutbox)
        #expect(enqueued == [.string("pt-BR")])
        #expect(store.touched.isEmpty, "en un móvil prestado le cambiaría el idioma al dueño en todos sus dispositivos")
        #expect(store.synchronizeCount == 0)
    }

    @Test("en la nube, «idioma del sistema» viaja como vacío, que el merge lee como quitar el override")
    func cloud_systemLanguageTravelsAsEmpty() {
        let (store, enqueued) = route(nil, .cloudOutbox)
        #expect(enqueued == [.string("")])
        #expect(store.touched.isEmpty)
        let decision = PreferenceMergeLogic.decide(key: .appLanguageOverride, remote: .string(""), local: .string("pt-BR"))
        #expect(decision.write == .remove, "el otro dispositivo de la cuenta tiene que volver al idioma del sistema")
    }

    @Test("control: en iCloud escribe el KV como siempre y no encola nada")
    func icloud_writesTheKeyValueStore() {
        let (store, enqueued) = route("en-GB", .icloudKeyValue)
        #expect(store.values[PrefSyncKey.appLanguageOverride.rawValue] as? String == "en-GB")
        #expect(store.synchronizeCount == 1)
        #expect(enqueued.isEmpty)

        let (cleared, _) = route(nil, .icloudKeyValue)
        #expect(cleared.touched == [PrefSyncKey.appLanguageOverride.rawValue])
        #expect(cleared.values[PrefSyncKey.appLanguageOverride.rawValue] == nil)
    }

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test("el setter del idioma y el remap de alias pasan por el canal, y en ningún otro sitio del fichero se escribe el KV")
    func languageManagerUsesTheChannel() throws {
        let source = try String(contentsOf: Self.repoRoot.appendingPathComponent("Yala/Utils/L10n.swift"), encoding: .utf8)
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }.joined(separator: " ")
        #expect(source.components(separatedBy: "PreferenceSyncService.shared.syncLanguageOverride(").count - 1 == 2)
        #expect(source.contains("sharedDefaults.set(newValue, forKey: overrideKey) PreferenceSyncService.shared.syncLanguageOverride(newValue) NotificationCenter.default.post(name: .languageDidChange, object: nil)"))
        #expect(!source.contains("OwnerKeyValueStore"))
    }
}
