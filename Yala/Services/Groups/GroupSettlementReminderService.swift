//
//  GroupSettlementReminderService.swift
//  Yala
//
//  El recordatorio amable de liquidación pendiente: un nudge al DEUDOR cuando una deuda de grupo
//  lleva semanas sin moverse. Corre en boot y foreground, junto al resto de chequeos por tiempo
//  transcurrido (`AppBootstrapper.ensureNotificationsScheduled`).
//
//  **Es el primer aviso de Grupos que NO reacciona a un hecho.** `GroupNotificationService` solo
//  habla cuando `SplitSyncManager` le entrega un cambio remoto; este habla porque NO ha pasado nada,
//  y por eso necesita disparo propio, reloj propio y dedup propio (`SettlementReminderTracker`).
//
//  ## Los cuatro gates, en orden de coste
//
//  1. **El toggle propio** (`groupSettlementRemindersEnabled`, default `false`). Cumple el AC «apagar
//     este nudge sin apagar el resto de Grupos».
//  2. **El maestro de Grupos** (`NotificationItem` con `typeRaw == "groups"`, `isActive`). Se respeta
//     a propósito, y no es redundante con el anterior: quien apaga Grupos entero espera no recibir
//     avisos de grupo, y este lo es. La independencia que pide el AC es en el otro sentido.
//  3. **Frescura del canal, POR ZONA** (`GroupChannelFreshness`). El más importante de los cuatro y
//     el que justifica este bloque de prosa: sin él, un arranque con los gastos ya bajados y las
//     liquidaciones todavía en vuelo calcularía una deuda que la otra persona YA PAGÓ y le diría al
//     usuario que la debe. Se decide por zona —no global— porque un grupo rezagado no debe retener
//     los avisos de los demás; el molde es `AppBootstrapper.awaitGroupsChannelEvidence`.
//  4. **La antigüedad y el rate-limit**, ya en `SettlementReminderLogic`.
//
//  ## Sobre el AC de quiescencia del store de Grupos
//
//  Este servicio **no escribe NADA en SwiftData**: lee, y su único efecto persistente es un
//  timestamp en `UserDefaults` vía el tracker. El AC «el chequeo no dispara ningún `save()` sobre el
//  store de Grupos antes de que el import personal asiente» se cumple porque no hay `save()` que
//  disparar, no porque se haya gateado. Si alguien añade aquí una escritura al store, ese AC pasa a
//  necesitar el gate de quiescencia de verdad (`awaitPersonalStoreReady`) — es la clase de bug que
//  costó semanas en la saga de crashes de restore.
//
//  ## Una notificación por GRUPO, no por deuda
//
//  Deberle a tres personas del mismo grupo son tres `Debt`, y tres pushes seguidos serían justo el
//  tono cobrador que la decisión del owner prohíbe. Se manda una, la de la deuda más quieta, y se
//  marcan TODAS las incluidas como avisadas — así el rate-limit sigue siendo por deuda (lo que pide
//  el AC) sin que el usuario reciba una ráfaga.
//

import Foundation
import SwiftData

@MainActor
final class GroupSettlementReminderService {

    static let shared = GroupSettlementReminderService()

    private var modelContext: ModelContext?
    private var isChecking = false
    private let tracker: SettlementReminderTracker

    /// Sustituye el envío real en tests. Mismo contrato que `NotificationService.sendNotification`:
    /// `true` = iOS aceptó el request.
    var sendOverride: ((_ title: String, _ body: String, _ deepLink: String) async -> Bool)?

    private init() {
        self.tracker = .shared
    }

    /// Init de test — tracker aislado. No usar en producción.
    init(tracker: SettlementReminderTracker) {
        self.tracker = tracker
    }

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    // MARK: - Chequeo principal

