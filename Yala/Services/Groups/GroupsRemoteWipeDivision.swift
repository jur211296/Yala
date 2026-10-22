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
//  **Por qué ids y no filas.** El receptor ya se llevó con su corte todo lo anterior a la señal: no queda ningún borrado
//  del espejo que esperar antes de reponer.
//
//  **El orden tardío no pasa por aquí.** Con filas de grupo posteriores a la señal, el receptor pide la convergencia entera
//  (`GroupsBridgeRestoreConvergenceLogic.remoteWipeTakesRowsTheOriginReconverged`), que ya cubría este caso.
//
//  **Lo que queda fuera, dicho entero:**
//   · **Lo que el origen promete y no repone lo repone el receptor, 72 horas después de resolver el reparto** (ticket
//     `wipe-division-exclusion-trusts-the-origin-to-converge`, `takeOverIfOverdue`): un gasto que agota los intentos de
//     `GroupsPendingBridgeIntent`, un relevo de persona o una desinstalación antes de su arranque en frío. Si el origen
//     repone después, su bridge concilia por id sobre las filas del receptor ya bajadas. Si los dos puentean antes de
//     cruzarse por el espejo —o dos receptores retoman a la vez—, duplica, y en una liquidación eso son dos borradores
//     aprobables que nadie poda (ticket `wipe-division-takeover-can-cross-a-late-origin-before-the-mirror`).
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

    /// **Cuánto se espera un reparto que no llega.** Cubre los arranques en frío hasta que el iCloud-KV sincroniza, y no
    /// deja una espera abierta para siempre.
    static let lifetime: TimeInterval = 30 * 24 * 60 * 60

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

    // MARK: - Lo prometido que no llega (ticket `wipe-division-exclusion-trusts-the-origin-to-converge`)

    /// **Lo que el receptor dejó en manos del origen**: los ids que excluyó de su convergencia, la hora de la señal y desde
    /// cuándo confía (el arranque que resolvió el reparto). Solo lo que falta: lo que ya llegó sale de aquí.
    struct Trusted: Codable, Equatable {
        let signaledAt: Double
        let since: Double
        let expenseIDs: Set<String>
        let settlementIDs: Set<String>
    }

    enum TrustReview: Equatable {
        /// Sigue faltando algo y el techo no ha pasado: se espera, con lo que queda.
        case keep(Trusted)
        /// Todo lo prometido llegó: el origen cumplió.
        case settled
        /// Pasó el techo: el receptor repone él lo que sigue faltando.
        case takeOver(expenses: Set<String>, settlements: Set<String>)
    }

    /// **Cuánto se confía en el origen**, desde el arranque que resolvió el reparto. Su convergencia corre en su siguiente
    /// arranque en frío, que suele llegar en horas. Tres días lo cubren sin dejar a la persona una semana sin sus gastos de grupo. Si el origen repone después, converge
    /// sobre las filas del receptor ya bajadas por el espejo y el bridge las concilia por id.
    static let trustCeiling: TimeInterval = 3 * 24 * 60 * 60

    /// Qué hace el arranque con lo confiado. Un id **llegó** si aquí hay alguna fila suya POSTERIOR a la señal (el llamador
    /// filtra): el corte del receptor se llevó todo lo anterior y su convergencia lo excluye, así que esa fila la trajo el
    /// espejo. Una anterior que baja tarde —de un tercer dispositivo sin red— no prueba nada: su propio corte se la llevará.
    /// **El plazo corre desde que se resolvió el reparto, no desde que se empezó a esperar** (review adversarial, lente de
    /// sync): un reparto que llega tarde, o un receptor que no arranca en días, daba la promesa por vencida en el mismo
    /// arranque que la apuntaba, sin dejar al origen ni un arranque de margen. El valor absoluto cubre un reloj que vuelve
    /// atrás, como en `resolve`.
    static func review(
        _ trusted: Trusted, arrivedExpenses: Set<String>, arrivedSettlements: Set<String>, now: Date
    ) -> TrustReview {
        let expenses = trusted.expenseIDs.subtracting(arrivedExpenses)
        let settlements = trusted.settlementIDs.subtracting(arrivedSettlements)
        guard !expenses.isEmpty || !settlements.isEmpty else { return .settled }
        guard abs(now.timeIntervalSince1970 - trusted.since) >= trustCeiling else {
            return .keep(Trusted(signaledAt: trusted.signaledAt, since: trusted.since,
                                 expenseIDs: expenses, settlementIDs: settlements))
        }
        return .takeOver(expenses: expenses, settlements: settlements)
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

    /// Lo que el receptor dejó en manos del origen (`GroupsRemoteWipeDivisionLogic.Trusted`). Prefijo
    /// `fullModeActivation.*`, como la espera.
    nonisolated static let trustedKey = "fullModeActivation.groupsConvergenceTrustedDivision"

    static func trusted(_ defaults: UserDefaults) -> GroupsRemoteWipeDivisionLogic.Trusted? {
        guard let data = defaults.data(forKey: trustedKey) else { return nil }
        do {
            return try JSONDecoder().decode(GroupsRemoteWipeDivisionLogic.Trusted.self, from: data)
        } catch {
            #if DEBUG
            print("GroupsRemoteWipeDivisionStore: Error: \(error)")
            #endif
            return nil
        }
    }

    static func setTrusted(_ trusted: GroupsRemoteWipeDivisionLogic.Trusted, _ defaults: UserDefaults) throws {
        defaults.set(try encoder().encode(trusted), forKey: trustedKey)
    }

    /// La retiran el origen que cumplió, la retoma pasado el techo y el relevo de persona.
    nonisolated static func clearTrusted(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: trustedKey)
    }
}

