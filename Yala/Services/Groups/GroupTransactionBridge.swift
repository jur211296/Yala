//
//  GroupTransactionBridge.swift
//  Yala
//
//  Bridge between shared expenses and personal TransactionItem/InboxDraft.
//  Creates/updates/removes personal records when group expenses change.
//

import Foundation
import OSLog
import SwiftData

@MainActor
@Observable
final class GroupTransactionBridge {

    // MARK: - Singleton

    static let shared = GroupTransactionBridge()

    // MARK: - Properties

    private var modelContext: ModelContext?
    private static let logger = Logger(subsystem: "com.yala", category: "GroupBridge")

    /// Whether the bridge has been initialized with a context.
    var isReady: Bool { modelContext != nil }

    /// M6: Flag interno para que `withSkippedDraftCleanup` permita que
    /// `DraftService.approveGroupExpenseAccountDraft` invoque `bridgeExpense` sin que el
    /// bridge borre el draft activo. NO setear directamente — usar el closure helper.
    private(set) var skipDraftCleanup: Bool = false

    /// Ejecuta `body` con `skipDraftCleanup=true` y resetea garantizado vía `defer`,
    /// incluso si `body` lanza. Único path autorizado para mutar el flag.
    func withSkippedDraftCleanup<T>(_ body: () throws -> T) rethrows -> T {
        skipDraftCleanup = true
        defer { skipDraftCleanup = false }
        return try body()
    }

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private func requireContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw GroupTransactionBridgeError.noContext
        }
        return context
    }

    // MARK: - Bridge Operations

    /// M6: Bridge SplitExpense ↔ TransactionItem con preserve+update Caso A.
    ///
    /// **Caso A** (yo pago, modo `.full/.completed`):
    /// - **TX cuenta REAL** (`-totalAmount` con subcat manual): refleja "salió de mi bolsillo"
    ///   en mi cuenta personal. Si ya existe Y currency compatible → **preserve+update** (solo
    ///   monto/fecha/splitTotalAmount/splitType; cuenta/subcat/note/tags/category INTACTOS).
    ///   Si currency incompatible → delete + draft con hint "currencyChanged".
    /// - **TX virtual lent** (`+lentAmount` sistema "Préstamo a grupos"): siempre derivada,
    ///   delete+recreate. Skip si `lentAmount == 0` (yo solo en split).
    ///
    /// **Caso A modo `.groupInvite`** (sin cuentas reales): fallback a M5 puro — TX1 virtual
    /// `-myShare` con subcat manual + TX2 virtual `+totalAmount` sistema. Sin TX cuenta real.
    ///
    /// **Caso B** (paga otro): TX1 virtual `-myShare` con subcat manual o nil. Sin cambios M5.
    ///
    /// **Auto-match subcat**: si falla Y Caso B (o A groupInvite): draft con TX-puntero. En
    /// Caso A `.full/.completed` la TX cuenta real se crea con subcat=nil + draft con puntero
    /// (path heredado M5 para subcat assignment via Inbox).
    ///
    /// **Idempotency Caso A `.full/.completed`**: TX cuenta real preservada cross-reinvocación.
    /// **Idempotency demás**: delete+recreate normal (todas las TX son derivadas).
    ///
    /// **Race race con DraftService.approve**: si `skipDraftCleanup == true`, el cleanup de
    /// `existingPendingDrafts` se omite (DraftService gestiona el draft activo).
    ///
    /// - Parameters:
    ///   - expense: The shared expense to bridge.
    ///   - group: The group containing the expense.
    ///   - accountForCurrentUser: Cuenta real para Caso A `.full/.completed` (form/draft input).
    ///     `nil` cuando el bridge se invoca por sync remoto o cuando user no proveyó (groupInvite, draft pending).
    ///   - isRemoteSync: `true` cuando se invoca desde `bridgeRemoteExpenses` (sync de grupos).
    ///     Distingue path local vs sync para guard defensivo.
    ///   - shouldSave: Whether to save the context (false when called from sync batch).
    func bridgeExpense(
        _ expense: SplitExpense,
        in group: SplitGroup,
        accountForCurrentUser: Account? = nil,
        isRemoteSync: Bool = false,
        isBulkImport: Bool = false,
        shouldSave: Bool = true
    ) throws {
        let context = try requireContext()

        // Defensa-en-profundidad: si el grupo está hidden (soft-deleted), no bridgear
        // expenses — el cleanup observer ya corrió o correrá. Previene bridging en el
        // device del invitado fresh-install que recibe el SplitGroup ya hidden vía sync.
        guard Self.shouldBridgeExpense(groupIsHidden: group.isHiddenForAll) else {
            #if DEBUG
            Self.logger.info("bridgeExpense: skip hidden group \(group.cloudKitZoneID, privacy: .public)")
            #endif
            return
        }

        // Find current user's member in this group.
        // pending/rejected members no triguean bridge.
        let zoneID = group.cloudKitZoneID
        let memberDescriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true }
        )
        guard let currentMember = try context.fetch(memberDescriptor).first,
              currentMember.isActive else { return }
        let currentMemberID = currentMember.id.uuidString

        // Saldo inicial (deuda de apertura): bridge virtual-only, independiente del modo
        // del bridge / `.groupInvite` / toggle ON-OFF. Va ANTES del `guard let myShare`
        // porque el acreedor (es `paidByMemberID` pero NO tiene share propio) también debe
        // reflejar su +Z en la cuenta virtual.
        if expense.isOpeningBalance {
            try bridgeOpeningBalance(expense, in: group, currentMemberID: currentMemberID, context: context)
            try saveIfNeeded(shouldSave: shouldSave, context: context)
            return
        }

        // Find current user's share in this expense.
        let expenseID = expense.id
        let shareDescriptor = FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.expenseID == expenseID && $0.memberID == currentMemberID }
        )
        guard let myShare = try context.fetch(shareDescriptor).first else { return }

        // Identidad y cantidades.
        let expenseIDStr = expense.id.uuidString
        let isCaseA = expense.paidByMemberID == currentMemberID
        let isGroupInvite = SessionState.shared.onboardingMode == .groupInvite
        let totalAmount = expense.amount
        let mySharedAmount = myShare.amount
        let lentAmount = totalAmount - mySharedAmount

        // Resolver decide si crear TX real para Caso A `.full/.completed`. Cuando OFF,
        // redirige al path "virtual-only" idéntico al Caso B. Caso B y `.groupInvite`
        // siempre virtual (no afectados por el modo del bridge).
        let effectiveBridgeEnabled = BridgeModeResolver.shared.isBridgeEnabled(
            for: group, context: context
        )

        // Fetch existing entities.
        let allExistingTxs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        ))
        let existingVirtualTxs = allExistingTxs.filter { $0.account?.isSystemAccount == true }
        var existingRealTx = allExistingTxs.first { $0.account?.isSystemAccount == false }

        let existingPendingDrafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        ))

        // Un draft opt-in pendiente con sheet combinado ya pide la subcategoría de este
        // gasto. Los paths virtual-only NO deben (re)crear el puntero [.subcategory] en
        // ese caso — el cleanup de abajo preserva el opt-in, y recrear el puntero en cada
        // re-bridge duplicaba el draft en el Inbox (B6-26 parte 2). Computado pre-cleanup:
        // los opt-in nunca se borran ahí.
        let optInCoversSubcategory = existingPendingDrafts.contains {
            $0.optInPersonalOnly && $0.needsUserInput.contains(DraftInputRequirement.subcategory)
        }

        // Cleanup: TX virtuales son derivadas, siempre delete+recreate.
        for tx in existingVirtualTxs { context.delete(tx) }
        // Drafts pendientes: cleanup salvo si DraftService los está procesando (race).
        // Opt-in drafts (`optInPersonalOnly==true`) NUNCA se borran aquí — representan
        // intent del user pendiente de aprobación que sobrevive cualquier re-bridge.
        if !skipDraftCleanup {
            for draft in existingPendingDrafts where !draft.optInPersonalOnly {
                context.delete(draft)
            }
        }

        // Resolve cuenta virtual + subcat.
        let virtualAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
            currencyCode: expense.currencyCode,
            colorHint: group.colorHex,
            context: context
        )
        let matchedSubcat = GroupTransactionBridge.matchSubcategory(name: expense.subcategoryName, context: context)
        let realSubcat: Subcategory? = (matchedSubcat?.isAnySystem == true) ? nil : matchedSubcat

        // Path Caso B (otro pagó): virtual-only. Con bridge ON la TX real residual se borra
        // (solo tiene sentido en Caso A). Con bridge OFF se preserva — pudo ser opt-in
        // user-driven cuando aún era payer (Caso A); un cambio de payer no debería destruir
        // el intent. Si el real sobrevive, el virtual se reconcilia a +lent (no -myShare)
        // para no duplicar (B6-25). `bridgeVirtualOnly` centraliza la regla.
        if !isCaseA {
            // DIAG (caso "registro de grupo desaparece al clasificar"): timeline del
            // delete+recreate de la TX virtual. Sin PII (solo id + counts). Quitar tras QA.
            Self.logger.info("caseB start expense=\(expenseIDStr, privacy: .public) existingVirtual=\(existingVirtualTxs.count, privacy: .public) existingDrafts=\(existingPendingDrafts.count, privacy: .public) matchedSubcat=\(realSubcat != nil, privacy: .public) remote=\(isRemoteSync, privacy: .public)")
            try bridgeVirtualOnly(
                expense: expense,
                existingRealTx: existingRealTx,
                deleteStaleReal: effectiveBridgeEnabled,
                myShareAmount: mySharedAmount,
                lentAmount: lentAmount,
                totalAmount: totalAmount,
                realSubcat: realSubcat,
                optInCoversSubcategory: optInCoversSubcategory,
                virtualAccount: virtualAccount,
                context: context
            )
            try saveIfNeeded(shouldSave: shouldSave, context: context)
            Self.logger.info("caseB saved expense=\(expenseIDStr, privacy: .public) shouldSave=\(shouldSave, privacy: .public)")
            return
        }

        // Path Caso A modo .groupInvite: fallback M5 puro (TX1 virtual -myShare + TX2 virtual +totalAmount).
        if isGroupInvite {
            if let stale = existingRealTx { context.delete(stale) }
            createGroupInviteCaseAVirtualPair(
                expense: expense,
                myShareAmount: mySharedAmount,
                lentAmount: lentAmount,
                totalAmount: totalAmount,
                realSubcat: realSubcat,
                optInCoversSubcategory: optInCoversSubcategory,
                virtualAccount: virtualAccount,
                context: context
            )
            try saveIfNeeded(shouldSave: shouldSave, context: context)
            return
        }

        // Path Caso A bridge effective OFF: virtual-only. Sin opt-in (no hay TX real) el
        // virtual es -myShare = mi costo directo. Si el user aprobó el opt-in (TX real
        // -total existe) el virtual pasa a +lent para NO duplicar (B6-25): net = -myShare,
        // idéntico a bridge-ON Caso A. La TX real se PRESERVA — su cleanup destructivo es
        // responsabilidad de `BridgeDeactivationSheet` (freeze vs delete), no del bridge
        // automático — pero sí se preserve+update (monto/fecha) dentro de `bridgeVirtualOnly`.
        if !effectiveBridgeEnabled {
            try bridgeVirtualOnly(
                expense: expense,
                existingRealTx: existingRealTx,
                deleteStaleReal: false,
                myShareAmount: mySharedAmount,
                lentAmount: lentAmount,
                totalAmount: totalAmount,
                realSubcat: realSubcat,
                optInCoversSubcategory: optInCoversSubcategory,
                virtualAccount: virtualAccount,
                context: context
            )
            try saveIfNeeded(shouldSave: shouldSave, context: context)
            return
        }

        // Path Caso A modo .full/.completed: gestionar TX cuenta real con preserve+update.
        if let realTx = existingRealTx {
            if realTx.currencyCode == expense.currencyCode {
                // PRESERVE+UPDATE: actualizar SOLO campos del grupo.
                realTx.amount = -totalAmount
                realTx.date = expense.date
                realTx.splitTotalAmount = totalAmount
                realTx.splitType = expense.splitType
                // NUNCA pisar account/note/tags/currencyCode ni una subcat ya puesta.
                // Excepción: rellenar subcat+category SOLO si la TX nunca tuvo (creada sin
                // clasificar) y el gasto ahora resuelve una — refleja el chip elegido al
                // editar el gasto, sin sobrescribir una clasificación manual del usuario.
                if GroupDraftFinalizationLogic.shouldFillPreservedSubcategory(
                    currentSubcatIsNil: realTx.subcategory == nil,
                    resolvedSubcatAvailable: realSubcat != nil
                ), let realSubcat {
                    realTx.subcategory = realSubcat
                    realTx.category = realSubcat.safeCategory
                }
                // Recalcular conversión a moneda preferida: amount/date cambiaron.
                realTx.recalculatePreferredCurrency(context: context)
            } else {
                // INCOMPATIBLE currency: delete TX real + draft hint impersonal.
                context.delete(realTx)
                existingRealTx = nil
                createDraftCaseA(
                    expense: expense,
                    reason: .currencyChanged,
                    actorName: nil,  // sync remoto no expone "modifiedBy" → impersonal.
                    groupName: group.name,
                    needsSubcategory: realSubcat == nil,
                    context: context
                )
            }
        } else if let providedAccount = accountForCurrentUser,
                  providedAccount.currencyCode == expense.currencyCode {
            // PRIMERA VEZ con cuenta proveída (form local crea, o DraftService.approve).
            let realTx = TransactionItem(
                date: expense.date,
                amount: -totalAmount,
                currencyCode: expense.currencyCode,
                note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
                category: realSubcat?.safeCategory,
                subcategory: realSubcat,
                account: providedAccount
            )
            realTx.splitExpenseID = expenseIDStr
            realTx.splitGroupZoneID = expense.groupZoneID
            realTx.splitTotalAmount = totalAmount
            realTx.splitType = expense.splitType
            context.insert(realTx)
            realTx.recalculatePreferredCurrency(context: context)
            // Enfoque B: exponer la TX real recién creada al bloque fallback de abajo
            // (si su subcat quedó nil, ofrecerá clasificarla vía draft [.subcategory]).
            existingRealTx = realTx
        } else if isRemoteSync {
            // Sync remoto sin cuenta local: draft pendiente con hint contextual.
            let payerName = resolveMemberDisplayName(memberID: expense.paidByMemberID, in: group, context: context)
            createDraftCaseA(
                expense: expense,
                reason: .remoteCreate,
                actorName: payerName,
                groupName: group.name,
                needsSubcategory: realSubcat == nil,
                context: context
            )
        } else {
            // Path local sin cuenta: F4.canSave debió bloquear el form salvo bulk import.
            // `isBulkImport=true` viene del `BridgeActivationSheet` "Importar todo el
            // historial" donde el user intencionalmente itera expenses históricos sin
            // cuenta — el resultado es draft pendiente esperando finalización por user.
            #if DEBUG
            if !isBulkImport {
                assertionFailure("Caso A local sin cuenta — F4 canSave debió bloquear el form")
            }
            #endif
            createDraftCaseA(
                expense: expense,
                reason: .remoteCreate,
                actorName: nil,
                groupName: group.name,
                needsSubcategory: realSubcat == nil,
                context: context
            )
        }

        // TX virtual lent (+lentAmount) — siempre regenerada en Caso A `.full/.completed`.
        // `createVirtualLent` es no-op si lent <= 0 (yo solo en el split).
        try createVirtualLent(
            expense: expense,
            lentAmount: lentAmount,
            totalAmount: totalAmount,
            virtualAccount: virtualAccount,
            context: context
        )

        // Enfoque B: si la TX real quedó sin subcategoría y el auto-match falla, (re)crear draft
        // [.subcategory] (TX-puntero, mismo mecanismo que Caso B) para clasificar desde el Inbox.
        // Aplica a preserve+update y first-create — las únicas sub-ramas de este path (.full/
        // .completed bridge-ON) que dejan una TX real con subcat=nil; las que crean draft
        // [.account(+subcategory)] ya cubren el ask vía createDraftCaseA. Skip durante
        // DraftService.approve (skipDraftCleanup): ahí el user ya asignó subcat. El cleanup de
        // drafts pendientes (arriba) ya corrió → no duplica; el re-bridge lo recrea (igual que
        // Caso B recrea su draft cada pasada).
        if GroupDraftFinalizationLogic.shouldOfferCaseASubcategoryFallback(
            skipDraftCleanup: skipDraftCleanup,
            hasRealTx: existingRealTx != nil,
            realTxSubcategoryIsNil: existingRealTx?.subcategory == nil,
            autoMatchFailed: realSubcat == nil
        ) {
            createCaseASubcategoryDraft(expense: expense, account: existingRealTx?.account, context: context)
        }

        try saveIfNeeded(shouldSave: shouldSave, context: context)
    }

    // MARK: - Helpers (M6)

    /// Path "virtual-only" (Caso B y Caso A bridge-OFF): el bridge NO crea TX real
    /// automáticamente, pero reconcilia el virtual con cualquier TX real coexistente
    /// (opt-in user-driven aprobado, o legacy de cuando el bridge estaba ON):
    ///   - Hay TX real `-total` que sobrevive → virtual `+lent` (compensa; net = -myShare).
    ///     Idéntico a bridge-ON Caso A. Si `lent == 0` → sin virtual (el real ya es mi costo).
    ///   - NO hay TX real → virtual `-myShare` (mi costo directo).
    /// Resuelve el doble conteo B6-25 (virtual `-myShare` + real `-total`, mismo signo).
    /// - Parameter deleteStaleReal: `true` solo en Caso B bridge-ON (la TX real solo tiene
    ///   sentido cuando yo soy payer; un cambio de payer con bridge ON la vuelve obsoleta).
    private func bridgeVirtualOnly(
        expense: SplitExpense,
        existingRealTx: TransactionItem?,
        deleteStaleReal: Bool,
        myShareAmount: Double,
        lentAmount: Double,
        totalAmount: Double,
        realSubcat: Subcategory?,
        optInCoversSubcategory: Bool,
        virtualAccount: Account,
        context: ModelContext
    ) throws {
        var realTx = existingRealTx
        if deleteStaleReal, let stale = realTx {
            context.delete(stale)
            realTx = nil
        }

        // Preserve+update del real superviviente: SOLO monto/fecha/grupo (jamás cuenta/
        // note/tags ni una subcat ya puesta). Gateado por currency compatible para no
        // corromper data del user.
        if let realTx, realTx.currencyCode == expense.currencyCode {
            realTx.amount = -totalAmount
            realTx.date = expense.date
            realTx.splitTotalAmount = totalAmount
            realTx.splitType = expense.splitType
            // Excepción (igual que bridgeExpense): rellenar subcat+category solo si la TX
            // nunca tuvo una y el gasto ahora resuelve una.
            if GroupDraftFinalizationLogic.shouldFillPreservedSubcategory(
                currentSubcatIsNil: realTx.subcategory == nil,
                resolvedSubcatAvailable: realSubcat != nil
            ), let realSubcat {
                realTx.subcategory = realSubcat
                realTx.category = realSubcat.safeCategory
            }
            realTx.recalculatePreferredCurrency(context: context)
        }

        switch BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: realTx != nil,
            lentAmount: lentAmount
        ) {
        case .myShareCost:
            createCaseBVirtualMyShare(
                expense: expense,
                myShareAmount: myShareAmount,
                realSubcat: realSubcat,
                optInCoversSubcategory: optInCoversSubcategory,
                virtualAccount: virtualAccount,
                context: context
            )
        case .lendingToCompensateReal:
            try createVirtualLent(
                expense: expense,
                lentAmount: lentAmount,
                totalAmount: totalAmount,
                virtualAccount: virtualAccount,
                context: context
            )
        case .noVirtual:
            break  // real -total ya es mi costo total (yo solo en el split).
        }
    }

    /// Crea la TX virtual `+lent` (sistema "Préstamo a grupos") que compensa una TX real
    /// `-total`: net (real `-total` + virtual `+lent`) = `-myShare`. No-op si `lent <= 0`.
    /// Reusada por bridge-ON Caso A (`bridgeExpense`) y por `bridgeVirtualOnly`.
    /// Saldo inicial (deuda de apertura): crea SOLO una TX virtual en la cuenta "Grupos"
    /// reflejando la obligación heredada (+ si me deben, − si debo), con una subcategoría
    /// de sistema dedicada. NUNCA toca cuenta real ni crea drafts — no hubo movimiento de
    /// dinero real hoy. Idempotente: delete+recreate de las TX por `splitExpenseID`.
    private func bridgeOpeningBalance(
        _ expense: SplitExpense,
        in group: SplitGroup,
        currentMemberID: String,
        context: ModelContext
    ) throws {
        let expenseIDStr = expense.id.uuidString

        // Cleanup idempotente: borrar TODAS las TX previas de este saldo inicial (son
        // derivadas). No hay drafts asociados (un saldo inicial nunca los crea).
        let existing = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        ))
        for tx in existing { context.delete(tx) }

        // Mi share en esta arista (0 si soy el acreedor, que no tiene share propio).
        let expenseID = expense.id
        let myShare = try context.fetch(FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.expenseID == expenseID && $0.memberID == currentMemberID }
        )).first?.amount ?? 0

        let isCreditor = expense.paidByMemberID == currentMemberID
        guard let plan = OpeningBalanceBridgeLogic.plan(
            isCreditor: isCreditor, myShare: myShare, amount: expense.amount
        ) else {
            // No involucrado en esta arista → ninguna TX personal.
            return
        }

        let role: GroupBridgeSystemEntities.SystemSubcategoryRole = plan.role == .owed ? .openingBalanceOwed : .openingBalanceDebt
        let subcat = try GroupBridgeSystemEntities.systemSubcategory(role: role, context: context)
        let virtualAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
            currencyCode: expense.currencyCode,
            colorHint: group.colorHex,
            context: context
        )

        let tx = TransactionItem(
            date: expense.date,
            amount: plan.txAmount,
            currencyCode: expense.currencyCode,
            note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
            category: subcat.safeCategory,
            subcategory: subcat,
            account: virtualAccount
        )
        tx.splitExpenseID = expenseIDStr
        tx.splitGroupZoneID = expense.groupZoneID
        tx.splitTotalAmount = expense.amount
        tx.splitType = expense.splitType
        context.insert(tx)
        tx.recalculatePreferredCurrency(context: context)
    }

    private func createVirtualLent(
        expense: SplitExpense,
        lentAmount: Double,
        totalAmount: Double,
        virtualAccount: Account,
        context: ModelContext
    ) throws {
        guard lentAmount > 0 else { return }
        let loanSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: context)
        let virtualLent = TransactionItem(
            date: expense.date,
            amount: lentAmount,  // M6: lent (no totalAmount como M5).
            currencyCode: expense.currencyCode,
            note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
            category: loanSubcat.safeCategory,
            subcategory: loanSubcat,
            account: virtualAccount
        )
        virtualLent.splitExpenseID = expense.id.uuidString
        virtualLent.splitGroupZoneID = expense.groupZoneID
        virtualLent.splitTotalAmount = totalAmount  // ref al gasto total origen.
        virtualLent.splitType = expense.splitType
        context.insert(virtualLent)
        virtualLent.recalculatePreferredCurrency(context: context)
    }

    /// Caso B (otro pagó): TX virtual -myShare con subcat manual o draft TX-puntero.
    private func createCaseBVirtualMyShare(
        expense: SplitExpense,
        myShareAmount: Double,
        realSubcat: Subcategory?,
        optInCoversSubcategory: Bool,
        virtualAccount: Account,
        context: ModelContext
    ) {
        let expenseIDStr = expense.id.uuidString
        let tx = TransactionItem(
            date: expense.date,
            amount: -myShareAmount,
            currencyCode: expense.currencyCode,
            note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
            category: realSubcat?.safeCategory,
            subcategory: realSubcat,
            account: virtualAccount
        )
        tx.splitExpenseID = expenseIDStr
        tx.splitGroupZoneID = expense.groupZoneID
        tx.splitTotalAmount = expense.amount
        tx.splitType = expense.splitType
        context.insert(tx)
        tx.recalculatePreferredCurrency(context: context)

        // Draft TX-puntero para asignar subcat si auto-match falló (path heredado M5).
        // Skip si un draft opt-in pendiente ya pide la subcategoría (B6-26 parte 2).
        if GroupDraftFinalizationLogic.shouldCreateVirtualSubcategoryPointer(
            autoMatchFailed: realSubcat == nil,
            optInDraftCoversSubcategory: optInCoversSubcategory
        ) {
            let draft = InboxDraft(
                note: expense.expenseDescription,
                amount: -myShareAmount,
                date: expense.date,
                account: virtualAccount,
                subcategory: nil,
                sourceType: .groupExpense,
                confidenceAmount: 1.0,
                confidenceDate: 1.0,
                confidenceMerchant: 1.0,
                confidenceSubcategory: nil,
                needsUserInput: [DraftInputRequirement.subcategory],
                splitExpenseID: expenseIDStr,
                splitGroupZoneID: expense.groupZoneID,
                splitSettlementID: nil,
                targetTransactionID: nil
            )
            context.insert(draft)
        }
    }

    /// Caso A modo .groupInvite: M5 puro (TX1 virtual -myShare + TX2 virtual +totalAmount sistema).
    private func createGroupInviteCaseAVirtualPair(
        expense: SplitExpense,
        myShareAmount: Double,
        lentAmount: Double,
        totalAmount: Double,
        realSubcat: Subcategory?,
        optInCoversSubcategory: Bool,
        virtualAccount: Account,
        context: ModelContext
    ) {
        let expenseIDStr = expense.id.uuidString
        // TX1 virtual -myShare.
        let tx1 = TransactionItem(
            date: expense.date,
            amount: -myShareAmount,
            currencyCode: expense.currencyCode,
            note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
            category: realSubcat?.safeCategory,
            subcategory: realSubcat,
            account: virtualAccount
        )
        tx1.splitExpenseID = expenseIDStr
        tx1.splitGroupZoneID = expense.groupZoneID
        tx1.splitTotalAmount = totalAmount
        tx1.splitType = expense.splitType
        context.insert(tx1)
        tx1.recalculatePreferredCurrency(context: context)

        if GroupDraftFinalizationLogic.shouldCreateVirtualSubcategoryPointer(
            autoMatchFailed: realSubcat == nil,
            optInDraftCoversSubcategory: optInCoversSubcategory
        ) {
            let draft = InboxDraft(
                note: expense.expenseDescription,
                amount: -myShareAmount,
                date: expense.date,
                account: virtualAccount,
                subcategory: nil,
                sourceType: .groupExpense,
                confidenceAmount: 1.0,
                confidenceDate: 1.0,
                confidenceMerchant: 1.0,
                confidenceSubcategory: nil,
                needsUserInput: [DraftInputRequirement.subcategory],
                splitExpenseID: expenseIDStr,
                splitGroupZoneID: expense.groupZoneID,
                splitSettlementID: nil,
                targetTransactionID: nil
            )
            context.insert(draft)
        }

        // TX2 virtual +totalAmount sistema (préstamo). Skip si lent==0.
        if lentAmount > 0 {
            do {
                let loanSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: context)
                let tx2 = TransactionItem(
                    date: expense.date,
                    amount: totalAmount,
                    currencyCode: expense.currencyCode,
                    note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
                    category: loanSubcat.safeCategory,
                    subcategory: loanSubcat,
                    account: virtualAccount
                )
                tx2.splitExpenseID = expenseIDStr
                tx2.splitGroupZoneID = expense.groupZoneID
                tx2.splitTotalAmount = totalAmount
                tx2.splitType = expense.splitType
                context.insert(tx2)
                tx2.recalculatePreferredCurrency(context: context)
            } catch {
                // Falla degradada (decisión D-A): la TX1 ya insertada sobrevive — abortar
                // aquí perdería el gasto completo. El saldo virtual queda desbalanceado
                // hasta el próximo re-bridge; la telemetría mide si ocurre en producción.
                #if DEBUG
                print("GroupTransactionBridge: TX2 virtual lent falló: \(error)")
                #endif
                TelemetryService.track(.bridgeVirtualLentTxFailed, parameters: [
                    "role": "loanToGroups"
                ])
            }
        }
    }

    /// M6: Crea InboxDraft pendiente de cuenta para Caso A cuando bridge no puede crear TX real.
    /// Enfoque B: `needsSubcategory` pide además clasificar (sheet combinado) si el auto-match
    /// de subcategoría falló.
    private func createDraftCaseA(
        expense: SplitExpense,
        reason: DraftOriginReason,
        actorName: String?,
        groupName: String,
        needsSubcategory: Bool,
        context: ModelContext
    ) {
        let draft = InboxDraft(
            note: expense.expenseDescription,
            amount: -expense.amount,
            date: expense.date,
            account: nil,
            subcategory: nil,
            sourceType: .groupExpense,
            confidenceAmount: 1.0,
            confidenceDate: 1.0,
            confidenceMerchant: 1.0,
            confidenceSubcategory: nil,
            needsUserInput: GroupDraftFinalizationLogic.caseADraftNeedsUserInput(needsSubcategory: needsSubcategory),
            splitExpenseID: expense.id.uuidString,
            splitGroupZoneID: expense.groupZoneID,
            splitSettlementID: nil,
            targetTransactionID: nil,
            originReasonKey: reason.rawValue,
            originActorName: actorName,
            originGroupName: groupName
        )
        context.insert(draft)
    }

    /// Enfoque B: draft TX-puntero `[.subcategory]` para clasificar una TX real Caso A cuyo
    /// auto-match de subcategoría falló. Mismo mecanismo que Caso B (`createCaseBVirtualMyShare`):
    /// el dispatch de `approveDraft` localiza la TX por `splitExpenseID && subcategory == nil` y
    /// le asigna la subcat (no crea TX nueva). `account` es el de la TX real (solo display).
    private func createCaseASubcategoryDraft(expense: SplitExpense, account: Account?, context: ModelContext) {
        let draft = InboxDraft(
            note: expense.expenseDescription,
            amount: -expense.amount,
            date: expense.date,
            account: account,
            subcategory: nil,
            sourceType: .groupExpense,
            confidenceAmount: 1.0,
            confidenceDate: 1.0,
            confidenceMerchant: 1.0,
            confidenceSubcategory: nil,
            needsUserInput: [DraftInputRequirement.subcategory],
            splitExpenseID: expense.id.uuidString,
            splitGroupZoneID: expense.groupZoneID,
            splitSettlementID: nil,
            targetTransactionID: nil
        )
        context.insert(draft)
    }

    /// Resolver displayName del miembro pagador (snapshot al crear draft).
    private func resolveMemberDisplayName(memberID: String, in group: SplitGroup, context: ModelContext) -> String? {
        // SwiftData no soporta `$0.id.uuidString == String` con tipos valor — convertir antes.
        // Si `memberID` no es UUID válido, retorna nil (degrade graceful para snapshot opcional).
        guard let memberUUID = UUID(uuidString: memberID) else { return nil }
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.id == memberUUID }
        )
        do {
            return try context.fetch(descriptor).first?.displayName
        } catch {
            Self.logger.error("resolveMemberDisplayName: fetch failed for \(memberID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func saveIfNeeded(shouldSave: Bool, context: ModelContext) throws {
        guard shouldSave else { return }
        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
        Task { await BudgetAlertService.shared.checkBudgetsAndNotify() }
    }

    /// Bridge remote expenses received in a sync batch. Called after context.save().
    /// `ids`: re-fetch en ESTE context (mainContext) en lugar de pasar objetos `SplitExpense` —
    /// el sync persiste los expenses y luego invoca esto con sus IDs; re-fetchear evita objetos stale.
    func bridgeRemoteExpenses(ids: [UUID]) throws {
        let context = try requireContext()
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        let expenses = try context.fetch(FetchDescriptor<SplitExpense>()).filter { idSet.contains($0.id) }
        // DIAG: re-bridge por sync remoto (distingue del edit local). Quitar tras QA.
        Self.logger.info("bridgeRemoteExpenses count=\(expenses.count, privacy: .public)")

        for expense in expenses {
            // Find the group for this expense
            let zoneID = expense.groupZoneID
            let groupDescriptor = FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.cloudKitZoneID == zoneID }
            )
            guard let group = try context.fetch(groupDescriptor).first else { continue }

            do {
                // M6: isRemoteSync=true marca path remoto. Sin accountForCurrentUser local
                // → bridge crea draft pendiente con hint si Caso A y no existe TX real.
                try bridgeExpense(expense, in: group, accountForCurrentUser: nil, isRemoteSync: true, shouldSave: false)
            } catch {
                #if DEBUG
                print("GroupTransactionBridge: Failed to bridge expense \(expense.id): \(error)")
                #endif
            }
        }

        try context.save()
        // UI refresh handled by SplitSyncManager's deferred markRemoteChangePending()
    }

    // MARK: - Settlement Bridge (A0-Bridge: Caso C + D)

    /// A0-Bridge: bridge para settlements. Solo procesa si `settlement.isConfirmed == true`.
    ///
    /// **Caso C** (yo `from`): TX1 virtual `+amount` con sistema "Pago de liquidación" (income).
    /// Si `userType ∈ .full|.completed` Y `accountForCurrentUser != nil`:
    ///   TX2 cuenta real `-amount` con sistema "Liquidación enviada" (expense).
    ///   + persiste defaultSettlementAccount preference.
    /// Si cuenta proveída es nil (form skipped): InboxDraft `groupSettlement` con
    ///   subcategory="Liquidación enviada", account=nil, splitSettlementID.
    /// Si `userType == .groupInvite`: solo TX1 virtual; NO draft. UI muestra toast upsell.
    ///
    /// **Caso D** (yo `to`, reactivo): TX1 virtual `-amount` con sistema "Cobro de préstamo" (expense).
    /// Si `.full|.completed`: InboxDraft `groupSettlement` con subcategory="Liquidación recibida",
    ///   amount=+amount, splitSettlementID. User finaliza desde Inbox para crear TX cuenta real.
    /// Si `.groupInvite`: solo TX1 virtual; NO draft.
    ///
    /// Idempotency: delete + recreate (mismo patrón que bridgeExpense).
    func bridgeSettlement(
        _ settlement: SplitSettlement,
        in group: SplitGroup,
        accountForCurrentUser: Account? = nil,
        shouldSave: Bool = true
    ) throws {
        let context = try requireContext()

        // Solo bridge si confirmed.
        guard settlement.isConfirmed else { return }

        // Find current user.
        // pending/rejected members no triguean bridge.
        let zoneID = group.cloudKitZoneID
        let memberDescriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true }
        )
        guard let currentMember = try context.fetch(memberDescriptor).first,
              currentMember.isActive else { return }
        let currentMemberID = currentMember.id.uuidString

        // Determinar caso C/D. Skip si user no es from ni to (settlement entre otros).
        let isCaseC = settlement.fromMemberID == currentMemberID
        let isCaseD = settlement.toMemberID == currentMemberID
        guard isCaseC || isCaseD else { return }

        // Idempotency: delete previous TX/Drafts.
        let settlementIDStr = settlement.id.uuidString
        let existingTxs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitSettlementID == settlementIDStr }
        ))
        for tx in existingTxs { context.delete(tx) }

        let existingDrafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitSettlementID == settlementIDStr }
        ))
        // Opt-in drafts preservados (mismo razonamiento que bridgeExpense).
        for draft in existingDrafts where !draft.optInPersonalOnly {
            context.delete(draft)
        }

        let amount = settlement.amount
        let currencyCode = settlement.currencyCode
        let userType = SessionState.shared.onboardingMode

        // Caso C: si bridge OFF se omiten TX2 cuenta real + draft auto. La creación
        // queda diferida al alert opt-in del form que crea draft Inbox bajo demanda.
        // Caso D mantiene draft auto (entrante via sync — el draft en Inbox actúa como
        // opt-in natural; user aprueba o ignora).
        let effectiveBridgeEnabled = BridgeModeResolver.shared.isBridgeEnabled(
            for: group, context: context
        )

        // Cuenta virtual SIEMPRE se crea (representa saldo del grupo).
        let virtualAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
            currencyCode: currencyCode,
            colorHint: group.colorHex,
            context: context
        )

        if isCaseC {
            // TX1 virtual: +amount sistema "Pago de liquidación" (income).
            let payoffSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementPayment, context: context)
            let tx1 = TransactionItem(
                date: settlement.date,
                amount: amount,
                currencyCode: currencyCode,
                note: settlement.note,
                category: payoffSubcat.safeCategory,
                subcategory: payoffSubcat,
                account: virtualAccount
            )
            tx1.splitSettlementID = settlementIDStr
            tx1.splitGroupZoneID = zoneID
            context.insert(tx1)
            tx1.recalculatePreferredCurrency(context: context)

            // TX2 cuenta real solo para .full/.completed Y bridge effective ON.
            if userType != .groupInvite && effectiveBridgeEnabled {
                if let account = accountForCurrentUser {
                    let sentSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementSent, context: context)
                    let tx2 = TransactionItem(
                        date: settlement.date,
                        amount: -amount,
                        currencyCode: currencyCode,
                        note: settlement.note,
                        category: sentSubcat.safeCategory,
                        subcategory: sentSubcat,
                        account: account
                    )
                    tx2.splitSettlementID = settlementIDStr
                    tx2.splitGroupZoneID = zoneID
                    context.insert(tx2)
                    tx2.recalculatePreferredCurrency(context: context)
                    // M6: NO defaults — eliminada persistencia de defaultSettlementAccount.
                } else {
                    // Sin cuenta proveída: draft pendiente. La subcat sistema es opcional (el user
                    // la completa en Inbox); do/catch para no tragar un error real con try?.
                    let sentSubcat: Subcategory?
                    do {
                        sentSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementSent, context: context)
                    } catch {
                        Self.logger.error("bridgeSettlement: systemSubcategory(settlementSent) failed: \(error.localizedDescription, privacy: .public)")
                        sentSubcat = nil
                    }
                    let draft = InboxDraft(
                        note: settlement.note ?? "",
                        amount: -amount,
                        date: settlement.date,
                        account: nil,
                        subcategory: sentSubcat,
                        sourceType: .groupSettlement,
                        confidenceAmount: 1.0,
                        confidenceDate: 1.0,
                        confidenceMerchant: 1.0,
                        confidenceSubcategory: 1.0,
                        needsUserInput: [DraftInputRequirement.account],
                        splitExpenseID: nil,
                        splitGroupZoneID: zoneID,
                        splitSettlementID: settlementIDStr,
                        targetTransactionID: nil
                    )
                    context.insert(draft)
                }
            }
        } else if isCaseD {
            // TX1 virtual: -amount sistema "Cobro de préstamo" (expense).
            let collectSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .loanCollection, context: context)
            let tx1 = TransactionItem(
                date: settlement.date,
                amount: -amount,
                currencyCode: currencyCode,
                note: settlement.note,
                category: collectSubcat.safeCategory,
                subcategory: collectSubcat,
                account: virtualAccount
            )
            tx1.splitSettlementID = settlementIDStr
            tx1.splitGroupZoneID = zoneID
            context.insert(tx1)
            tx1.recalculatePreferredCurrency(context: context)

            // Para .full/.completed: draft groupSettlement para asignar cuenta real.
            // M6: NO defaults universales — sin preselect, user siempre elige cuenta.
            if userType != .groupInvite {
                let receivedSubcat: Subcategory?
                do {
                    receivedSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementReceived, context: context)
                } catch {
                    Self.logger.error("bridgeSettlement: systemSubcategory(settlementReceived) failed: \(error.localizedDescription, privacy: .public)")
                    receivedSubcat = nil
                }
                let draft = InboxDraft(
                    note: settlement.note ?? "",
                    amount: amount,
                    date: settlement.date,
                    account: nil,
                    subcategory: receivedSubcat,
                    sourceType: .groupSettlement,
                    confidenceAmount: 1.0,
                    confidenceDate: 1.0,
                    confidenceMerchant: 1.0,
                    confidenceSubcategory: 1.0,
                    needsUserInput: [DraftInputRequirement.account],
                    splitExpenseID: nil,
                    splitGroupZoneID: zoneID,
                    splitSettlementID: settlementIDStr,
                    targetTransactionID: nil
                )
                context.insert(draft)
            }
        }

        if shouldSave {
            try context.save()
            SessionState.shared.incrementDataVersion()
            WidgetDataCache.updateCache(context: context)
        }
    }

    /// Bridge remote settlements received via sync. Llamado desde SplitSyncManager.
    /// Solo procesa settlements confirmed (skipea unconfirmed).
    /// `ids`: re-fetch en ESTE context (mainContext) — ver `bridgeRemoteExpenses(ids:)`.
    func bridgeRemoteSettlements(ids: [UUID]) throws {
        let context = try requireContext()
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        let settlements = try context.fetch(FetchDescriptor<SplitSettlement>()).filter { idSet.contains($0.id) }

        for settlement in settlements {
            let zoneID = settlement.groupZoneID
            let groupDescriptor = FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.cloudKitZoneID == zoneID }
            )
            guard let group = try context.fetch(groupDescriptor).first else { continue }

            do {
                try bridgeSettlement(settlement, in: group, accountForCurrentUser: nil, shouldSave: false)
            } catch {
                #if DEBUG
                print("GroupTransactionBridge: Failed to bridge settlement \(settlement.id): \(error)")
                #endif
            }
        }

        try context.save()
    }

    /// Remove all bridged TransactionItems and InboxDrafts vinculadas a un settlement.
    func unbridgeSettlement(settlementID: String) throws {
        let context = try requireContext()

        let txs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitSettlementID == settlementID }
        ))
        for tx in txs { context.delete(tx) }

        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitSettlementID == settlementID }
        ))
        for draft in drafts { context.delete(draft) }

        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    /// Remove all bridged TransactionItems and InboxDrafts vinculadas a un expense.
    /// A0-Bridge: el modelo M5 puede crear 1-2 TX por expense + un draft groupExpense
    /// con targetTransactionID. Esta función borra TODAS las entidades con `splitExpenseID == X`.
    func unbridgeExpense(expenseID: String) throws {
        let context = try requireContext()

        let txs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        ))
        for tx in txs { context.delete(tx) }

        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        ))
        for draft in drafts { context.delete(draft) }

        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    // MARK: - Freeze on Soft-delete / Leave / Remove

    /// Clasificación pure-logic por tipo de TX bridgeada al limpiar tras soft-delete/leave/remove.
    /// TX cuenta real → libera 3 IDs (preserva monto/fecha/cuenta/subcat/note/tags).
    /// TX virtual sistema → preserva intacta (rastro "presté X" / "me liquidaron").
    enum SoftDeleteCleanupAction {
        case releaseRealAccountTx
        case preserveVirtualSystemTx
    }

    /// Pure-logic classifier: decide qué hacer con una TX bridgeada en el cleanup.
    nonisolated static func classifyForSoftDelete(transactionAccountIsSystem: Bool) -> SoftDeleteCleanupAction {
        transactionAccountIsSystem ? .preserveVirtualSystemTx : .releaseRealAccountTx
    }

    /// Pure-logic helper: si el grupo está hidden, no bridgear sus expenses.
    /// Defensa-en-profundidad contra invitados fresh-install que reciben SplitGroup ya hidden.
    nonisolated static func shouldBridgeExpense(groupIsHidden: Bool) -> Bool { !groupIsHidden }

    /// Pure-logic plan computado a partir de fetches del context. Testeable sin context.
    struct FreezePlan {
        let txsToRelease: [TransactionItem]
        let draftsToConvert: [InboxDraft]
        /// Punteros de clasificación `[.subcategory]` redundantes: su TX se preserva en el freeze,
        /// así que el draft sobra y, convertido a manual, duplicaría la TX al aprobarlo. Se borran.
        let draftsToDelete: [InboxDraft]
    }

    /// Pure-logic: dado un array de TX/drafts ya fetcheados, devuelve qué hacer con cada uno.
    /// Idempotente: si TX/draft ya está limpio, lo excluye del plan (no se modifica).
    nonisolated static func computeFreezePlan(transactions: [TransactionItem], drafts: [InboxDraft]) -> FreezePlan {
        let txsToRelease = transactions.filter { tx in
            // Solo TX cuenta real (no system). TX ya liberadas (IDs nil) excluidas.
            guard tx.account?.isSystemAccount == false else { return false }
            return tx.splitExpenseID != nil || tx.splitSettlementID != nil || tx.splitGroupZoneID != nil
        }
        let groupExpenseRaw = DraftSourceType.groupExpense.rawValue
        let groupSettlementRaw = DraftSourceType.groupSettlement.rawValue

        var draftsToConvert: [InboxDraft] = []
        var draftsToDelete: [InboxDraft] = []
        for draft in drafts where draft.sourceTypeRaw == groupExpenseRaw || draft.sourceTypeRaw == groupSettlementRaw {
            // Puntero de clasificación: draft `.groupExpense` que SOLO pide subcategoría (no cuenta)
            // y apunta a una TX existente vía `splitExpenseID`. Esa TX se preserva en el freeze (la
            // real, liberada arriba; o la virtual sistema, intacta), así que el user la clasifica
            // editándola directamente — el draft es redundante. Convertido a manual duplicaría la TX
            // al aprobarlo (el path genérico de `approveDraft` inserta una TransactionItem nueva). →
            // borrarlo. Si el puntero quedó huérfano (sin TX para su `splitExpenseID`), cae a convert
            // y no se pierde el rastro del gasto. Los drafts `[.account]` (Caso A pendiente de cuenta)
            // y los `.groupSettlement` NO son punteros — siguen convirtiéndose a manual.
            if draft.sourceTypeRaw == groupExpenseRaw,
               draft.needsUserInput.contains(DraftInputRequirement.subcategory),
               !draft.needsUserInput.contains(DraftInputRequirement.account),
               let splitID = draft.splitExpenseID,
               transactions.contains(where: { $0.splitExpenseID == splitID }) {
                draftsToDelete.append(draft)
            } else {
                draftsToConvert.append(draft)
            }
        }
        return FreezePlan(txsToRelease: txsToRelease, draftsToConvert: draftsToConvert, draftsToDelete: draftsToDelete)
    }

    /// Libera TX cuenta real (nilea splitExpenseID/splitSettlementID/splitGroupZoneID) +
    /// convierte drafts `groupExpense`/`groupSettlement` a `.manual` preservando cached fields.
    /// Reemplaza el destructive `unbridgeExpenses` eliminado — preserva el rastro financiero.
    /// Idempotente: TX/drafts ya limpios se excluyen del plan.
    func freezeForSoftDelete(group: SplitGroup) throws {
        let context = try requireContext()
        let zoneID = group.cloudKitZoneID

        let txDescriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitGroupZoneID == zoneID }
        )
        let transactions = try context.fetch(txDescriptor)

        let draftDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitGroupZoneID == zoneID }
        )
        let drafts = try context.fetch(draftDescriptor)

        let plan = Self.computeFreezePlan(transactions: transactions, drafts: drafts)

        // TX cuenta real: libera 3 IDs. Preserva monto/fecha/cuenta/subcat/note/tags.
        for tx in plan.txsToRelease {
            tx.splitExpenseID = nil
            tx.splitSettlementID = nil
            tx.splitGroupZoneID = nil
        }

        // Drafts groupExpense/groupSettlement: convert a manual. Preserva cached fields.
        let manualRaw = DraftSourceType.manual.rawValue
        for draft in plan.draftsToConvert {
            draft.sourceTypeRaw = manualRaw
            draft.splitExpenseID = nil
            draft.splitSettlementID = nil
            draft.splitGroupZoneID = nil
            draft.needsUserInput = []
        }

        // Punteros de clasificación redundantes: su TX se preserva → el draft sobra. Borrarlo
        // evita la TX duplicada que produciría aprobarlo ya convertido a manual.
        for draft in plan.draftsToDelete {
            context.delete(draft)
        }

        guard !plan.txsToRelease.isEmpty || !plan.draftsToConvert.isEmpty || !plan.draftsToDelete.isEmpty else { return }

        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)

        #if DEBUG
        Self.logger.info("freezeForSoftDelete zone=\(zoneID, privacy: .public) released=\(plan.txsToRelease.count, privacy: .public) converted=\(plan.draftsToConvert.count, privacy: .public) deleted=\(plan.draftsToDelete.count, privacy: .public)")
        #endif
    }

    // MARK: - Category Matching

    /// Match a subcategory name to a user's personal Subcategory.
    /// Priority: exact (case-insensitive) → contains → nil.
    static func matchSubcategory(name: String?, context: ModelContext) -> Subcategory? {
        guard let name, !name.isEmpty else { return nil }

        let descriptor = FetchDescriptor<Subcategory>()
        let all: [Subcategory]
        do {
            all = try context.fetch(descriptor)
        } catch {
            logger.error("matchSubcategory: Subcategory fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        // Exact match (case-insensitive)
        if let exact = all.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return exact
        }

        // Contains match
        if let partial = all.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
            return partial
        }

        return nil
    }

}

// MARK: - Errors

enum GroupTransactionBridgeError: LocalizedError {
    case noContext

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "GroupTransactionBridge: No ModelContext available"
        }
    }
}
