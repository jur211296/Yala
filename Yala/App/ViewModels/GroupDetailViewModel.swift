//
//  GroupDetailViewModel.swift
//  Yala
//
//  ViewModel for a single group's detail — expenses, balances, debts, members.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GroupDetailViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    let group: SplitGroup

    // MARK: - Data

    private(set) var members: [SplitMember] = []
    private(set) var expenses: [SplitExpense] = []
    private(set) var shares: [SplitShare] = []
    private(set) var settlements: [SplitSettlement] = []
    private(set) var balances: [MemberBalance] = []
    private(set) var debts: [Debt] = []

    /// Drives `isEstimate` del `AmountText` para prefijar "≈" solo cuando hubo conversión
    /// real (al menos un balance/debt original tenía currency ≠ `group.currencyCode`).
    private(set) var balancesWereConverted: Bool = false
    private(set) var debtsWereConverted: Bool = false

    // MARK: - Computed

    /// memberID.uuidString → displayName (rebuilt in loadData)
    private(set) var memberNameLookup: [String: String] = [:]

    /// expense.id.uuidString → bridged personal TX1 (subcat manual o nil; nunca TX2 sistema).
    /// Permite renderizar icono+color de la subcat per-user en el feed.
    private(set) var txBridgeMap: [String: TransactionItem] = [:]

    /// expense.id → mi share. Filtrado por currentMemberID en loadData (no soy miembro → vacío).
    private(set) var mySharesByExpense: [UUID: SplitShare] = [:]

    /// uuidString del current member (para resolver perspectiva personal en el feed).
    var currentMemberID: String? { currentUserMember?.id.uuidString }

    var currentUserMember: SplitMember? {
        members.first { $0.isCurrentUser }
    }

    var activeMembers: [SplitMember] {
        members.filter(\.isActive)
    }

    var canCurrentUserParticipate: Bool {
        currentUserMember?.isActive == true
    }

    var isCurrentUserAdmin: Bool {
        guard let me = currentUserMember, me.isActive else { return false }
        return me.isAdmin
    }

    /// members awaiting admin approval — visible solo en sección "Solicitudes pendientes" para admins.
    var pendingApprovalMembers: [SplitMember] {
        members.filter { $0.isPendingApproval }
    }

    /// Members visibles en GroupSettingsView (activos + pending approval).
    /// Estados terminales (left/removed/rejected) se ocultan vía `isVisible`.
    var visibleMembers: [SplitMember] {
        members.filter(\.isVisible)
    }

    // MARK: - UI State

    var activeSheet: GroupSheet?

    // MARK: - Init

    init(group: SplitGroup) {
        self.group = group
    }

    // MARK: - Context

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        do {
            members = try GroupService.shared.fetchMembers(for: group)
            memberNameLookup = Dictionary(
                members.map { ($0.id.uuidString, $0.displayName) },
                uniquingKeysWith: { first, _ in first }
            )
            expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
            shares = try GroupExpenseService.shared.fetchAllShares(for: group)
            settlements = try GroupExpenseService.shared.fetchSettlements(for: group)

            let rawBalances = GroupBalanceService.calculateBalances(
                expenses: expenses,
                shares: shares,
                members: members,
                settlements: settlements
            )

            let rawDebts = GroupBalanceService.calculateDebts(
                expenses: expenses,
                shares: shares,
                settlements: settlements,
                simplifyDebts: group.simplifyDebts
            )

            if group.showDebtsInSingleCurrency {
                let target = group.currencyCode
                balancesWereConverted = rawBalances.contains { $0.currencyCode != target }
                debtsWereConverted = rawDebts.contains { $0.currencyCode != target }
                balances = balancesWereConverted
                    ? GroupBalanceService.consolidatedBalances(from: rawBalances, targetCurrency: target)
                    : rawBalances
                debts = debtsWereConverted
                    ? GroupBalanceService.consolidatedDebts(from: rawDebts, targetCurrency: target)
                    : rawDebts
            } else {
                balances = rawBalances
                debts = rawDebts
                if balancesWereConverted { balancesWereConverted = false }
                if debtsWereConverted { debtsWereConverted = false }
            }

            rebuildBridgeMaps(context: context)
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error loading data: \(error)")
            #endif
        }
    }

    /// Prefetch TX bridge personal por `splitExpenseID` filtrado a la zona del grupo +
    /// build `mySharesByExpense` con el share del current user. Evita N+1 query en el feed.
    private func rebuildBridgeMaps(context: ModelContext) {
        let zoneID = group.cloudKitZoneID
        do {
            let bridgedTXs = try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitGroupZoneID == zoneID }
            ))

            // TX1 preferida: subcat manual O nil (no TX2 sistema "Préstamo a grupos").
            txBridgeMap = Dictionary(grouping: bridgedTXs, by: { $0.splitExpenseID ?? "" })
                .compactMapValues { txs in
                    txs.first(where: { tx in
                        guard let sub = tx.subcategory else { return true }
                        return !sub.isAnySystem
                    })
                }
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: fetch de TX bridgeadas falló: \(error)")
            #endif
            txBridgeMap = [:]
        }

        // mySharesByExpense: filter shares to current user only.
        if let currentID = currentMemberID {
            mySharesByExpense = Dictionary(
                shares.filter { $0.memberID == currentID }.map { ($0.expenseID, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        } else {
            mySharesByExpense = [:]
        }
    }

    // MARK: - Actions

    func deleteExpense(_ expense: SplitExpense) {
        do {
            try GroupExpenseService.shared.deleteExpense(expense, in: group)
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error deleting expense: \(error)")
            #endif
            surfaceActionError(L10n.Groups.Errors.actionFailed)
        }
    }

    /// Name for a member ID, with fallback.
    func memberName(for memberID: String) -> String {
        memberNameLookup[memberID] ?? memberID
    }

    func confirmSettlement(_ settlement: SplitSettlement) {
        do {
            try GroupExpenseService.shared.confirmSettlement(settlement, in: group)
            TelemetryService.track(.groupSettlementConfirmed)
            DS.Haptic.success()
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error confirming settlement: \(error)")
            #endif
            surfaceActionError(L10n.Groups.Errors.actionFailed)
        }
    }

    func rejectSettlement(_ settlement: SplitSettlement) {
        do {
            try GroupExpenseService.shared.deleteSettlement(settlement, in: group)
            TelemetryService.track(.groupSettlementRejected)
            DS.Haptic.warning()
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error rejecting settlement: \(error)")
            #endif
            surfaceActionError(L10n.Groups.Errors.actionFailed)
        }
    }

    func sharesForExpense(_ expense: SplitExpense) -> [SplitShare] {
        shares.filter { $0.expenseID == expense.id }
    }

    // MARK: - Share Link

    private(set) var shareURL: URL?
    var isCreatingShare = false

    // MARK: - Error feedback

    /// Mensaje de error de una acción del usuario (eliminar gasto, liquidar, invitar). La vista lo
    /// muestra en un alert — antes estos fallos solo se logueaban en DEBUG y en Release el botón
    /// "no hacía nada".
    var actionErrorMessage: String?
    var showActionError = false

    private func surfaceActionError(_ message: String) {
        actionErrorMessage = message
        showActionError = true
        DS.Haptic.warning()
    }

    func createShareLink() async {
        guard !isCreatingShare else { return }
        guard group.isOwner, isCurrentUserAdmin else { return }
        if shareURL != nil { return }
        isCreatingShare = true
        do {
            let (_, ckURL) = try await SplitZoneManager(syncManager: .shared).createShare(for: group)
            if let ckURL {
                shareURL = buildBrandedInviteURL(from: ckURL)
            }
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error creating share: \(error)")
            #endif
            // SplitZoneError carries localized copy (e.g. "sync preparing"); any other error
            // (raw CKError — network/quota) maps to the branded inviteFailed copy instead of
            // leaking a technical system string into the alert.
            let message = (error as? SplitZoneError)?.errorDescription ?? L10n.Groups.Errors.inviteFailed
            surfaceActionError(message)
        }
        isCreatingShare = false
    }

    private func buildBrandedInviteURL(from ckURL: URL) -> URL {
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let inviterName = name.isEmpty ? L10n.Profile.defaultName : name
        return InviteLinkService.buildInviteURL(
            shareURL: ckURL,
            group: group,
            members: activeMembers,
            inviterName: inviterName
        ) ?? ckURL
    }
}

// MARK: - Sheet Enum

enum GroupSheet: Identifiable {
    case settings
    case addExpense
    case editExpense(SplitExpense)
    case settlement(Debt)

    var id: String {
        switch self {
        case .settings: "settings"
        case .addExpense: "addExpense"
        case .editExpense(let e): "editExpense-\(e.id)"
        case .settlement(let d): "settlement-\(d.id)"
        }
    }
}
