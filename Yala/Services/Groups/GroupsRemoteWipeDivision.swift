//
//  GroupsRemoteWipeDivision.swift
//  Yala
//
//  **«Vaciar datos» en un dispositivo sin los grupos ya no deja al resto sin los gastos de grupo** (ticket
//  `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere`).
//
//  **El hueco.** «Vaciar datos» borra toda `TransactionItem`, también lo que el bridge puso en lo personal, y pide la
//  convergencia para reponerlo (`DataWipeService.wipePersonalDataKeepingGroups`). La convergencia re-puentea desde el store
//  LOCAL de Grupos, que no viaja por iCloud (`cloudKitDatabase: .none`). Un iPad que nunca entró en Grupos converge sobre
//  nada, y su borrado viaja por el espejo. El iPhone con grupos recibe la señal y, en el orden normal (sin nada de grupo
//  posterior a la señal), no pedía su convergencia: daba por repuesto lo que el origen no iba a reponer.
//
//  **La receta: el origen dice QUÉ repone, y el receptor repone el resto.**
//
//  - **El origen escribe el reparto** en el iCloud-KV, antes de la señal y con la misma hora: los ids que su convergencia
//    va a re-puentear, con los filtros de ella. Sin grupos, el reparto va vacío.
//  - **El receptor apunta que lo espera**, antes de su borrado (`awaitOrigin`). En el arranque, antes de la convergencia
//    (`resolveIfArrived`), pide la suya SIN los ids del reparto. Sin reparto espera, y a los 30 días lo suelta.
//  - Origen y receptor reponen conjuntos disjuntos, así que no se cruzan las dos convergencias del 27-sep.
//
//  **Por qué ids y no un «sí puedo / no puedo».** Un sí/no no cubre al origen con una parte de los grupos, ni el gasto que
//  el origen aún no conocía al vaciar: el corte del receptor se lo lleva (es anterior a la señal) y nadie lo repondría.
//
//  **Por qué ids y no filas** (como las declaraciones de `GroupsRemoteWipeReturn`). El receptor ya se llevó con su corte
//  todo lo anterior a la señal: no queda ningún borrado del espejo que esperar antes de reponer.
//
//  **El orden tardío no pasa por aquí.** Con filas de grupo posteriores a la señal, el receptor pide la convergencia entera
//  (`GroupsBridgeRestoreConvergenceLogic.remoteWipeTakesRowsTheOriginReconverged`), que ya cubría este caso.
//
//  **Lo que queda fuera, dicho entero:**
//   · **«Disjuntos y que lo cubren todo» vale si el origen llega a converger.** Lo que declara y luego no repone —un gasto
//     que agota los intentos de `GroupsPendingBridgeIntent`, un relevo de persona o una desinstalación antes de su arranque
//     en frío— no vuelve. Antes del reparto tampoco volvía.
//   · **Un reparto que no se deja leer se trata como uno que no llegó**: se espera y a los 30 días se suelta. Reponer todo
//     arriesgaría el duplicado que el reparto existe para evitar; el formato está fijado por test.
//   · **Una petición ENTERA ya puesta gana**, aunque dos vaciados seguidos en dos dispositivos con grupos permitirían
//     afinarla (ticket `consecutive-wipes-whole-convergence-ignores-the-second-division`).
//   · **La clave del KV no se retira nunca**: cada vaciado la sobrescribe (ticket `wipe-division-kv-key-has-no-quota-ceiling`).
//   · **Lo que el origen recibe por su canal DESPUÉS de vaciar** lo puentea su sync de grupos, y el receptor también lo
//     repone. Es el residual de siempre de «cada dispositivo con grupos puentea lo que le llega»: duplica solo si los dos
//     puentean antes de cruzarse por el espejo, y el siguiente re-puente del gasto lo concilia.
//   · **Dos receptores con grupos** (tres dispositivos o más) reponen los dos lo que no está en el reparto. Mismo residual.
//   · **Un origen con un build anterior** no escribe reparto: el receptor espera 30 días y lo suelta, como hasta hoy.
//   · **La cuota del KV** (1 MB para todo el Apple ID). El reparto lleva un id por gasto y por liquidación: unos 39 bytes
//     cada uno.
//   · Sigue siendo en el arranque en frío (`wipe-data-group-rows-return-only-on-the-next-cold-launch`), y en el flujo
//     típico en el SEGUNDO: la señal se procesa después de `retryPendingBridges`, así que la espera se apunta tarde para ese.
//

