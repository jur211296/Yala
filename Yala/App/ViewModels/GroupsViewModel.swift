//
//  GroupsViewModel.swift
//  Yala
//
//  ViewModel for the Groups tab — list, global summary, per-group balances.
//

import Foundation
import SwiftData
import UIKit

@MainActor
@Observable
final class GroupsViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Recalculation State (debounce — espejo de PanelViewModel)

    /// El freno compartido de Grupos: coalesce ráfagas de `onChange(dataVersion)` del sync remoto en
    /// un solo recálculo. Inyectable para que el coalescing se pruebe sin `applicationState`.
    @ObservationIgnored private let debouncer: RecalculationDebouncer

    init(debouncer: RecalculationDebouncer? = nil) {
        self.debouncer = debouncer ?? RecalculationDebouncer(label: "GroupsViewModel")
    }

    // MARK: - Data

    private(set) var groups: [SplitGroup] = []

    /// `true` una vez que `loadData()` completó con éxito al menos una vez. Mientras es `false` la
    /// vista muestra un spinner en lugar del empty state: en un cold launch de "Solo Grupos" el tab
    /// monta antes de que el bootstrap configure el `modelContext` de `GroupService` (paso 16), así
    /// que el primer `loadData()` puede fallar en silencio y dejar `groups` vacío — sin este gate se
    /// vería "no tienes grupos" indebidamente hasta cambiar de tab y volver.
    private(set) var hasLoadedOnce: Bool = false

    private(set) var membersByGroup: [String: [SplitMember]] = [:]       // zoneID → members
    private(set) var balancesByGroup: [String: [MemberBalance]] = [:]    // zoneID → balances
    private(set) var globalSummary: GroupGlobalSummary?

    /// M6 D3: cached fuentes para recalcular `currentUserDebts(for:)` on-demand.
    /// Pobladas en `loadData()` para evitar fetch repetido por cada card render.
    private(set) var expensesByGroup: [String: [SplitExpense]] = [:]
    private(set) var sharesByGroup: [String: [SplitShare]] = [:]
    private(set) var settlementsByGroup: [String: [SplitSettlement]] = [:]

    /// zoneID → deudas del current user ya calculadas, listas para la tarjeta.
    ///
    /// Evitar el fetch por render (M6 D3) no evitaba el CÁLCULO: `currentUserDebts(for:)` corría
    /// `calculateDebts` (gastos × repartos) en el body de cada tarjeta, así que cualquier
    /// invalidación de `GroupsContainerView` lo repetía una vez POR GRUPO. Y `searchText` vive en
    /// este `@Observable`, de modo que cada tecla del buscador invalidaba ese body. Medido con
    /// 30 grupos × 6 miembros × 50 gastos: ~25 ms por tecla, en el hilo principal — más que el
    /// frame entero de 16,7 ms. Precalcularlo en `recalculate()` lo deja en un cálculo por
    /// recarga de datos y un lookup por tarjeta.
    ///
    /// No lleva clave de invalidación propia a propósito: sus entradas son exactamente los dicts
    /// de arriba más los toggles del grupo, y `recalculate()` es el único punto donde ese conjunto
    /// puede haber cambiado — el mismo ciclo que ya gobierna `balancesByGroup`.
    private(set) var debtsByGroup: [String: [DebtRow]] = [:]

    // MARK: - DebtRow (M6 D3)

    /// Una deuda perspectiva del current user para renderizar en la card del grupo.
    /// Estilo Splitwise: "Maria te debe S/X" / "Le debes a Juan USD Y".
    struct DebtRow: Identifiable, Equatable {
        let id: String
        let counterpartyName: String
        let amount: Double
        let currencyCode: String
        let perspective: Perspective
        let wasConverted: Bool
    }

    enum Perspective: Equatable {
        case iOwe
        case theyOweMe
    }

    // MARK: - UI State

    var showCreateGroup: Bool = false
    /// Detalle pusheado vía `navigationDestination(item:)` en GroupsContainerView.
    var selectedGroup: SplitGroup?
    var searchText: String = ""

    // MARK: - Computed

    var activeGroups: [SplitGroup] {
        groups.filter { !$0.isArchived && !$0.isHiddenForAll }
    }

    var archivedGroups: [SplitGroup] {
        groups.filter { $0.isArchived && !$0.isHiddenForAll }
    }

    var filteredGroups: [SplitGroup] {
        let base = activeGroups
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter { $0.name.lowercased().contains(query) }
    }

    var showArchived: Bool = false

    // MARK: - Context

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    /// Path síncrono instantáneo: fetch + recálculo en una pasada. Usado por los ~19 callers locales
    /// (setContext, Settings, Members, expense form, opening balance, retorno de detalle, archiveGroup)
    /// que esperan feedback inmediato. El sync remoto (onChange dataVersion) usa `reloadAndRecalculate`.
    func loadData() {
        fetchData()
        recalculate()
    }

    /// Fase de FETCH pura (SwiftData). Puebla `groups` + los dicts por-grupo. NO calcula balances/summary.
    private func fetchData() {
        guard modelContext != nil else { return }

        do {
            let fetchedGroups = try GroupService.shared.fetchAllGroups()
            if fetchedGroups != groups { groups = fetchedGroups }

            // fetchAllGroups es el fetch que prueba que GroupService ya tiene contexto (la carrera de
            // arranque). Marcamos "cargado" aquí, no al final: si un fetch por-grupo posterior lanzara
            // (p.ej. datos de un grupo corruptos), la vista igual sale del spinner y muestra lo cargado,
            // en vez de quedar en un ProgressView permanente.
            hasLoadedOnce = true

            for group in groups {
                let members = try GroupService.shared.fetchMembers(for: group)
                membersByGroup[group.cloudKitZoneID] = members

                // Skip heavy data loading for archived groups
                guard !group.isArchived else { continue }

                // M6 D3: cache para recalcular debts on-demand (currentUserDebts) + para `recalculate()`.
                expensesByGroup[group.cloudKitZoneID] = try GroupExpenseService.shared.fetchExpenses(for: group)
                sharesByGroup[group.cloudKitZoneID] = try GroupExpenseService.shared.fetchAllShares(for: group)
                settlementsByGroup[group.cloudKitZoneID] = try GroupExpenseService.shared.fetchSettlements(for: group)
            }
        } catch {
            #if DEBUG
            print("GroupsViewModel: Error fetching data: \(error)")
            #endif
        }
    }

    /// Fase de CÁLCULO pura: opera sobre los dicts ya cacheados por `fetchData()` (sin fetch nuevo).
    /// Reconstruye los acumuladores cruzando-grupos que antes se armaban en el loop de fetch.
    private func recalculate() {
        guard modelContext != nil else { return }

        var allExpenses: [SplitExpense] = []
        var allShares: [SplitShare] = []
        var allSettlements: [SplitSettlement] = []
        var currentUserMemberIDs = Set<String>()
        var newBalancesByGroup: [String: [MemberBalance]] = [:]
        var newDebtsByGroup: [String: [DebtRow]] = [:]

        for group in groups {
            let zoneID = group.cloudKitZoneID
            let members = membersByGroup[zoneID] ?? []

            // Deudas de la tarjeta: ANTES del guard de archivado, porque "Ver archivados" también
            // pinta tarjetas y `computeDebts(for:)` reproduce el corte exacto que tenía el body —
            // un grupo archivado EN ESTA SESIÓN conserva sus fuentes en los dicts (nadie las
            // retira) y por eso su tarjeta sigue mostrando deudas hasta el próximo arranque.
            // Saltárselo aquí cambiaría lo que ve el usuario, que no es lo que vengo a tocar.
            if let rows = computeDebts(for: group) { newDebtsByGroup[zoneID] = rows }

            guard !group.isArchived else { continue }

            let expenses = expensesByGroup[zoneID] ?? []
            let shares = sharesByGroup[zoneID] ?? []
            let settlements = settlementsByGroup[zoneID] ?? []

            newBalancesByGroup[zoneID] = GroupBalanceService.calculateBalances(
                expenses: expenses,
                shares: shares,
                members: members,
                settlements: settlements
            )

            allExpenses.append(contentsOf: expenses)
            allShares.append(contentsOf: shares)
            allSettlements.append(contentsOf: settlements)

            for member in members where member.isCurrentUser && member.isActive {
                currentUserMemberIDs.insert(member.id.uuidString)
            }
            // Ventana temprana (recién llegado por enlace: el pull no enciende `isCurrentUser`): sin esto
            // el usuario no contaba en el resumen global aunque la tarjeta del grupo ya lo reconociera.
            // AÑADE, no sustituye: en una zona migrada el mismo humano puede tener su member CloudKit
            // legacy Y el backend, y quedarse solo con el canónico borraría del resumen el saldo del otro.
            // Resolver SOBRE LOS ACTIVOS, no resolver y filtrar: con dos filas mías y la más antigua
            // inactiva, lo segundo devuelve la inactiva y el fix no dispara en la zona migrada que este
            // comentario invoca.
            if let resolved = GroupExpenseService.resolveCurrentUserMember(
                from: members.filter(\.isActive)) {
                currentUserMemberIDs.insert(resolved.id.uuidString)
            }
        }

        if newBalancesByGroup != balancesByGroup { balancesByGroup = newBalancesByGroup }
        if newDebtsByGroup != debtsByGroup { debtsByGroup = newDebtsByGroup }

        // Global summary
        let newSummary: GroupGlobalSummary?
        if !groups.isEmpty {
            newSummary = GroupBalanceService.globalSummary(
                allExpenses: allExpenses,
                allShares: allShares,
                allSettlements: allSettlements,
                currentUserMemberIDs: currentUserMemberIDs
            )
        } else {
            newSummary = nil
        }
        if newSummary != globalSummary { globalSummary = newSummary }
    }

    /// Fuerza un fetch remoto y recarga la lista (refresh acotado a Grupos, no un bump global de
    /// dataVersion). Usado por pull-to-refresh (`force: true`) y entrada al tab (`force: false`).
    /// Fase 3: queda un solo canal. `syncNowFromUI` está self-gateado (no-op sin sesión de nube o con el
    /// kill remoto puesto) y descarta su `Bool` — residuo declarado en la re-medición de A1 (§S5.1), fuera
    /// del alcance de este commit.
    func refreshFromCloud(force: Bool) async {
        _ = force
        await GroupsSyncClient.shared.syncNowFromUI()
        loadData()
    }

    // MARK: - Debounced Recalculation (sync remoto)

    /// Recálculo debounced (150ms) — usado por el sync remoto (`onChange(dataVersion)` / vuelta a
    /// foreground). Coalesce ráfagas de cambios de CloudKit en un solo `fetchData()` + `recalculate()`.
    /// Las acciones LOCALES del usuario siguen usando `loadData()` directo (instantáneo).
    func reloadAndRecalculate() {
        scheduleRecalculation(reload: true)
    }

    /// Cancela cualquier recálculo pendiente (llamado desde `.onDisappear`).
    func cancelRecalculation() {
        debouncer.cancel()
    }

    /// Estado de background — suprime el recálculo mientras la app no está activa.
    func setBackground(_ value: Bool) {
        debouncer.setBackground(value)
    }

    /// Debounce compartido (150ms, `RecalculationDebouncer`): un reload pedido dentro de la ventana no
    /// se pierde, y la espera la suprimen el segundo plano y la app inactiva.
    private func scheduleRecalculation(reload: Bool) {
        debouncer.schedule(reload: reload) { [weak self] shouldReload in
            guard let self else { return }
            if shouldReload {
                fetchData()
            }
            recalculate()
        }
    }

    // MARK: - Helpers

    /// Get the current user's net balance for a specific group.
    func currentUserBalance(for group: SplitGroup) -> MemberBalance? {
        // Identidad RESUELTA: con el flag pelado, la tarjeta del grupo se contradecía sola — su
        // `currentMemberStatus` (ya canónico) reconocía al recién llegado mientras su saldo salía vacío.
        guard let balances = balancesByGroup[group.cloudKitZoneID],
              let members = membersByGroup[group.cloudKitZoneID],
              let currentMember = GroupExpenseService.resolveCurrentUserMember(from: members) else {
            return nil
        }
        let memberID = currentMember.id.uuidString
        return balances.first { $0.memberID == memberID }
    }

    /// M6 D3: Devuelve las deudas simplificadas (estilo Splitwise) que involucran al
    /// current user, ordenadas por monto descendente. Cada `DebtRow` tiene perspectiva
    /// (`.iOwe` / `.theyOweMe`) + counterpartyName resuelto.
    ///
    /// Worst case (5p × 3 monedas) puede generar 15 rows; la card aplica truncation max 3.
    ///
    /// Lookup puro: el cálculo vive en `recalculate()` (ver `debtsByGroup`). Se llama desde el body
    /// de cada tarjeta, así que NO debe volver a calcular nada.
    func currentUserDebts(for group: SplitGroup) -> [DebtRow] {
        debtsByGroup[group.cloudKitZoneID] ?? []
    }

    /// Calcula las deudas de un grupo desde los dicts que pobló `fetchData()`.
    ///
    /// Devuelve `nil` —y no `[]`— cuando al grupo le falta alguna fuente, para distinguir
    /// "sin datos cargados" de "cargado y sin deudas": lo primero no entra en `debtsByGroup`, y
    /// así el lookup cae en su `?? []`. Es el mismo corte que hacía el guard del body.
    private func computeDebts(for group: SplitGroup) -> [DebtRow]? {
        guard let members = membersByGroup[group.cloudKitZoneID],
              let expenses = expensesByGroup[group.cloudKitZoneID],
              let shares = sharesByGroup[group.cloudKitZoneID],
              let settlements = settlementsByGroup[group.cloudKitZoneID] else {
            return nil
        }
        return Self.computeCurrentUserDebts(
            members: members,
            expenses: expenses,
            shares: shares,
            settlements: settlements,
            simplifyDebts: group.simplifyDebts,
            convertTo: group.showDebtsInSingleCurrency ? group.currencyCode : nil
        )
    }

    /// Pure-logic helper para tests sin contexto. Calcula debts filtradas al current
    /// user, con perspectiva resuelta + nameLookup, sort by amount desc.
    /// - Parameter simplifyDebts: respeta el toggle del grupo (`SplitGroup.simplifyDebts`).
    ///   Debe coincidir con lo que muestra el detalle (pestaña Balances / Deudas pendientes);
    ///   NO asumir siempre simplificado. Parámetro obligatorio a propósito — un default
    ///   oculto causó que la card y el detalle divergieran.
    /// - Parameter convertTo: si no es nil y al menos un debt original está en otra
    ///   moneda, las debts se consolidan a esta moneda y los rows resultantes quedan
    ///   marcados con `wasConverted=true`.
    static func computeCurrentUserDebts(
        members: [SplitMember],
        expenses: [SplitExpense],
        shares: [SplitShare],
        settlements: [SplitSettlement],
        simplifyDebts: Bool,
        convertTo: String? = nil,
        converter: CurrencyConverting? = nil
    ) -> [DebtRow] {
        // Identidad RESUELTA, gemela de `currentUserBalance(for:)`: sin ella el recién llegado veía la
        // lista de deudas vacía. Sigue siendo pure-logic para el test: sin sesión ni `recordName` los dos
        // fallbacks no matchean nada y la resolución es byte-idéntica al `first { $0.isCurrentUser }`.
        guard let currentMember = GroupExpenseService.resolveCurrentUserMember(from: members) else {
            return []
        }
        let currentMemberID = currentMember.id.uuidString
        let nameLookup = Dictionary(
            members.map { ($0.id.uuidString, $0.resolvedDisplayName) },
            uniquingKeysWith: { first, _ in first }
        )

        let allDebts = GroupBalanceService.calculateDebts(
            expenses: expenses,
            shares: shares,
            settlements: settlements,
            simplifyDebts: simplifyDebts
        )

        let wasConverted: Bool
        let effectiveDebts: [Debt]
        if let target = convertTo {
            wasConverted = allDebts.contains { $0.currencyCode != target }
            let actualConverter = converter ?? CurrencyConverter.shared
            effectiveDebts = wasConverted
                ? GroupBalanceService.consolidatedDebts(from: allDebts, targetCurrency: target, converter: actualConverter)
                : allDebts
        } else {
            wasConverted = false
            effectiveDebts = allDebts
        }

        return effectiveDebts.compactMap { debt -> DebtRow? in
            if debt.fromMemberID == currentMemberID {
                return DebtRow(
                    id: "\(debt.fromMemberID)-\(debt.toMemberID)-\(debt.currencyCode)",
                    counterpartyName: nameLookup[debt.toMemberID] ?? "?",
                    amount: debt.amount,
                    currencyCode: debt.currencyCode,
                    perspective: .iOwe,
                    wasConverted: wasConverted
                )
            } else if debt.toMemberID == currentMemberID {
                return DebtRow(
                    id: "\(debt.fromMemberID)-\(debt.toMemberID)-\(debt.currencyCode)",
                    counterpartyName: nameLookup[debt.fromMemberID] ?? "?",
                    amount: debt.amount,
                    currencyCode: debt.currencyCode,
                    perspective: .theyOweMe,
                    wasConverted: wasConverted
                )
            }
            return nil
        }.sorted { $0.amount > $1.amount }
    }

    // MARK: - Direction-Grouped Debts (card trailing)

    /// Un monto agregado por moneda en un sentido (te deben / debes).
    struct GroupedDebtAmount: Equatable {
        let currencyCode: String
        let amount: Double
    }

    /// Neto del current user por moneda, repartido por sentido, para el trailing de la card.
    /// Reemplaza el listado por-persona (que se iba a muchas filas): cada sentido muestra hasta
    /// `maxPerDirection` monedas + overflow ("+N más"). "Debes" en una moneda aparece cuando su
    /// neto es negativo (debes más de lo que te deben en esa moneda).
    struct DirectionGroupedDebts: Equatable {
        let owedToMe: [GroupedDebtAmount]
        let owedToMeOverflow: Int
        let iOwe: [GroupedDebtAmount]
        let iOweOverflow: Int

        var isEmpty: Bool { owedToMe.isEmpty && iOwe.isEmpty }
    }

    /// Pure-logic: NETEA las deudas del current user por moneda (te deben − debes), igual que
    /// `GroupBalanceService.computeGroupHeaderBalance` — así la card coincide con la banda del
    /// header y el resumen global. Reparte el neto por sentido (>0 → te deben, <0 → debes),
    /// ordena por código de moneda y aplica el cap por sentido.
    static func groupDebtsByDirection(_ debts: [DebtRow], maxPerDirection: Int = 2) -> DirectionGroupedDebts {
        // Neto por moneda: theyOweMe suma, iOwe resta (invariante a simplifyDebts).
        var net: [String: Double] = [:]
        for row in debts {
            switch row.perspective {
            case .theyOweMe: net[row.currencyCode, default: 0] += row.amount
            case .iOwe: net[row.currencyCode, default: 0] -= row.amount
            }
        }
        var owedToMe: [String: Double] = [:]
        var iOwe: [String: Double] = [:]
        for (currency, raw) in net {
            let value = (raw * 100).rounded() / 100
            if value > 0.01 {
                owedToMe[currency] = value
            } else if value < -0.01 {
                iOwe[currency] = -value
            }
        }
        func summarize(_ byCurrency: [String: Double]) -> (shown: [GroupedDebtAmount], overflow: Int) {
            let sorted = byCurrency
                .map { GroupedDebtAmount(currencyCode: $0.key, amount: $0.value) }
                .sorted { $0.currencyCode < $1.currencyCode }
            return (Array(sorted.prefix(maxPerDirection)), max(0, sorted.count - maxPerDirection))
        }
        let owed = summarize(owedToMe)
        let owe = summarize(iOwe)
        return DirectionGroupedDebts(
            owedToMe: owed.shown,
            owedToMeOverflow: owed.overflow,
            iOwe: owe.shown,
            iOweOverflow: owe.overflow
        )
    }

    /// Member count for a group.
    func memberCount(for group: SplitGroup) -> Int {
        membersByGroup[group.cloudKitZoneID]?.filter(\.isActive).count ?? 0
    }

    /// Pending approval member count for a group. Returns 0 for archived groups
    /// (UX: nadie aprueba pending en un grupo archivado; mostrar el badge sobre
    /// card opacity-0.6 sería confuso).
    func pendingMemberCount(for group: SplitGroup) -> Int {
        guard !group.isArchived else { return 0 }
        return membersByGroup[group.cloudKitZoneID]?.filter(\.isPendingApproval).count ?? 0
    }

    /// Status del current user en el grupo. Drives `GroupCardView.displayMode`
    /// para mostrar chip pending/rejected en lugar del balance trailing.
    /// Identidad RESUELTA, como en `GroupDetailViewModel.currentUserMember`. Sin esto la tarjeta
    /// contradecía al detalle, y sobre todo: la tarjeta YA está cableada para los dos estados
    /// —`.pendingApproval` la desactiva (`GroupCardView:90`) y `.rejected` enruta a `onRejectedTap`
    /// (:275 → `GroupsContainerView:396`, la confirmación de salir)—, así que resolver aquí pone al
    /// rechazado delante de esa salida en sesión viva, sin depender de que abra el detalle.
    ///
    /// Esa salida NO servía de nada por sí sola: `leaveGroup` no toleraba `memberNotFound` y a un
    /// rechazado —que ya no es miembro server-side— el RPC le respondía con eso. Se le ofrecía una
    /// acción destructiva que fallaba. Arreglado en el mismo commit dándole el `catch` que
    /// `batchLeave` ya tenía.
    func currentMemberStatus(for group: SplitGroup) -> SplitMemberStatus? {
        guard let members = membersByGroup[group.cloudKitZoneID] else { return nil }
        return GroupExpenseService.resolveCurrentUserMember(from: members)?.memberStatus
    }

    /// Grupos donde el current user puede crear un gasto USABLE (activo + miembro `.active`
    /// presente). Usado por el FAB del tab para decidir si ofrecer "Nuevo gasto" y poblar el
    /// composer. Filtra `groups` crudo (no `activeGroups`) para que el guard archived/hidden
    /// del helper sea load-bearing en un solo sitio.
    func eligibleGroupsForExpense() -> [SplitGroup] {
        groups.filter {
            GroupExpenseEligibilityLogic.canCreateExpense(
                currentMemberStatus: currentMemberStatus(for: $0),
                isArchived: $0.isArchived,
                isHiddenForAll: $0.isHiddenForAll,
                isMigratedFrozen: $0.isMigratedFrozen
            )
        }
    }

    /// Miembros activos de un grupo desde el cache (para el form de gasto desde el composer).
    func activeMembers(for group: SplitGroup) -> [SplitMember] {
        (membersByGroup[group.cloudKitZoneID] ?? []).filter(\.isActive)
    }

    /// memberID.uuidString → displayName (todos los miembros) desde el cache. Espeja el
    /// lookup de `GroupDetailViewModel` para resolver nombres en el form de gasto.
    func memberNameLookup(for group: SplitGroup) -> [String: String] {
        Dictionary(
            (membersByGroup[group.cloudKitZoneID] ?? []).map { ($0.id.uuidString, $0.resolvedDisplayName) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - Actions

    func archiveGroup(_ group: SplitGroup) {
        do {
            try GroupService.shared.setArchived(group, isArchived: true)
            loadData()
        } catch {
            #if DEBUG
            print("GroupsViewModel: Error archiving group: \(error)")
            #endif
        }
    }

    /// ¿Se le puede abrir el detalle de este grupo al usuario actual? Envuelve el SSOT
    /// (`GroupCardDisplayLogic.allowsDetailEntry`) con la identidad ya resuelta, para que las TRES
    /// puertas del tab —la tarjeta, el deep link de una notificación y la acción de un nudge— hagan
    /// la misma pregunta en vez de tres parecidas.
    func canOpenDetail(for group: SplitGroup) -> Bool {
        GroupCardDisplayLogic.allowsDetailEntry(
            memberStatus: currentMemberStatus(for: group),
            migrationState: group.migrationState
        )
    }

    /// El primer grupo de la lista que SÍ se puede abrir. Para quien navega sin haber elegido grupo
    /// (hoy, el nudge `.openGroupDetail`): sin esto aterrizaba en `activeGroups.first`, que puede ser
    /// justo el que está esperando aprobación.
    func firstGroupOpenableInDetail() -> SplitGroup? {
        activeGroups.first { canOpenDetail(for: $0) }
    }

    /// Push del detalle vía `navigationDestination(item:)`: setear `selectedGroup` empuja.
    func openDetail(for group: SplitGroup) {
        selectedGroup = group
    }
}
