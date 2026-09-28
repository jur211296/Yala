//
//  GroupsRemoteWipeReturn.swift
//  Yala
//
//  **Los gastos y liquidaciones de grupo que se lleva el «Vaciar datos» de OTRO dispositivo, procesado tarde en uno que
//  no puede reponerlos, los repone quien sí puede, y cuando ya faltan** (ticket
//  `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`).
//
//  **El hueco.** Desde el ticket `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`, el dispositivo que
//  procesa la señal DESPUÉS de que el origen repusiera sus filas de grupo pide la convergencia para devolverlas. Pero la
//  convergencia re-puentea desde el store LOCAL de Grupos, que no viaja por iCloud (`cloudKitDatabase: .none`): un iPad
//  que nunca entró en su cuenta de grupos, o con el canal parado, no tiene los `SplitExpense` que borra. Su borrado viaja
//  por el espejo al iPhone y nadie vuelve a pedir nada: los gastos de grupo desaparecen de lo personal en todo el parque.
//
//  **La receta:**
//
//  - **El receptor converge lo que puede y declara lo demás.** Por cada gasto o liquidación que se lleva y que su
//    convergencia no va a reponer (no lo tiene, o es una liquidación que allí sigue sin confirmar), escribe en el
//    iCloud-KV del Apple ID la HUELLA de cada fila POSTERIOR a la señal que borra (`createdAt` y si es de la cuenta de
//    grupos: la real y la virtual de un mismo gesto del bridge nacen a microsegundos). Lo anterior a la señal ya lo
//    borró el origen. Se escribe
//    ANTES del borrado, como las peticiones de «Vaciar datos»: un corte después la perdería, y antes es inocua porque quien
//    la atiende espera a que falten esas filas.
//  - **Quien tiene grupos repone por id cuando ya no queda aquí NINGUNA de las filas declaradas de ese id**
//    (`returnIfDeclared`). Mientras quede una, el borrado no ha llegado por el espejo y reponer sería reponer debajo de él:
//    la carrera por la que el ticket padre descartó la petición ciega por el KV. **La prueba es por FILA y no por id** (lo
//    tumbó la review): si el receptor solo tenía una parte de las filas del gasto —importó la virtual y no la real—, o si
//    aquí se rehízo la virtual con otra identidad, «no queda ninguna fila del gasto» no llega nunca y el gasto se quedaba a
//    medias para siempre. Cuando las declaradas faltan, el gasto se re-puentea aunque queden otras: el bridge concilia
//    (conserva la real, rehace la virtual, sustituye los borradores).
//  - **Las liquidaciones, con el criterio de la convergencia**: faltando las declaradas, solo se re-puentea la que se quedó
//    SIN NINGUNA pata. `bridgeSettlement` borra todas sus transacciones, reales incluidas, antes de rehacerla.
//
//  **Una vez.** Lo repuesto se apunta en local POR DECLARACIÓN: otra declaración posterior del mismo gasto (otro receptor
//  tardío se llevó lo repuesto) se atiende de nuevo cuando falten SUS filas. Quien declara se apunta la suya y no la atiende.
//
//  **Lo que queda fuera, dicho entero:**
//   · **Una liquidación aprobada ANTES de que existiera la marca de aprobación vuelve a preguntar.** Desde el ticket
//     `settlement-approval-leaves-no-trace-so-a-rebridge-asks-again`, aprobar su borrador deja un borrador aprobado nuevo
//     enlazado a la transacción real, y el re-puente de aquí la lee (`GroupSettlementDraftResolutionLogic`): rehace la
//     pata virtual sin volver a preguntar. Las aprobadas antes no tienen marca; su borrador ya se puede rechazar.
//     Y si un receptor importó la marca sin la transacción real (o al revés), esa fila queda como antes: las dos nacen
//     en el mismo guardado y viajan juntas.
//   · **Dos dispositivos que puentean el mismo id antes de cruzarse por el espejo duplican**: dos con grupos que atienden
//     la misma declaración, uno que la atiende mientras otro converge por su cuenta, o el canal de grupos del propio
//     receptor que se pone al día y puentea lo que baja —cada dispositivo con grupos puentea lo que le llega—. Y un
//     dispositivo que aún no importó las filas declaradas (recién instalado, o con el espejo atrasado) las ve como ausentes.
//   · **Una liquidación con dos patas de un mismo gesto** (el formulario con cuenta: virtual y real enlazada) de la que el
//     receptor solo importó una: la otra sigue aquí, así que no se re-puentea —el bridge borraría la real— y la que se
//     llevó no vuelve.
//   · **Una fila cuya cuenta el receptor aún no tenía hidratada** se declara sin tipo y casa con las dos: si aquí hay otra
//     del mismo gesto que el receptor no se llevó, se espera hasta que la declaración caduca.
//   · La cuota del KV (1 MB para todo el Apple ID): la declaración lleva solo lo posterior a la señal, pero con miles de
//     filas puede no subir, y la relectura de la caché local no lo ve. No hay techo que recorte en silencio.
//   · Dos receptores que declaran a la vez: el KV es último-gana y una declaración se pierde.
//   · Sigue siendo en el arranque en frío (`wipe-data-group-rows-return-only-on-the-next-cold-launch`).
//

