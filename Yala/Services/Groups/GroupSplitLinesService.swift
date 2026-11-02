//
//  GroupSplitLinesService.swift
//  Yala
//
//  Grupos B, cards 5 y 6: lo que las pantallas necesitan para partir tu parte de un gasto de grupo y guardar las líneas.
//  La receta y su aplicación son del puente (`GroupTransactionBridge+SplitLines`); aquí solo se escribe la receta en la
//  pata que la lleva y se le pide al puente que pase.
//
//  QUÉ PATA LLEVA LA RECETA (D2 del diseño técnico, `tickets/in-progress/grupos-tu-parte-en-lineas.md`): la que el puente
//  conserva. Pagaste tú (Caso A, puente activo): la pata real. Pagó otro (Caso B): la virtual clasificable de «Grupos».
//  Se elige con el mismo criterio que `BridgeBranchLogic.partitionVirtualTxs`: la que ya lleva receta, si no la que no
//  tiene una categoría de sistema, y entre iguales la más antigua.
//

import Foundation
import OSLog
import SwiftData

enum GroupSplitLinesServiceError: Error {
    /// El gasto ya no está (borrado en remoto con la hoja abierta).
    case expenseMissing
    /// El gasto no tiene todavía la pata que lleva la receta (el puente no ha pasado).
    case holderMissing
}

@MainActor
enum GroupSplitLinesService {

    private static var logger: Logger { Logger(subsystem: "com.yala", category: "GroupBridge") }

    /// Tu parte de un gasto de grupo, lista para la tarjeta «Tu parte».
    struct Target {
        let expense: SplitExpense
        let group: SplitGroup
        /// Tu parte, en la divisa del gasto.
        let share: Decimal
        var currencyCode: String { expense.currencyCode }
        /// Pagaste tú.
        let isCaseA: Bool
        /// La pata que lleva (o llevará) la receta. `nil` en el Caso A sin pata real todavía (el borrador que pide la
        /// cuenta): ahí la crea la aprobación.
        let holder: TransactionItem?
        /// De dónde sale una recarga: la cuenta con que pagaste (Caso A) o «Grupos» (Caso B).
        let transferSourceName: String
        /// La cuenta de origen si es tuya: no se ofrece como destino.
        let transferSourceAccount: Account?
        /// Si la pantalla ofrece partir (`GroupSplitLinesEntryLogic.offersSplit`).
        let offersSplit: Bool

        /// Con qué líneas abre la tarjeta.
        var initialLines: [GroupSplitLinesRecipe.Line] {
            GroupSplitLinesEntryLogic.initialLines(
                stored: GroupSplitLinesRecipe.parse(holder?.splitLinesRaw), share: share,
                subcategoryID: holder?.subcategory?.isAnySystem == true ? nil : holder?.subcategory?.shortcutID,
                currencyCode: currencyCode)
        }
    }

    // MARK: - Leer

