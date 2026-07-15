//
//  GroupsConsentStateTests.swift
//  YalaTests
//
//  Contrato C5 (G4): lectura del consent de grupos vía las nuevas PrefSyncKey. La ESCRITURA
//  (`register()`) va por `PreferenceSyncService` (dual-write) — su verificación completa es de A2.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupsConsentStateTests {

    @Test func isAccepted_defaultFalse_trueOnceEpochWritten() {
        let d = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let previous = GroupsConsentState.defaults
        GroupsConsentState.defaults = d
        defer { GroupsConsentState.defaults = previous }

        #expect(!GroupsConsentState.isAccepted)
        d.set(Int(Date.now.timeIntervalSince1970), forKey: PrefSyncKey.groupsConsentAcceptedAt.rawValue)
        #expect(GroupsConsentState.isAccepted)
    }

    @Test func consentKeys_areIntPresenceFamily() {
        // Familia = intPresence (molde cloudConsent*) → viajan por el canal de prefs sin cambios server.
        #expect(PrefSyncKey.groupsConsentAcceptedAt.family == .intPresence)
        #expect(PrefSyncKey.groupsConsentTextVersion.family == .intPresence)
    }
}
