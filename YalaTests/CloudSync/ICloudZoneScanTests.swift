//
//  ICloudZoneScanTests.swift
//  YalaTests / CloudSync
//
//  El recorrido de las zonas del espejo con plazo SIN AVANCE (card blqa del QA guiado del TF19, 2026-10-20). Hasta ese
//  día las tres revisiones de iCloud cortaban con un plazo TOTAL, y un iCloud con mucho historial se cortaba siempre
//  aunque cada página llegara a tiempo: «No pudimos conectarnos a iCloud · Puede ser la conexión».
//
//  Puro: páginas fabricadas y un reloj propio. No hay CloudKit en el simulador.
//

import CloudKit
import Foundation
import Testing

@testable import Yala

@Suite("Revisión de iCloud con plazo sin avance (blqa)")
@MainActor
struct ICloudZoneScanTests {

    /// Reloj que solo avanza cuando el IO lo dice.
    final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 0)
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private let zoneA = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
    private let zoneB = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone.2", ownerName: CKCurrentUserDefaultName)

    private func record(_ name: String, type: String = "CD_TransactionItem", zone: CKRecordZone.ID? = nil) -> CKRecord {
        CKRecord(recordType: type, recordID: CKRecord.ID(recordName: name, zoneID: zone ?? zoneA))
    }

    /// Una zona con `pages` páginas; cada una tarda `secondsPerPage` en llegar y trae `recordsPerPage` registros y
    /// `deletionsPerPage` borrados. `pageCalls` cuenta las peticiones.
    private func io(clock: Clock,
                    zones: [CKRecordZone.ID]? = nil,
                    zoneListSeconds: TimeInterval = 1,
                    pages: Int,
                    secondsPerPage: @escaping (Int) -> TimeInterval,
                    recordsPerPage: Int = 2,
                    deletionsPerPage: Int = 0,
                    failedRecordOnPage: Int? = nil,
                    missingZone: CKRecordZone.ID? = nil,
                    pageCalls: Counter) -> ICloudZoneScanIO<Int> {
        ICloudZoneScanIO(
            zoneIDs: {
                clock.advance(zoneListSeconds)
                return zones ?? [self.zoneA]
            },
            page: { zone, cursor in
                if zone == missingZone { return nil }
                let index = cursor ?? 0
                pageCalls.value += 1
                clock.advance(secondsPerPage(index))
                var records: [CKRecord?] = (0..<recordsPerPage).map { self.record("\(zone.zoneName)-\(index)-\($0)", zone: zone) }
                if failedRecordOnPage == index { records.append(nil) }
                return ICloudZoneScanPage(records: records, deletions: deletionsPerPage,
                                          cursor: index + 1, moreComing: index + 1 < pages)
            },
            now: { clock.now })
    }

    final class Counter { var value = 0 }

    // MARK: - El caso de la card

    /// Cuarenta páginas de 2 s: 80 s en total, ninguna espera pasa de 25 s. Con el plazo total se cortaba a los 25 s.
    @Test func muchoHistorial_cadaPaginaATiempo_terminaAunqueElTotalPaseDelPlazo() async throws {
        let clock = Clock(); let calls = Counter()
        let outcome = try await ICloudZoneScan.run(
            io: io(clock: clock, pages: 40, secondsPerPage: { _ in 2 }, pageCalls: calls),
            stallLimit: 25) { _ in false }

        #expect(outcome.end == .finished)
        #expect(calls.value == 40)
        #expect(clock.now.timeIntervalSinceReferenceDate > 25)   // el total sí pasó del plazo
        #expect(outcome.stats.pages == 40)
        #expect(outcome.stats.records == 80)
    }

    /// Control: una sola espera que pasa del plazo corta, aunque el total sea corto. Es el caso en que cortar era lo
    /// correcto, y sigue cortando.
    @Test func unaEsperaQuePasaDelPlazo_corta() async throws {
        let clock = Clock(); let calls = Counter()
        let outcome = try await ICloudZoneScan.run(
            io: io(clock: clock, pages: 5, secondsPerPage: { $0 == 2 ? 26 : 1 }, pageCalls: calls),
            stallLimit: 25) { _ in false }

        #expect(outcome.end == .stalled)
        #expect(calls.value == 3)               // no pide la cuarta
        #expect(outcome.stats.pages == 3)       // la tardía llegó, y el rastro la cuenta
    }

    /// Una página que llega tarde con lo que el llamador buscaba vale como respuesta (review del 2026-10-20): el adopt
    /// que encuentra un registro relevante en ella contesta `found` y no «se quedó sin avanzar».
    @Test func paginaTardia_conLoQueSeBuscaba_vale() async throws {
        let clock = Clock(); let calls = Counter()
        let outcome = try await ICloudZoneScan.run(
            io: io(clock: clock, pages: 5, secondsPerPage: { $0 == 1 ? 30 : 1 }, pageCalls: calls),
            stallLimit: 25) { records in records.contains { $0.recordID.recordName.hasSuffix("-1-0") } }

        #expect(outcome.end == .stopped)
        #expect(calls.value == 2)
    }

    /// Una zona que ya no existe también es una respuesta: su espera no se suma a la página siguiente.
    @Test func zonaBorrada_cuentaComoRespuesta() async throws {
        let clock = Clock()
        let zoneA = self.zoneA
        let zoneB = self.zoneB
        // Zona A borrada tras 20 s; la página de B tarda 10 s. Ninguna espera pasa de 25.
        let outcome = try await ICloudZoneScan.run(
            io: ICloudZoneScanIO<Int>(
                zoneIDs: { [zoneA, zoneB] },
                page: { zone, _ in
                    if zone == zoneA { clock.advance(20); return nil }
                    clock.advance(10)
                    let record = CKRecord(recordType: "CD_TransactionItem",
                                          recordID: CKRecord.ID(recordName: "b", zoneID: zone))
                    return ICloudZoneScanPage(records: [record], deletions: 0, cursor: 1, moreComing: false)
                },
                now: { clock.now }),
            stallLimit: 25) { _ in false }

        #expect(outcome.end == .finished)
    }

    /// La frontera: justo el plazo no corta; un poco más, sí.
    @Test func laFronteraDelPlazo() async throws {
        let clock1 = Clock()
        let exacto = try await ICloudZoneScan.run(
            io: io(clock: clock1, pages: 2, secondsPerPage: { _ in 25 }, pageCalls: Counter()),
            stallLimit: 25) { _ in false }
        #expect(exacto.end == .finished)

        let clock2 = Clock()
        let pasado = try await ICloudZoneScan.run(
            io: io(clock: clock2, pages: 2, secondsPerPage: { _ in 25.5 }, pageCalls: Counter()),
            stallLimit: 25) { _ in false }
        #expect(pasado.end == .stalled)
    }

    /// Una página que solo trae borrados también es avance: el servidor está contestando. Y el rastro los cuenta.
    @Test func paginasSoloDeBorrados_sonAvance_yQuedanEnElRastro() async throws {
        let clock = Clock()
        let outcome = try await ICloudZoneScan.run(
            io: io(clock: clock, pages: 30, secondsPerPage: { _ in 3 }, recordsPerPage: 0, deletionsPerPage: 200,
                   pageCalls: Counter()),
            stallLimit: 25) { _ in false }

        #expect(outcome.end == .finished)
        #expect(outcome.stats.records == 0)
        #expect(outcome.stats.deletions == 6000)
    }

    /// La lista de zonas también es una espera.
    @Test func listaDeZonasLenta_corta() async throws {
        let clock = Clock(); let calls = Counter()
        let outcome = try await ICloudZoneScan.run(
            io: io(clock: clock, zoneListSeconds: 30, pages: 1, secondsPerPage: { _ in 1 }, pageCalls: calls),
            stallLimit: 25) { _ in false }

        #expect(outcome.end == .stalled)
        #expect(calls.value == 0)
    }

    // MARK: - Lo que no cambió

    /// Un registro que no se deja leer no se salta: contar de menos es decir «vacío» sin saberlo.
    @Test func falloParcial_noSeSalta() async throws {
        let clock = Clock(); var paginasVistas = 0
        let outcome = try await ICloudZoneScan.run(
            io: io(clock: clock, pages: 3, secondsPerPage: { _ in 1 }, failedRecordOnPage: 1, pageCalls: Counter()),
            stallLimit: 25) { _ in paginasVistas += 1; return false }

        #expect(outcome.end == .partialRecordFailure)
        #expect(paginasVistas == 1)   // la página con el fallo no llega al llamador
    }

    /// El llamador para cuando ya sabe lo que quería, y no se piden más páginas.
    @Test func elLlamadorPara_noSePidenMasPaginas() async throws {
        let clock = Clock(); let calls = Counter()
        let outcome = try await ICloudZoneScan.run(
            io: io(clock: clock, pages: 10, secondsPerPage: { _ in 1 }, pageCalls: calls),
            stallLimit: 25) { records in records.contains { $0.recordID.recordName.hasSuffix("-1-0") } }

        #expect(outcome.end == .stopped)
        #expect(calls.value == 2)
    }

    /// Una zona que ya no existe se salta y se sigue con la siguiente.
    @Test func zonaQueYaNoExiste_seSalta() async throws {
        let clock = Clock(); var zonasVistas = Set<String>()
        let outcome = try await ICloudZoneScan.run(
            io: io(clock: clock, zones: [zoneA, zoneB], pages: 1, secondsPerPage: { _ in 1 },
                   missingZone: zoneA, pageCalls: Counter()),
            stallLimit: 25) { records in
                records.forEach { zonasVistas.insert($0.recordID.zoneID.zoneName) }
                return false
            }

        #expect(outcome.end == .finished)
        #expect(zonasVistas == [zoneB.zoneName])
    }

    // MARK: - El texto

    /// Solo el plazo cambia el texto; cualquier otro fallo conserva el «Puede ser la conexión» de siempre.
    @Test func elTextoQueNoCulpaALaConexion_soloConElPlazo() {
        #expect(WelcomePrivateICloudGateLogic.wasStalled(ICloudZoneScanEnd.stalledReason))
        #expect(WelcomePrivateICloudGateLogic.wasStalled("scanStalled"))
        // Controles: un CKError, un registro ilegible y el motivo del plazo TOTAL de un build anterior.
        #expect(!WelcomePrivateICloudGateLogic.wasStalled("CKError.4"))
        #expect(!WelcomePrivateICloudGateLogic.wasStalled("partialRecordFailure"))
        #expect(!WelcomePrivateICloudGateLogic.wasStalled("scanDeadline"))
        // Y el texto nuevo no habla de la conexión.
        #expect(!L10n.Welcome.PrivateICloud.stalledBody.isEmpty)
        #expect(L10n.Welcome.PrivateICloud.stalledTitle != L10n.Welcome.PrivateICloud.errorTitle)
        #expect(L10n.Welcome.PrivateICloud.discardStalledBody != L10n.Welcome.PrivateICloud.discardUnverifiedBody)
    }

    /// La puerta decide `.unreachable` con el motivo dentro: lo que la vista lee para elegir el texto.
    @Test func laPuertaConservaElMotivo() {
        let decision = WelcomePrivateICloudGateLogic.decide(
            skipValidation: false, outcome: .failed(ICloudZoneScanEnd.stalledReason), deviceData: .none)
        #expect(decision == .unreachable("scanStalled"))
    }
}

