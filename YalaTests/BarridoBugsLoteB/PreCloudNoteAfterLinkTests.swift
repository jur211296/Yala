//
//  PreCloudNoteAfterLinkTests.swift
//  YalaTests
//
//  Barrido del iPhone 14 (14-nov), lote B, card zy1d: tras crear datos nuevos solo en iCloud («Prueba») y restaurarlos, la
//  pantalla decía «Esta copia de iCloud es de antes de que pasaras tus datos a tu cuenta de Yala». El faro del iCloud-KV
//  sobrevive y la nota solo lo miraba a él. Desde aquí, un movimiento de la copia posterior al enlace la apaga.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Lote B · la nota de «copia de antes» mira la fecha del enlace (zy1d)", .serialized)
struct PreCloudNoteAfterLinkTests {

    private let linked = Date(timeIntervalSince1970: 1_794_600_000)

    /// El caso del barrido: la copia tiene un movimiento creado después de enlazar la cuenta.
    @Test func aCopyWithATransactionCreatedAfterTheLink_hasNoNote() {
        #expect(!WelcomeRestoreView.showsPreCloudNote(
            beaconLinked: true, transactions: 2, accounts: 2,
            linkedAt: linked, newestTransactionCreatedAt: linked.addingTimeInterval(3600)))
    }

    /// La copia de verdad anterior: todos sus movimientos son de antes del enlace (o del mismo instante).
    @Test func aCopyWhoseNewestTransactionPredatesTheLink_keepsTheNote() {
        for newest in [linked.addingTimeInterval(-86_400), linked] {
            #expect(WelcomeRestoreView.showsPreCloudNote(
                beaconLinked: true, transactions: 40, accounts: 2,
                linkedAt: linked, newestTransactionCreatedAt: newest))
        }
    }

    /// Sin fecha de enlace (faro viejo) o sin movimientos con fecha no se puede saber: regla de antes.
    @Test func withoutEitherDate_theOldRuleDecides() {
        #expect(WelcomeRestoreView.showsPreCloudNote(
            beaconLinked: true, transactions: 3, accounts: 1,
            linkedAt: nil, newestTransactionCreatedAt: linked.addingTimeInterval(3600)))
        #expect(WelcomeRestoreView.showsPreCloudNote(
            beaconLinked: true, transactions: 0, accounts: 1, linkedAt: linked, newestTransactionCreatedAt: nil))
        #expect(!WelcomeRestoreView.showsPreCloudNote(
            beaconLinked: false, transactions: 3, accounts: 1,
            linkedAt: linked, newestTransactionCreatedAt: linked.addingTimeInterval(-60)))
    }

    /// El faro devuelve la fecha que guardó y `nil` sin ella.
    @MainActor
    @Test func theBeaconReadsItsLinkDate() {
        let store = InMemoryBeaconStore()
        let beacon = CloudBeacon(store: store)
        #expect(beacon.linkedAt == nil)
        beacon.writeCloudAccountLinked(provider: "google", accountSub: "sub", now: linked)
        #expect(beacon.linkedAt == linked)
    }

    /// El más reciente es el propio: un movimiento de Grupos más nuevo no cuenta.
    @MainActor
    @Test func newestOwnTransaction_skipsGroupRows() throws {
        let context = try makeTestContext()
        let own = TransactionItem(date: linked, amount: -10, currencyCode: "PEN", note: "propio")
        own.createdAt = linked
        let group = TransactionItem(date: linked, amount: -5, currencyCode: "PEN", note: "grupo")
        group.createdAt = linked.addingTimeInterval(7200)
        group.splitExpenseID = UUID().uuidString
        context.insert(own)
        context.insert(group)
        try context.save()
        #expect(WelcomeRestoreView.newestOwnTransactionCreatedAt(in: context) == linked)
    }
}

private final class InMemoryBeaconStore: BeaconKeyValueStore {
    private var values: [String: Any] = [:]
    func setBool(_ value: Bool, forKey key: String) { values[key] = value }
    func setString(_ value: String, forKey key: String) { values[key] = value }
    func setDouble(_ value: Double, forKey key: String) { values[key] = value }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func removeObject(forKey key: String) { values[key] = nil }
    func synchronize() -> Bool { true }
}
