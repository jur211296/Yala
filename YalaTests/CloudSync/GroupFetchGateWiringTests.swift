//
//  GroupFetchGateWiringTests.swift
//  YalaTests / CloudSync
//
//  Cableado de producción del gate C-4 (source-scan). Los tests de comportamiento del uploader INYECTAN
//  la señal, así que un adaptador mal construido —leer el engine equivocado, hardcodear la cuenta,
//  olvidar un búfer— los deja a todos en verde. Estos scans nombran al culpable. Mismo patrón y misma
//  razón que `HandoverGroupsWiringTests` / `SignOutNotificationWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("C-4 · cableado del gate de fetch (source-scan)")
struct GroupFetchGateWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Igual que `source(_:)` pero SIN líneas de comentario. Los asserts NEGATIVOS hablan de CÓDIGO: el
    /// fix documenta en prosa POR QUÉ jamás se fuerza un fetch, y un `contains` sobre el fuente crudo se
    /// auto-refutaría en cuanto alguien escribiera el nombre del método en esa explicación. (Ninguno de
    /// los dos ficheros escaneados usa comentarios de bloque, así que basta el filtro por líneas.)
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El adaptador lee el engine PRIVADO (los candidatos son siempre `isOwner` ⇒ sus zonas viven en la
    /// base privada; el `shared` no entrega nada suyo), la cuenta REAL, `autoSyncActive` y los TRES
    /// búferes de la ventana export-only. Nada hardcodeado.
    @Test func adapterReadsTheRightManagerState() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        #expect(src.contains("func privateFetchGateSignal(candidateZoneNames: Set<String>)"))
        #expect(src.contains("privateEngineMounted: privateEngine != nil"))
        #expect(!src.contains("privateEngineMounted: sharedEngine != nil"))
        #expect(src.contains("accountAvailable: iCloudSyncService.shared.isAccountAvailable"))
        #expect(src.contains("autoSyncActive: autoSyncActive"))
        #expect(src.contains("deferredRecordZoneEventCount: deferredFetchedRecordZoneEvents.count"))
        #expect(src.contains("deferredDatabaseEventCount: deferredFetchedDatabaseEvents.count"))
        #expect(src.contains("deferredClearAllRequested: deferredClearAllRequested"))
        #expect(src.contains("zonesWithFailedFetch: zonesWithFailedFetchThisSession"))
    }

    /// El DEFAULT de producción del seam lee el singleton. Es el único assert que distingue «gate
    /// cableado» de «gate presente pero muerto»: un default inerte (una señal constante «sin canal»)
    /// dejaría en verde los tests de comportamiento del uploader Y desactivaría el gate en producción.
    @Test func productionDefaultReadsTheManagerSignal() throws {
        let src = try Self.code("Yala/Services/CloudSync/Groups/GroupMigrationUploader.swift")
        #expect(src.contains("SplitSyncManager.shared.privateFetchGateSignal(candidateZoneNames: zones)"))
    }

    /// El testigo se alimenta de los eventos del delegate y de nada más: `.willFetchChanges` abre ciclo,
    /// `.didFetchChanges` lo cierra, y el error por zona se registra donde ya se filtra por `event.error`.
    @Test func witnessIsFedByDelegateEventsOnly() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        #expect(src.contains("fetchCyclesInFlight[name, default: 0] += 1"))
        #expect(src.contains("enginesWithCompletedFetchCycle.insert(name)"))
        // El apply fallido invalida el testigo en SUS DOS caminos (save fallido y sin contexto).
        #expect(src.components(separatedBy: "fetchApplyFailedThisSession = true").count - 1 == 2)
        // Los tokens invalidados limpian el testigo: «ya completó un ciclo» deja de decir nada del corpus
        // que viene.
        #expect(src.contains("enginesWithCompletedFetchCycle.removeAll()"))

        // El AUTO-SANADO del testigo por zona es una cuestión de ORDEN: el `remove` tiene que ir DESPUÉS
        // del guard de error, o una zona que falló una vez bloquearía el gate para siempre.
        let insert = try #require(src.range(of: "zonesWithFailedFetchThisSession.insert(zoneName)"))
        let remove = try #require(src.range(of: "zonesWithFailedFetchThisSession.remove(zoneName)"))
        #expect(insert.lowerBound < remove.lowerBound)
    }

    /// La señal es PASIVA: el uploader jamás fuerza un fetch (fetchearía la base privada ENTERA y
    /// descartaría, con avance de token, lo de los grupos ya congelados en esa misma pasada) ni dispara
    /// la promoción (que lanza un Task con un fetch que nadie awaitea).
    @Test func theSignalIsPassive_neverForcesAFetchNorThePromotion() throws {
        let src = try Self.code("Yala/Services/CloudSync/Groups/GroupMigrationUploader.swift")
        #expect(!src.contains("fetchChanges"))
        #expect(!src.contains("evaluateQuiescentPromotion"))
        #expect(!src.contains("syncNow"))
    }

    /// El gate va de PASADA y ANTES de `fetchCandidates()`: así cubre el `buildPayload` del primer grupo
    /// y no invalida el array de candidatos (aquí todavía no existe).
    @Test func theGateRunsBeforeFetchCandidates() throws {
        let src = try Self.code("Yala/Services/CloudSync/Groups/GroupMigrationUploader.swift")
        let gate = try #require(src.range(of: "await awaitGroupFetchSettled(candidateZoneNames: gateZones)"))
        let candidates = try #require(src.range(of: "let candidates = fetchCandidates()"))
        #expect(gate.lowerBound < candidates.lowerBound)
    }

    /// El diferimiento usa su PROPIA serie de canario: `groupMigrationFailed` significa «un paso de la
    /// migración falló» y se lee para decidir el encendido — un diferimiento benigno la envenenaría. Y
    /// las dos claves están separadas: con una sola, el diferimiento de PASADA (que gana casi siempre)
    /// silenciaría para todo el proceso al de GRUPO, que es la señal más accionable.
    @Test func deferralUsesItsOwnCanarySeries() throws {
        let src = try Self.code("Yala/Services/CloudSync/Groups/GroupMigrationUploader.swift")
        #expect(src.contains(".groupMigrationDeferred"))
        #expect(src.contains("\"fetchGate\""))
        #expect(src.contains("\"fetchGatePerGroup\""))
        #expect(!src.contains("canaryOnce(.groupMigrationFailed"))
    }
}
