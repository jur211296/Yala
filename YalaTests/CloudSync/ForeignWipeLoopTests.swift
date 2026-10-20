//
//  ForeignWipeLoopTests.swift
//  YalaTests / CloudSync
//
//  «Volver a iCloud › Empezar sin ellos» con un iCloud grande (QA guiado del 2026-10-19, 4nt6): el borrado tenía un
//  plazo TOTAL de 120 s y con 1.541 movimientos se cortaba siempre a la mitad. Ahora sigue mientras avance
//  (`ICloudPersonalCorpusProbe.foreignWipeStallLimit`, sin avance) y solo se corta si CloudKit deja de contestar.
//
//  El recorrido (`runForeignWipe`) se prueba contra un iCloud en memoria con un reloj propio que avanza en cada
//  llamada: sin red y sin esperar de verdad.
//

import CloudKit
import Foundation
import Testing

@testable import Yala

/// Un iCloud en memoria: una zona con registros en orden, páginas por índice y un reloj que avanza con cada llamada.
@MainActor
private final class FakeMirrorZone {
    let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
    private(set) var order: [CKRecord.ID] = []
    private var types: [CKRecord.ID: String] = [:]
    private(set) var deleted: Set<CKRecord.ID> = []
    var clock = Date(timeIntervalSince1970: 1_000_000)
    var pageSize = 200
    var pageLatency: TimeInterval = 5
    var deleteLatency: TimeInterval = 30
    /// Cuántas llamadas de borrado devuelven «ocupado» para todos sus registros antes de aceptar.
    var busyDeleteCalls = 0
    /// Si es `true`, todo borrado devuelve «ocupado» para siempre: CloudKit deja de avanzar.
    var alwaysBusy = false
    /// Si no es `nil`, el borrado LANZA este error.
    var deleteThrows: CKError?
    /// Si no es `nil`, cada registro de la tanda falla con este código.
    var deleteFailsPerRecord: CKError.Code?
    /// Si no es `nil`, leer una página LANZA este error.
    var pageThrows: CKError?
    /// Si es `true`, la zona desaparece antes de leerla (`page` devuelve `nil`).
    var zoneGone = false
    /// Fusible: un recorrido que no corta nunca da un rojo en vez de colgar el test.
    let callFuse = 2_000
    private var calls = 0
    private(set) var deleteCalls = 0
    private(set) var pauses: [TimeInterval] = []

    func add(_ count: Int, type: String, prefix: String) {
        for index in 0..<count {
            let id = CKRecord.ID(recordName: "\(prefix)-\(index)", zoneID: zone)
            order.append(id)
            types[id] = type
        }
    }

    private func blowFuse() throws {
        calls += 1
        if calls > callFuse { throw CKError(.internalError) }
    }

    var foreignLeft: Int { order.filter { !deleted.contains($0) && $0.recordName.hasPrefix("ajeno") }.count }

    var io: ForeignWipeIO<Int> {
        ForeignWipeIO(
            zoneIDs: { [zone = self.zone] in [zone] },
            page: { _, cursor in
                try self.blowFuse()
                self.clock += self.pageLatency
                if self.zoneGone { return nil }
                if let error = self.pageThrows { throw error }
                let start = cursor ?? 0
                let end = min(start + self.pageSize, self.order.count)
                let records = self.order[start..<end]
                    .filter { !self.deleted.contains($0) }
                    .map { ForeignWipeRecord(id: $0, type: self.types[$0]) }
                return ForeignWipePage(records: records, cursor: end, moreComing: end < self.order.count)
            },
            delete: { ids in
                try self.blowFuse()
                self.deleteCalls += 1
                self.clock += self.deleteLatency
                if let error = self.deleteThrows { throw error }
                if let code = self.deleteFailsPerRecord {
                    return Dictionary(uniqueKeysWithValues: ids.map { ($0, .failure(CKError(code))) })
                }
                if self.alwaysBusy || self.busyDeleteCalls > 0 {
                    self.busyDeleteCalls -= 1
                    return Dictionary(uniqueKeysWithValues: ids.map { ($0, .failure(CKError(.zoneBusy))) })
                }
                var results: [CKRecord.ID: Result<Void, Error>] = [:]
                for id in ids {
                    results[id] = self.deleted.contains(id) ? .failure(CKError(.unknownItem)) : .success(())
                    self.deleted.insert(id)
                }
                return results
            },
            now: { self.clock },
            pause: { seconds in
                self.pauses.append(seconds)
                self.clock += seconds
            }
        )
    }
}

@Suite("Vuelta a iCloud · el borrado de «Empezar sin ellos» sigue mientras avance")
@MainActor
struct ForeignWipeLoopTests {

