//
//  DraftService.swift
//  Yala
//
//  Service for managing InboxDraft operations (create, approve, reject, delete).
//  Fase C.1: Arquitectura - Services para ModelContext
//

import Foundation
import OSLog
import SwiftData
import WidgetKit

// MARK: - DraftService Implementation

/// Service for managing InboxDraft operations
@MainActor
@Observable
final class DraftService {

    // MARK: - Singleton

    static let shared = DraftService()

    // MARK: - Properties

    private var modelContext: ModelContext?

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    /// Sets the model context (call this from views that use the service)
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Private Helpers

    private func requireContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw DraftServiceError.noContext
        }
        return context
    }

    /// Caches display values on a draft for when relationships are deleted
    private func cacheDisplayValues(_ draft: InboxDraft) {
        if let account = draft.account {
            draft.cachedAccountName = account.name
            draft.cachedCurrencyCode = account.currencyCode
        }
        if let subcategory = draft.subcategory {
            draft.cachedSubcategoryName = subcategory.name
            draft.cachedCategoryColorHex = subcategory.safeCategory.colorHex
            draft.cachedSubcategoryIcon = subcategory.iconName ?? subcategory.safeCategory.iconName
        }
    }

    /// Updates needsUserInput array based on draft state
    private func updateNeedsUserInput(_ draft: InboxDraft) {
        var needs: [String] = []
        if draft.account == nil { needs.append("account") }
        if draft.subcategory == nil { needs.append("subcategory") }
        if draft.amount == nil { needs.append("amount") }
        draft.needsUserInput = needs
    }

    // MARK: - Create Operations

    func createDraft(_ draft: InboxDraft) throws {
        let context = try requireContext()
        context.insert(draft)
        try context.save()
    }

    func createDrafts(_ drafts: [InboxDraft]) throws {
        let context = try requireContext()
        for draft in drafts {
            context.insert(draft)
        }
        try context.save()
    }

    // MARK: - Approve Operations

    func approveDraft(
        _ draft: InboxDraft,
        currencyConverter: CurrencyConverter
    ) throws -> TransactionItem {
        let context = try requireContext()

        // M6: drafts groupExpense Caso A pendiente cuenta. Crea TX cuenta real con
        // splitExpenseID + invoca bridge para regenerar TX virtual lent.
        // Detección: groupExpense + targetTransactionID==nil + needsUserInput contains "account".
        if draft.sourceType == .groupExpense,
           draft.targetTransactionID == nil,
           draft.needsUserInput.contains(DraftInputRequirement.account) {
            return try approveGroupExpenseAccountDraft(draft, currencyConverter: currencyConverter, context: context)
        }

        // Drafts groupExpense apuntan a una TX virtual con subcategory=nil creada por
        // GroupTransactionBridge. Aprobar = asignar subcat a la TX existente, no crear una nueva.
        if draft.sourceType == .groupExpense, let subcategory = draft.subcategory,
           let splitID = draft.splitExpenseID {
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID == splitID && $0.subcategory == nil }
            )
            if let targetTx = try context.fetch(descriptor).first {
                targetTx.subcategory = subcategory
                targetTx.category = subcategory.safeCategory
                cacheDisplayValues(draft)
                context.delete(draft)
                try context.save()
                SessionState.shared.incrementDataVersion()
                TelemetryService.track(.draftApproved, parameters: ["source": draft.sourceTypeRaw])
                return targetTx
            }
            // TX target ausente: sync race con remote delete del expense, o flow inválido.
            // Logger.error en lugar de print(DEBUG) para que se capture en producción.
            Logger(subsystem: "com.yala", category: "GroupBridge").error(
                "groupExpense draft target TX not found for splitExpenseID=\(splitID, privacy: .public). Falling back."
            )
        }

        // A0-Bridge V2.0 (D7): drafts groupSettlement crean TX nueva en cuenta real
        // (subcat sistema "Liquidación enviada/recibida" ya asignada por el bridge).
        // La TX queda como TX MANUAL INDEPENDIENTE — NO setear splitSettlementID/splitGroupZoneID.
        // Razón: el bridge hace delete+recreate sobre TX con splitSettlementID al editar el
        // settlement. Mantener esos campos haría que una edición posterior del settlement
        // borre la TX manual del user (ej: transferiste vía Yape, después editas el monto del
        // settlement → tu TX en Yape desaparece). La TX virtual (lado bridge) sigue ligada
        // al settlement y se regenera correctamente.
        if draft.sourceType == .groupSettlement, let account = draft.account,
           let amount = draft.amount, let subcategory = draft.subcategory {
            let preferredCode = CurrencyDefaults.currentPreferred
            let amountInPreferred = currencyConverter.convert(
                Decimal(amount),
                from: account.currencyCode,
                to: preferredCode,
                on: draft.effectiveDate,
                context: context
            )

            let exchangeRate: Double = abs(amount) > 0.0001
                ? (amountInPreferred as NSDecimalNumber).doubleValue / amount
                : 1.0

            let tx = TransactionItem(
                date: draft.effectiveDate,
                amount: amount,
                currencyCode: account.currencyCode
            )
            tx.note = draft.note.isEmpty ? nil : draft.note
            tx.account = account
            tx.subcategory = subcategory
            tx.category = subcategory.safeCategory
            tx.exchangeRate = abs(exchangeRate)
            tx.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
            tx.preferredCurrencyCode = preferredCode
            // D7: NO setear tx.splitSettlementID ni tx.splitGroupZoneID — TX queda manual independiente.

            context.insert(tx)
            cacheDisplayValues(draft)
            context.delete(draft)
            try context.save()

            SessionState.shared.incrementDataVersion()
            WidgetDataCache.updateCache(context: context)
            TelemetryService.track(.draftApproved, parameters: ["source": draft.sourceTypeRaw])
            return tx
        }

        // Validate: block future dates
        guard draft.effectiveDate <= Date.now else {
            throw DraftServiceError.futureDateNotAllowed
        }

        guard let account = draft.account else {
            throw DraftServiceError.missingAccount
        }
        guard let amount = draft.amount else {
            throw DraftServiceError.missingAmount
        }
        guard let subcategory = draft.subcategory else {
            throw DraftServiceError.missingSubcategory
        }

        // Calculate amount in preferred currency for charts/statistics
        let preferredCode = CurrencyDefaults.currentPreferred
        let amountInPreferred = currencyConverter.convert(
            Decimal(amount),
            from: account.currencyCode,
            to: preferredCode,
            on: draft.effectiveDate,
            context: context
        )

        let exchangeRate: Double
        if abs(amount) > 0.0001 {
            exchangeRate = (amountInPreferred as NSDecimalNumber).doubleValue / amount
        } else {
            exchangeRate = 1.0
        }

        // Create TransactionItem
        let transaction = TransactionItem(
            date: draft.effectiveDate,
            amount: amount,
            currencyCode: account.currencyCode
        )
        transaction.note = draft.note.isEmpty ? nil : draft.note
        transaction.account = account
        transaction.subcategory = subcategory
        transaction.category = subcategory.safeCategory
        transaction.tags = draft.tags
        transaction.exchangeRate = abs(exchangeRate)
        transaction.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
        transaction.preferredCurrencyCode = preferredCode

        context.insert(transaction)

        // Cache display values BEFORE changing status
        cacheDisplayValues(draft)

        // Update draft status and link to transaction
        draft.status = .approved
        draft.approvedTransaction = transaction
        draft.updatedAt = Date.now

        // Update merchant memory (learn from approved drafts)
        if !draft.note.trimmingCharacters(in: .whitespaces).isEmpty {
            let merchantService = MerchantMemoryService(modelContext: context)
            merchantService.updateMemory(
                merchantRaw: draft.note,
                subcategory: subcategory,
                wasCorrection: false
            )
        }

        // Update scheduled payment if this draft came from one
        ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)

        try context.save()

        TelemetryService.track(.draftApproved, parameters: ["source": draft.sourceTypeRaw])

        // Count approved draft toward transaction total (for review prompt)
        let txCount = UserDefaults.standard.integer(forKey: "transactionsSavedCount") + 1
        UserDefaults.standard.set(txCount, forKey: "transactionsSavedCount")

        if ReviewPromptService.shouldPrompt(transactionCount: txCount) {
            AppRouter.shared.enqueue(.requestAppStoreReview)
        }

        // Check milestone upgrade for Free users
        if !FeatureGateService.shared.isProUser,
           ProUpsellService.shared.shouldShowMilestone(transactionCount: txCount),
           let milestone = ProUpsellService.shared.nextMilestone(for: txCount) {
            AppRouter.shared.enqueue(.presentMilestoneUpgrade(milestone))
            ProUpsellService.shared.markMilestoneShown(milestone)
        }

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()

        // Check budget alerts
        Task {
            await BudgetAlertService.shared.checkBudgetsAndNotify()
        }

        return transaction
    }

    func bulkApprove(
        _ drafts: [InboxDraft],
        currencyConverter: CurrencyConverter
    ) throws -> [TransactionItem] {
        let context = try requireContext()
        var transactions: [TransactionItem] = []
        let preferredCode = CurrencyDefaults.currentPreferred

        for draft in drafts where draft.isReadyToApprove {
            // Skip drafts with future dates
            guard draft.effectiveDate <= Date.now else { continue }

            guard let account = draft.account,
                  !account.isArchived,
                  let amount = draft.amount,
                  let subcategory = draft.subcategory else { continue }

            // Calculate amount in preferred currency
            let amountInPreferred = currencyConverter.convert(
                Decimal(amount),
                from: account.currencyCode,
                to: preferredCode,
                on: draft.effectiveDate,
                context: context
            )

            let exchangeRate: Double
            if abs(amount) > 0.0001 {
                exchangeRate = (amountInPreferred as NSDecimalNumber).doubleValue / amount
            } else {
                exchangeRate = 1.0
            }

            let transaction = TransactionItem(
                date: draft.effectiveDate,
                amount: amount,
                currencyCode: account.currencyCode
            )
            transaction.note = draft.note.isEmpty ? nil : draft.note
            transaction.account = account
            transaction.subcategory = subcategory
            transaction.category = subcategory.safeCategory
            transaction.tags = draft.tags
            transaction.exchangeRate = abs(exchangeRate)
            transaction.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
            transaction.preferredCurrencyCode = preferredCode

            context.insert(transaction)

            // Cache display values
            cacheDisplayValues(draft)

            // Update draft
            draft.status = .approved
            draft.approvedTransaction = transaction
            draft.updatedAt = Date.now

            // Update scheduled payment
            ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)

            // Update merchant memory (learn from approved drafts)
            if !draft.note.trimmingCharacters(in: .whitespaces).isEmpty {
                let merchantService = MerchantMemoryService(modelContext: context)
                merchantService.updateMemory(
                    merchantRaw: draft.note,
                    subcategory: subcategory,
                    wasCorrection: false
                )
            }

            transactions.append(transaction)
        }

        try context.save()

        // Count all approved drafts toward transaction total
        if !transactions.isEmpty {
            let txCount = UserDefaults.standard.integer(forKey: "transactionsSavedCount") + transactions.count
            UserDefaults.standard.set(txCount, forKey: "transactionsSavedCount")

            if ReviewPromptService.shouldPrompt(transactionCount: txCount) {
                AppRouter.shared.enqueue(.requestAppStoreReview)
            }
        }

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()

        // Check budget alerts
        Task {
            await BudgetAlertService.shared.checkBudgetsAndNotify()
        }

        return transactions
    }

    // MARK: - Reject Operations

    func rejectDraft(_ draft: InboxDraft) throws {
        // A0-Bridge: drafts de grupos no se rechazan desde Inbox.
        // Solo se eliminan desde el grupo (delete del expense/settlement origen).
        if draft.isFromGroup {
            throw DraftServiceError.cannotRejectGroupDraft
        }

        let context = try requireContext()

        // Cache values for display in archived list
        cacheDisplayValues(draft)

        draft.status = .rejected
        draft.updatedAt = Date.now

        try context.save()

        TelemetryService.track(.draftRejected, parameters: ["source": draft.sourceTypeRaw])
    }

    func bulkReject(_ drafts: [InboxDraft]) throws {
        let context = try requireContext()

        for draft in drafts {
            // A0-Bridge: skip drafts de grupos (silent skip en bulk).
            if draft.isFromGroup { continue }
            cacheDisplayValues(draft)
            draft.status = .rejected
            draft.updatedAt = Date.now
        }

        try context.save()
    }

    // MARK: - Delete Operations

    func deleteDraft(_ draft: InboxDraft) throws {
        // A0-Bridge: drafts de grupos no se eliminan desde Inbox.
        // Solo se eliminan al borrar el expense/settlement origen en el grupo.
        if draft.isFromGroup {
            throw DraftServiceError.cannotDeleteGroupDraft
        }
        let context = try requireContext()
        context.delete(draft)
        try context.save()
    }

    func bulkDelete(_ drafts: [InboxDraft]) throws {
        let context = try requireContext()
        for draft in drafts {
            // A0-Bridge: skip drafts de grupos (silent skip en bulk).
            if draft.isFromGroup { continue }
            context.delete(draft)
        }
        try context.save()
    }

    // MARK: - Return to Pending

    func returnToPending(_ draft: InboxDraft) throws {
        let context = try requireContext()

        draft.status = .pending
        draft.updatedAt = Date.now
        updateNeedsUserInput(draft)

        try context.save()
    }

    func bulkReturnToPending(_ drafts: [InboxDraft]) throws {
        let context = try requireContext()

        for draft in drafts {
            draft.status = .pending
            draft.updatedAt = Date.now
            updateNeedsUserInput(draft)
        }

        try context.save()
    }

    // MARK: - Save (without approve)

    func saveDraft(_ draft: InboxDraft) throws {
        let context = try requireContext()

        draft.updatedAt = Date.now
        updateNeedsUserInput(draft)

        try context.save()
    }

    // MARK: - Bulk Updates

    func bulkUpdateAccount(_ drafts: [InboxDraft], account: Account) throws {
        let context = try requireContext()

        for draft in drafts {
            draft.account = account
            draft.updatedAt = Date.now
            updateNeedsUserInput(draft)
        }

        try context.save()
    }

    func bulkUpdateSubcategory(_ drafts: [InboxDraft], subcategory: Subcategory) throws {
        let context = try requireContext()

        for draft in drafts {
            draft.subcategory = subcategory
            draft.updatedAt = Date.now
            updateNeedsUserInput(draft)
        }

        try context.save()
    }

    // MARK: - M6: Approve groupExpense Caso A pendiente cuenta

    /// Crea TX cuenta real con `splitExpenseID` setteado e invoca el bridge para regenerar
    /// la TX virtual lent. La TX cuenta real recién creada activa el path preserve+update
    /// del bridge (no se duplica).
    ///
    /// **Orden de operaciones**:
    /// 1. Guard: campos requeridos del draft.
    /// 2. Fetch SplitExpense + SplitGroup origen.
    /// 3. Crear TX cuenta real con todos los fields del expense.
    /// 4. Set bridge.skipDraftCleanup=true (defer reset) para que el bridge no borre el draft activo.
    /// 5. Invocar bridge.bridgeExpense(...) → preserve+update detecta TX recién creada,
    ///    regenera virtual lent.
    /// 6. Cache display + delete draft + save.
    private func approveGroupExpenseAccountDraft(
        _ draft: InboxDraft,
        currencyConverter: CurrencyConverter,
        context: ModelContext
    ) throws -> TransactionItem {
        // 1. Guards.
        guard let account = draft.account else {
            throw DraftServiceError.missingAccount
        }
        guard let amount = draft.amount else {
            throw DraftServiceError.missingAmount
        }
        guard let splitID = draft.splitExpenseID,
              let zoneID = draft.splitGroupZoneID else {
            // Inválido: draft groupExpense sin splitExpenseID/zoneID — no pertenece al M6 path.
            throw DraftServiceError.missingAccount  // reuse error code; UX displays generic message.
        }
        // SwiftData no soporta `$0.id.uuidString == String` con tipos valor — convertir antes.
        guard let splitUUID = UUID(uuidString: splitID) else {
            // splitExpenseID malformado: no se puede resolver SplitExpense origen.
            throw DraftServiceError.missingAccount
        }

        // 2. Fetch SplitExpense + SplitGroup.
        let expenseDescriptor = FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.id == splitUUID }
        )
        guard let expense = try context.fetch(expenseDescriptor).first else {
            // Expense origen ya no existe (sync race con remote delete) — limpia draft y aborta.
            context.delete(draft)
            try context.save()
            throw DraftServiceError.missingAccount
        }
        let groupDescriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneID }
        )
        guard let group = try context.fetch(groupDescriptor).first else {
            throw DraftServiceError.missingAccount
        }

        // 3. Crear TX cuenta real. Currency desde el expense (fuente de verdad del grupo).
        let matchedSubcat = GroupTransactionBridge.matchSubcategory(name: expense.subcategoryName, context: context)
        let realSubcat = (matchedSubcat?.isAnySystem == true) ? nil : matchedSubcat
        let preferredCode = CurrencyDefaults.currentPreferred
        let amountInPreferred = currencyConverter.convert(
            Decimal(amount),
            from: expense.currencyCode,
            to: preferredCode,
            on: draft.effectiveDate,
            context: context
        )
        let exchangeRate: Double = abs(amount) > 0.0001
            ? (amountInPreferred as NSDecimalNumber).doubleValue / amount
            : 1.0

        let realTx = TransactionItem(
            date: expense.date,
            amount: amount,  // -totalAmount (draft fue creado con -expense.amount).
            currencyCode: expense.currencyCode,
            note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
            category: realSubcat?.safeCategory,
            subcategory: realSubcat,
            account: account
        )
        realTx.splitExpenseID = splitID
        realTx.splitGroupZoneID = expense.groupZoneID
        realTx.splitTotalAmount = expense.amount
        realTx.splitType = expense.splitType
        realTx.exchangeRate = abs(exchangeRate)
        realTx.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
        realTx.preferredCurrencyCode = preferredCode
        context.insert(realTx)

        // 4 + 5. Invocar bridge con flag para no borrar este draft activo.
        // Bridge detecta realTx existente → preserve+update path → regenera virtual lent.
        // El closure `withSkippedDraftCleanup` garantiza reset del flag aunque body lance.
        do {
            try GroupTransactionBridge.shared.withSkippedDraftCleanup {
                try GroupTransactionBridge.shared.bridgeExpense(
                    expense,
                    in: group,
                    accountForCurrentUser: account,
                    isRemoteSync: false,
                    shouldSave: false  // save abajo en step 6.
                )
            }
        } catch {
            #if DEBUG
            print("DraftService.approveGroupExpenseAccountDraft: bridge failed: \(error)")
            #endif
            // Bridge falló — TX real ya creada, draft permanece para retry.
            throw error
        }

        // 6. Cache + delete draft + save.
        cacheDisplayValues(draft)
        context.delete(draft)
        try context.save()

        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
        TelemetryService.track(.draftApproved, parameters: ["source": draft.sourceTypeRaw])
        return realTx
    }
}

// MARK: - Errors

enum DraftServiceError: LocalizedError {
    case noContext
    case missingAccount
    case missingAmount
    case missingSubcategory
    case futureDateNotAllowed
    case saveFailed(Error)
    /// A0-Bridge: drafts de grupos (groupExpense/groupSettlement) no permiten eliminar/rechazar.
    /// Solo se borran al eliminar el expense/settlement origen en el grupo.
    case cannotDeleteGroupDraft
    case cannotRejectGroupDraft

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "DraftService: No ModelContext available"
        case .missingAccount:
            return L10n.Inbox.errorNoAccount
        case .missingAmount:
            return L10n.Inbox.errorNoAmount
        case .missingSubcategory:
            return L10n.Inbox.errorNoSubcategory
        case .futureDateNotAllowed:
            return L10n.Inbox.errorFutureDate
        case .saveFailed(let error):
            return "DraftService: Save failed - \(error.localizedDescription)"
        case .cannotDeleteGroupDraft, .cannotRejectGroupDraft:
            return L10n.Inbox.groupDraftCannotDelete
        }
    }
}