import Foundation
import SwiftData
import os

/// La decisión pura.
nonisolated enum GroupsRemoteWipeDivisionLogic {

    /// **Lo que el origen de un vaciado repone**, atado a la hora de su señal. Las claves son los ids tal como los guarda la
    /// fila (`uuidString`).
    struct Division: Codable, Equatable {
        let signaledAt: Double
        let expenseIDs: Set<String>
        let settlementIDs: Set<String>
    }

    /// Lo que el receptor espera: el reparto de la señal que procesó, y desde cuándo lo espera.
    struct Awaiting: Codable, Equatable {
        let signaledAt: Double
        let since: Double
    }

    enum Resolution: Equatable {
        /// Pedir la convergencia sin estos ids: los repone el origen.
        case request(excludingExpenses: Set<String>, excludingSettlements: Set<String>)
        /// El reparto aún no llegó.
        case wait
        /// Pasó el plazo sin reparto: el origen no lo escribe (un build anterior). Se suelta, como hasta hoy.
        case giveUp
    }

    /// **Cuánto se espera un reparto que no llega.** El del KV de las declaraciones: cubre los arranques en frío hasta que
    /// el iCloud-KV sincroniza, y no deja una espera abierta para siempre.
    static let lifetime: TimeInterval = GroupsRemoteWipeReturnLogic.lifetime

    /// **El reparto es el de ESTA señal.** La hora viaja como `Double` por el KV y el receptor la pasa por `Date`. La vuelta
    /// es exacta (medido en la review sobre 4 millones de valores), así que el margen es defensivo: cubre una hora que algún
    /// día se redondee por el camino. Un milisegundo separa de sobra dos vaciados.
    static let signalTolerance: TimeInterval = 0.001

    static func sameSignal(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < signalTolerance
    }

    /// **Lo que el origen repone: los mismos filtros de su convergence** (`GroupsBridgeRestoreConvergence`). Todos los gastos
    /// locales —el bridge decide los de grupos ocultos sin crear nada, aquí y en el receptor—, y las liquidaciones
    /// confirmadas fuera de grupos ocultos. Con el dominio cerrado su convergencia espera y no repone: reparto vacío.
    static func originDivision(
        signaledAt: Date, domainOpen: Bool,
        localExpenseIDs: Set<String>, confirmedVisibleSettlementIDs: Set<String>
    ) -> Division {
        guard domainOpen else {
            return Division(signaledAt: signaledAt.timeIntervalSince1970, expenseIDs: [], settlementIDs: [])
        }
        return Division(signaledAt: signaledAt.timeIntervalSince1970,
                        expenseIDs: localExpenseIDs, settlementIDs: confirmedVisibleSettlementIDs)
    }

    /// Qué hace el arranque con lo que espera. El plazo corre desde que se empezó a esperar, no desde la señal: un
    /// dispositivo que procesa una señal vieja todavía encuentra su reparto en el KV. El valor absoluto cubre un reloj que
    /// vuelve atrás.
    static func resolve(awaiting: Awaiting, division: Division?, now: Date) -> Resolution {
        if let division, sameSignal(division.signaledAt, awaiting.signaledAt) {
            return .request(excludingExpenses: division.expenseIDs, excludingSettlements: division.settlementIDs)
        }
        return abs(now.timeIntervalSince1970 - awaiting.since) >= lifetime ? .giveUp : .wait
    }
}