import Foundation
import SwiftData
import os

/// La decisión pura.
nonisolated enum GroupsRemoteWipeReturnLogic {

    /// Lo que un receptor declara al parque: por cada gasto y cada liquidación que se llevó sin poder reponerlos, la huella
    /// de las filas que borró. Las claves son los ids tal como los guarda la fila.
    struct Declaration: Codable, Equatable {
        let id: UUID
        let declaredAt: Date
        let expenses: [String: [Stamp]]
        let settlements: [String: [Stamp]]
    }

    /// **La huella de una fila**: su `createdAt` (segundos desde 1970), que no cambia nunca, y si es de la cuenta de grupos.
    /// La hora sola no basta: la transacción real y la virtual de un mismo gesto del bridge nacen a microsegundos, dentro del
    /// margen, y un receptor que solo importó una de las dos dejaba la otra «presente» para siempre. `nil` es una cuenta aún
    /// sin hidratar (ventana lazy del espejo): casa con las dos.
    struct Stamp: Codable, Equatable {
        let createdAt: Double
        let groupsAccount: Bool?
    }

    /// Una fila puenteada, en valores planos.
    struct BridgedRow: Equatable {
        let expenseID: String?
        let settlementID: String?
        let createdAt: Date
        let groupsAccount: Bool?

        var stamp: Stamp { .init(createdAt: createdAt.timeIntervalSince1970, groupsAccount: groupsAccount) }
    }

    /// **Cuánto vale una declaración.** Tiene que cubrir los arranques en frío de quien la atiende hasta que el borrado le
    /// llegue por el espejo. Nadie la borra del KV —otro dispositivo puede necesitarla todavía—, así que sin plazo un
    /// dispositivo nuevo del Apple ID la atendería meses después.
    static let lifetime: TimeInterval = 30 * 24 * 60 * 60

    static func isLive(_ declaration: Declaration, now: Date) -> Bool {
        now.timeIntervalSince(declaration.declaredAt) < lifetime
    }

    /// **Cuándo una fila de aquí es una fila declarada.** El `createdAt` viaja por el espejo de CloudKit, y no está medido
    /// que conserve más precisión que el milisegundo: se compara con margen. En la misma cuenta, dos filas del mismo id a
    /// menos de esto solo las crea un mismo gesto del bridge (el par virtual de una sesión solo-grupos), y entonces una
    /// presente hace esperar a la otra hasta que llegue su borrado o caduque la declaración.
    static let stampTolerance: TimeInterval = 0.005

    static func matches(_ row: Stamp, declared: Stamp) -> Bool {
        guard abs(row.createdAt - declared.createdAt) < stampTolerance else { return false }
        guard let mine = row.groupsAccount, let theirs = declared.groupsAccount else { return true }
        return mine == theirs
    }

    /// Lo que el receptor declara: las filas POSTERIORES a la señal cuyo gasto o liquidación no va a reponer su propia
    /// convergencia —`returnableExpenseIDs`/`returnableSettlementIDs`, con los filtros de ella—. Lo que sí repone no se
    /// declara: dos reponedores del mismo id. Y lo anterior a la señal tampoco: el origen ya lo borró en su vaciado, así
    /// que allí ya «falta» y declararlo solo agrandaría la declaración y haría re-puentear todo el histórico a cualquier
    /// otro dispositivo con grupos.
    static func toDeclare(
        rows: [BridgedRow], signaledAt: Date,
        returnableExpenseIDs: Set<String>, returnableSettlementIDs: Set<String>
    ) -> (expenses: [String: [Stamp]], settlements: [String: [Stamp]]) {
        var expenses: [String: [Stamp]] = [:], settlements: [String: [Stamp]] = [:]
        for row in rows where row.createdAt > signaledAt {
            if let id = row.expenseID, !returnableExpenseIDs.contains(id) { expenses[id, default: []].append(row.stamp) }
            if let id = row.settlementID, !returnableSettlementIDs.contains(id) {
                settlements[id, default: []].append(row.stamp)
            }
        }
        return (expenses, settlements)
    }

    /// **¿Ya faltan aquí las filas declaradas de este id?** Con una sola presente, el borrado aún no llegó por el espejo.
    static func declaredRowsAreGone(declared: [Stamp], local: [Stamp]) -> Bool {
        !local.contains { row in declared.contains { matches(row, declared: $0) } }
    }
}