    /// Tu parte del gasto `splitExpenseID`. `nil` si el gasto, el grupo o tu miembro no están aquí, o si no participas.
    static func target(splitExpenseID: String, context: ModelContext) throws -> Target? {
        guard let expenseUUID = UUID(uuidString: splitExpenseID) else { return nil }
        var expenseDescriptor = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == expenseUUID })
        expenseDescriptor.fetchLimit = 1
        guard let expense = try context.fetch(expenseDescriptor).first else { return nil }
        let zoneID = expense.groupZoneID
        var groupDescriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID })
        groupDescriptor.fetchLimit = 1
        guard let group = try context.fetch(groupDescriptor).first,
              let member = try GroupExpenseService.resolveCurrentUserMember(inZone: zoneID, context: context)
        else { return nil }
        let memberID = member.id.uuidString
        let shareDescriptor = FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.expenseID == expenseUUID && $0.memberID == memberID })
        let share = try context.fetch(shareDescriptor).first.map { GroupSplitLinesBridgeLogic.decimal($0.amount) } ?? 0
        let isCaseA = expense.paidByMemberID == memberID

        let legs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == splitExpenseID }))
        let holder = isCaseA ? caseAHolder(in: legs) : caseBHolder(in: legs)

        // Venta, con el mismo criterio que el puente (`GroupTransactionBridge.bridgeExpense`, card 8).
        let matched = GroupTransactionBridge.matchSubcategory(name: expense.subcategoryName, context: context)
        let isSale = GroupSaleBridgeLogic.isSale(
            isCaseA: isCaseA, subcategoryIsIncome: matched.map { $0.safeCategory.isIncome },
            subcategoryIsSystem: matched?.isAnySystem == true)
        let offers = GroupSplitLinesEntryLogic.offersSplit(.init(
            bridgeEnabled: BridgeModeResolver.shared.isBridgeEnabled(for: group, context: context),
            hasPrivateSession: SessionState.shared.hasPrivateSession,
            isGroupsFocusedShell: SessionState.shared.isGroupsFocusedShell,
            share: share,
            isOpeningBalance: expense.isOpeningBalance,
            isSale: isSale
        )) && (holder == nil ? isCaseA : holder?.currencyCode == expense.currencyCode)

        let sourceAccount = isCaseA ? holder?.account : nil
        let sourceName = holder?.account?.name ?? ""
        return Target(expense: expense, group: group, share: share, isCaseA: isCaseA, holder: holder,
                      transferSourceName: sourceName, transferSourceAccount: sourceAccount, offersSplit: offers)
    }

    /// Caso A: la pata real (cuenta que no es de sistema y que no es una pata derivada de una línea).
    static func caseAHolder(in legs: [TransactionItem]) -> TransactionItem? {
        legs.first { $0.account?.isSystemAccount == false && !GroupSplitLinesBridgeLogic.isDerivedMarker($0.splitLinesRaw) }
    }

    /// Caso B: la virtual clasificable de «Grupos» que el puente conserva.
    static func caseBHolder(in legs: [TransactionItem]) -> TransactionItem? {
        let candidates = legs.filter {
            $0.account?.isSystemAccount == true && !$0.isDeleted
                && !GroupSplitLinesBridgeLogic.isDerivedMarker($0.splitLinesRaw)
        }
        let classifiable = candidates.filter {
            GroupSplitLinesBridgeLogic.mayCarryRecipe($0.splitLinesRaw)
                || $0.subcategory == nil || $0.subcategory?.isAnySystem != true
                || $0.balanceAdjustmentType != nil
        }
        return classifiable.min { lhs, rhs in
            let lhsRecipe = GroupSplitLinesBridgeLogic.mayCarryRecipe(lhs.splitLinesRaw)
            let rhsRecipe = GroupSplitLinesBridgeLogic.mayCarryRecipe(rhs.splitLinesRaw)
            if lhsRecipe != rhsRecipe { return lhsRecipe }
            return lhs.createdAt < rhs.createdAt
        }
    }

    // MARK: - Guardar (pantalla de éxito y detalle del registro)

    /// Guarda `lines` como tu parte del gasto y pasa el puente. Una sola línea de gasto es lo de siempre: sin receta, con
    /// esa categoría en tu parte. Quien llama ya comprobó `GroupSplitLinesEditorLogic.canSave`.
    static func save(_ lines: [GroupSplitLinesRecipe.Line], for target: Target, context: ModelContext) throws {
        guard !target.expense.isDeleted else { throw GroupSplitLinesServiceError.expenseMissing }
        guard let holder = target.holder, !holder.isDeleted else { throw GroupSplitLinesServiceError.holderMissing }
        let singleSubcategory = try GroupSplitLinesEntryLogic.singleExpenseSubcategoryID(lines)
            .flatMap { try GroupTransactionBridge.subcategory(shortcutID: $0, context: context) }

        holder.splitLinesRaw = GroupSplitLinesRecipe.encode(lines)
        if let singleSubcategory { classify(holder, as: singleSubcategory) }
        try GroupTransactionBridge.shared.bridgeExpense(target.expense, in: target.group, shouldSave: false)

        // Volver a una línea desde una ancla que era una recarga: el puente le quita la forma de recarga y, con ella, la
        // categoría. Se le pone la elegida y se retira el puntero que pediría clasificarla.
        if let singleSubcategory, !holder.isDeleted, holder.subcategory == nil {
            classify(holder, as: singleSubcategory)
            try removeClassificationPointers(splitExpenseID: target.expense.id.uuidString, context: context)
        }
        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
        logger.info("splitLines saved lines=\(lines.count, privacy: .public) caseA=\(target.isCaseA, privacy: .public)")
    }

    private static func classify(_ tx: TransactionItem, as subcategory: Subcategory) {
        tx.subcategory = subcategory
        tx.category = subcategory.safeCategory
    }

    /// Los punteros `[.subcategory]` del gasto que ya no apuntan a nada: tu parte quedó clasificada.
    static func removeClassificationPointers(splitExpenseID: String, context: ModelContext) throws {
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == splitExpenseID }))
        for draft in drafts where !draft.optInPersonalOnly
            && draft.targetTransactionID == nil
            && draft.needsUserInput.contains(DraftInputRequirement.subcategory)
            && !draft.needsUserInput.contains(DraftInputRequirement.account) {
            context.delete(draft)
        }
    }
}