@MainActor
enum GroupsRemoteWipeDivision {

    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    /// El iCloud-KV de producción, siempre por la puerta. Los llamadores lo reciben como valor por defecto sin nombrarla.
    /// `nonisolated` porque un valor por defecto se evalúa en el contexto del llamador; la fachada no tiene estado.
    nonisolated static var defaultStore: OwnerKeyValueWriting { OwnerKeyValueStore.shared }

    /// **El origen escribe lo que va a reponer.** Lo llama «Vaciar datos» antes de borrar y antes de la señal, con la hora
    /// de la señal. Si no se puede escribir, deja rastro y el borrado sigue: el receptor espera, y a los 30 días lo suelta.
    /// `domainOpen` sin valor por defecto: es la puerta de la convergencia del origen, con SUS `defaults`
    /// (`GroupTransactionBridge.isDomainOpenForBridge(defaults:)`), y el llamador la tiene que nombrar.
    static func declare(
        context: ModelContext, signaledAt: Date,
        kv: OwnerKeyValueWriting = defaultStore,
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
        kv: OwnerKeyValueWriting = defaultStore,
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
                // Lo que se deja en manos del origen, ANTES de la petición: un corte entre las dos deja la espera puesta y
                // el arranque siguiente lo rehace. Al revés, la exclusión quedaría sin promesa y lo del origen, sin techo.
                // Sustituye a la de un reparto anterior, como la exclusión; vacía, no hay nada que confiar.
                if expenses.isEmpty && settlements.isEmpty {
                    GroupsRemoteWipeDivisionStore.clearTrusted(defaults)
                } else {
                    try GroupsRemoteWipeDivisionStore.setTrusted(
                        .init(signaledAt: awaiting.signaledAt, since: now.timeIntervalSince1970,
                              expenseIDs: expenses, settlementIDs: settlements), defaults)
                }
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

    /// **Lo que el origen prometió y no llega, lo repone el receptor pasado el techo** (ticket
    /// `wipe-division-exclusion-trusts-the-origin-to-converge`). En el arranque, justo después de la convergencia y con sus
    /// mismos gates (`AppBootstrapper.retryPendingBridges`: import quieto y dominio abierto), y con sesión privada como ella:
    /// en solo-grupos el bridge borra las transacciones reales que re-puentea.
    ///
    /// - Lo que ya bajó del origen (filas posteriores a la señal) sale de la promesa. Si llegó todo, se suelta.
    /// - Pasado el techo, re-puentea lo prometido que siga faltando y que tenga aquí, con los filtros de la convergencia
    ///   (liquidaciones confirmadas fuera de grupos ocultos), y suelta la promesa. Lo que el bridge no atiende pasa a la
    ///   intención durable con el canal del backend, como en la convergencia.
    /// - **Mientras se espera el reparto de una señal más nueva no hace nada**: ese reparto decide, y al resolverse
    ///   sustituye la promesa.
    ///
    /// **Sin copias dobles cuando el origen repone tarde.** Si sus filas llegan antes de que el receptor mire, no se
    /// re-puentea nada. Si el origen converge después, lo hace detrás de la quiescencia del import, sobre las filas del
    /// receptor ya bajadas, y el bridge las concilia por id. Queda el residual de siempre: los dos puentean antes de cruzarse
    /// por el espejo, y el siguiente re-puente lo concilia. Si el bridge lanza, la promesa sigue y el arranque siguiente
    /// reintenta: lo que sí se repuso ya cuenta como llegado.
    static func takeOverIfOverdue(context: ModelContext, defaults: UserDefaults = .standard, now: Date = .now) {
        guard let trusted = GroupsRemoteWipeDivisionStore.trusted(defaults) else { return }
        guard GroupsRemoteWipeDivisionStore.awaiting(defaults) == nil else { return }
        guard SessionState.shared.hasPrivateSession else { return }
        guard GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults) else { return }
        do {
            // Llegó lo que tiene aquí alguna fila posterior a la señal: una transacción o un borrador (la marca de una
            // liquidación aprobada es un borrador, y su transacción real no lleva `splitSettlementID`). Mismo reloj que el
            // del origen, que fecha lo que repone; una fila del receptor con su reloj atrasado cuenta como no llegada, y
            // re-puentearla aquí es idempotente.
            let signal = Date(timeIntervalSince1970: trusted.signaledAt)
            let rows = try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }))
                .filter { $0.createdAt > signal }
            let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }))
                .filter { $0.createdAt > signal }
            let review = GroupsRemoteWipeDivisionLogic.review(
                trusted,
                arrivedExpenses: Set(rows.compactMap(\.splitExpenseID) + drafts.compactMap(\.splitExpenseID)),
                arrivedSettlements: Set(rows.compactMap(\.splitSettlementID) + drafts.compactMap(\.splitSettlementID)),
                now: now)
            switch review {
            case .settled:
                GroupsRemoteWipeDivisionStore.clearTrusted(defaults)
                logger.notice("GroupsRemoteWipeDivision origin returned what it promised")
            case .keep(let rest):
                if rest != trusted { try GroupsRemoteWipeDivisionStore.setTrusted(rest, defaults) }
            case .takeOver(let expenses, let settlements):
                let hiddenZones = Set(try context.fetch(FetchDescriptor<SplitGroup>(
                    predicate: #Predicate { $0.isHiddenForAll })).map(\.cloudKitZoneID))
                let expenseIDs = Set(try context.fetch(FetchDescriptor<SplitExpense>()).map(\.id)
                    .filter { expenses.contains($0.uuidString) })
                let settlementIDs = Set(try context.fetch(FetchDescriptor<SplitSettlement>())
                    .filter { $0.isConfirmed && !hiddenZones.contains($0.groupZoneID)
                        && settlements.contains($0.id.uuidString) }
                    .map(\.id))
                let bridge = GroupTransactionBridge.shared
                let attendedExpenses = expenseIDs.isEmpty ? [] : try bridge.bridgeRemoteExpenses(ids: Array(expenseIDs))
                let attendedSettlements = settlementIDs.isEmpty
                    ? [] : try bridge.bridgeRemoteSettlements(ids: Array(settlementIDs))
                GroupsPendingBridgeIntent.arm(
                    expenseIDs: GroupsBridgeRestoreConvergenceLogic.unattended(
                        requested: expenseIDs, attended: attendedExpenses),
                    settlementIDs: GroupsBridgeRestoreConvergenceLogic.unattended(
                        requested: settlementIDs, attended: attendedSettlements),
                    channel: .backend)
                GroupsRemoteWipeDivisionStore.clearTrusted(defaults)
                logger.notice("GroupsRemoteWipeDivision took over expenses=\(expenseIDs.count, privacy: .public) settlements=\(settlementIDs.count, privacy: .public)")
            }
        } catch {
            logger.notice("GroupsRemoteWipeDivision takeover deferred reason=bridgeFailed")
            #if DEBUG
            print("GroupsRemoteWipeDivision: Error: \(error)")
            #endif
        }
    }
}