/// Lo que persiste: las declaraciones en el iCloud-KV del Apple ID, y en local qué se hizo con cada una. En el main actor,
/// como la superficie del KV (`OwnerKeyValueWriting`) y sus dos llamadores.
enum GroupsRemoteWipeReturnStore {

    /// Las declaraciones vivas, en el iCloud-KV: una lista en JSON dentro de un string (la puerta no escribe `Data`). Es
    /// formato compartido entre versiones de la app en el parque: no se renombra.
    static let kvKey = "groupsRowsToReturnAfterRemoteWipe"

    /// Lo hecho aquí con cada declaración. Prefijo `fullModeActivation.*`: fuera de las listas del reset de preferencias,
    /// así que sobrevive al borrado del receptor, que se apunta aquí la suya antes de borrar.
    static let handledKey = "fullModeActivation.remoteWipeReturn.handled"

    /// Lo hecho aquí con una declaración: si la escribió este dispositivo (y entonces no la atiende), y qué ids repuso.
    struct Handled: Codable, Equatable {
        var own: Bool
        var returnedIDs: Set<String>
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    static func read(_ kv: OwnerKeyValueWriting) -> [GroupsRemoteWipeReturnLogic.Declaration] {
        guard let json = kv.string(forKey: kvKey), let data = json.data(using: .utf8) else { return [] }
        do {
            return try decoder().decode([GroupsRemoteWipeReturnLogic.Declaration].self, from: data)
        } catch {
            #if DEBUG
            print("GroupsRemoteWipeReturnStore: Error: \(error)")
            #endif
            return []
        }
    }

    static func write(_ declarations: [GroupsRemoteWipeReturnLogic.Declaration], to kv: OwnerKeyValueWriting) throws {
        let data = try encoder().encode(declarations)
        guard let json = String(data: data, encoding: .utf8) else { return }
        kv.setString(json, forKey: kvKey)
        kv.synchronize()
    }

    static func handled(_ defaults: UserDefaults) -> [String: Handled] {
        guard let data = defaults.data(forKey: handledKey) else { return [:] }
        do {
            return try decoder().decode([String: Handled].self, from: data)
        } catch {
            #if DEBUG
            print("GroupsRemoteWipeReturnStore: Error: \(error)")
            #endif
            return [:]
        }
    }

    static func setHandled(_ handled: [String: Handled], _ defaults: UserDefaults) throws {
        defaults.set(try encoder().encode(handled), forKey: handledKey)
    }

    /// Lo retira el relevo de persona (`DataWipeService.removeGroupsDomainPreferenceKeys`): lo hecho aquí lo hizo el humano
    /// anterior.
    static func clearHandled(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: handledKey)
    }
}

@MainActor
enum GroupsRemoteWipeReturn {

    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    /// El iCloud-KV de producción, siempre por la puerta. Los llamadores lo reciben como valor por defecto sin nombrarla.
    /// `nonisolated` porque un valor por defecto se evalúa en el contexto del llamador; la fachada no tiene estado.
    nonisolated static var defaultStore: OwnerKeyValueWriting { OwnerKeyValueStore.shared }

