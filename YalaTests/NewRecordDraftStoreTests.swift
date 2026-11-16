//
//  NewRecordDraftStoreTests.swift
//  YalaTests
//
//  El borrador de Nuevo registro que sobrevive a que iOS cierre Yala (card 77j1): qué se guarda, cuándo caduca y qué
//  no cuenta como borrador.
//

import Foundation
import Testing
@testable import Yala

@Suite("Borrador de Nuevo registro")
struct NewRecordDraftStoreTests {
    private func makeIsolatedDefaults() throws -> UserDefaults {
        try #require(testDefaults(suiteName: "test.\(UUID().uuidString)"))
    }

    private func draft(amount: String = "45.50", note: String = "Almuerzo", savedAt: Date) -> SavedNewRecordDraft {
        SavedNewRecordDraft(
            savedAt: savedAt, type: TransactionType.expense.rawValue, amountString: amount, currencyCode: "PEN",
            accountID: UUID(), sourceAccountID: nil, destinationAccountID: nil, subcategoryID: nil, need: nil,
            date: savedAt, tagIDs: [], note: note, exchangeRate: 1, isExchangeRateManual: false, destinationAmount: 0)
    }

    @Test func guardadoYLeido_esElMismo() throws {
        let defaults = try makeIsolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let saved = draft(savedAt: now)
        NewRecordDraftStore.save(saved, in: defaults)
        #expect(NewRecordDraftStore.load(now: now.addingTimeInterval(60), in: defaults) == saved)
    }

    @Test func pasadas24Horas_caducaYSeBorra() throws {
        let defaults = try makeIsolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        NewRecordDraftStore.save(draft(savedAt: now), in: defaults)
        #expect(NewRecordDraftStore.load(now: now.addingTimeInterval(NewRecordDraftStore.maxAge), in: defaults) != nil)
        #expect(NewRecordDraftStore.load(now: now.addingTimeInterval(NewRecordDraftStore.maxAge + 1), in: defaults) == nil)
        #expect(defaults.data(forKey: NewRecordDraftStore.key) == nil)
    }

    @Test func conElRelojHaciaAtras_cuentaComoCaducado() throws {
        let defaults = try makeIsolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        NewRecordDraftStore.save(draft(savedAt: now), in: defaults)
        #expect(NewRecordDraftStore.load(now: now.addingTimeInterval(-60), in: defaults) == nil)
    }

    @Test func sinNadaEscrito_noSeGuardaYBorraElAnterior() throws {
        let defaults = try makeIsolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        NewRecordDraftStore.save(draft(savedAt: now), in: defaults)
        NewRecordDraftStore.save(draft(amount: "", note: "  ", savedAt: now), in: defaults)
        #expect(defaults.data(forKey: NewRecordDraftStore.key) == nil)
    }

    @Test func soloElImporte_oSoloLaNota_cuentan() {
        let now = Date()
        #expect(draft(amount: "0.5", note: "", savedAt: now).hasContent)
        #expect(draft(amount: "", note: "Taxi", savedAt: now).hasContent)
        #expect(draft(amount: "0", note: "", savedAt: now).hasContent == false)
        #expect(draft(amount: "0.00", note: "", savedAt: now).hasContent == false)
    }

    @Test func ilegible_seBorraSinRomper() throws {
        let defaults = try makeIsolatedDefaults()
        defaults.set(Data("no es json".utf8), forKey: NewRecordDraftStore.key)
        #expect(NewRecordDraftStore.load(in: defaults) == nil)
        #expect(defaults.data(forKey: NewRecordDraftStore.key) == nil)
    }

    @MainActor @Test func losDosBorrados_seLlevanElBorrador() throws {
        let defaults = try makeIsolatedDefaults()
        NewRecordDraftStore.save(draft(savedAt: .now), in: defaults)
        DataWipeService.removeRowDerivedKeys(from: defaults)
        #expect(defaults.data(forKey: NewRecordDraftStore.key) == nil)
    }

    /// La hoja que se cierra borra el borrador en disco solo si su formulario lo escribió o lo recuperó: una hoja abierta
    /// con una cuenta precargada no tira el borrador pendiente de otra.
    @MainActor @Test func cerrarLaHoja_borraElBorradorSoloSiEraSuyo() throws {
        let defaults = try makeIsolatedDefaults()
        NewRecordDraftStore.save(draft(savedAt: .now), in: defaults)

        let ajena = NewRecordDraft()
        ajena.discard(savedDraftsIn: defaults)
        #expect(defaults.data(forKey: NewRecordDraftStore.key) != nil)

        let propia = NewRecordDraft()
        propia.ownsSavedDraft = true
        propia.discard(savedDraftsIn: defaults)
        #expect(defaults.data(forKey: NewRecordDraftStore.key) == nil)
        #expect(propia.ownsSavedDraft == false)
    }
}