/// El cableado: las tres revisiones de producción pasan por el recorrido con plazo sin avance, y la puerta elige el texto
/// por el motivo. Source-scan porque la producción habla con un `CKContainer` real, que el simulador no tiene.
@Suite("Revisión de iCloud con plazo sin avance · cableado (blqa)")
struct ICloudZoneScanWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func code(_ path: String) throws -> String {
        let source = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
            .joined(separator: "\n")
    }

    private static let probePath = "Yala/Services/CloudSync/ICloudPersonalCorpusProbe.swift"

    @Test func lasTresRevisiones_pasanPorElRecorridoSinAvance() throws {
        let probe = try Self.code(Self.probePath)
        #expect(probe.contains("stallLimit: scanStallLimit") )
        #expect(probe.components(separatedBy: "stallLimit: scanStallLimit").count - 1 == 2)   // puerta + adopt
        #expect(probe.contains("stallLimit: foreignScanStallLimit"))                            // vuelta a iCloud
        #expect(probe.components(separatedBy: "ICloudZoneScan.run(").count - 1 == 3)
        // Ningún plazo total sobrevive.
        #expect(!probe.contains("timeIntervalSince(startedAt)"))
        #expect(!probe.contains("scanDeadline"))
        // Cada una traduce el plazo a su motivo.
        #expect(probe.contains("case .stalled:              return .failed(ICloudZoneScanEnd.stalledReason)"))
        #expect(probe.contains("case .stalled:              throw ForeignScanError.stalled"))
        // La puerta conserva su trato de una zona que desaparece (fallo); el adopt y la vuelta la saltan.
        #expect(probe.contains("liveZoneScanIO(desiredKeys: desiredKeys, skipsDeletedZones: false)"))
        #expect(probe.components(separatedBy: "skipsDeletedZones: true)").count - 1 == 2)
    }

    @Test func laPuerta_eligeElTextoPorElMotivo() throws {
        let view = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        #expect(view.contains("phase = .unreachable(stalled: WelcomePrivateICloudGateLogic.wasStalled(reason))"))
        #expect(view.contains(
            "title: stalled ? L10n.Welcome.PrivateICloud.stalledTitle : L10n.Welcome.PrivateICloud.errorTitle"))
        #expect(view.contains("case (.proceedWatchingTheMirror, true): return L10n.Welcome.PrivateICloud.stalledBody"))
        #expect(view.contains(
            "case (.returnWithoutClaimingAWipe, true): return L10n.Welcome.PrivateICloud.discardStalledBody"))
        #expect(view.contains("case (.proceedWatchingTheMirror, false): return L10n.Welcome.PrivateICloud.errorBody"))
    }
}
