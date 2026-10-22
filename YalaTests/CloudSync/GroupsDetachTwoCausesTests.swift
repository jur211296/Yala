//
//  GroupsDetachTwoCausesTests.swift
//  YalaTests / CloudSync
//
//  Ticket `detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes` (opción B de Jürgen, 2026-10-05). Con el
//  drain de Grupos atascado Y la sesión caducada (o sin App Attest, o con los cambios de otra cuenta), «Desasociar» decía solo
//  la primera causa: la persona la arreglaba, volvía a intentarlo y le salía la segunda. Los cierres de sesión no lo sufren,
//  porque su salida «Cerrar sesión y perderlos» lo resuelve todo; el desasociar no la tiene (decisión del 2026-09-15).
//
//  **Medido antes del arreglo**, con la tubería ya puesta y `detachBlockedNotice` devolviendo `.reason(reason)` —lo que hacía
//  el código, un solo motivo—: rojos los tres casos de la lógica pura con la captura atascada y los cuatro del desasociar con
//  dos causas; verdes los controles.
//
//  Tres suites:
//   1. La lógica pura (`CloudSignOutFlowLogic.detachBlockedNotice`).
//   2. El desasociar REAL, con el ciclo y la captura sustituidos (`GroupsExitWitness`): los DOS caminos del push-all que
//      devuelven una causa de la salida con la captura atascada —el outbox a 0 (`stuckCaptureVerdict`) y las filas vivas con
//      la re-captura atascada (`lossBlockAfterRecapture`)— y las tres causas. Más dos controles: la causa sola sin atasco, y
//      el atasco solo.
//   3. Cableado y copy (source-scan): la sección pinta un texto propio por causa, y el español es el literal de Jürgen.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - 1. La lógica pura

@Suite("Desasociar · el aviso nombra las dos causas cuando hay dos (lógica pura)")
struct DetachBlockedNoticeLogicTests {

    typealias L = CloudSignOutFlowLogic

