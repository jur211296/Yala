//
//  GroupsViewModel.swift
//  Yala
//
//  ViewModel for the Groups tab — list, global summary, per-group balances.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GroupsViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var groups: [SplitGroup] = []
    private(set) var membersByGroup: [String: [SplitMember]] = [:]       // zoneID → members
    private(set) var balancesByGroup: [String: [MemberBalance]] = [:]    // zoneID → balances
    private(set) var globalSummary: GroupGlobalSummary?

    /// M6 D3: cached fuentes para recalcular `currentUserDebts(for:)` on-demand.
    /// Pobladas en `loadData()` para evitar fetch repetido por cada card render.
    private(set) var expensesByGroup: [String: [SplitExpense]] = [:]
    private(set) var sharesByGroup: [String: [SplitShare]] = [:]
    private(set) var settlementsByGroup: [String: [SplitSettlement]] = [:]

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

    func loadData() {
        guard modelContext != nil else { return }

        do {
            groups = try GroupService.shared.fetchAllGroups()

            // Per-group data
            var allExpenses: [SplitExpense] = []
            var allShares: [SplitShare] = []
            var allSettlements: [SplitSettlement] = []
            var currentUserMemberIDs = Set<String>()

            for group in groups {
                let members = try GroupService.shared.fetchMembers(for: group)
                membersByGroup[group.cloudKitZoneID] = members

                // Skip heavy data loading for archived groups
                guard !group.isArchived else { continue }

                let expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
                let shares = try GroupExpenseService.shared.fetchAllShares(for: group)
                let settlements = try GroupExpenseService.shared.fetchSettlements(for: group)

                // M6 D3: cache para recalcular debts on-demand (currentUserDebts).
                expensesByGroup[group.cloudKitZoneID] = expenses
                sharesByGroup[group.cloudKitZoneID] = shares
                settlementsByGroup[group.cloudKitZoneID] = settlements

                let balances = GroupBalanceService.calculateBalances(
                    expenses: expenses,
                    shares: shares,
                    members: members,
                    settlements: settlements
                )
                balancesByGroup[group.cloudKitZoneID] = balances

                allExpenses.append(contentsOf: expenses)
                allShares.append(contentsOf: shares)
                allSettlements.append(contentsOf: settlements)

                for member in members where member.isCurrentUser && member.isActive {
                    currentUserMemberIDs.insert(member.id.uuidString)
                }
            }

            // Global summary
            if !groups.isEmpty {
                globalSummary = GroupBalanceService.globalSummary(
                    allExpenses: allExpenses,
                    allShares: allShares,
                    allSettlements: allSettlements,
                    currentUserMemberIDs: currentUserMemberIDs
                )
            } else {
                globalSummary = nil
            }
        } catch {
            #if DEBUG
            print("GroupsViewModel: Error loading data: \(error)")
            #endif
        }
    }

    // MARK: - Helpers

    /// Get the current user's net balance for a specific group.
    func currentUserBalance(for group: SplitGroup) -> MemberBalance? {
        guard let balances = balancesByGroup[group.cloudKitZoneID],
              let members = membersByGroup[group.cloudKitZoneID],
              let currentMember = members.first(where: { $0.isCurrentUser }) else {
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
    func currentUserDebts(for group: SplitGroup) -> [DebtRow] {
        guard let members = membersByGroup[group.cloudKitZoneID],
              let expenses = expensesByGroup[group.cloudKitZoneID],
              let shares = sharesByGroup[group.cloudKitZoneID],
              let settlements = settlementsByGroup[group.cloudKitZoneID] else {
            return []
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
        guard let currentMember = members.first(where: { $0.isCurrentUser }) else {
            return []
        }
        let currentMemberID = currentMember.id.uuidString
        let nameLookup = Dictionary(
            members.map { ($0.id.uuidString, $0.displayName) },
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
    func currentMemberStatus(for group: SplitGroup) -> SplitMemberStatus? {
        membersByGroup[group.cloudKitZoneID]?
            .first(where: { $0.isCurrentUser })?
            .memberStatus
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
                isHiddenForAll: $0.isHiddenForAll
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
            (membersByGroup[group.cloudKitZoneID] ?? []).map { ($0.id.uuidString, $0.displayName) },
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

    /// Push del detalle vía `navigationDestination(item:)`: setear `selectedGroup` empuja.
    func openDetail(for group: SplitGroup) {
        selectedGroup = group
    }
}