/// Lo que persiste: el reparto en el iCloud-KV del Apple ID, y en local lo que el receptor espera. En el main actor, como la
/// superficie del KV (`OwnerKeyValueWriting`).
enum GroupsRemoteWipeDivisionStore {

    /// El reparto del último vaciado, en JSON dentro de un string (la puerta no escribe `Data`). Formato compartido entre
    /// versiones de la app en el parque: no se renombra.
    static let kvKey = "groupsWipeDivision"

    /// Lo que el receptor espera. Prefijo `fullModeActivation.*`: fuera de las listas del reset de preferencias, así que
    /// sobrevive al borrado que lo apunta.
    nonisolated static let awaitingKey = "fullModeActivation.groupsConvergenceAwaitingDivision"

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    static func readDivision(_ kv: OwnerKeyValueWriting) -> GroupsRemoteWipeDivisionLogic.Division? {
        guard let json = kv.string(forKey: kvKey), let data = json.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(GroupsRemoteWipeDivisionLogic.Division.self, from: data)
        } catch {
            #if DEBUG
            print("GroupsRemoteWipeDivisionStore: Error: \(error)")
            #endif
            return nil
        }
    }

    /// **Sin `synchronize` propio.** El origen lo escribe justo antes de la señal, y el `synchronize` de
    /// `PreferenceSyncService.signalWipeInitiated` sube los dos cambios juntos.
    static func writeDivision(_ division: GroupsRemoteWipeDivisionLogic.Division, to kv: OwnerKeyValueWriting) throws {
        let data = try encoder().encode(division)
        guard let json = String(data: data, encoding: .utf8) else { return }
        kv.setString(json, forKey: kvKey)
    }

    static func awaiting(_ defaults: UserDefaults) -> GroupsRemoteWipeDivisionLogic.Awaiting? {
        guard let data = defaults.data(forKey: awaitingKey) else { return nil }
        do {
            return try JSONDecoder().decode(GroupsRemoteWipeDivisionLogic.Awaiting.self, from: data)
        } catch {
            #if DEBUG
            print("GroupsRemoteWipeDivisionStore: Error: \(error)")
            #endif
            return nil
        }
    }

    static func setAwaiting(_ awaiting: GroupsRemoteWipeDivisionLogic.Awaiting, _ defaults: UserDefaults) throws {
        defaults.set(try encoder().encode(awaiting), forKey: awaitingKey)
    }

    /// Lo retiran una petición ENTERA de convergencia (que repone todo, también lo que se esperaba) y el relevo de persona
    /// (`DataWipeService.removeGroupsDomainPreferenceKeys`).
    nonisolated static func clearAwaiting(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: awaitingKey)
    }
}

