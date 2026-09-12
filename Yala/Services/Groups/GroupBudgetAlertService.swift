//
//  GroupBudgetAlertService.swift
//  Yala
//
//  Avisa cuando el gasto del grupo cruza un umbral de su presupuesto (G14). Molde estructural de
//  `BudgetAlertService` (el del presupuesto personal) y de `GroupSettlementReminderService` (los gates
//  de Grupos).
//
//  POR QUÉ AQUÍ NO HAY GATE DE FRESCURA, cuando su vecino de dominio sí lo tiene y espera hasta 30 s.
//  `GroupSettlementReminderService` avisa de una AUSENCIA («esta deuda lleva tres semanas sin
//  moverse»), y una ausencia medida sobre datos sin sincronizar es falsa: por eso espera evidencia del
//  canal. Este servicio avisa de una PRESENCIA («el grupo ya lleva gastado el 75 %»), y los gastos que
//  hay en local YA son gasto real. Si faltan gastos por bajar, el porcentaje sale MÁS BAJO que el real
//  y el aviso llega tarde; si el límite aún no ha bajado, no hay presupuesto y no avisa nada. Los dos
//  errores posibles son del lado seguro, así que pagar 30 s en cada foreground no compraría corrección.
//
//  UNA SOLA NOTIFICACIÓN POR GRUPO Y CICLO, la del umbral más alto cruzado. Cruzar del 40 % al 100 %
//  con un solo gasto grande dispara cuatro umbrales a la vez, y cuatro avisos seguidos diciendo casi lo
//  mismo son ruido. Los umbrales menores se marcan igual —para que no vuelvan a sonar— y el más alto
//  solo se marca si iOS confirmó la entrega, así que un fallo de entrega deja el aviso reintentable.
//  Es la misma asimetría deliberada de `BudgetAlertService.notifyCrossedThresholds`.
//

import Foundation
import SwiftData

@MainActor
final class GroupBudgetAlertService {

    static let shared = GroupBudgetAlertService()

    private var modelContext: ModelContext?
    private var isChecking = false

    /// Inyección para tests: evita tocar `NotificationService` (y el permiso del sistema).
    var sendOverride: ((_ title: String, _ body: String, _ deepLink: String) async -> Bool)?

    private init() {}

    /// Init de test.
    init(context: ModelContext?, tracker: GroupBudgetAlertTracker) {
        self.modelContext = context
        self.tracker = tracker
    }

    private var tracker: GroupBudgetAlertTracker = .shared

    func setContext(_ context: ModelContext?) {
        modelContext = context
    }

    // MARK: - Chequeo

    func checkGroupBudgetsAndNotify() async {
        // Gate 1 — el toggle de avisos de presupuesto. Se REUSA el del presupuesto personal en vez de
        // inventar uno nuevo: para el usuario esto es «avisos de presupuesto», y un ajuste más que
        // nadie pidió es un ajuste más que mantener.
        guard UserDefaults.standard.bool(forKey: AppPreferences.Keys.budgetAlertsEnabled) else { return }

        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let context = modelContext else { return }

        // Gate 2 — el maestro de notificaciones de Grupos.
        guard isGroupsNotificationActive(context: context) else { return }

        let groups: [SplitGroup]
        do {
            groups = try context.fetch(FetchDescriptor<SplitGroup>())
        } catch {
            #if DEBUG
            print("GroupBudgetAlertService: Error fetching groups: \(error)")
            #endif
            return
        }

        // Un grupo archivado, oculto o CONGELADO ya cerró su puerta: no genera avisos. En el congelado
        // además el número sería mentira — enseña una copia vieja que nadie puede mover.
        let candidates = groups.filter {
            $0.budgetLimitAmount != nil
                && !$0.isArchived && !$0.isHiddenForAll && !$0.isMigratedFrozen
                && !$0.cloudKitZoneID.isEmpty
        }
        guard !candidates.isEmpty else { return }

        for group in candidates {
            await checkGroup(group, context: context)
        }

        // Las claves de topes viejos (o de grupos que ya no están) se van aquí: sin fecha dentro, la
        // única forma de saber que sobran es que no estén entre las vivas.
        //
        // Y las vivas se calculan sobre TODOS los grupos con presupuesto, no sobre `candidates`: un
        // grupo archivado no genera avisos, pero su memoria de «ya avisé» tiene que sobrevivir al
        // archivado. Con `candidates` aquí, archivar un viaje al 100 % borraba su clave y
        // desarchivarlo meses después volvía a anunciar que se alcanzó el presupuesto.
        let liveKeys = Set(groups.compactMap { g -> String? in
            guard let limit = g.budgetLimitAmount, !g.cloudKitZoneID.isEmpty else { return nil }
            return tracker.liveKey(groupZoneID: g.cloudKitZoneID, limitAmount: limit)
        })
        tracker.cleanupOrphanedEntries(liveKeys: liveKeys)
    }

