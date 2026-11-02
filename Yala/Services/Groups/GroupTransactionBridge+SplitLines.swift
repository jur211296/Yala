//
//  GroupTransactionBridge+SplitLines.swift
//  Yala
//
//  Grupos B · card 2: el puente crea tus registros desde las LÍNEAS de tu parte (gasto o recarga). Qué se decide está
//  en `GroupSplitLinesBridgeLogic`; aquí, cómo se escriben las patas. Diseño: `tickets/in-progress/grupos-tu-parte-en-lineas.md`.
//
//  LAS PATAS DERIVADAS. Cada línea que no es la ancla es una pata en la cuenta «Grupos» del gasto (D1), con su
//  `splitExpenseID` y la MARCA `{"of":"<id línea>","v":1}` en `splitLinesRaw`. Una recarga es además un par de
//  transferencia: la salida en «Grupos» y la ENTRADA en la cuenta destino, que lleva la misma marca y NO lleva
//  `splitExpenseID` (D4: si lo llevara, sería «la pata real» para los ~45 consumidores de ese campo).
//
//  IDENTIDAD ESTABLE. El `transferPairID` del par es el id de la línea: dos aparatos que crean la misma recarga crean el
//  mismo par, y la entrada se encuentra por la marca aunque llegue antes que su salida o aunque
//  `TransferPairReconcileService` le haya quitado el par. Una pata que ya existe se actualiza en sitio
//  (preserve+update); solo se borra y se rehace si está duplicada o le falta su pareja.
//
//  BORRAR UNA PATA DEL GASTO BORRA SU ENTRADA. `deleteLegWithEntries` y `derivedEntries(of:)` son el único camino:
//  la entrada no lleva `splitExpenseID`, así que ningún borrado por ese campo la alcanza solo.
//

import Foundation
import OSLog
import SwiftData

extension GroupTransactionBridge {

    private static var splitLinesLogger: Logger { Logger(subsystem: "com.yala", category: "GroupBridge") }

    // MARK: - Resolución

