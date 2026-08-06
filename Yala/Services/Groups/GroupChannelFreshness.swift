//
//  GroupChannelFreshness.swift
//  Yala
//
//  Adaptador de runtime de `GroupChannelFreshnessGate`: lee el store y los DOS canales de Grupos y produce
//  el veredicto por ZONA. La decisión vive en la lógica pura; aquí solo se recoge la evidencia.
//
//  Sus dos consumidores hacen la MISMA pregunta y por eso comparten esta pieza: `OrphanedBridgedTxSweeper`
//  (que borra o suelta punteros cuando la respuesta es «el gasto no existe») y
//  `NewTransactionView.resolveBridgedPointer` (que devuelve Borrar/Duplicar al usuario con la misma
//  respuesta). Resolverlos con dos reglas distintas es el anti-patrón que este repo lleva media docena de
//  fixes persiguiendo.
//
//  **Fail-closed en TODOS los `catch`.** Un fetch que lanza devuelve `.noSettledGroup`, igual que una zona
//  desconocida: sin evidencia no se toca nada y se reintenta en el próximo arranque.
//

import Foundation
import SwiftData

@MainActor
enum GroupChannelFreshness {

    /// Señales de SESIÓN de los dos canales. Se pasan como valor —y no se leen dentro— para que la
    /// evidencia sea inyectable en test sin tocar los singletons vivos, que llevan estado de proceso
    /// (`lastPullCycleCompleted` se apaga en cada ciclo no completado; los sets de engines se limpian con
    /// `resetLocalGroupsSyncState`) y se filtrarían de un test al siguiente.
    struct ChannelSignals {
        let backendPullCompleted: Bool
        let cloudKitAllEnginesCompletedFetchCycle: Bool
        let cloudKitZoneFetchFailed: (String) -> Bool

        /// Lo que ven los call-sites de producción. Es `static func` y no `static var` con default de
        /// parámetro: un default se evalúa en contexto NONISOLATED y leer los singletons `@MainActor`
        /// desde ahí es un warning hoy y un error en Swift 6 — por eso los métodos toman `ChannelSignals?`
        /// y resuelven `?? .live()` DENTRO del cuerpo, que sí es `@MainActor`.
        static func live() -> ChannelSignals {
            ChannelSignals(
                backendPullCompleted: GroupsSyncClient.shared.lastPullCycleCompleted,
                cloudKitAllEnginesCompletedFetchCycle:
                    SplitSyncManager.shared.hasCompletedFetchCycleOnAllEngines,
                cloudKitZoneFetchFailed: { SplitSyncManager.shared.zoneFetchFailedThisSession($0) }
            )
        }
    }

    // MARK: - Veredicto

    /// Veredicto de una zona **y a qué canal se le pidió la evidencia**.
    ///
    /// Las dos cosas viajan juntas porque el barrido necesita las dos y son preguntas distintas: el
    /// veredicto decide si «no está» significa «no existe», y `belongsToBackendChannel` decide si la zona
    /// entra siquiera en su conjunto de CANDIDATAS. Van en el mismo valor para no repetir el fetch de
    /// grupos ni ampliar el número de call-sites de esta primitiva, que va con conteo esperado en
    /// `freshnessGate_hasExactlyItsThreeProductionCallSites`.
    struct ZoneStatus: Equatable {
        let verdict: GroupChannelFreshnessGate.Verdict
        /// ALGUNA fila de la zona pertenece al canal backend (ANY-row) — el mismo predicado con el que el
        /// gate eligió a qué canal preguntar.
        let belongsToBackendChannel: Bool

        var isFresh: Bool { verdict.isFresh }
    }