@MainActor
enum GroupsRemoteWipeDivision {

    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    /// **El origen escribe lo que va a reponer.** Lo llama «Vaciar datos» antes de borrar y antes de la señal, con la hora
    /// de la señal. Si no se puede escribir, deja rastro y el borrado sigue: el receptor espera, y a los 30 días lo suelta.
    /// `domainOpen` sin valor por defecto: es la puerta de la convergencia del origen, con SUS `defaults`
    /// (`GroupTransactionBridge.isDomainOpenForBridge(defaults:)`), y el llamador la tiene que nombrar.
    static func declare(
        context: ModelContext, signaledAt: Date,
        kv: OwnerKeyValueWriting = GroupsRemoteWipeReturn.defaultStore,
        domainOpen: Bool
    ) {
        do {
            let hiddenZones = Set(try context.fetch(FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.isHiddenForAll })).map(\.cloudKitZoneID))
            let division = GroupsRemoteWipeDivisionLogic.originDivision(
                signaledAt: signaledAt, domainOpen: domainOpen,
                localExpenseIDs: Set(try context.fetch(FetchDescriptor<SplitExpense>()).map(\.id.uuidString)),
                confirmedVisibleSettlementIDs: Set(try context.fetch(FetchDescriptor<SplitSettlement>())
                    .filter { $0.isConfirmed && !hiddenZones.contains($0.groupZoneID) }.map(\.id.uuidString)))
            try GroupsRemoteWipeDivisionStore.writeDivision(division, to: kv)
            logger.notice("GroupsRemoteWipeDivision declared expenses=\(division.expenseIDs.count, privacy: .public) settlements=\(division.settlementIDs.count, privacy: .public)")
        } catch {
            logger.error("GroupsRemoteWipeDivision declaration not stored")
            #if DEBUG
            print("GroupsRemoteWipeDivision: Error: \(error)")
            #endif
        }
    }

    /// **El receptor apunta que espera el reparto de la señal que procesa.** Antes de su borrado, como las peticiones de
    /// convergencia: un corte después lo perdería. Con una petición ENTERA puesta, apuntar no cambia nada: al resolverse,
    /// la petición con exclusión no la recorta (`GroupsBridgeRestoreConvergenceStore.markPending(excluding:)`). Si no se
    /// puede apuntar, deja rastro y el borrado sigue: un borrado a medias sería peor.
    static func awaitOrigin(signaledAt: Date, defaults: UserDefaults, now: Date = .now) {
        do {
            try GroupsRemoteWipeDivisionStore.setAwaiting(
                .init(signaledAt: signaledAt.timeIntervalSince1970, since: now.timeIntervalSince1970), defaults)
        } catch {
            logger.error("GroupsRemoteWipeDivision awaiting not stored")
            #if DEBUG
            print("GroupsRemoteWipeDivision: Error: \(error)")
            #endif
        }
    }

    /// **El arranque resuelve lo que se espera**, antes de la convergencia (`AppBootstrapper.retryPendingBridges`): con el
    /// reparto de la señal, pide la convergencia sin lo que repone el origen, con las liquidaciones.
    ///
    /// **Con una petición ENTERA ya puesta solo suelta la espera** (review adversarial, lente de tests): la entera repone
    /// todo lo local. Y no pide las liquidaciones: la de restaurar dentro de «Activar Yala completo» las deja fuera a
    /// propósito, porque re-puentearlas con el corpus aún bajando borraría las reales que vuelven.
    static func resolveIfArrived(
        kv: OwnerKeyValueWriting = GroupsRemoteWipeReturn.defaultStore,
        defaults: UserDefaults = .standard, now: Date = .now
    ) {
        guard let awaiting = GroupsRemoteWipeDivisionStore.awaiting(defaults) else { return }
        guard !GroupsBridgeRestoreConvergenceStore.isWholePending(defaults) else {
            GroupsRemoteWipeDivisionStore.clearAwaiting(defaults)
            logger.notice("GroupsRemoteWipeDivision covered by a whole convergence")
            return
        }
        switch GroupsRemoteWipeDivisionLogic.resolve(
            awaiting: awaiting, division: GroupsRemoteWipeDivisionStore.readDivision(kv), now: now) {
        case .request(let expenses, let settlements):
            do {
                GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
                try GroupsBridgeRestoreConvergenceStore.markPending(
                    excluding: .init(expenseIDs: expenses, settlementIDs: settlements), defaults)
                GroupsRemoteWipeDivisionStore.clearAwaiting(defaults)
                logger.notice("GroupsRemoteWipeDivision requested excludedExpenses=\(expenses.count, privacy: .public) excludedSettlements=\(settlements.count, privacy: .public)")
            } catch {
                logger.notice("GroupsRemoteWipeDivision deferred reason=requestNotStored")
                #if DEBUG
                print("GroupsRemoteWipeDivision: Error: \(error)")
                #endif
            }
        case .wait:
            logger.notice("GroupsRemoteWipeDivision waiting")
        case .giveUp:
            GroupsRemoteWipeDivisionStore.clearAwaiting(defaults)
            logger.notice("GroupsRemoteWipeDivision gave up")
        }
    }
}