    @Test("MUTACIÓN: con la captura atascada, cada motivo que en un cierre abre la salida lleva la segunda causa")
    func aStuckCaptureAddsTheSecondCause() {
        #expect(L.detachBlockedNotice(reason: .sessionExpired, captureStuck: true) == .alsoCaptureUnfinished(.noSession))
        #expect(L.detachBlockedNotice(reason: .attestUnavailable, captureStuck: true)
                == .alsoCaptureUnfinished(.attestUnavailable))
        #expect(L.detachBlockedNotice(reason: .groupsChangesFromAnotherAccount, captureStuck: true)
                == .alsoCaptureUnfinished(.otherAccount))
    }

    @Test("MUTACIÓN: sin la captura atascada, el aviso es el del motivo, también para los que abren la salida")
    func withoutAStuckCaptureTheReasonStands() {
        for reason in L.BlockReason.allCases {
            #expect(L.detachBlockedNotice(reason: reason, captureStuck: false) == .reason(reason), "\(reason)")
        }
    }

    @Test("MUTACIÓN: con la captura atascada, un motivo que no abre la salida va solo")
    func aStuckCaptureWithAReasonThatOpensNoExitStandsAlone() {
        let sinSalida = L.BlockReason.allCases.filter { L.lossCause($0) == nil }
        // Control: el atasco solo es uno de ellos —ya nombra el drain— y fuera quedan exactamente los cuatro que abren la
        // salida. Si `lossCause` cambia, este test tiene que volver a pensarse.
        #expect(sinSalida.contains(.groupsCaptureUnfinished))
        #expect(L.BlockReason.allCases.count - sinSalida.count == 4)
        for reason in sinSalida {
            #expect(L.detachBlockedNotice(reason: reason, captureStuck: true) == .reason(reason), """
                \(reason) con la captura atascada sale como dos causas: su texto no nombra ninguna de la salida
                """)
        }
    }
}

// MARK: - 2. El desasociar real

@MainActor
@Suite("Desasociar · con el drain atascado y otra causa, un solo aviso con las dos", .serialized)
struct GroupsDetachTwoCausesTests {

    typealias Notice = CloudSignOutFlowLogic.DetachBlockedNotice
    private let coordinator = CloudSessionSignOut.shared

    private final class Count { var value = 0 }

    private func reset() {
        coordinator.acknowledgeBlocked()
        coordinator.exitWitnessOverride = nil
        coordinator.exitCaptureDelayOverride = nil
    }

    private func clearOutbox(_ context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        try context.save()
    }

    private func liveRow() -> GroupSyncOutbox {
        GroupSyncOutbox(syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert, hlc: "hlc",
                        fieldsJSON: "{\"amount\":300}", author: "a", rejectedReason: nil)
    }

    private static func reading(_ outcome: SyncCadencePolicy.CadenceOutcome,
                                attest: Bool = false) -> CloudSessionSignOut.GroupsCycleReading {
        .init(outcome: outcome, channelKilled: false, attestUnavailable: attest, uploadFailed: false)
    }

    /// La captura falla en todos sus intentos (`captures`) y el History guarda `history`; el ciclo, sin red, devuelve `cycle`.
    private func witness(
        captureCompletes: Bool = false, history: [GroupsSyncClient.UncapturedChange],
        cycle: CloudSessionSignOut.GroupsCycleReading, cycles: Count = Count()
    ) -> CloudSessionSignOut.GroupsExitWitness {
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in captureCompletes },
            mirrorPending: { _, _ in 0 }, mirrorPendingKeys: { _, _ in [] })
        witness.uncapturedChanges = { _ in history }
        witness.cycle = { _ in cycles.value += 1; return cycle }
        return witness
    }

    private static func own(_ keys: [String]) -> [GroupsSyncClient.UncapturedChange] {
        keys.map { .init(key: $0, heldForAnotherAccount: false) }
    }

    private static func held(_ keys: [String]) -> [GroupsSyncClient.UncapturedChange] {
        keys.map { .init(key: $0, heldForAnotherAccount: true) }
    }

    private func detach(_ witness: CloudSessionSignOut.GroupsExitWitness,
                        liveRows: Int = 0) async throws -> CloudSessionSignOut.DetachOutcome {
        let context = try makeTestContext()
        try clearOutbox(context)
        for _ in 0..<liveRows { context.insert(liveRow()) }
        try context.save()
        try #require(coordinator.phase == .idle, "el coordinador venía ocupado de otro test")
        coordinator.exitWitnessOverride = witness
        let outcome = await coordinator.detachGroupsAccount(context: context, choice: .keep)
        #expect(coordinator.phase == .idle, "el bloqueo del desasociar se quedó en la fase compartida")
        return outcome
    }

    /// **El caso del ticket**: el outbox a 0, el drain atascado con cambios de esta sesión y la sesión caducada. Antes: «Tu
    /// sesión de grupos caducó», y al volver a entrar, el segundo aviso.
    @Test("MUTACIÓN: outbox a 0, drain atascado y sesión caducada: un aviso con las dos causas")
    func emptyOutbox_stuckDrain_expiredSession() async throws {
        reset(); defer { reset() }
        let cycles = Count()
        let outcome = try await detach(witness(history: Self.own(["h1", "h2"]), cycle: Self.reading(.sessionExpired),
                                               cycles: cycles))
        #expect(cycles.value >= 1, "control: la captura atascada tiene que ciclar para saber la causa")
        #expect(outcome == .blockedBeforeWriting(notice: .alsoCaptureUnfinished(.noSession)), """
            el desasociar nombra una sola causa (\(outcome)): la persona vuelve a entrar, lo intenta otra vez y le sale el \
            drain atascado
            """)
    }

    /// El gemelo del App Attest, por el mismo camino.
    @Test("MUTACIÓN: outbox a 0, drain atascado y sin App Attest: un aviso con las dos causas")
    func emptyOutbox_stuckDrain_noAttest() async throws {
        reset(); defer { reset() }
        let outcome = try await detach(witness(history: Self.own(["h1"]), cycle: Self.reading(.transient, attest: true)))
        #expect(outcome == .blockedBeforeWriting(notice: .alsoCaptureUnfinished(.attestUnavailable)), "\(outcome)")
    }

    /// La tercera causa que llega al desasociar: todo lo que el drain no captura es de otra cuenta. Entrar con ella no basta
    /// —el drain sigue atascado— y arreglar el drain tampoco —siguen siendo de otra cuenta—.
    @Test("MUTACIÓN: outbox a 0, drain atascado con cambios de otra cuenta: un aviso con las dos causas")
    func emptyOutbox_stuckDrain_otherAccount() async throws {
        reset(); defer { reset() }
        let outcome = try await detach(witness(history: Self.held(["h1", "h2"]), cycle: Self.reading(.completed)))
        #expect(outcome == .blockedBeforeWriting(notice: .alsoCaptureUnfinished(.otherAccount)), "\(outcome)")
    }

    /// **El segundo camino**: hay filas vivas, el ciclo bloquea con la sesión caducada y la re-captura sale atascada
    /// (`lossBlockAfterRecapture` conserva el motivo). Sin cubrirlo, el arreglo valdría solo con el outbox a 0.
    @Test("MUTACIÓN: filas vivas, sesión caducada y la re-captura atascada: un aviso con las dos causas")
    func liveRows_expiredSession_stuckRecapture() async throws {
        reset(); defer { reset() }
        let outcome = try await detach(witness(history: Self.own(["h1"]), cycle: Self.reading(.sessionExpired)),
                                       liveRows: 2)
        #expect(outcome == .blockedBeforeWriting(notice: .alsoCaptureUnfinished(.noSession)), "\(outcome)")
    }

    /// Control: la sesión caducada SIN atasco —la captura termina— sigue diciendo solo lo de la sesión. Sin este test, un
    /// arreglo que marcara siempre las dos causas pasaría los de arriba.
    @Test("MUTACIÓN: filas vivas y sesión caducada con la captura completa: solo la sesión")
    func liveRows_expiredSession_completedCapture() async throws {
        reset(); defer { reset() }
        let outcome = try await detach(witness(captureCompletes: true, history: [], cycle: Self.reading(.sessionExpired)),
                                       liveRows: 1)
        #expect(outcome == .blockedBeforeWriting(notice: .reason(.sessionExpired)), "\(outcome)")
    }

    /// Control: el drain atascado en un teléfono sano sigue siendo una sola causa, con su texto (`.groupsCaptureUnfinished`).
    @Test("control: el drain atascado en un teléfono sano sigue siendo una sola causa")
    func emptyOutbox_stuckDrain_healthyPhone() async throws {
        reset(); defer { reset() }
        let outcome = try await detach(witness(history: Self.own(["h1"]), cycle: Self.reading(.completed)))
        #expect(outcome == .blockedBeforeWriting(notice: .reason(.groupsCaptureUnfinished)), "\(outcome)")
    }
}

// MARK: - 3. Cableado y copy

@Suite("Desasociar · cada combinación tiene su texto, y el español es el decidido (source-scan)")
struct GroupsDetachTwoCausesWiringTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // CloudSync/
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // repo root

    private static func code(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "no se pudo leer \(locale)")
    }

    private static let keys = [
        "storage.groups.detachBlockedSessionAndCaptureUnfinished",
        "storage.groups.detachBlockedAttestAndCaptureUnfinished",
        "storage.groups.detachBlockedOtherAccountAndCaptureUnfinished",
    ]

    @Test("MUTACIÓN: la sección pinta un texto propio para cada causa con el drain atascado")
    func theSectionPaintsEachCombination() throws {
        let section = try Self.code("Yala/App/Views/Settings/GroupsAssociationSection.swift")
        for line in [
            "case .alsoCaptureUnfinished(.noSession): return L10n.Storage.Groups.detachBlockedSessionAndCaptureUnfinished",
            "case .alsoCaptureUnfinished(.attestUnavailable): return L10n.Storage.Groups.detachBlockedAttestAndCaptureUnfinished",
            "case .alsoCaptureUnfinished(.otherAccount): return L10n.Storage.Groups.detachBlockedOtherAccountAndCaptureUnfinished",
        ] {
            #expect(section.contains(line), "falta en el aviso del desasociar: \(line)")
        }
        let l10n = try Self.code("Yala/Utils/L10n.swift")
        for key in Self.keys { #expect(l10n.contains("ls(\"\(key)\""), "sin accesor: \(key)") }
    }

    @Test("MUTACIÓN: el bloqueo del push-all es el único que pasa el testigo de la captura; los demás, `false`")
    func onlyThePushAllPassesTheCaptureWitness() throws {
        let source = try Self.code("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let start = try #require(source.range(of: "func detachGroupsAccount("))
        let end = try #require(source.range(of: "private func releaseDetachBlock(", range: start.upperBound..<source.endIndex))
        let detach = String(source[start.lowerBound..<end.lowerBound])
        #expect(detach.components(separatedBy: "releaseDetachBlock(captureStuck: groupsCaptureStuck)").count - 1 == 1)
        #expect(detach.components(separatedBy: "releaseDetachBlock(captureStuck: false)").count - 1 == 4)
        let push = try #require(detach.range(of: "guard await pushGroupsForSignOut(context: context, lossExit: nil) else {"))
        let next = try #require(detach.range(of: "}", range: push.upperBound..<detach.endIndex))
        #expect(detach[push.upperBound..<next.lowerBound].contains("captureStuck: groupsCaptureStuck"), """
            el testigo de la captura ya no va con el bloqueo del push-all: el desasociar vuelve a nombrar una sola causa
            """)
    }

    @Test("el español es el texto que decidió Jürgen, y los gemelos arrancan con el hecho de su causa")
    func theSpanishCopyIsTheDecidedOne() throws {
        let es = try Self.strings("es-419")
        #expect(es["storage.groups.detachBlockedSessionAndCaptureUnfinished"] == """
            Tu sesión de grupos caducó y algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos. \
            No se pierden. Entra otra vez, cierra y vuelve a abrir Yala (si sigue pasando, actualízala) y vuelve a intentarlo.
            """)
        let attest = try #require(es["storage.groups.detachBlockedAttestAndCaptureUnfinished"])
        #expect(attest.hasPrefix("Este teléfono lleva más de un día sin conseguir la verificación de seguridad que pide nuestro servidor"))
        let other = try #require(es["storage.groups.detachBlockedOtherAccountAndCaptureUnfinished"])
        #expect(other.hasPrefix("Hay cambios de grupos que se apuntaron en este teléfono con otra cuenta, y solo se pueden subir con ella."))
        for text in [attest, other] {
            #expect(text.contains("no se pudieron preparar para subirlos"), "el gemelo no nombra el drain atascado: \(text)")
            #expect(text.lowercased().contains("cierra y vuelve a abrir yala (si sigue pasando, actualízala)"),
                    "no dice qué hacer: \(text)")
        }
        // Reabrir Yala cura el drain, no la verificación: el gemelo del attest no puede prometer que reintentar lo resuelve
        // todo (review adversarial del 2026-10-05). Al reintentar sale el aviso del attest a secas, que es verdad.
        #expect(!attest.contains("vuelve a intentarlo"), "el gemelo del attest promete que reabrir y reintentar basta: \(attest)")
    }

    @Test("los tres textos están en los 16 locales y no repiten el de una sola causa")
    func everyLocaleHasTheThreeTexts() throws {
        let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl", "pt-BR",
                       "pt-PT", "pt", "zh-Hans"]
        for locale in locales {
            let table = try Self.strings(locale)
            let values = Self.keys.compactMap { table[$0] }
            #expect(values.count == 3, "\(locale) no tiene las tres claves")
            #expect(Set(values).count == 3, "\(locale) repite un texto entre las tres causas")
            for single in ["storage.groups.detachBlockedSession", "groups.errors.attestUnavailable",
                           "groups.errors.groupsChangesFromAnotherAccount", "groups.errors.captureUnfinished"] {
                #expect(!values.contains(table[single] ?? "—"), "\(locale): un texto de dos causas es el de una (\(single))")
            }
        }
    }
}
