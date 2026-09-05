//
//  GroupDetailViewModel.swift
//  Yala
//
//  ViewModel for a single group's detail — expenses, balances, debts, members.
//

import Foundation
import SwiftData
import UIKit

@MainActor
@Observable
final class GroupDetailViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    let group: SplitGroup

    // MARK: - Recalculation State (debounce — espejo de PanelViewModel)

    /// Task de recálculo debounced — coalesce ráfagas de `onChange(dataVersion)` del sync remoto.
    private var recalculateTask: Task<Void, Never>?
    /// Un reload solicitado dentro de la ventana de debounce no se pierde (se ejecuta al disparar).
    private var pendingReload = false
    /// Suprime el recálculo en background (evita trabajo inútil / traps de snapshot).
    private(set) var isInBackground = false

    // MARK: - Data

    private(set) var members: [SplitMember] = []
    private(set) var expenses: [SplitExpense] = []
    private(set) var shares: [SplitShare] = []
    private(set) var settlements: [SplitSettlement] = []
    private(set) var balances: [MemberBalance] = []
    private(set) var debts: [Debt] = []

    /// `true` tras el primer `fetchData()` con éxito. Mientras es `false` el detalle muestra un
    /// skeleton en vez de contenido a medio poblar (espejo de `GroupsViewModel.hasLoadedOnce`).
    private(set) var isReady: Bool = false

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

    /// `[nombre normalizado de subcategoría: (icono, colorHex)]` de las subcategorías locales.
    /// Fallback self-contained para el icono del feed cuando NO hay bridge personal (device fresco
    /// / re-onboardeado, no-participante, `.groupInvite`): casa `SplitExpense.subcategoryName` —
    /// el nombre localizado del creador que viaja en el record — contra las subcategorías locales.
    /// SSOT compartida vía `GroupExpenseIconResolver.buildNameLookup`.
    private(set) var subcategoryNameLookup: [String: (iconName: String, colorHex: String)] = [:]

    /// expense.id → mi share. Filtrado por currentMemberID en loadData (no soy miembro → vacío).
    private(set) var mySharesByExpense: [UUID: SplitShare] = [:]

    /// uuidString del current member (para resolver perspectiva personal en el feed).
    var currentMemberID: String? { currentUserMember?.id.uuidString }

    /// Neto del usuario actual por moneda, para la banda de balance del header del detalle.
    /// `debts` ya respeta `showDebtsInSingleCurrency` (se consolida en `loadData`).
    var headerBalance: GroupHeaderBalance? {
        guard let currentMemberID else { return nil }
        return GroupBalanceService.computeGroupHeaderBalance(debts: debts, currentMemberID: currentMemberID)
    }

    /// Identidad RESUELTA (flag → `sub` del canal backend → identidad iCloud), no el flag pelado.
    ///
    /// `GroupsSyncClient.applyMember` NUNCA enciende `isCurrentUser`, y el único call-site de
    /// producción de `refreshCurrentUserFlags` está en el ARRANQUE (`AppBootstrapper:526`). Quien se
    /// une por el canal backend en sesión viva no tenía identidad local hasta reiniciar la app: de
    /// aquí cuelgan los dos banners de estado de `GroupDetailView` (:136 y :138), así que el
    /// rechazado se quedaba sin cartel y —porque `discardRejectedGroup` solo se llama desde ese
    /// banner— sin salida.
    var currentUserMember: SplitMember? {
        GroupExpenseService.resolveCurrentUserMember(from: members)
    }

    var activeMembers: [SplitMember] {
        members.filter(\.isActive)
    }

    var canCurrentUserParticipate: Bool {
        // G6-3 (C4): grupo migrado y CONGELADO → sin escrituras (oculta FAB/editar/borrar/liquidar/confirmar
        // de un golpe — la UX primaria del freeze; el guard service-level es la RED).
        if group.isMigratedFrozen { return false }
        return currentUserMember?.isActive == true
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

    /// Gasto pendiente de editar tras cerrar el detalle (reemplazo de sheet: el
    /// detalle baja en medium, el editor sube en large). Espejo de RecordsViewModel.
    private var pendingEditExpense: SplitExpense?

    // MARK: - Init

    init(group: SplitGroup) {
        self.group = group
    }

    // MARK: - Context

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    /// Fuerza un fetch remoto y recarga (refresh acotado, no bump global de dataVersion).
    /// Usado por pull-to-refresh (`force: true`) y entrada al detalle (`force: false`) — así los
    /// gastos de otros miembros aún no sincronizados aparecen al abrir el grupo.
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
    /// foreground). Coalesce ráfagas de cambios de CloudKit. Las acciones LOCALES del usuario
    /// (delete/confirm/reject/removeOpeningBalance) siguen usando `loadData()` directo (instantáneo).
    func reloadAndRecalculate() {
        scheduleRecalculation(reload: true)
    }

    /// Cancela cualquier recálculo pendiente (llamado desde `.onDisappear`).
    func cancelRecalculation() {
        recalculateTask?.cancel()
    }

    /// Estado de background — suprime el recálculo mientras la app no está activa.
    func setBackground(_ value: Bool) {
        isInBackground = value
        if value {
            recalculateTask?.cancel()
            recalculateTask = nil
            pendingReload = false
        }
    }

    /// Debounce compartido (150ms). `pendingReload` asegura que un reload solicitado dentro de la
    /// ventana no se pierda. Gateado por `isInBackground` + `applicationState`.
    private func scheduleRecalculation(reload: Bool) {
        guard !isInBackground else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        if reload { pendingReload = true }
        recalculateTask?.cancel()
        recalculateTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard !Task.isCancelled else { return }
            let shouldReload = pendingReload
            pendingReload = false
            if shouldReload {
                fetchData()
            }
            recalculate()
        }
    }

    // MARK: - Data Loading

    /// Path síncrono instantáneo: fetch + recálculo en una pasada. Usado por los callers locales
    /// (setContext, delete/confirm/reject/removeOpeningBalance) que esperan feedback inmediato.
    /// El sync remoto (onChange dataVersion) usa `reloadAndRecalculate`.
    func loadData() {
        fetchData()
        recalculate()
    }

    /// Fase de FETCH pura (SwiftData): members/nameLookup/expenses/shares/settlements + bridge maps.
    /// NO calcula balances/debts.
    private func fetchData() {
        guard let context = modelContext else { return }
        // Con contexto presente, tras el INTENTO marcamos listo (mostrar contenido/estado, no un
        // skeleton eterno si un fetch falla) — espeja el diseño temprano de `hasLoadedOnce` en
        // GroupsViewModel. Sin contexto (carrera de bootstrap) NO se marca → sigue el skeleton.
        defer { isReady = true }

        do {
            // Fetch atómico: a locales primero, asignar solo si TODOS tuvieron éxito. Un fallo a
            // medias no deja `members` nuevo con `expenses` viejo (estado mixto que `recalculate`
            // computaría como balances inconsistentes); las propiedades conservan su valor previo.
            let fetchedMembers = try GroupService.shared.fetchMembers(for: group)
            let fetchedExpenses = try GroupExpenseService.shared.fetchExpenses(for: group)
            let fetchedShares = try GroupExpenseService.shared.fetchAllShares(for: group)
            let fetchedSettlements = try GroupExpenseService.shared.fetchSettlements(for: group)

            members = fetchedMembers
            memberNameLookup = Dictionary(
                fetchedMembers.map { ($0.id.uuidString, $0.resolvedDisplayName) },
                uniquingKeysWith: { first, _ in first }
            )
            expenses = fetchedExpenses
            shares = fetchedShares
            settlements = fetchedSettlements

            rebuildBridgeMaps(context: context)
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error fetching data: \(error)")
            #endif
        }
    }

    /// Fase de CÁLCULO pura: balances + debts + consolidación single-currency sobre los arrays ya
    /// cacheados por `fetchData()` (sin fetch nuevo). Equality guards para no churnear `@Observable`.
    private func recalculate() {
        guard modelContext != nil else { return }

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

        let newBalances: [MemberBalance]
        let newDebts: [Debt]
        if group.showDebtsInSingleCurrency {
            let target = group.currencyCode
            balancesWereConverted = rawBalances.contains { $0.currencyCode != target }
            debtsWereConverted = rawDebts.contains { $0.currencyCode != target }
            newBalances = balancesWereConverted
                ? GroupBalanceService.consolidatedBalances(from: rawBalances, targetCurrency: target)
                : rawBalances
            newDebts = debtsWereConverted
                ? GroupBalanceService.consolidatedDebts(from: rawDebts, targetCurrency: target)
                : rawDebts
        } else {
            newBalances = rawBalances
            newDebts = rawDebts
            if balancesWereConverted { balancesWereConverted = false }
            if debtsWereConverted { debtsWereConverted = false }
        }

        if newBalances != balances { balances = newBalances }
        if newDebts != debts { debts = newDebts }
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

        // Lookup nombre→icono/color: fallback self-contained del feed cuando no hay bridge.
        do {
            let subs = try context.fetch(FetchDescriptor<Subcategory>())
            subcategoryNameLookup = GroupExpenseIconResolver.buildNameLookup(from: subs)
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: fetch de subcategorías falló: \(error)")
            #endif
            subcategoryNameLookup = [:]
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

    /// Botón Editar del detalle: marca el gasto pendiente y cierra el sheet de
    /// detalle. El padre, en `onDismiss`, presenta `.editExpense`.
    func requestEditFromDetail(_ expense: SplitExpense) {
        pendingEditExpense = expense
        activeSheet = nil
    }

    /// Consume (one-shot) el gasto pendiente de edición. Lo invoca el padre en el
    /// `onDismiss` del sheet para decidir entre presentar el editor o recargar.
    func consumePendingEditFromDetail() -> SplitExpense? {
        defer { pendingEditExpense = nil }
        return pendingEditExpense
    }

    func deleteExpense(_ expense: SplitExpense) {
        do {
            try GroupExpenseService.shared.deleteExpense(expense, in: group)
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error deleting expense: \(error)")
            #endif
            // Solo los errores con copy localizado de usuario se propagan; el resto
            // (mensajes técnicos del servicio) caen al genérico.
            let message: String
            switch error {
            case GroupExpenseServiceError.expenseHasAssociatedSettlements:
                message = L10n.Groups.Bridge.deleteExpenseBlocked
            case GroupExpenseServiceError.pendingApproval:
                message = L10n.Groups.Errors.pendingApproval
            default:
                message = L10n.Groups.Errors.actionFailed
            }
            surfaceActionError(message)
        }
    }

    /// Elimina un saldo inicial (owner-only; guard targeted en el servicio).
    func removeOpeningBalance(_ expense: SplitExpense) {
        do {
            try GroupExpenseService.shared.removeOpeningBalance(expense, in: group)
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error removing opening balance: \(error)")
            #endif
            let message: String
            switch error {
            case GroupExpenseServiceError.expenseHasAssociatedSettlements:
                message = L10n.Groups.Bridge.deleteExpenseBlocked
            default:
                message = L10n.Groups.Errors.actionFailed
            }
            surfaceActionError(message)
        }
    }

    /// Name for a member ID, with fallback.
    func memberName(for memberID: String) -> String {
        memberNameLookup[memberID] ?? memberID
    }

    func confirmSettlement(_ settlement: SplitSettlement) {
        do {
            try GroupExpenseService.shared.confirmSettlement(settlement, in: group)
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
            DS.Haptic.warning()
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error rejecting settlement: \(error)")
            #endif
            surfaceActionError(L10n.Groups.Errors.actionFailed)
        }
    }

    /// Elimina una liquidación YA CONFIRMADA. Hermano deliberado de `rejectSettlement`: hoy comparten
    /// mecánica (`deleteSettlement` no tiene guard sobre `isConfirmed`), pero «rechazar» niega una
    /// pendiente y «eliminar» deshace un hecho consumado. Si mañana una notifica y la otra no, la
    /// separación ya está hecha — por eso no delega.
    ///
    /// El servicio ya limpia lo que cuelga de la liquidación: `unbridgeSettlement` borra el movimiento
    /// personal bridgeado y `enqueueDeletion` propaga la baja a los otros devices.
    func deleteConfirmedSettlement(_ settlement: SplitSettlement) {
        do {
            try GroupExpenseService.shared.deleteSettlement(settlement, in: group)
            DS.Haptic.warning()
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error deleting confirmed settlement: \(error)")
            #endif
            surfaceActionError(L10n.Groups.Settlement.deleteFailed)
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
            // Fase 3: el `else` era el CKShare y ya no existe canal que lo sirva. El guard se conserva
            // ENTERO —flag + zona backend— y su rama negativa informa: un grupo legacy no se puede invitar
            // por ninguna vía, y dejar el botón mudo sería el apagón silencioso que la re-medición marca
            // como peor modo de fallo (§S5.2).
            if CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup {
                // C4: grupo backend → invite por TOKEN RPC. El link vuelve YA branded (buildBackendInviteURL) →
                // se asigna directo. El cache in-VM
                // (`shareURL != nil`, arriba) SE CONSERVA para backend: evita mintear un token nuevo por re-tap
                // en la misma sesión de la vista (tokens múltiples son válidos igual). Nota A1: no emitir links
                // backend hasta que la base instalada tenga el parser — el flag lo cubre por construcción.
                shareURL = try await GroupBackendInviteService(
                    membership: GroupBackendMembershipService(
                        client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
                ).createInviteLink(for: group, inviterName: currentInviterName, members: activeMembers)
            } else {
                // Copy POR CAUSA (`GroupInviteLinkCreationLogic`): este `else` cubre dos bloqueos de
                // naturaleza opuesta y hasta hoy los dos decían «revisa tu conexión». Idéntico en
                // `GroupMembersView.createShareLink`, la otra superficie que acuña enlace.
                let message = switch GroupInviteLinkCreationLogic.blocker(
                    backendEnabled: CloudSyncFlags.groupsBackendEnabled,
                    isBackendGroup: group.isBackendGroup
                ) {
                case .legacyGroup: L10n.Groups.Errors.inviteLegacyGroup
                case .channelOff: L10n.Groups.Errors.inviteChannelOff
                // No alcanzable: este `else` es la negación exacta del guard que la logic evalúa.
                // El copy de red es el fallback correcto si algún día dejan de ser el mismo predicado.
                case nil: L10n.Groups.Errors.inviteFailed
                }
                surfaceActionError(message)
                isCreatingShare = false
                return
            }
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error creating share: \(error)")
            #endif
            surfaceActionError(L10n.Groups.Errors.inviteFailed)
        }
        isCreatingShare = false
    }

    /// Nombre del invitador para el link (perfil o `defaultName`). Compartido por el CKShare y el token backend.
    private var currentInviterName: String {
        let name = SessionDefaults.current.string(forKey: "userName") ?? ""
        return name.isEmpty ? L10n.Profile.defaultName : name
    }

}

// MARK: - Sheet Enum

enum GroupSheet: Identifiable {
    case settings
    case members
    case addExpense
    case expenseDetail(SplitExpense)
    case editExpense(SplitExpense)
    case openingBalanceDetail(SplitExpense)
    case editOpeningBalance(SplitExpense)
    case settlement(Debt)

    var id: String {
        switch self {
        case .settings: "settings"
        case .members: "members"
        case .addExpense: "addExpense"
        case .expenseDetail(let e): "expenseDetail-\(e.id)"
        case .editExpense(let e): "editExpense-\(e.id)"
        case .openingBalanceDetail(let e): "openingBalanceDetail-\(e.id)"
        case .editOpeningBalance(let e): "editOpeningBalance-\(e.id)"
        case .settlement(let d): "settlement-\(d.id)"
        }
    }
}
