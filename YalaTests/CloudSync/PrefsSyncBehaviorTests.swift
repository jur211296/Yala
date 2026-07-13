//
//  PrefsSyncBehaviorTests.swift
//  YalaTests / CloudSync
//
//  Resolver puro del comportamiento de prefs (M1 Inc 4, decisión 7): la sesión secundaria fuerza
//  `localOnly` — ni iKV del dueño ni outbox de la invitada, en ninguna dirección.
//

import Foundation
import Testing

@testable import Yala

@Suite("PrefsSyncBehavior · resolver (M1)")
struct PrefsSyncBehaviorTests {

    @Test func table_secondaryWinsOverBothModes() {
        // La celda TRAMPA: en secundaria el modo que llega es el EFECTIVO (.cloud) — sin la
        // precedencia, cloudOutbox subiría las prefs del dueño a la cuenta de la invitada.
        #expect(PrefsSyncBehavior.resolve(storageMode: .cloud, secondarySessionActive: true) == .localOnly)
        // Y si llegara .icloud (override/estado raro), icloudKeyValue escribiría las prefs de la
        // invitada al iCloud KV del DUEÑO. La secundaria gana SIEMPRE.
        #expect(PrefsSyncBehavior.resolve(storageMode: .icloud, secondarySessionActive: true) == .localOnly)
    }

    @Test func table_legacyIntact_withoutSecondary() {
        #expect(PrefsSyncBehavior.resolve(storageMode: .icloud, secondarySessionActive: false) == .icloudKeyValue)
        #expect(PrefsSyncBehavior.resolve(storageMode: .cloud, secondarySessionActive: false) == .cloudOutbox)
    }
}