    /// **El receptor declara lo que se lleva sin poder reponerlo**, junto a las declaraciones que sigan vivas, y se apunta
    /// la suya: la repone otro. Si la relectura no la encuentra (la puerta del KV cerrada; hoy no se da, porque obedecer la
    /// señal exige la sesión privada que la abre), deja rastro y el borrado sigue: un borrado a medias sería peor. La cuota
    /// del KV no la ve: la relectura es de la caché local.
    static func declare(
        expenses: [String: [GroupsRemoteWipeReturnLogic.Stamp]], settlements: [String: [GroupsRemoteWipeReturnLogic.Stamp]],
        kv: OwnerKeyValueWriting, defaults: UserDefaults, now: Date = .now
    ) throws {
        guard !expenses.isEmpty || !settlements.isEmpty else { return }
        let declaration = GroupsRemoteWipeReturnLogic.Declaration(
            id: UUID(), declaredAt: now, expenses: expenses, settlements: settlements)
        var handled = GroupsRemoteWipeReturnStore.handled(defaults)
        handled[declaration.id.uuidString] = .init(own: true, returnedIDs: [])
        try GroupsRemoteWipeReturnStore.setHandled(handled, defaults)
        let live = GroupsRemoteWipeReturnStore.read(kv).filter { GroupsRemoteWipeReturnLogic.isLive($0, now: now) }
        try GroupsRemoteWipeReturnStore.write(live + [declaration], to: kv)
        guard GroupsRemoteWipeReturnStore.read(kv).contains(where: { $0.id == declaration.id }) else {
            logger.error("GroupsRemoteWipeReturn declaration not stored")
            return
        }
        logger.notice("GroupsRemoteWipeReturn declared expenses=\(expenses.count, privacy: .public) settlements=\(settlements.count, privacy: .public)")
    }