    func checkPendingSettlementsAndNotify(now: Date = .now) async {
        // Gate 1 — el toggle propio (default false: nadie recibe esto sin encenderlo).
        guard UserDefaults.standard.bool(forKey: AppPreferences.Keys.groupSettlementRemindersEnabled) else { return }

        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let context = modelContext else { return }

        // Gate 2 — el maestro de Grupos.
        guard isGroupsNotificationActive(context: context) else { return }

        let groups: [SplitGroup]
        do {
            groups = try context.fetch(FetchDescriptor<SplitGroup>())
        } catch {
            #if DEBUG
            print("GroupSettlementReminderService: Error fetching groups: \(error)")
            #endif
            return
        }

        // Un grupo archivado, oculto o CONGELADO ya cerró su puerta: no genera avisos. El freeze entra
        // por la misma razón que el filtro por `isActive` de más abajo — en un grupo migrado-congelado
        // las escrituras están bloqueadas (`GroupService` lanza `movedToBackend`), así que un push que
        // pide liquidar manda a una pantalla donde no se puede.
        let candidates = groups.filter {
            !$0.isArchived && !$0.isHiddenForAll && !$0.isMigratedFrozen && !$0.cloudKitZoneID.isEmpty
        }
        guard !candidates.isEmpty else { return }

        // Gate 3 — frescura, esperando a que el canal dé evidencia. Ver `awaitFreshVerdicts`.
        let watched = Set(candidates.map(\.cloudKitZoneID))
        guard let freshness = await awaitFreshVerdicts(context: context, zones: watched) else { return }

        for group in candidates {
            guard let status = freshness[group.cloudKitZoneID] else { continue }
            // `belongsToBackendChannel` ADEMÁS de `isFresh`, y no es redundante: el gate concede
            // `.fresh` INCONDICIONAL a una zona sin canal (`GroupChannelFreshnessGate`: «nadie puede
            // entregarle nada ya, así que "no está" es "no existe"»). Para el editor eso es correcto;
            // aquí significaría lo contrario de lo que necesitamos — los datos de una zona legacy son
            // un snapshot congelado, y sobre ellos «lleva tres semanas sin moverse» es cierto POR
            // CONSTRUCCIÓN, porque nada puede moverlos. Es la misma exclusión que hace
            // `OrphanedBridgedTxSweeper` antes de mirar el veredicto.
            guard status.belongsToBackendChannel, status.isFresh else { continue }
            await checkGroup(group, context: context, now: now)
        }
    }

    /// Espera acotada a que alguna de las zonas VIGILADAS sea fresca, y devuelve el mapa de veredictos.
    /// `nil` si se agota el tope: sin evidencia no se avisa, y se reintenta en el próximo foreground.
    ///
    /// **Preguntar sin esperar es la forma de romper esto sin que ningún test se ponga rojo**, y está
    /// escrito en el repo: `AppBootstrapper.awaitGroupsChannelEvidence` avisa de que en el arranque el
    /// primer `syncCycleOnce` incluye un viaje de red, así que un veredicto pedido en frío da «no
    /// fresco» en TODOS los arranques.
    ///
    /// **Pero la condición de salida mira SOLO las zonas de `zones`, y esa acotación es la mitad que
    /// falta.** El molde de `awaitGroupsChannelEvidence` pregunta «¿alguna zona del store?», y ahí es
    /// inocuo porque su barrido ya excluyó las no-backend de sus candidatas. Copiado tal cual aquí, un
    /// solo grupo legacy en el store —que el gate declara `.fresh` incondicional y para siempre, y que
    /// `LegacyGroupsRetirement` deja en disco oculto -- bastaría para salir del bucle en el primer poll
    /// y congelar el mapa ANTES de que ninguna zona del backend haya completado su pull. El feature
    /// quedaría silenciosamente muerto en el arranque para toda la cohorte que tuvo grupos antiguos.
    ///
    /// Sale **en cuanto una** zona vigilada es fresca, no cuando lo son todas: una zona rezagada no
    /// debe retener los avisos de las demás, se queda para la próxima. El tope es más corto que el de
    /// su molde (60 s) porque esto corre en CADA foreground.
    private func awaitFreshVerdicts(
        context: ModelContext,
        zones: Set<String>
    ) async -> [String: GroupChannelFreshness.ZoneStatus]? {
        let pollInterval: TimeInterval = 2
        let hardCap: TimeInterval = 30
        var waited: TimeInterval = 0

        while true {
            let verdicts = GroupChannelFreshness.verdictsByZone(context: context)
            let watched = zones.compactMap { verdicts[$0] }
            // Sin ninguna zona vigilada EN EL CANAL no hay nada que esperar: esperar el tope entero
            // sería quemar 30 s de polling en cada foreground para acabar sin avisar igual.
            guard watched.contains(where: \.belongsToBackendChannel) else { return nil }
            if watched.contains(where: { $0.belongsToBackendChannel && $0.isFresh }) { return verdicts }
            guard waited < hardCap else { return nil }
            do {
                try await Task.sleep(for: .seconds(pollInterval))
            } catch {
                // Task cancelado ⇒ conservador, no se avisa (regla «nunca `try?` que silencia»).
                return nil
            }
            waited += pollInterval
        }
    }

