//
//  WidgetGroupsSnapshotBuilder.swift
//  Yala
//
//  Los grupos de la foto del App Group (widget «Grupos», 2.2): el resumen de arriba de la lista y una fila por grupo
//  activo. **No calcula nada propio**: llama a las mismas funciones que `GroupsViewModel.recalculate()`, así que el
//  widget dice lo que dice la lista. Lo fija `WidgetGroupsSnapshotParityTests`.
//
//  Lee con el `context` que le pasan y no por `GroupService.shared`: el paso 9 del arranque escribe la foto antes del
//  paso 16, que es el que da contexto a los servicios de grupos.
//

import Foundation
import SwiftData

@MainActor
enum WidgetGroupsSnapshotBuilder {

    /// Lo que la lista de Grupos tiene de cada grupo: el grupo y sus cuatro fuentes, con los mismos fetch (y el mismo
    /// orden) que `GroupService.fetchMembers` y `GroupExpenseService.fetchExpenses/fetchAllShares/fetchSettlements`.
    struct Sources {
        let group: SplitGroup
        let members: [SplitMember]
        let expenses: [SplitExpense]
        let shares: [SplitShare]
        let settlements: [SplitSettlement]
    }

    /// Los grupos de la foto, o `nil` si el store de grupos no se deja leer (el widget enseña entonces «Abre Yala», no
    /// un «no tienes grupos» que sería mentira). Sin grupos devuelve el resumen vacío: es la invitación a crear uno.
    static func build(context: ModelContext) -> WidgetGroupsSummary? {
        do {
            let groups = try context.fetch(FetchDescriptor<SplitGroup>(sortBy: [SortDescriptor(\.name)]))
            let sources = try groups.map { group in
                Sources(
                    group: group,
                    members: try GroupService.shared.fetchMembers(for: group, context: context),
                    expenses: try fetchExpenses(zoneID: group.cloudKitZoneID, context: context),
                    shares: try fetchShares(zoneID: group.cloudKitZoneID, context: context),
                    settlements: try fetchSettlements(zoneID: group.cloudKitZoneID, context: context)
                )
            }
            return summary(from: sources)
        } catch {
            #if DEBUG
            print("WidgetGroupsSnapshotBuilder: Error fetching groups: \(error)")
            #endif
            return nil
        }
    }

    /// La cuenta, sin leer nada: la parte que el test de paridad compara con la app.
    ///
    /// - Resumen: `GroupBalanceService.globalSummary` sobre los grupos NO archivados (ocultos para todos incluidos), con
    ///   los ids de «yo» de cada grupo: `isCurrentUser` activo y la identidad resuelta sobre los activos. Es el bucle de
    ///   `GroupsViewModel.recalculate()`, y lo que enseña arriba la lista (`GroupSummaryHeader`).
    /// - Archivados: la misma cuenta sobre los archivados no ocultos (`GroupsViewModel.archivedSummary`): la línea
    ///   «+ S/ 190.00 que te deben en grupos archivados» de la lista (L19-9). Archivar no salda nada.
    /// - Filas: los grupos de `activeGroups` (ni archivados ni ocultos) cuya tarjeta enseña saldos
    ///   (`GroupCardDisplayLogic.displayMode == .active`; un pendiente, un rechazado o un congelado enseñan un chip, no
    ///   cifras). Cada fila dice lo que dice la CABECERA DEL DETALLE de su grupo, que es lo que abre al tocarla
    ///   (`GroupDetailViewModel.headerBalance`): las deudas del grupo con su «simplificar» y, con «una sola moneda»,
    ///   consolidadas; neteadas por divisa con `computeGroupHeaderBalance`. La tarjeta de la lista las enseña por persona.
    static func summary(from sources: [Sources]) -> WidgetGroupsSummary {
        var allExpenses: [SplitExpense] = []
        var allShares: [SplitShare] = []
        var allSettlements: [SplitSettlement] = []
        var currentUserMemberIDs = Set<String>()
        var archivedExpenses: [SplitExpense] = []
        var archivedShares: [SplitShare] = []
        var archivedSettlements: [SplitSettlement] = []
        var archivedMemberIDs = Set<String>()
        var activeGroupCount = 0
        var rows: [WidgetGroupBalance] = []

        for source in sources {
            let group = source.group
            if group.isArchived {
                guard !group.isHiddenForAll else { continue }
                archivedExpenses.append(contentsOf: source.expenses)
                archivedShares.append(contentsOf: source.shares)
                archivedSettlements.append(contentsOf: source.settlements)
                archivedMemberIDs.formUnion(myMemberIDs(in: source.members))
                continue
            }
            allExpenses.append(contentsOf: source.expenses)
            allShares.append(contentsOf: source.shares)
            allSettlements.append(contentsOf: source.settlements)
            currentUserMemberIDs.formUnion(myMemberIDs(in: source.members))

            guard !group.isHiddenForAll else { continue }
            activeGroupCount += 1
            let me = GroupExpenseService.resolveCurrentUserMember(from: source.members)
            let mode = GroupCardDisplayLogic.displayMode(memberStatus: me?.memberStatus,
                                                         migrationState: group.migrationState)
            guard mode == .active else { continue }
            let band = headerBalance(source, currentMemberID: me?.id.uuidString)
            rows.append(WidgetGroupBalance(
                id: group.id.uuidString,
                name: group.name,
                iconName: group.iconName,
                colorHex: group.colorHex,
                iOwe: amounts(band?.iOwe ?? [:]),
                owedToMe: amounts(band?.owedToMe ?? [:])
            ))
        }

        let global = GroupBalanceService.globalSummary(
            allExpenses: allExpenses,
            allShares: allShares,
            allSettlements: allSettlements,
            currentUserMemberIDs: currentUserMemberIDs
        )
        let archived = archivedExpenses.isEmpty ? nil : GroupBalanceService.globalSummary(
            allExpenses: archivedExpenses,
            allShares: archivedShares,
            allSettlements: archivedSettlements,
            currentUserMemberIDs: archivedMemberIDs
        )

        return WidgetGroupsSummary(
            iOwe: amounts(global.totalIOwe),
            owedToMe: amounts(global.totalOwedToMe),
            activeGroupCount: activeGroupCount,
            groups: rows,
            archivedIOwe: amounts(archived?.totalIOwe ?? [:]),
            archivedOwedToMe: amounts(archived?.totalOwedToMe ?? [:])
        )
    }