    private let known: Set<String> = Set((0..<300).map { "mio-\($0)" })

    /// El caso del QA: 1.541 movimientos ajenos más 300 propios, con CloudKit tardando 30 s por tanda. El recorrido
    /// entero dura bastante más que el plazo viejo de 120 s y termina igual, en un solo intento.
    @Test func aCorpusAboveTheOldDeadline_finishesInOneAttempt() async {
        let icloud = FakeMirrorZone()
        icloud.add(300, type: "CD_Account", prefix: "mio")
        icloud.add(1_541, type: "CD_TransactionItem", prefix: "ajeno")
        let start = icloud.clock
        var progress: [Int] = []

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(
            known: known, io: icloud.io, onProgress: { progress.append($0) })

        #expect(outcome == .done)
        #expect(icloud.foreignLeft == 0)
        #expect(icloud.clock.timeIntervalSince(start) > 120, "el corpus del test no supera el plazo viejo")
        // La copia propia no se toca nunca.
        #expect(icloud.deleted.allSatisfy { $0.recordName.hasPrefix("ajeno") })
        // El progreso crece y acaba en todo lo ajeno.
        #expect(progress.last == 1_541)
        #expect(progress == progress.sorted())
    }

    /// «Ocupado» no corta: se espera y se repite, y lo repetido acaba borrado.
    @Test func busyBatches_areRetried_notFailed() async {
        let icloud = FakeMirrorZone()
        icloud.add(500, type: "CD_TransactionItem", prefix: "ajeno")
        icloud.busyDeleteCalls = 2

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(known: [], io: icloud.io, onProgress: { _ in })

        #expect(outcome == .done)
        #expect(icloud.foreignLeft == 0)
        #expect(icloud.pauses.count == 2)
    }

    /// Control: si CloudKit deja de avanzar, cortar SÍ es lo correcto —el comportamiento viejo de cortar se conserva—,
    /// pero por falta de avance y sin culpar a la red.
    @Test func noProgress_stopsAsStalled() async {
        let icloud = FakeMirrorZone()
        icloud.add(500, type: "CD_TransactionItem", prefix: "ajeno")
        icloud.alwaysBusy = true

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(known: [], io: icloud.io, onProgress: { _ in })

        #expect(outcome == .stalled)
        #expect(icloud.foreignLeft == 500)
        #expect(ReverseICloudPriorDataLogic.wipeFailureMessage(outcome) == L10n.Storage.Revert.Prior.wipeStopped)
    }

    /// Se corta por falta de avance, no por el tiempo total: el corte llega poco después de la última tanda buena.
    @Test func theStall_isMeasuredFromTheLastProgress() async {
        let icloud = FakeMirrorZone()
        icloud.add(1_000, type: "CD_TransactionItem", prefix: "ajeno")
        icloud.pageSize = 400
        icloud.deleteLatency = 100   // cada tanda buena tarda casi el límite entero, y aun así cuenta como avance
        var lastProgressAt = icloud.clock
        var deletedBeforeStall = 0
        var calls = 0
        let io = icloud.io
        var wrapped = io
        wrapped.delete = { ids in
            calls += 1
            if calls > 2 { icloud.alwaysBusy = true }
            let results = try await io.delete(ids)
            if results.values.contains(where: { if case .success = $0 { return true } else { return false } }) {
                lastProgressAt = icloud.clock
            }
            return results
        }

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(
            known: [], io: wrapped, onProgress: { deletedBeforeStall = $0 })

        #expect(outcome == .stalled)
        #expect(deletedBeforeStall == 800)
        let stalledFor = icloud.clock.timeIntervalSince(lastProgressAt)
        #expect(stalledFor > ICloudPersonalCorpusProbe.foreignWipeStallLimit)
        #expect(stalledFor < ICloudPersonalCorpusProbe.foreignWipeStallLimit + 2 * icloud.deleteLatency)
    }

    /// Sin red es el único fallo cuyo texto habla de la conexión.
    @Test func noNetwork_failsAsNetwork_andOnlyThatBlamesTheConnection() async {
        let icloud = FakeMirrorZone()
        icloud.add(10, type: "CD_TransactionItem", prefix: "ajeno")
        icloud.deleteThrows = CKError(.networkUnavailable)

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(known: [], io: icloud.io, onProgress: { _ in })

        #expect(outcome == .failed("CKError.\(CKError.Code.networkUnavailable.rawValue)", network: true))
        #expect(ReverseICloudPriorDataLogic.wipeFailureMessage(outcome) == L10n.Storage.Revert.Prior.wipeFailed)
        let other = ForeignWipeOutcome.failed("CKError.\(CKError.Code.permissionFailure.rawValue)", network: false)
        #expect(ReverseICloudPriorDataLogic.wipeFailureMessage(other) == L10n.Storage.Revert.Prior.wipeStopped)
    }

