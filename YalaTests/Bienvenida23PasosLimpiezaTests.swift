//
//  Bienvenida23PasosLimpiezaTests.swift
//  YalaTests
//
//  Lote 03 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): «¿Borramos los de prueba?» al cerrar el paso 2 (Y23-10). En su propio fichero porque pide
//  `makeTestContext()` (una suite por fichero, `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Y23-10 · «¿Borramos los de prueba?»

@MainActor
@Suite("Bienvenida 2.3 · paso 2, borrar los de prueba (Y23-10)", .serialized)
struct PracticeRecordsCleanupTests {

    /// Todos marcados al abrir; borrar quita los marcados (y devuelve el saldo); los desmarcados se quedan.
    @Test func deletesTheMarked_keepsTheRest() throws {
        let context = try makeTestContext()
        let account = Account(name: "Mi dinero", currencyCode: "PEN", colorHex: "#6063F1", iconName: "wallet.pass",
                              type: AccountType.general.rawValue)
        context.insert(account)
        func record(_ amount: Double) throws -> TransactionItem {
            let item = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: amount, currencyCode: "PEN")
            item.account = account
            context.insert(item)
            return item
        }
        let manual = try record(-86.4)
        let voice = try record(-25)
        let ai = try record(-45)
        try context.save()

        let records = [manual, voice, ai].enumerated().map { index, item in
            RecordTutorialRecord(persistentID: item.persistentModelID,
                                 method: RecordTutorialLogic.Method.allCases[index], isDraft: false, additionalIDs: [])
        }
        var selected = RecordTutorialLogic.initialSelection(records.map(\.persistentID))
        #expect(selected.count == 3)
        selected.remove(voice.persistentModelID)

        let deleted = PracticeRecordsCleanup.delete(records, selected: selected, in: context)

        #expect(deleted == 2)
        let left = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(left.map(\.amount) == [-25])
        #expect(RecordTutorialLogic.asksToCleanUp(recordCount: 1))
        #expect(!RecordTutorialLogic.asksToCleanUp(recordCount: 0))
    }

    /// Lo que ya no existe (un borrador aprobado en la Bandeja, algo borrado por otro camino) no cuenta como borrado.
    @Test func missingRecords_doNotCount() throws {
        let context = try makeTestContext()
        let kept = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: -12, currencyCode: "PEN")
        let gone = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: -30, currencyCode: "PEN")
        context.insert(kept)
        context.insert(gone)
        try context.save()
        let records = [kept, gone].map {
            RecordTutorialRecord(persistentID: $0.persistentModelID, method: .manual, isDraft: false, additionalIDs: [])
        }
        context.delete(gone)
        try context.save()
        #expect(PracticeRecordsCleanup.delete(records, selected: Set(records.map(\.persistentID)), in: context) == 1)
        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).isEmpty)
    }

    /// «Conservarlos todos» (nada marcado) no borra nada.
    @Test func nothingMarked_deletesNothing() throws {
        let context = try makeTestContext()
        let item = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: -12, currencyCode: "PEN")
        context.insert(item)
        try context.save()
        let records = [RecordTutorialRecord(persistentID: item.persistentModelID, method: .manual, isDraft: false,
                                            additionalIDs: [])]
        #expect(PracticeRecordsCleanup.delete(records, selected: [], in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).count == 1)
    }
}