    /// Los ids de «yo» en un grupo para el resumen: el flag activo y la identidad resuelta sobre los activos (las dos
    /// cosas, como `GroupsViewModel.recalculate`: en una zona migrada pueden ser dos filas del mismo humano).
    private static func myMemberIDs(in members: [SplitMember]) -> Set<String> {
        var ids = Set(members.filter { $0.isCurrentUser && $0.isActive }.map(\.id.uuidString))
        if let resolved = GroupExpenseService.resolveCurrentUserMember(from: members.filter(\.isActive)) {
            ids.insert(resolved.id.uuidString)
        }
        return ids
    }

    /// La banda de la cabecera del detalle del grupo, con la misma cuenta que `GroupDetailViewModel` (deudas con el
    /// «simplificar» del grupo; con «una sola moneda», consolidadas solo si hay otra divisa). `nil` sin «yo» en el grupo.
    static func headerBalance(_ source: Sources, currentMemberID: String?) -> GroupHeaderBalance? {
        guard let currentMemberID else { return nil }
        let group = source.group
        let raw = GroupBalanceService.calculateDebts(
            expenses: source.expenses,
            shares: source.shares,
            settlements: source.settlements,
            simplifyDebts: group.simplifyDebts
        )
        let debts: [Debt]
        if group.showDebtsInSingleCurrency, raw.contains(where: { $0.currencyCode != group.currencyCode }) {
            debts = GroupBalanceService.consolidatedDebts(from: raw, targetCurrency: group.currencyCode)
        } else {
            debts = raw
        }
        return GroupBalanceService.computeGroupHeaderBalance(debts: debts, currentMemberID: currentMemberID)
    }

    /// Las divisas de un lado del resumen con algo pendiente, en el orden del resumen de la lista
    /// (`GroupSummaryHeader.amounts`: más de un céntimo, por código).
    static func amounts(_ byCurrency: [String: Double]) -> [WidgetGroupAmount] {
        byCurrency
            .filter { $0.value > 0.01 }
            .sorted { $0.key < $1.key }
            .map { WidgetGroupAmount(currencyCode: $0.key, amount: $0.value) }
    }

    // MARK: - Fetch (concretos por tipo: un `#Predicate` genérico crashea, `swiftdata-cloudkit.md`)

    private static func fetchExpenses(zoneID: String, context: ModelContext) throws -> [SplitExpense] {
        try context.fetch(FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.groupZoneID == zoneID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
    }

    private static func fetchShares(zoneID: String, context: ModelContext) throws -> [SplitShare] {
        try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneID }))
    }

    private static func fetchSettlements(zoneID: String, context: ModelContext) throws -> [SplitSettlement] {
        try context.fetch(FetchDescriptor<SplitSettlement>(
            predicate: #Predicate { $0.groupZoneID == zoneID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
    }
}