    /// Un registro que no se deja leer para el recorrido: no se puede decidir si es ajeno.
    @Test func anUnreadableRecord_stopsWithoutDeletingIt() async {
        let icloud = FakeMirrorZone()
        icloud.add(5, type: "CD_TransactionItem", prefix: "ajeno")
        var io = icloud.io
        io.page = { _, _ in
            ForeignWipePage(records: [ForeignWipeRecord(id: CKRecord.ID(recordName: "x", zoneID: icloud.zone), type: nil)],
                            cursor: 1, moreComing: false)
        }

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(known: [], io: io, onProgress: { _ in })

        #expect(outcome == .failed("partialRecordFailure", network: false))
        #expect(icloud.deleteCalls == 0)
    }

    /// Si toda la operación de borrado dice «ocupado» sin parar, también se corta por falta de avance.
    @Test func aBusyOperationForever_stopsAsStalled() async {
        let icloud = FakeMirrorZone()
        icloud.add(50, type: "CD_TransactionItem", prefix: "ajeno")
        icloud.deleteThrows = CKError(.zoneBusy)

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(known: [], io: icloud.io, onProgress: { _ in })

        #expect(outcome == .stalled)
        #expect(icloud.deleteCalls > 1, "el ocupado de la operación no se repitió")
    }

    /// Una espera larga que pide CloudKit no alarga el corte: se acota al rato sin avance que queda.
    @Test func aLongRetryAfter_doesNotStretchTheStall() async {
        let icloud = FakeMirrorZone()
        icloud.add(50, type: "CD_TransactionItem", prefix: "ajeno")
        icloud.alwaysBusy = true
        icloud.deleteLatency = 1

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(
            known: [], io: icloud.io, retryDelay: 600, onProgress: { _ in })

        #expect(outcome == .stalled)
        #expect(icloud.pauses.allSatisfy { $0 <= ICloudPersonalCorpusProbe.foreignWipeStallLimit + 1 })
    }

    /// La zona que desaparece entre la lista y la lectura no deja nada que el espejo vaya a bajar.
    @Test func aZoneThatIsGone_finishes() async {
        let icloud = FakeMirrorZone()
        icloud.add(10, type: "CD_TransactionItem", prefix: "ajeno")
        icloud.zoneGone = true

        let outcome = await ICloudPersonalCorpusProbe.runForeignWipe(known: [], io: icloud.io, onProgress: { _ in })

        #expect(outcome == .done)
        #expect(icloud.deleteCalls == 0)
    }

    /// Sin red al leer una página, o con la red cortada registro a registro, el fallo es de conexión.
    @Test func noNetworkWhileReadingOrPerRecord_isNetwork() async {
        let reading = FakeMirrorZone()
        reading.add(10, type: "CD_TransactionItem", prefix: "ajeno")
        reading.pageThrows = CKError(.networkFailure)
        let readOutcome = await ICloudPersonalCorpusProbe.runForeignWipe(known: [], io: reading.io, onProgress: { _ in })
        #expect(readOutcome == .failed("CKError.\(CKError.Code.networkFailure.rawValue)", network: true))

        let perRecord = FakeMirrorZone()
        perRecord.add(10, type: "CD_TransactionItem", prefix: "ajeno")
        perRecord.deleteFailsPerRecord = .networkUnavailable
        let recordOutcome = await ICloudPersonalCorpusProbe.runForeignWipe(
            known: [], io: perRecord.io, onProgress: { _ in })
        #expect(recordOutcome == .failed("CKError.\(CKError.Code.networkUnavailable.rawValue)", network: true))

        // Control: un fallo por registro que no es de red no habla de la conexión.
        let denied = FakeMirrorZone()
        denied.add(10, type: "CD_TransactionItem", prefix: "ajeno")
        denied.deleteFailsPerRecord = .permissionFailure
        let deniedOutcome = await ICloudPersonalCorpusProbe.runForeignWipe(
            known: [], io: denied.io, onProgress: { _ in })
        #expect(deniedOutcome == .failed("CKError.\(CKError.Code.permissionFailure.rawValue)", network: false))
    }

    /// El canario conserva los motivos de siempre y gana el del corte por falta de avance.
    @Test func canaryReasons() {
        #expect(ForeignWipeOutcome.done.canaryReason == nil)
        #expect(ForeignWipeOutcome.stalled.canaryReason == "wipeStalled")
        #expect(ForeignWipeOutcome.failed("CKError.4", network: true).canaryReason == "CKError.4")
    }
}
