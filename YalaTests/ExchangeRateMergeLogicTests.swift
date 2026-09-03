//
//  ExchangeRateMergeLogicTests.swift
//  YalaTests
//
//  H3 de `fx-partial-rate-rows-silent-1to1`: la fila de tasas se FUSIONA, no se reemplaza.
//

import Foundation
import Testing

@testable import Yala

struct ExchangeRateMergeLogicTests {

    // MARK: - La fusión

    /// El caso exacto que ocurría en cada arranque: la fila ya tiene las 54 divisas (la escribió
    /// `updateTodayIfNeeded`) y llega el preload con las 3 del usuario. Con reemplazo, las 51
    /// restantes desaparecían.
    @Test func incomingPartialWrite_keepsWhatTheRowAlreadyHad() {
        let existing = ["USD": 1.0, "PEN": 3.75, "JPY": 157.0, "EUR": 0.92]
        let incoming = ["USD": 1.0, "PEN": 3.80]

        let merged = ExchangeRateMergeLogic.merged(existing: existing, incoming: incoming)

        #expect(merged["JPY"] == 157.0, "JPY no venía en la escritura nueva: se conserva.")
        #expect(merged["EUR"] == 0.92)
        #expect(merged.count == 4)
    }

    /// Sobre una divisa que está en las dos, gana la entrante: viene de una respuesta más reciente.
    @Test func incomingValue_winsOverTheStoredOne() {
        let merged = ExchangeRateMergeLogic.merged(
            existing: ["PEN": 3.75], incoming: ["PEN": 3.80]
        )
        #expect(merged["PEN"] == 3.80)
    }

    /// Fila nueva o vacía: la fusión no puede inventar nada.
    @Test func emptyExisting_yieldsExactlyTheIncoming() {
        let merged = ExchangeRateMergeLogic.merged(existing: [:], incoming: ["USD": 1.0])
        #expect(merged == ["USD": 1.0])
    }

    /// Y el simétrico, que es el que protege de una fusión escrita al revés: una escritura VACÍA no
    /// puede vaciar la fila.
    @Test func emptyIncoming_neverWipesTheRow() {
        let merged = ExchangeRateMergeLogic.merged(
            existing: ["USD": 1.0, "PEN": 3.75], incoming: [:]
        )
        #expect(merged.count == 2)
    }

    // MARK: - El timestamp

    /// `persistRate` declara `timestamp: Date? = nil` y lo asignaba incondicionalmente ⇒ el preload,
    /// que no lo pasa, borraba la hora real que había puesto la llamada de la API.
    @Test func missingIncomingTimestamp_doesNotEraseTheStoredOne() {
        let stored = Date(timeIntervalSince1970: 1_756_800_000)
        #expect(ExchangeRateMergeLogic.mergedTimestamp(existing: stored, incoming: nil) == stored)
    }

    @Test func incomingTimestamp_replacesTheStoredOne() {
        let stored = Date(timeIntervalSince1970: 1_756_800_000)
        let fresh = Date(timeIntervalSince1970: 1_756_900_000)
        #expect(ExchangeRateMergeLogic.mergedTimestamp(existing: stored, incoming: fresh) == fresh)
    }

    @Test func noTimestampAnywhere_staysNil() {
        #expect(ExchangeRateMergeLogic.mergedTimestamp(existing: nil, incoming: nil) == nil)
    }
}

// MARK: - Cableado (source-scan)

/// Una fusión correcta que nadie llama no arregla nada, y `persistRate` es `private`: no hay forma de
/// alcanzarla desde un unit test. Este scan es lo que impide que el reemplazo vuelva — molde de
/// `NeutralMountWiringTests`, que existe por la misma razón.
@Suite("H3 · cableado de la fusión de tasas (source-scan)")
struct ExchangeRateMergeWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("`persistRate` fusiona y no reemplaza el blob")
    func persistRate_mergesInsteadOfOverwriting() throws {
        let src = try Self.source("Yala/Services/ExchangeRateService.swift")

        #expect(src.contains("ExchangeRateMergeLogic.merged(existing: existing.decodedRates()"), """
            La rama de fila existente tiene que partir de lo que la fila YA tenía. Sin esto, cada
            arranque deja la fila de hoy con las 2-4 divisas del preload en vez de las 54.
            """)
        #expect(src.contains("ExchangeRateMergeLogic.mergedTimestamp("), """
            El timestamp entrante es `Date? = nil` por defecto: asignarlo a pelo BORRA el de la fila.
            """)
        #expect(!src.contains("existing.timestamp = timestamp"), """
            Ésa es exactamente la asignación incondicional que borraba la hora real de la API.
            """)
    }

    /// El merge tiene que quedar DESPUÉS del gate de quiescencia de import, como avisa el ticket: por
    /// delante, escribiría durante el restore de iCloud y dispararía el `_assertionFailure`.
    @Test("La fusión va después del gate de quiescencia")
    func mergeStaysBehindTheQuiescenceGate() throws {
        let src = try Self.source("Yala/Services/ExchangeRateService.swift")
        let gate = try #require(src.range(of: "guard iCloudSyncService.shared.isImportQuiescent"))
        let merge = try #require(src.range(of: "ExchangeRateMergeLogic.merged("))
        #expect(gate.lowerBound < merge.lowerBound)
    }
}
