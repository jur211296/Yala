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

    /// Todos los miembros activos del grupo — la lista que muestra el sheet de división
    /// (estilo Splitwise: todos aparecen; en `.equal` con check, en los demás con campo).
    var activeSheetMembers: [SplitMember] {
        members.filter { selectableMemberIDs.contains($0.id.uuidString) }
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

    /// Monto efectivo por miembro ACTIVO según los valores actuales — SIEMPRE disponible,
    /// aunque la división no cuadre (a diferencia de `calculatedShares`, que es `nil` si no
    /// balancea). Los no-participantes (sin valor / sin check) quedan en 0. Lo consume el
    /// sheet para mostrar el monto debajo de cada nombre en todo momento.
    var effectiveAmountsByID: [String: Double] {
        let participants = selectedMembers.map { member in
            (id: member.id.uuidString, rawValue: participantRawValue(member.id.uuidString, type: splitType))
        }
        let effective = GroupSplitConversion.effectiveAmounts(splitType: splitType, total: amount, participants: participants)
        var map = Dictionary(effective.map { ($0.id, $0.amount) }, uniquingKeysWith: { first, _ in first })
        for id in selectableMemberIDs where map[id] == nil { map[id] = 0 }
        return map
    }

    /// Valores brutos (string) del tipo de división activo, por memberID.
    private var currentRawValues: [String: String] {
        switch splitType {
        case .exact: return exactAmounts
        case .percentage: return percentages
        case .shares: return sharesCounts
        case .equal: return [:]
        }
    }

    /// Monto ya asignado por los valores INGRESADOS (los vacíos no cuentan). Base del
    /// "Restante" incremental — baja en tiempo real con cada dato. `.equal`/`.shares`
    /// reparten siempre todo el total → asignado = total (no hay restante).
    var assignedToAllocate: Double {
        let entered: [Double] = selectedMembers.compactMap { member in
            let raw = (currentRawValues[member.id.uuidString] ?? "").trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return nil }
            return AmountInputHelper.parseDecimal(raw)
        }
        return GroupSplitConversion.assignedAmount(splitType: splitType, total: amount, enteredValues: entered)
    }

    /// Restante por asignar (incremental). > 0 = falta; < 0 = se pasó del total.
    var remainingToAllocate: Double {
        amount - assignedToAllocate
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

    // MARK: - Two-person quick split

    /// Grupo de exactamente 2 miembros activos → habilita la pre-pantalla de 4 opciones
    /// en lenguaje natural (estilo Splitwise) en lugar de los chips "Pagado por · Dividido".
    var isTwoPersonGroup: Bool { selectableMemberIDs.count == 2 }

    /// El otro miembro activo (no el current user). `nil` si no resuelve → el form cae al
    /// flujo de 2-chips estándar.
    var otherActiveMemberID: String? {
        guard let myID = currentUserMemberID else { return nil }
        return activeSheetMembers.first(where: { $0.id.uuidString != myID })?.id.uuidString
    }

    /// Nombre de la otra persona del grupo de 2 (para los textos de las opciones rápidas).
    var otherActiveMemberName: String {
        guard let otherID = otherActiveMemberID else { return "" }
        return memberNameLookup[otherID] ?? ""
    }

    /// Qué opción rápida representa el estado actual del split, o `nil` si es "personalizado"
    /// (el usuario configuró %/exacto/partes en "Más opciones"). En grupos de 3+ siempre `nil`.
    var activeTwoPersonChoice: TwoPersonSplitOptions.Choice? {
        guard isTwoPersonGroup, let myID = currentUserMemberID, let otherID = otherActiveMemberID else { return nil }
        return TwoPersonSplitOptions.detect(
            paidByMemberID: paidByMemberID,
            splitType: splitType,
            selectedMemberIDs: selectedMemberIDs,
            currentMemberID: myID,
            otherMemberID: otherID
        )
    }

    /// Aplica una opción rápida: fija pagador, tipo `.equal` y participantes. Las opciones
    /// "es todo de X" dejan al pagador fuera de `selectedMemberIDs` (la otra persona debe el total).
    func applyTwoPersonChoice(_ choice: TwoPersonSplitOptions.Choice) {
        guard let myID = currentUserMemberID, let otherID = otherActiveMemberID else { return }
        let resolution = TwoPersonSplitOptions.resolution(for: choice, currentMemberID: myID, otherMemberID: otherID)
        paidByMemberID = resolution.paidBy
        splitType = resolution.splitType
        selectedMemberIDs = resolution.participants
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

    /// Prellena el form para CREAR un gasto desde una plantilla (no edición). Usado al aprobar
    /// un pago planificado de grupo. El pagador permanece = current user (Caso A, fijado en init).
    /// Reconciliación stale: solo se incluyen participantes que siguen siendo miembros activos.
    func applyTemplate(_ template: GroupExpensePrefillTemplate) {
        amountString = AmountInputHelper.formatWithGrouping(template.totalAmount)
        currencyCode = template.currencyCode
        expenseDescription = template.description
        splitType = template.splitType

        let activeIDs = Set(activeSheetMembers.map { $0.id.uuidString })
        selectedMemberIDs = Set(template.participantIDs.map { $0.uuidString }).intersection(activeIDs)

        exactAmounts = [:]; percentages = [:]; sharesCounts = [:]
        for (uuid, value) in template.values {
            let id = uuid.uuidString
            guard activeIDs.contains(id) else { continue }
            switch template.splitType {
            case .exact: exactAmounts[id] = AmountInputHelper.formatWithGrouping(value)
            case .percentage: percentages[id] = String(format: "%.1f", value)
            case .shares: sharesCounts[id] = String(Int(value.rounded()))
            case .equal: break
            }
        }

        if let account = template.accountPrefill {
            selectedAccount = account
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

    /// Inclusión implícita en modos ≠ `.equal`: el sheet llama esto desde el `onChange`
    /// del campo de cada miembro — llenar (no vacío) lo incluye, vaciar lo excluye.
    /// Sin esto, escribir en un miembro no seleccionado se ignoraría en el cálculo.
    func setParticipation(_ memberID: String, included: Bool) {
        guard selectableMemberIDs.contains(memberID) else { return }
        if included {
            selectedMemberIDs.insert(memberID)
        } else {
            selectedMemberIDs.remove(memberID)
        }
    }

    // MARK: - Split Type Conversion / Cleanup

    /// Convierte el ajuste del tipo SALIENTE al ENTRANTE preservando los montos efectivos:
    /// 60/40 % → 60/40 monto → 3/2 partes. Si no hay base (sin monto o sin participantes)
    /// limpia el dict entrante. Llamado al cambiar de tipo (post-prefill).
    func convertSplitValues(from oldType: SplitType, to newType: SplitType) {
        guard oldType != newType else { return }
        guard amount > 0, !selectedMembers.isEmpty else {
            clearValues(for: newType)
            return
        }
        let participants: [(id: String, rawValue: Double)] = selectedMembers.map { member in
            (id: member.id.uuidString, rawValue: participantRawValue(member.id.uuidString, type: oldType))
        }
        let amounts = GroupSplitConversion.effectiveAmounts(splitType: oldType, total: amount, participants: participants)
        switch newType {
        case .exact:
            distributeExact(amounts)
        case .percentage:
            distributePercentage(amounts)
        case .shares:
            for entry in GroupSplitConversion.deriveCounts(amounts: amounts) {
                sharesCounts[entry.id] = String(entry.count)
            }
        case .equal:
            break
        }
    }

    /// Reparte montos exactos (2 decimales) y asigna el remanente de redondeo al pagador
    /// (o al primer participante) para que sumen EXACTO el total — al venir de Iguales,
    /// 300/3 da 100/100/100; 100/3 da 33.34/33.33/33.33 en vez de 33.33×3 = 99.99.
    private func distributeExact(_ amounts: [(id: String, amount: Double)]) {
        var byID: [String: Double] = [:]
        for entry in amounts { byID[entry.id] = (max(0, entry.amount) * 100).rounded() / 100 }
        let sum = byID.values.reduce(0, +)
        let diff = ((amount - sum) * 100).rounded() / 100
        if abs(diff) >= 0.01, let target = remainderTargetID(among: amounts.map(\.id)) {
            byID[target, default: 0] += diff
        }
        for (id, value) in byID { exactAmounts[id] = AmountInputHelper.formatWithGrouping(value) }
    }

    /// Igual que `distributeExact` pero en porcentajes (1 decimal) que deben sumar 100 —
    /// 300 entre 3 iguales da 33.4/33.3/33.3 (el pagador recibe el remanente), no 33.3×3.
    private func distributePercentage(_ amounts: [(id: String, amount: Double)]) {
        guard amount > 0 else { return }
        var byID: [String: Double] = [:]
        for entry in amounts { byID[entry.id] = ((entry.amount / amount * 100) * 10).rounded() / 10 }
        let sum = byID.values.reduce(0, +)
        let diff = ((100 - sum) * 10).rounded() / 10
        if abs(diff) >= 0.05, let target = remainderTargetID(among: amounts.map(\.id)) {
            byID[target, default: 0] += diff
        }
        for (id, pct) in byID { percentages[id] = String(format: "%.1f", pct) }
    }

    /// Miembro que recibe el remanente de redondeo: el pagador si participa, si no el primero.
    private func remainderTargetID(among ids: [String]) -> String? {
        ids.contains(paidByMemberID) ? paidByMemberID : ids.first
    }

    private func clearValues(for type: SplitType) {
        switch type {
        case .exact: exactAmounts.removeAll()
        case .percentage: percentages.removeAll()
        case .shares: sharesCounts.removeAll()
        case .equal: break
        }
    }

    /// Deselecciona del pago a los miembros sin valor ingresado en el tipo activo (≠ `.equal`).
    /// Llamado al cerrar el sheet de división: quien no recibió monto/porcentaje/partes no participa.
    func purgeEmptyParticipants() {
        guard splitType != .equal else { return }
        let dict = currentRawValues
        for member in selectedMembers {
            let id = member.id.uuidString
            if (dict[id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                selectedMemberIDs.remove(id)
            }
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
        selectedMembers.map { member in
            let id = member.id.uuidString
            return GroupSplitCalculator.Participant(memberID: id, value: participantRawValue(id, type: splitType))
        }
    }

    /// Valor numérico de un miembro en el tipo dado, con parseo/default UNIFICADOS para
    /// todos los consumidores (cálculo del split, conversión y restante). `.exact`/`.percentage`
    /// usan `parseDecimal` para respetar el separador decimal de la locale — el field inserta
    /// "," en es-ES/fr/de/it (`AmountInputHelper.filterAmountInput`), donde `Double(_:)` daría 0.
    private func participantRawValue(_ memberID: String, type: SplitType) -> Double {
        switch type {
        case .equal: return 1
        case .exact: return AmountInputHelper.parseDecimal(exactAmounts[memberID] ?? "")
        case .percentage: return AmountInputHelper.parseDecimal(percentages[memberID] ?? "")
        case .shares:
            let raw = sharesCounts[memberID] ?? ""
            return raw.isEmpty ? 1 : AmountInputHelper.parseDecimal(raw)
        }
    }

}