    /// Las cuentas destino de una receta, por `shortcutID`. Las que no están aquí simplemente faltan.
    static func splitLineDestinations(
        for stored: GroupSplitLinesRecipe.Stored, context: ModelContext
    ) throws -> [UUID: Account] {
        var result: [UUID: Account] = [:]
        for id in GroupSplitLinesBridgeLogic.destinationIDs(in: stored) {
            var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.shortcutID == id })
            descriptor.fetchLimit = 1
            if let account = try context.fetch(descriptor).first { result[id] = account }
        }
        return result
    }

    /// La subcategoría de una línea de gasto, por su `shortcutID`. `nil` si aquí no existe (todavía).
    static func subcategory(shortcutID: UUID, context: ModelContext) throws -> Subcategory? {
        var descriptor = FetchDescriptor<Subcategory>(predicate: #Predicate { $0.shortcutID == shortcutID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Las ENTRADAS de recarga que cuelgan de esta pata: las de su `transferPairID` y las de su marca y, si la pata lleva
    /// la receta y `includeRecipeLines`, las de cada recarga de la receta. Solo filas sin puntero de grupo que llevan una
    /// marca de línea: ninguna transferencia del usuario.
    static func derivedEntries(
        of leg: TransactionItem, includeRecipeLines: Bool = true, context: ModelContext
    ) throws -> [TransactionItem] {
        var lineIDs: Set<UUID> = []
        if let pair = leg.transferPairID, let id = UUID(uuidString: pair) { lineIDs.insert(id) }
        switch GroupSplitLinesRecipe.parse(leg.splitLinesRaw) {
        case let .derived(lineID):
            lineIDs.insert(lineID)
        case let .recipe(lines):
            if includeRecipeLines { for line in lines where line.kind == .transfer { lineIDs.insert(line.id) } }
        case .none, .newerVersion, .unreadable:
            break
        }
        var result: [TransactionItem] = []
        var seen: Set<PersistentIdentifier> = [leg.persistentModelID]
        for lineID in lineIDs {
            for entry in try entries(lineID: lineID, context: context) where seen.insert(entry.persistentModelID).inserted {
                result.append(entry)
            }
        }
        return result
    }

    /// Las entradas de la recarga `lineID`: por par y por marca, sin puntero de grupo y con la marca de una línea, en el
    /// orden en que dos aparatos eligen superviviente.
    static func entries(lineID: UUID, context: ModelContext) throws -> [TransactionItem] {
        let pairID = lineID.uuidString
        let marker = GroupSplitLinesRecipe.encodeDerivedMarker(lineID: lineID)
        let byPair = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.transferPairID == pairID }))
        let byMarker = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitLinesRaw == marker }))
        var seen: Set<PersistentIdentifier> = []
        return (byPair + byMarker).filter { tx in
            tx.splitExpenseID == nil && tx.splitSettlementID == nil && !tx.isDeleted
                && GroupSplitLinesBridgeLogic.isDerivedMarker(tx.splitLinesRaw)
                && seen.insert(tx.persistentModelID).inserted
        }.sorted(by: GroupSplitLinesBridgeLogic.survivorFirst)
    }

    /// Las recargas que una receta necesita: sus entradas no se borran al borrar una pata, porque otra pata de la misma
    /// pasada las va a reutilizar (la ancla cambió, o una pata duplicada sale). Vacío si no es una receta.
    static func transferLineIDs(in raw: String?) -> Set<UUID> {
        guard case let .recipe(lines) = GroupSplitLinesRecipe.parse(raw) else { return [] }
        return Set(lines.filter { $0.kind == .transfer }.map(\.id))
    }

    /// Las recargas de un plan, la ancla incluida.
    static func transferLineIDs(in plan: GroupSplitLinesBridgeLogic.Plan?) -> Set<UUID> {
        guard let plan else { return [] }
        return Set(([plan.anchor].compactMap { $0 } + plan.derived).filter { $0.kind == .transfer }.map(\.id))
    }

    /// Borra una pata del gasto y las entradas de recarga que cuelgan de ella, salvo las de `keep`.
    func deleteLegWithEntries(_ leg: TransactionItem, keep: Set<UUID> = [], context: ModelContext) throws {
        guard !leg.isDeleted else { return }
        for entry in try Self.derivedEntries(of: leg, context: context) {
            if let lineID = GroupSplitLinesBridgeLogic.entryLineID(entry), keep.contains(lineID) { continue }
            context.delete(entry)
        }
        context.delete(leg)
    }

    // MARK: - Barridos que sueltan o borran patas

    /// Para los caminos que SUELTAN una pata del puente (desasociar, huérfanas, retirada de Grupos legacy): la pata
    /// pierde la receta o la marca, y la entrada de SU recarga (la de su par o su marca, no las de la receta: esas siguen
    /// la suerte de su salida) se queda como una transferencia normal. Si no se puede leer, se queda como estaba y lo dice.
    static func releaseSplitLines(of leg: TransactionItem, context: ModelContext) {
        do {
            for entry in try derivedEntries(of: leg, includeRecipeLines: false, context: context) {
                entry.splitLinesRaw = nil
            }
        } catch {
            splitLinesLogger.error("releaseSplitLines: entries unreadable \(String(describing: type(of: error)), privacy: .public)")
            #if DEBUG
            print("GroupTransactionBridge: Error: releaseSplitLines \(error)")
            #endif
        }
        leg.splitLinesRaw = nil
    }

    /// Para los caminos que BORRAN una pata del puente fuera de `bridgeExpense`: borra antes la entrada de su recarga,
    /// que no lleva puntero de grupo (D4) y quedaría como media transferencia.
    static func deleteSplitLineEntries(of leg: TransactionItem, context: ModelContext) {
        do {
            for entry in try derivedEntries(of: leg, context: context) where !entry.isDeleted { context.delete(entry) }
        } catch {
            splitLinesLogger.error("deleteSplitLineEntries: entries unreadable \(String(describing: type(of: error)), privacy: .public)")
            #if DEBUG
            print("GroupTransactionBridge: Error: deleteSplitLineEntries \(error)")
            #endif
        }
    }

    // MARK: - Pata conservada del Caso B

    /// La pata conservada del Caso B deja de ser una recarga: vuelve a ser tu parte en una línea, sin categoría (la
    /// rellena el puente o el puntero de la Bandeja), y su entrada se borra salvo que otra pata la reutilice (`keep`).
    func revertTransferShape(of holder: TransactionItem, keep: Set<UUID>, context: ModelContext) throws {
        if let pair = holder.transferPairID, let lineID = UUID(uuidString: pair), !keep.contains(lineID) {
            for entry in try Self.entries(lineID: lineID, context: context) { context.delete(entry) }
        }
        holder.balanceAdjustmentType = nil
        holder.transferPairID = nil
        holder.subcategory = nil
        holder.category = nil
    }

    /// Caso B con receta: la pata conservada toma la forma de la línea ancla. Un gasto, con su categoría; una recarga,
    /// como la salida de un par cuya entrada va a la cuenta destino. El importe ya lo puso el upsert del Caso B. Si antes
    /// era la salida de OTRA recarga que ya no está en la receta, la entrada de aquella se va.
    func applyAnchor(
        _ anchor: GroupSplitLinesRecipe.Line?,
        toCaseBHolder holder: TransactionItem,
        keep: Set<UUID>,
        expense: SplitExpense,
        destinations: [UUID: Account],
        context: ModelContext
    ) throws {
        guard let anchor else { return }
        if let pair = holder.transferPairID, let previous = UUID(uuidString: pair), previous != anchor.id,
           !keep.contains(previous) {
            for entry in try Self.entries(lineID: previous, context: context) { context.delete(entry) }
        }
        switch anchor.kind {
        case .expense:
            if let subcategoryID = anchor.subcategoryID,
               let subcat = try Self.subcategory(shortcutID: subcategoryID, context: context) {
                holder.subcategory = subcat
                holder.category = subcat.safeCategory
            }
        case .transfer:
            guard let destinationID = anchor.destinationAccountID, let destination = destinations[destinationID] else { return }
            let outflow = try TransferCategoryResolver.outflow(context: context)
            holder.subcategory = outflow
            holder.category = outflow.safeCategory
            holder.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            holder.transferPairID = anchor.id.uuidString
            try upsertEntry(for: anchor, destination: destination, expense: expense, context: context)
        }
    }

    // MARK: - Patas derivadas

    /// Deja las patas derivadas como dice `plan`: una por línea derivada (y su entrada si es una recarga), actualizadas
    /// en sitio. Sin plan, ninguna. Lo que sobra se borra con sus entradas, salvo las que otra pata del plan reutiliza.
    /// Las líneas de gasto heredan las etiquetas de la pata conservada (`holder`): tu parte entera lleva tus etiquetas.
    func reconcileDerivedLegs(
        expense: SplitExpense,
        plan: GroupSplitLinesBridgeLogic.Plan?,
        existing: [TransactionItem],
        holder: TransactionItem?,
        virtualAccount: Account,
        destinations: [UUID: Account],
        context: ModelContext
    ) throws {
        let wanted = plan?.derived ?? []
        let wantedIDs = Set(wanted.map(\.id))
        let keep = Self.transferLineIDs(in: plan)
        var byLine: [UUID: [TransactionItem]] = [:]
        for leg in existing where !leg.isDeleted {
            if let lineID = GroupSplitLinesBridgeLogic.derivedLineID(leg.splitLinesRaw), wantedIDs.contains(lineID) {
                byLine[lineID, default: []].append(leg)
            } else {
                try deleteLegWithEntries(leg, keep: keep, context: context)
            }
        }

        let holderTags: [Tag]
        if let holder, !holder.isDeleted, wanted.contains(where: { $0.kind == .expense }) {
            holderTags = TagResolver.fetchOrEmpty(
                ids: holder.resolvedTagIDs() ?? [], in: context, errorContext: "GroupTransactionBridge/splitLines")
        } else {
            holderTags = []
        }

        for line in wanted {
            // Copias de la misma línea (dos aparatos a la vez): los dos conservan la misma y borran el resto.
            let legs = (byLine[line.id] ?? []).sorted(by: GroupSplitLinesBridgeLogic.survivorFirst)
            let leg: TransactionItem
            if let survivor = legs.first {
                for duplicate in legs.dropFirst() { context.delete(duplicate) }
                leg = survivor
            } else {
                leg = TransactionItem(date: expense.date, amount: 0, currencyCode: expense.currencyCode)
                context.insert(leg)
            }
            try writeDerivedLeg(leg, line: line, expense: expense, virtualAccount: virtualAccount,
                                tags: holderTags, context: context)
            if line.kind == .transfer {
                if let destinationID = line.destinationAccountID, let destination = destinations[destinationID] {
                    try upsertEntry(for: line, destination: destination, expense: expense, context: context)
                }
            } else {
                // Una línea de gasto no tiene entrada: lo que cuelgue de su id sobra (la línea cambió de tipo).
                for entry in try Self.entries(lineID: line.id, context: context) { context.delete(entry) }
            }
        }
    }

    /// Escribe una pata derivada en «Grupos». Solo los campos del puente: es una pata del gasto, no un registro suelto.
    private func writeDerivedLeg(
        _ leg: TransactionItem,
        line: GroupSplitLinesRecipe.Line,
        expense: SplitExpense,
        virtualAccount: Account,
        tags: [Tag],
        context: ModelContext
    ) throws {
        leg.amount = -GroupSplitLinesBridgeLogic.double(line.amount)
        leg.date = expense.date
        leg.currencyCode = expense.currencyCode
        leg.note = expense.expenseDescription.isEmpty ? nil : expense.expenseDescription
        if leg.account?.persistentModelID != virtualAccount.persistentModelID { leg.account = virtualAccount }
        leg.splitExpenseID = expense.id.uuidString
        leg.splitGroupZoneID = expense.groupZoneID
        leg.splitTotalAmount = expense.amount
        leg.splitType = expense.splitType
        leg.splitLinesRaw = GroupSplitLinesRecipe.encodeDerivedMarker(lineID: line.id)
        switch line.kind {
        case .expense:
            if let subcategoryID = line.subcategoryID,
               let subcat = try Self.subcategory(shortcutID: subcategoryID, context: context) {
                leg.subcategory = subcat
                leg.category = subcat.safeCategory
            }
            leg.balanceAdjustmentType = nil
            leg.transferPairID = nil
            if Set(tags.map(\.id)) != (leg.resolvedTagIDs() ?? []) { leg.setTags(from: tags) }
        case .transfer:
            let outflow = try TransferCategoryResolver.outflow(context: context)
            leg.subcategory = outflow
            leg.category = outflow.safeCategory
            leg.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            leg.transferPairID = line.id.uuidString
        }
        leg.recalculatePreferredCurrency(context: context)
    }

    /// La entrada de una recarga en su cuenta destino: crea o actualiza la única que debe haber. Con copias, los dos
    /// aparatos conservan la misma.
    private func upsertEntry(
        for line: GroupSplitLinesRecipe.Line,
        destination: Account,
        expense: SplitExpense,
        context: ModelContext
    ) throws {
        let existing = try Self.entries(lineID: line.id, context: context)
        let entry: TransactionItem
        if let survivor = existing.first {
            for duplicate in existing.dropFirst() { context.delete(duplicate) }
            entry = survivor
        } else {
            entry = TransactionItem(date: expense.date, amount: 0, currencyCode: expense.currencyCode)
            context.insert(entry)
        }
        let inflow = try TransferCategoryResolver.inflow(context: context)
        entry.amount = GroupSplitLinesBridgeLogic.double(line.amount)
        entry.date = expense.date
        entry.currencyCode = expense.currencyCode
        entry.note = expense.expenseDescription.isEmpty ? nil : expense.expenseDescription
        if entry.account?.persistentModelID != destination.persistentModelID { entry.account = destination }
        entry.subcategory = inflow
        entry.category = inflow.safeCategory
        entry.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        entry.transferPairID = line.id.uuidString
        entry.splitLinesRaw = GroupSplitLinesRecipe.encodeDerivedMarker(lineID: line.id)
        entry.recalculatePreferredCurrency(context: context)
    }

    // MARK: - Aviso de «no cuadra» (D6)

    /// El gasto cambió y las líneas ya no suman tu parte: tu parte quedó en una línea y la Bandeja lo avisa. Pide la
    /// categoría de esa línea; aprobarlo retira la receta (`DraftService`). Durante una aprobación en vuelo
    /// (`skipDraftCleanup`) no se duplica el que ya está.
    func createSplitLinesMismatchDraft(
        expense: SplitExpense,
        holder: TransactionItem?,
        myShareAmount: Double,
        groupName: String,
        existingPendingDrafts: [InboxDraft],
        context: ModelContext
    ) {
        if skipDraftCleanup, existingPendingDrafts.contains(where: \.isSplitLinesMismatchNotice) { return }
        let draft = InboxDraft(
            note: expense.expenseDescription,
            amount: -myShareAmount,
            date: expense.date,
            account: holder?.account,
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
            targetTransactionID: nil,
            originReasonKey: DraftOriginReason.splitLinesMismatch.rawValue,
            originActorName: nil,
            originGroupName: groupName
        )
        context.insert(draft)
        Self.splitLinesLogger.notice("splitLines: mismatch notice created")
    }
}