    /// **Quien tiene los grupos repone lo declarado cuyas filas ya faltan aquí.** En el arranque, detrás de la convergencia
    /// y de sus mismos gates (`AppBootstrapper.retryPendingBridges`: import quieto y dominio abierto), y solo en una sesión
    /// que obedece la señal de vaciado (`obeysWipeSignal`: privada y en iCloud; la declaración habla de ese espejo, y en la
    /// nube las filas viven en otro store). Con sesión privada además, como la convergencia: en solo-grupos el bridge borra
    /// las transacciones reales que re-puentea.
    ///
    /// Si el bridge lanza, no se apunta nada y el arranque siguiente lo reintenta: lo que sí se repuso tiene ya filas nuevas,
    /// que no son las declaradas, así que se re-puentea otra vez y el bridge lo concilia. Lo que el bridge no atiende
    /// (member propio sin resolver) pasa a la intención durable con el canal del backend, como en la convergencia.
    static func returnIfDeclared(
        context: ModelContext,
        kv: OwnerKeyValueWriting = defaultStore,
        defaults: UserDefaults = .standard,
        obeysWipeSignal: Bool = DestructiveScopeLogic.wipeSignalObeyedByThisSession(
            confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession(),
            storageMode: CloudSyncFlags.storageMode),
        now: Date = .now
    ) {
        guard SessionState.shared.hasPrivateSession, obeysWipeSignal else { return }
        guard GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults) else { return }
        let declarations = GroupsRemoteWipeReturnStore.read(kv).filter { GroupsRemoteWipeReturnLogic.isLive($0, now: now) }
        // No se poda lo de declaraciones que no se leen ahora: una lectura vacía de un KV aún sin sincronizar se llevaría
        // la marca de «es mía», y el receptor atendería después su propia declaración. Es una entrada por declaración.
        var handled = GroupsRemoteWipeReturnStore.handled(defaults)
        let pending = declarations.filter { handled[$0.id.uuidString]?.own != true }
        do {
            var expenses: [String: Set<String>] = [:], settlements: [String: Set<String>] = [:]
            if !pending.isEmpty {
                let bridged = try context.fetch(FetchDescriptor<TransactionItem>(
                    predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }))
                let localExpenses = Set(try context.fetch(FetchDescriptor<SplitExpense>()).map(\.id.uuidString))
                let hiddenZones = Set(try context.fetch(FetchDescriptor<SplitGroup>(
                    predicate: #Predicate { $0.isHiddenForAll })).map(\.cloudKitZoneID))
                // Las liquidaciones, con los dos filtros de la convergencia: solo confirmadas —sin confirmar el bridge no
                // crea nada y la daría por no atendida— y fuera de los grupos ocultos, porque `bridgeSettlement` no los mira
                // y el gasto que la compensaba no vuelve (`GroupsBridgeRestoreConvergence.reBridgeSettlementLegs`).
                let localSettlements = Set(try context.fetch(FetchDescriptor<SplitSettlement>())
                    .filter { $0.isConfirmed && !hiddenZones.contains($0.groupZoneID) }.map(\.id.uuidString))
                let stamp = { (tx: TransactionItem) in
                    GroupsRemoteWipeReturnLogic.Stamp(createdAt: tx.createdAt.timeIntervalSince1970,
                                                      groupsAccount: tx.account?.isSystemAccount)
                }
                let expenseRows = Dictionary(grouping: bridged.filter { $0.splitExpenseID != nil }) { $0.splitExpenseID ?? "" }
                    .mapValues { $0.map(stamp) }
                let settlementRows = Dictionary(grouping: bridged.filter { $0.splitSettlementID != nil }) {
                    $0.splitSettlementID ?? ""
                }.mapValues { $0.map(stamp) }
                for declaration in pending {
                    let key = declaration.id.uuidString
                    let returned = handled[key]?.returnedIDs ?? []
                    for (id, stamps) in declaration.expenses where localExpenses.contains(id) && !returned.contains(id)
                        && GroupsRemoteWipeReturnLogic.declaredRowsAreGone(declared: stamps, local: expenseRows[id] ?? []) {
                        expenses[key, default: []].insert(id)
                    }
                    for (id, stamps) in declaration.settlements where localSettlements.contains(id) && !returned.contains(id)
                        && GroupsRemoteWipeReturnLogic.declaredRowsAreGone(declared: stamps, local: settlementRows[id] ?? []) {
                        settlements[key, default: []].insert(id)
                    }
                }
                let expenseIDs = Set(expenses.values.joined())
                // Una liquidación que conserva otra pata no se re-puentea: el bridge la borraría, real incluida.
                let settlementIDs = Set(settlements.values.joined()).filter { (settlementRows[$0] ?? []).isEmpty }
                if !expenseIDs.isEmpty || !settlementIDs.isEmpty {
                    let bridge = GroupTransactionBridge.shared
                    let expenseUUIDs = Set(expenseIDs.compactMap(UUID.init(uuidString:)))
                    let settlementUUIDs = Set(settlementIDs.compactMap(UUID.init(uuidString:)))
                    let attendedExpenses = try bridge.bridgeRemoteExpenses(ids: Array(expenseUUIDs))
                    let attendedSettlements = try bridge.bridgeRemoteSettlements(ids: Array(settlementUUIDs))
                    GroupsPendingBridgeIntent.arm(
                        expenseIDs: GroupsBridgeRestoreConvergenceLogic.unattended(
                            requested: expenseUUIDs, attended: attendedExpenses),
                        settlementIDs: GroupsBridgeRestoreConvergenceLogic.unattended(
                            requested: settlementUUIDs, attended: attendedSettlements),
                        channel: .backend)
                    logger.notice("GroupsRemoteWipeReturn returned expenses=\(expenseIDs.count, privacy: .public) settlements=\(settlementIDs.count, privacy: .public)")
                }
            }
            for declaration in pending {
                let key = declaration.id.uuidString
                var entry = handled[key] ?? .init(own: false, returnedIDs: [])
                entry.returnedIDs.formUnion(expenses[key] ?? [])
                entry.returnedIDs.formUnion(settlements[key] ?? [])
                handled[key] = entry
            }
            try GroupsRemoteWipeReturnStore.setHandled(handled, defaults)
        } catch {
            logger.notice("GroupsRemoteWipeReturn deferred reason=bridgeFailed")
            #if DEBUG
            print("GroupsRemoteWipeReturn: Error: \(error)")
            #endif
        }
    }
}
