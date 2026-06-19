//
//  GroupExpenseViewModel.swift
//  Yala
//
//  Form state, validation, and save logic for group expense create/edit.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GroupExpenseViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    let group: SplitGroup
    let members: [SplitMember]
    let memberNameLookup: [String: String]

    // MARK: - Mode

    private(set) var editingExpense: SplitExpense?
    var isEditMode: Bool { editingExpense != nil }

    // MARK: - Form State

    var amountString: String = ""
    var expenseDescription: String = ""
    /// Preservado para compat con TX históricas con nota — no expuesto en UI.
    /// El form no tiene field para editarla desde el refactor de mayo 2026; `prefill`
    /// la carga desde `expense.note` y `save` la propaga sin cambios, manteniendo
    /// notas históricas intactas al editar TX antiguas que ya las tenían.
    var note: String = ""
    var date: Date = .now
    var paidByMemberID: String = ""
    var currencyCode: String = ""
    var subcategoryName: String?
    var selectedSubcategory: Subcategory? {
        didSet { subcategoryName = selectedSubcategory?.name }
    }
    var splitType: SplitType = .equal

    /// M6: Cuenta personal real para Caso A `.full/.completed`. `nil` cuando user aún no eligió,
    /// está en modo `.groupInvite`, o no es Caso A. El form la resuelve via `AccountSelectorSheet`.
    var selectedAccount: Account?

    // Per-participant state
    var selectedMemberIDs: Set<String> = []
    var exactAmounts: [String: String] = [:]
    var percentages: [String: String] = [:]
    var sharesCounts: [String: String] = [:]
    private var selectableMemberIDs: Set<String> = []

    // MARK: - UI State

    var isSaving: Bool = false
    var saveError: String?

    /// Opt-out: ID del SplitExpense recién creado (no edit). Consumido por el form
    /// para presentar el alert in-line "¿También registrar?" cuando bridge OFF + Caso A.
    /// Reset en cada `save()`.
    var lastCreatedExpenseID: String?

    // MARK: - Computed

    var amount: Double {
        AmountInputHelper.parseDecimal(amountString)
    }

    var selectedMembers: [SplitMember] {
        members.filter { selectedMemberIDs.contains($0.id.uuidString) && selectableMemberIDs.contains($0.id.uuidString) }
    }

    var calculatedShares: [(memberID: String, amount: Double)]? {
        let participants = buildParticipants()
        guard !participants.isEmpty, amount > 0 else { return nil }
        return GroupSplitCalculator.calculate(
            total: amount,
            splitType: splitType,
            participants: participants
        )
    }

    var sharesTotal: Double {
        calculatedShares?.reduce(0.0) { $0 + $1.amount } ?? 0
    }

    var remainingToAllocate: Double {
        amount - sharesTotal
    }

    /// `true` solo cuando hay más de un participante: únicamente entonces tiene sentido
    /// configurar la división (abrir el sheet) o advertir de un desbalance. Con un solo
    /// participante el split es trivial (todo es suyo).
    var isSplitConfigurable: Bool { selectedMembers.count > 1 }

    var isSharesBalanced: Bool {
        // Con un solo participante (o ninguno) la división es trivial → nunca desbalanceada.
        // `canSave` sigue exigiendo monto válido y al menos un participante.
        if selectedMembers.count <= 1 { return true }
        guard calculatedShares != nil else { return splitType == .equal && !selectedMemberIDs.isEmpty }
        return abs(remainingToAllocate) < 0.02
    }

    var isAmountValid: Bool { amount > 0 }
    var isDescriptionValid: Bool { !expenseDescription.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasSelectedMembers: Bool { !selectedMemberIDs.isEmpty }
    var isPaidByValid: Bool { !paidByMemberID.isEmpty }

    // MARK: - M6 computed

    /// MemberID del current user en este grupo. `nil` si no está como miembro (caso edge raro).
    var currentUserMemberID: String? {
        members.first(where: { $0.isCurrentUser })?.id.uuidString
    }

    /// Form puede abrirse: current user resuelto como miembro del grupo.
    /// Gating en `GroupDetailView` para evitar form sin contexto válido.
    var isReady: Bool { currentUserMemberID != nil }

    /// `true` cuando el current user es el payer del gasto (Caso A del bridge).
    var isCaseA: Bool {
        guard let myID = currentUserMemberID else { return false }
        return paidByMemberID == myID && !paidByMemberID.isEmpty
    }

    /// User en modo `.groupInvite` no tiene cuentas reales — bridge fallback a M5 puro.
    /// Default: lee `SessionState.shared`. Tests inyectan via `isGroupInviteOverride`.
    var isGroupInviteMode: Bool {
        isGroupInviteOverride ?? (SessionState.shared.onboardingMode == .groupInvite)
    }

    /// Override solo para tests (pure-logic sin singletons). Producción: nil → lee SessionState.
    var isGroupInviteOverride: Bool?

    /// Override para tests. Producción: nil → lee resolver con context+prefs reales.
    var effectiveBridgeEnabledOverride: Bool?

    /// Modo efectivo del bridge para este grupo. `true` por default cuando el resolver
    /// no está disponible (e.g. tests sin context). Producción: delega al singleton.
    var effectiveBridgeEnabled: Bool {
        if let override = effectiveBridgeEnabledOverride { return override }
        guard let context = modelContext else { return true }
        return BridgeModeResolver.shared.isBridgeEnabled(for: group, context: context)
    }

    /// Caso A `.full/.completed` requiere cuenta personal real seleccionada solo cuando
    /// el bridge effective está ON. Si OFF, el form NO pide cuenta (alert post-save F2c
    /// ofrece opt-in para crear draft Inbox).
    var isAccountRequired: Bool {
        isCaseA && !isGroupInviteMode && effectiveBridgeEnabled
    }

    /// Cuenta seleccionada compatible con la moneda actual del gasto.
    var isAccountCompatibleWithCurrency: Bool {
        guard let account = selectedAccount else { return false }
        return account.currencyCode == currencyCode
    }

    var canSave: Bool {
        isAmountValid
            && isDescriptionValid
            && hasSelectedMembers
            && isPaidByValid
            && isSharesBalanced
            && (!isAccountRequired || isAccountCompatibleWithCurrency)
    }

    /// Llamado desde el form `onChange(of: currencyCode)`. Limpia selectedAccount si la moneda
    /// dejó de ser compatible — el user deberá re-seleccionar antes de guardar.
    func resetAccountIfIncompatible() {
        guard let account = selectedAccount, account.currencyCode != currencyCode else { return }
        selectedAccount = nil
    }

    // MARK: - Init

    init(group: SplitGroup, members: [SplitMember], memberNameLookup: [String: String]) {
        self.group = group
        self.members = members
        self.memberNameLookup = memberNameLookup

        // Defaults
        self.currencyCode = group.currencyCode
        self.splitType = SplitType(rawValue: group.defaultSplitType) ?? .equal
        self.selectableMemberIDs = Set(members.filter(\.isActive).map { $0.id.uuidString })
        self.paidByMemberID = members.first(where: { $0.isCurrentUser && $0.isActive })?.id.uuidString ?? ""
        self.selectedMemberIDs = selectableMemberIDs
    }

    func setContext(_ ctx: ModelContext) {
        self.modelContext = ctx
    }

    // MARK: - Actions

    func save() -> Bool {
        guard canSave else { return false }
        guard let shares = calculatedShares else { return false }

        isSaving = true
        saveError = nil
        lastCreatedExpenseID = nil

        do {
            // M6: pasar selectedAccount solo si Caso A (en Caso B, la cuenta del user no aplica).
            let accountToPass: Account? = isCaseA ? selectedAccount : nil
            if let existing = editingExpense {
                try GroupExpenseService.shared.updateExpense(
                    existing,
                    in: group,
                    amount: amount,
                    currencyCode: currencyCode,
                    description: expenseDescription.trimmingCharacters(in: .whitespaces),
                    note: note.isEmpty ? nil : note,
                    date: date,
                    paidByMemberID: paidByMemberID,
                    splitType: splitType.rawValue,
                    subcategoryName: subcategoryName,
                    shares: shares,
                    accountForCurrentUser: accountToPass
                )
            } else {
                let created = try GroupExpenseService.shared.createExpense(
                    in: group,
                    amount: amount,
                    currencyCode: currencyCode,
                    description: expenseDescription.trimmingCharacters(in: .whitespaces),
                    note: note.isEmpty ? nil : note,
                    date: date,
                    paidByMemberID: paidByMemberID,
                    splitType: splitType.rawValue,
                    subcategoryName: subcategoryName,
                    shares: shares,
                    accountForCurrentUser: accountToPass
                )
                lastCreatedExpenseID = created.id.uuidString
            }
            isSaving = false
            return true
        } catch {
            #if DEBUG
            print("GroupExpenseViewModel: Error saving: \(error)")
            #endif
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func prefill(from expense: SplitExpense, shares: [SplitShare]) {
        editingExpense = expense
        amountString = AmountInputHelper.formatWithGrouping(expense.amount)
        expenseDescription = expense.expenseDescription
        note = expense.note ?? ""
        date = expense.date
        paidByMemberID = expense.paidByMemberID
        currencyCode = expense.currencyCode
        subcategoryName = expense.subcategoryName
        resolveSubcategory()
        splitType = SplitType(rawValue: expense.splitType) ?? .equal

        selectedMemberIDs = Set(shares.map(\.memberID))
        selectableMemberIDs.formUnion(selectedMemberIDs)
        selectableMemberIDs.insert(expense.paidByMemberID)

        // `SplitShare` solo persiste el monto, no el conteo original de partes. Para `.shares`
        // reconstruimos enteros relativos desde los montos (ratio sobre la parte unitaria): los
        // montos ya son proporcionales al conteo, así que el ratio se preserva y el split
        // recalculado es idéntico. Evita el reset silencioso a 1:1 que rebalanceaba las deudas.
        let sharesCountStrings: [String: String] = splitType == .shares
            ? Self.deriveShareCounts(from: shares)
            : [:]

        // Populate per-type fields from existing shares
        for share in shares {
            let id = share.memberID
            switch splitType {
            case .exact:
                exactAmounts[id] = AmountInputHelper.formatWithGrouping(share.amount)
            case .percentage:
                let pct = expense.amount > 0 ? (share.amount / expense.amount) * 100 : 0
                percentages[id] = String(format: "%.1f", pct)
            case .shares:
                sharesCounts[id] = sharesCountStrings[id] ?? "1"
            case .equal:
                break
            }
        }

        // M6: si edit Caso A `.full/.completed`, recupera la cuenta personal real bridgeada.
        // Si TX aún no llegó vía sync personal (race), `selectedAccount` queda nil y form
        // pide selección antes de guardar (canSave bloquea).
        resolveSelectedAccountForCaseA(expense: expense)
    }

    /// Fetch TX cuenta real existente (`splitExpenseID == X && account.isSystemAccount == false`)
    /// y popula `selectedAccount`. Solo aplica si Caso A `.full/.completed`.
    private func resolveSelectedAccountForCaseA(expense: SplitExpense) {
        guard isCaseA, !isGroupInviteMode, let ctx = modelContext else { return }
        let expenseIDStr = expense.id.uuidString
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { tx in
                tx.splitExpenseID == expenseIDStr
                    && tx.account?.isSystemAccount == false
            }
        )
        do {
            if let realTx = try ctx.fetch(descriptor).first, let account = realTx.account {
                selectedAccount = account
            }
        } catch {
            #if DEBUG
            print("GroupExpenseViewModel: error resolving selectedAccount for case A: \(error)")
            #endif
        }
    }

    // MARK: - Member Selection

    func selectAllMembers() {
        selectedMemberIDs = selectableMemberIDs
    }

    func deselectAllMembers() {
        selectedMemberIDs.removeAll()
    }

    func toggleMember(_ memberID: String) {
        guard selectableMemberIDs.contains(memberID) else { return }
        if selectedMemberIDs.contains(memberID) {
            selectedMemberIDs.remove(memberID)
        } else {
            selectedMemberIDs.insert(memberID)
        }
    }

    // MARK: - Private

    /// Reconstruye conteos enteros de partes a partir de los montos persistidos en `SplitShare`
    /// (que no guarda el conteo original). Como en un split por partes el monto es proporcional
    /// al conteo (`amount = total · partes / totalPartes`), el ratio entre montos recupera los
    /// conteos: se divide cada monto por el menor monto positivo (la "parte unitaria") y se
    /// redondea, tolerando el remainder de redondeo que `adjustLastForRounding` reparte en ±1
    /// céntimo (p. ej. 33.33/33.33/33.34 → 1/1/1; 75/25 → 3/1). Si los montos no son
    /// proporcionales o son cero, cae a "1" — nunca peor que el estado previo.
    static func deriveShareCounts(from shares: [SplitShare]) -> [String: String] {
        guard !shares.isEmpty else { return [:] }

        // Montos → céntimos enteros (preserva el ratio, evita ruido de punto flotante).
        let cents: [(id: String, value: Int)] = shares.map {
            let amount = $0.amount.isFinite ? max(0, $0.amount) : 0
            return (id: $0.memberID, value: Int((amount * 100).rounded()))
        }

        // La parte unitaria es el menor monto positivo; dividir por ella y redondear recupera
        // los conteos pequeños tolerando el ±1 céntimo de redondeo del reparto.
        guard let base = cents.map(\.value).filter({ $0 > 0 }).min(), base > 0 else {
            return Dictionary(cents.map { ($0.id, "1") }, uniquingKeysWith: { first, _ in first })
        }

        let pairs = cents.map { entry -> (String, String) in
            let count = entry.value <= 0 ? 1 : max(1, Int((Double(entry.value) / Double(base)).rounded()))
            return (entry.id, String(count))
        }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    /// Resuelve subcategoryName (String) → Subcategory object via fetch
    private func resolveSubcategory() {
        guard let name = subcategoryName, let ctx = modelContext else { return }
        do {
            var descriptor = FetchDescriptor<Subcategory>(
                predicate: #Predicate { $0.name == name }
            )
            descriptor.fetchLimit = 1
            selectedSubcategory = try ctx.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("GroupExpenseViewModel: Error resolving subcategory '\(name)': \(error)")
            #endif
        }
    }

    private func buildParticipants() -> [GroupSplitCalculator.Participant] {
        let selected = members.filter { selectedMemberIDs.contains($0.id.uuidString) && selectableMemberIDs.contains($0.id.uuidString) }
        return selected.map { member in
            let id = member.id.uuidString
            let value: Double = switch splitType {
            case .equal:
                1.0
            case .exact:
                AmountInputHelper.parseDecimal(exactAmounts[id] ?? "0")
            case .percentage:
                Double(percentages[id] ?? "0") ?? 0
            case .shares:
                Double(sharesCounts[id] ?? "1") ?? 1
            }
            return GroupSplitCalculator.Participant(memberID: id, value: value)
        }
    }

    /// Mapa `[memberID: rawValue]` con los valores brutos del usuario por miembro,
    /// según el `splitType` activo. Consumido por `GroupSplitChipFormatter` para
    /// renderizar suffixes de porcentaje y proporciones en el chip-detalle.
    /// - `.equal`: no aplica (todos 1.0).
    /// - `.exact`: monto exacto parseado.
    /// - `.percentage`: 0-100.
    /// - `.shares`: count entero (default 1 si vacío).
    var participantValuesByID: [String: Double] {
        Dictionary(
            buildParticipants().map { ($0.memberID, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