    /// Veredicto de TODAS las zonas con `SplitGroup` local, con un solo fetch de grupos y uno del cursor.
    /// Es la forma que usa el barrido, que decide sobre muchas zonas a la vez.
    ///
    /// Una zona AUSENTE del mapa es una zona sin `SplitGroup` local: el caller la trata como
    /// `.noSettledGroup` (ver `verdict(for:in:)`), nunca como fresca.
    static func verdictsByZone(
        context: ModelContext,
        signals: ChannelSignals? = nil
    ) -> [String: ZoneStatus] {
        let signals = signals ?? .live()
        let rows: [SplitGroup]
        do {
            rows = try context.fetch(FetchDescriptor<SplitGroup>())
        } catch {
            #if DEBUG
            print("GroupChannelFreshness: fetch de grupos falló — ninguna zona se da por fresca: \(error)")
            #endif
            return [:]
        }
        let pulledZones = GroupsSyncClient.shared.pulledGroupIDs(context: context)

        var byZone: [String: [SplitGroup]] = [:]
        for row in rows where !row.cloudKitZoneID.isEmpty {
            byZone[row.cloudKitZoneID, default: []].append(row)
        }
        return byZone.mapValues { zoneRows in
            let e = evidence(zoneID: zoneRows[0].cloudKitZoneID, rows: zoneRows,
                             pulledZones: pulledZones, signals: signals)
            return ZoneStatus(
                verdict: GroupChannelFreshnessGate.evaluate(e),
                belongsToBackendChannel: e.belongsToBackendChannel)
        }
    }

    /// Veredicto de UNA zona (la forma que usa el editor, que solo tiene la transacción abierta).
    /// `nil`/vacío ⇒ `.noSettledGroup`: sin zona no hay canal al que preguntarle.
    static func verdict(
        forZone zoneID: String?,
        context: ModelContext,
        signals: ChannelSignals? = nil
    ) -> GroupChannelFreshnessGate.Verdict {
        guard let zoneID, !zoneID.isEmpty else { return .noSettledGroup }
        let signals = signals ?? .live()
        let rows: [SplitGroup]
        do {
            rows = try context.fetch(
                FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID }))
        } catch {
            #if DEBUG
            print("GroupChannelFreshness: fetch de la zona falló — se trata como no fresca: \(error)")
            #endif
            return .noSettledGroup
        }
        let pulledZones = GroupsSyncClient.shared.pulledGroupIDs(context: context)
        return GroupChannelFreshnessGate.evaluate(
            evidence(zoneID: zoneID, rows: rows, pulledZones: pulledZones, signals: signals))
    }

    /// Azúcar del editor: ¿puedo afirmar que lo que no está en el store NO EXISTE?
    static func isFresh(
        zone zoneID: String?,
        context: ModelContext,
        signals: ChannelSignals? = nil
    ) -> Bool {
        verdict(forZone: zoneID, context: context, signals: signals).isFresh
    }

    // MARK: - Recolección de la evidencia

    /// Traduce las filas de UNA zona + las señales a la forma que consume la lógica pura.
    ///
    /// Los dos cuantificadores son deliberados y opuestos, y es el criterio de esta familia:
    /// «asentada» se exige a TODAS las filas (restringe — con un duplicado, una fila que sigue importando
    /// tiene que bloquear) y «del canal backend» basta con UNA (es la que decide a QUÉ canal preguntarle,
    /// y una fila backend en la zona significa que su verdad vive allí).
    private static func evidence(
        zoneID: String,
        rows: [SplitGroup],
        pulledZones: Set<String>,
        signals: ChannelSignals
    ) -> GroupChannelFreshnessGate.ZoneEvidence {
        GroupChannelFreshnessGate.ZoneEvidence(
            zoneHasSettledGroup: !rows.isEmpty && rows.allSatisfy { $0.initialMemberImportStartedAt == nil },
            belongsToBackendChannel: GroupZoneCacheGate.belongsToBackendChannel(
                rowsInZone: rows.map {
                    (isBackendGroup: $0.isBackendGroup, movedToBackendAt: $0.movedToBackendAt)
                }),
            backendPullCompleted: signals.backendPullCompleted,
            backendCursorListsZone: pulledZones.contains(zoneID),
            cloudKitBothEnginesCompletedFetchCycle: signals.cloudKitAllEnginesCompletedFetchCycle,
            cloudKitZoneFetchFailedThisSession: signals.cloudKitZoneFetchFailed(zoneID)
        )
    }
}