    // MARK: - Un grupo

    private func checkGroup(_ group: SplitGroup, context: ModelContext) async {
        guard let limit = group.budgetLimitAmount else { return }

        let expenses: [SplitExpense]
        do {
            expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
        } catch {
            #if DEBUG
            print("GroupBudgetAlertService: Error fetching expenses: \(error)")
            #endif
            return
        }

        guard let progress = GroupBudgetLogic.progress(group: group, expenses: expenses) else { return }

        // LÍNEA BASE: la primera vez que este teléfono ve este par (grupo, tope) no se avisa de nada —
        // se anota lo que YA estaba cruzado y se sale. Sin esto, el aviso miraría hacia atrás en los dos
        // casos que más desconciertan: reinstalar la app y que suene «llegasteis al presupuesto» por un
        // viaje cerrado hace meses, y ponerle hoy un tope a un grupo con año y medio de gastos, que
        // dispararía los cuatro umbrales a la vez. Se avisa de lo que se cruza estando ya mirando.
        //
        // Lo que esto cuesta, y se acepta: bajar el tope por debajo de lo ya gastado estrena clave, así
        // que tampoco avisa. Quien acaba de recortar el presupuesto está mirando la pantalla y ve la
        // barra; quien reinstala no espera un aviso de un viaje terminado.
        guard tracker.hasBaseline(groupZoneID: group.cloudKitZoneID, limitAmount: limit) else {
            tracker.setBaseline(
                groupZoneID: group.cloudKitZoneID,
                limitAmount: limit,
                thresholds: GroupBudgetLogic.newlyCrossedThresholds(
                    percentage: progress.percentage, alreadyNotified: [])
            )
            return
        }

        let already = tracker.notifiedThresholds(groupZoneID: group.cloudKitZoneID, limitAmount: limit)
        let crossed = GroupBudgetLogic.newlyCrossedThresholds(
            percentage: progress.percentage, alreadyNotified: already
        )
        guard let highest = crossed.last else { return }

        // Los menores se marcan incondicionalmente: ya no van a sonar por su cuenta, y su aviso queda
        // subsumido en el del umbral más alto.
        for threshold in crossed where threshold != highest {
            tracker.markNotified(
                groupZoneID: group.cloudKitZoneID, limitAmount: limit, threshold: threshold)
        }

        guard let body = L10n.Groups.Budget.alertBody(threshold: highest) else { return }
        let delivered = await send(
            title: L10n.Groups.Budget.alertTitle(group.name),
            body: body,
            deepLink: "groups/\(group.id.uuidString)"
        )

        // Solo se marca el más alto si iOS confirmó la entrega: un fallo lo deja reintentable en el
        // próximo foreground, que es la mitad que evita perder el aviso que más importa.
        if delivered {
            tracker.markNotified(
                groupZoneID: group.cloudKitZoneID, limitAmount: limit, threshold: highest)
        }
    }

    // MARK: - Colaboradores

    private func isGroupsNotificationActive(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<NotificationItem>(predicate: #Predicate { $0.typeRaw == "groups" })
        do {
            guard let item = try context.fetch(descriptor).first else { return false }
            return item.isActive
        } catch {
            #if DEBUG
            print("GroupBudgetAlertService: Error fetching groups notification setting: \(error)")
            #endif
            return false
        }
    }

    private func send(title: String, body: String, deepLink: String) async -> Bool {
        if let override = sendOverride {
            return await override(title, body, deepLink)
        }
        return await NotificationService.shared.sendNotification(
            title: title, body: body, deepLink: deepLink)
    }
}