    /// El maestro de Grupos (`NotificationItem` `.groups`). Fail-CERRADO: si el fetch lanza, no se
    /// avisa — el mismo criterio que `GroupNotificationService`.
    private func isGroupsNotificationActive(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<NotificationItem>(predicate: #Predicate { $0.typeRaw == "groups" })
        do {
            guard let item = try context.fetch(descriptor).first else { return false }
            return item.isActive
        } catch {
            #if DEBUG
            print("GroupSettlementReminderService: Error fetching groups notification setting: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Un grupo

    private func checkGroup(_ group: SplitGroup, context: ModelContext, now: Date) async {
        let zoneID = group.cloudKitZoneID
        let members: [SplitMember]
        let expenses: [SplitExpense]
        let shares: [SplitShare]
        let settlements: [SplitSettlement]
        do {
            members = try context.fetch(FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneID }))
            expenses = try context.fetch(FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID }))
            shares = try context.fetch(FetchDescriptor<SplitShare>(
                predicate: #Predicate { $0.groupZoneID == zoneID }))
            settlements = try context.fetch(FetchDescriptor<SplitSettlement>(
                predicate: #Predicate { $0.groupZoneID == zoneID }))
        } catch {
            #if DEBUG
            print("GroupSettlementReminderService: Error fetching zone \(zoneID): \(error)")
            #endif
            return
        }

        // Identidad RESUELTA —no el flag `isCurrentUser`, que en el canal backend nace apagado para
        // casi todo el mundo—, pero **filtrando ANTES por `isActive`**, que es la forma que la regla
        // de `.claude/rules/swiftdata-cloudkit.md` (caso 4) prescribe: `resolver-y-filtrar` devuelve
        // la fila canónica y luego la descarta, dando «no hay nadie» cuando sí lo hay; hay que
        // buscar la que cumple LAS DOS cosas.
        //
        // El estado importa aquí porque `resolveCurrentUserMember` **no lo mira**: puede devolver un
        // member `pendingApproval`, `left` o `removed`. A un pendiente de aprobación no le
        // corresponde ninguna deuda todavía, y a quien salió o fue expulsado del grupo un push que
        // le pide liquidar lo manda a un grupo en el que ya no puede hacerlo.
        //
        // Diverge a propósito de `GroupsViewModel.computeCurrentUserDebts`, que resuelve sin filtrar:
        // la pantalla RESPONDE a quien ya la abrió, y este servicio decide a quién INTERRUMPIR.
        guard let me = GroupExpenseService.resolveCurrentUserMember(
            from: members.filter(\.isActive))?.id.uuidString else { return }

        // **Deudas DIRECTAS siempre (`simplifyDebts: false`), aunque el grupo tenga la simplificación
        // encendida.** Es la decisión menos obvia de este fichero y la primera versión la tuvo al revés,
        // «para que el aviso diga lo mismo que la pantalla». La medición la tumbó: con simplificación,
        // la arista `yo → X` no la produjo ningún gasto entre X y yo — es un enrutado de mínimo flujo
        // de caja calculado sobre los saldos de TERCEROS. Y este feature no muestra un saldo: **afirma
        // una antigüedad**, y ese reloj solo existe por par directo. Los dos daños concretos:
        //
        // 1. **Afirma quietud sobre dinero de ayer.** Si Carlos me prestó 30 hace dos meses y ayer cené
        //    con Ana por 300, el greedy puede emitir «yo → Carlos 230». Mi reloj con Carlos marca dos
        //    meses ⇒ push «lleva semanas sin moverse: le debes 230 a Carlos», cuando 200 de esos nacieron
        //    anoche. Es el AC «un gasto nuevo resetea el contador» roto por la puerta de atrás.
        // 2. **Rompe el rate-limit.** La clave de dedup es `Debt.id` (`from-to-divisa`), y bajo
        //    simplificación el acreedor lo deciden pagos entre terceros: basta con que dos personas que
        //    no soy yo se paguen algo para que la arista se re-enrute, nazca un `Debt.id` virgen y salga
        //    un segundo push en 24 h nombrando a otra persona.
        //
        // El precio, dicho en voz alta: en un grupo con simplificación el importe del aviso puede no
        // coincidir con la fila que enseña la pantalla. Es el lado correcto del trade-off — el importe
        // directo es un hecho verificable con actividad atribuible, y el deep link lleva al grupo, donde
        // la persona ve el reparto real.
        //
        // `showDebtsInSingleCurrency` tampoco se aplica, por lo mismo en su versión suave: no cambia
        // ningún hecho, solo presenta el importe convertido con la última tasa conocida y marcado «≈».
        // Un push no puede llevar ese matiz, y una tasa vieja en un aviso de dinero es peor que el
        // importe real en su moneda real.
        let debts = GroupBalanceService.calculateDebts(
            expenses: expenses,
            shares: shares,
            settlements: settlements,
            simplifyDebts: false
        )

        let activities = Self.activities(me: me, expenses: expenses, shares: shares, settlements: settlements)
        let myDebtIDs = debts.filter { $0.fromMemberID == me }.map(\.id)
        guard !myDebtIDs.isEmpty else { return }

        let due = SettlementReminderLogic.dueReminders(
            debts: debts,
            currentMemberID: me,
            lastActivityByPair: SettlementReminderLogic.lastActivityByPair(activities, now: now),
            lastNotifiedByDebt: tracker.lastNotified(forDebtIDs: myDebtIDs),
            now: now
        )
        guard let oldest = due.first else { return }

        let nameLookup = Dictionary(
            members.map { ($0.id.uuidString, $0.resolvedDisplayName) },
            uniquingKeysWith: { first, _ in first }
        )
        // El copy se elige por número de ACREEDORES, no de deudas — ver `namesASingleCreditor`, que es
        // donde vive el criterio y donde está pinneado.
        let body: String
        if SettlementReminderLogic.namesASingleCreditor(due) {
            let creditor = nameLookup[oldest.toMemberID] ?? L10n.Notifications.Group.fallbackMember
            let amount = YalaFormatterStatic.currency(value: oldest.amount, currencyCode: oldest.currencyCode)
            body = L10n.Notifications.Group.settlementReminder(amount, creditor)
        } else {
            body = L10n.Notifications.Group.settlementReminderMultiple
        }

        let delivered = await send(
            title: group.name.isEmpty ? L10n.Notifications.Group.fallbackGroup : group.name,
            body: body,
            deepLink: "groups/\(group.id.uuidString)"
        )

        // Solo con entrega confirmada. Marcar tras un `false` quemaría la semana de supresión sin
        // que el usuario haya visto nada (ver docblock de `NotificationService.sendNotification`).
        guard delivered else { return }
        for debt in due {
            tracker.markNotified(debtID: debt.id, at: now)
        }
    }

    private func send(title: String, body: String, deepLink: String) async -> Bool {
        if let override = sendOverride {
            return await override(title, body, deepLink)
        }
        return await NotificationService.shared.sendNotification(title: title, body: body, deepLink: deepLink)
    }

    // MARK: - Actividad

    /// Los hechos que han movido las cuentas del usuario con cada otro miembro.
    ///
    /// **Qué fecha lleva cada hecho, y por qué:**
    /// - Gasto ⇒ `createdAt`, no `date`. `date` es cuándo se gastó y puede ser retroactiva; un gasto
    ///   registrado hoy con fecha del mes pasado ES actividad de hoy, y con `date` no resetearía el
    ///   contador — el usuario acabaría recibiendo un aviso justo después de tocar la deuda.
    /// - Liquidación ⇒ `date`, que es el único campo temporal que `SplitSettlement` tiene.
    ///
    /// **Las liquidaciones SIN confirmar también cuentan**, aunque no muevan el saldo: registrar un
    /// pago es movimiento, y recordarle la deuda a quien acaba de decir que la pagó y espera
    /// confirmación es exactamente el tono que este feature evita.
    /// `nonisolated` porque es PURA: solo lee propiedades de los modelos que recibe y no toca ningún
    /// estado de la clase. Es lo que la hace verificable desde `YalaTests`, cuyo target no lleva
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION` y por tanto corre sus tests fuera del MainActor.
    nonisolated static func activities(
        me: String,
        expenses: [SplitExpense],
        shares: [SplitShare],
        settlements: [SplitSettlement]
    ) -> [DebtActivity] {
        var result: [DebtActivity] = []
        let sharesByExpense = Dictionary(grouping: shares, by: \.expenseID)

        for expense in expenses {
            let participants = Set(sharesByExpense[expense.id]?.map(\.memberID) ?? []).union([expense.paidByMemberID])
            guard participants.contains(me) else { continue }
            for other in participants where other != me {
                result.append(DebtActivity(memberA: me, memberB: other, at: expense.createdAt))
            }
        }

        for settlement in settlements {
            let pair = [settlement.fromMemberID, settlement.toMemberID]
            guard pair.contains(me), let other = pair.first(where: { $0 != me }) else { continue }
            result.append(DebtActivity(memberA: me, memberB: other, at: settlement.date))
        }

        return result
    }
}
