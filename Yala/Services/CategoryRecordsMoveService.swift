//
//  CategoryRecordsMoveService.swift
//  Yala
//
//  «Mover sus registros…» de una categoría que no se puede borrar porque tiene registros
//  (auditoría UX 2.2, lote 7, L7-10). Antes la única salida era vaciarla subcategoría por subcategoría.
//

import Foundation
import SwiftData

@MainActor
enum CategoryRecordsMoveService {

    enum Failure: Error, Equatable {
        /// Las categorías sistema del bridge de grupos no se tocan.
        case systemCategory
        /// El destino es de la propia categoría, es de sistema o es del otro tipo (ingreso / gasto).
        case invalidDestination
    }

    /// Un sitio al que se pueden mover los registros: una subcategoría de otra categoría.
    struct Destination: Identifiable {
        let category: Category
        let subcategories: [Subcategory]
        var id: PersistentIdentifier { category.persistentModelID }
    }

    // MARK: - Qué hay dentro

    /// Los registros de la categoría: los que la llevan y los que llevan una de sus subcategorías.
    ///
    /// Las dos vías, y no solo `category`: un registro antiguo puede tener la subcategoría y no la categoría, y
    /// borrar la categoría lo dejaría sin ninguna de las dos. **Lanza** si no puede leer: un recuento a cero por
    /// error abriría el borrado de una categoría con registros.
    static func records(of category: Category, context: ModelContext) throws -> [TransactionItem] {
        let categoryID = category.persistentModelID
        var byID: [PersistentIdentifier: TransactionItem] = [:]
        let direct = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { $0.category?.persistentModelID == categoryID }))
        for row in direct { byID[row.persistentModelID] = row }
        for subcategory in category.subcategories ?? [] {
            let subcategoryID = subcategory.persistentModelID
            let rows = try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { $0.subcategory?.persistentModelID == subcategoryID }))
            for row in rows { byID[row.persistentModelID] = row }
        }
        return Array(byID.values)
    }

    static func recordCount(of category: Category, context: ModelContext) throws -> Int {
        try records(of: category, context: context).count
    }

    // MARK: - A dónde

    /// Las subcategorías que pueden recibir los registros: visibles, de otra categoría del mismo tipo
    /// (gasto con gasto, ingreso con ingreso) y que no sean de sistema (ajustes de saldo, transferencias, grupos).
    static func destinations(for category: Category, among subcategories: [Subcategory]) -> [Destination] {
        let sourceID = category.persistentModelID
        let candidates = subcategories.filter { subcategory in
            guard subcategory.isVisible, !subcategory.isAnySystem, let parent = subcategory.category else {
                return false
            }
            return parent.persistentModelID != sourceID && !parent.isSystem && parent.isIncome == category.isIncome
        }
        let grouped = Dictionary(grouping: candidates) { $0.category?.persistentModelID }
        return grouped.compactMap { _, subs -> Destination? in
            guard let parent = subs.first?.category else { return nil }
            let sorted = subs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return Destination(category: parent, subcategories: sorted)
        }
        .sorted { lhs, rhs in
            if lhs.category.sortOrder != rhs.category.sortOrder { return lhs.category.sortOrder < rhs.category.sortOrder }
            return lhs.category.name.localizedCaseInsensitiveCompare(rhs.category.name) == .orderedAscending
        }
    }

    static func isValidDestination(_ destination: Subcategory, for category: Category) -> Bool {
        guard let parent = destination.category, !destination.isAnySystem, !parent.isSystem else { return false }
        return parent.persistentModelID != category.persistentModelID && parent.isIncome == category.isIncome
    }

    // MARK: - Mover y eliminar

    /// Una categoría que guarda subcategorías de sistema («Ajustes de saldo», «Transferencia entre cuentas») no se
    /// mueve ni se borra: sus registros son saldos iniciales, ajustes y transferencias, y pasarían a contarse como
    /// gastos de la subcategoría destino. Es el caso de «Otros» e «Ingresos» (review de UX 2.2 · L7-10).
    static func holdsSystemSubcategories(_ category: Category) -> Bool {
        (category.subcategories ?? []).contains { $0.isAnySystem }
    }

    /// Mueve a `destination` TODO lo que cuelga de la categoría —registros, pagos planificados, favoritos,
    /// borradores pendientes de la Bandeja, presupuestos, líneas del flujo de caja y lo aprendido de los comercios—
    /// y después elimina la categoría con sus subcategorías, en un solo guardado. Devuelve cuántos registros movió.
    ///
    /// **Se vuelve a leer todo aquí**, no se fía del recuento que enseñó la confirmación: entre la pregunta y el
    /// «sí» pudo llegar un registro por sync, y con el recuento viejo se quedaría sin categoría.
    ///
    /// **Primero se lee todo y después se escribe.** Si una lectura falla no se ha tocado nada; si falla el borrado,
    /// las asignaciones se devuelven a mano a su valor de antes (no `rollback()`: el contexto es el compartido y se
    /// llevaría otras ediciones).
    ///
    /// Decidido por la sesión (2026-10-17): **el presupuesto sigue a sus registros.** Uno que contaba subcategorías
    /// de la categoría pasa a contar la subcategoría destino en su lugar; si no, al borrarlas se quedaba sin filtro
    /// de subcategoría y contaba todo el gasto, o en cero. Y una línea del flujo de caja que llega a un destino que ya
    /// tiene la suya se apaga en vez de duplicar su previsión (se conserva, por si tenía un importe a mano).
    @discardableResult
    static func moveAllAndDelete(
        from category: Category,
        to destination: Subcategory,
        context: ModelContext,
        deletionService: EntityDeletionService
    ) throws -> Int {
        guard !category.isSystem, !holdsSystemSubcategories(category) else { throw Failure.systemCategory }
        guard isValidDestination(destination, for: category) else { throw Failure.invalidDestination }
        let destinationCategory = destination.category
        let sourceCategoryID = category.persistentModelID
        let sourceSubcategories = category.subcategories ?? []
        let sourceIDs = Set(sourceSubcategories.map(\.persistentModelID))
        let sourceShortcutIDs = Set(sourceSubcategories.map(\.shortcutID))
        func isSource(_ subcategory: Subcategory?) -> Bool {
            subcategory.map { sourceIDs.contains($0.persistentModelID) } ?? false
        }

        // 1 · Leer.
        let rows = try records(of: category, context: context)
        let payments = try context.fetch(FetchDescriptor<ScheduledPayment>()).filter { isSource($0.subcategory) }
        let favorites = try context.fetch(FetchDescriptor<FavoritePayment>()).filter { isSource($0.subcategory) }
        let pending = DraftStatus.pending.rawValue
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.statusRaw == pending }))
            .filter { isSource($0.subcategory) }
        let memories = try context.fetch(FetchDescriptor<MerchantMemory>()).filter { isSource($0.subcategory) }
        let allLines = try context.fetch(FetchDescriptor<CashFlowLine>())
        let movedLines = allLines.filter { line in
            isSource(line.subcategory) || line.category?.persistentModelID == sourceCategoryID
        }
        let budgets = try context.fetch(FetchDescriptor<Budget>()).filter { budget in
            let csv = CSVMirrorCodec.decode(budget.subcategoryIDs) ?? []
            return !csv.isDisjoint(with: sourceShortcutIDs) || (budget.subcategories ?? []).contains { isSource($0) }
        }

        // 2 · Escribir, apuntando cómo estaba cada cosa.
        var undo: [() -> Void] = []
        for row in rows {
            let (oldSub, oldCat) = (row.subcategory, row.category)
            undo.append { row.subcategory = oldSub; row.category = oldCat }
            row.subcategory = destination
            row.category = destinationCategory
        }
        for payment in payments {
            let old = payment.subcategory
            undo.append { payment.subcategory = old }
            payment.subcategory = destination
        }
        for favorite in favorites {
            let old = favorite.subcategory
            undo.append { favorite.subcategory = old }
            favorite.subcategory = destination
        }
        for draft in drafts {
            let old = draft.subcategory
            undo.append { draft.subcategory = old }
            draft.subcategory = destination
        }
        for memory in memories {
            let old = memory.subcategory
            undo.append { memory.subcategory = old }
            memory.subcategory = destination
        }
        for line in movedLines {
            let (oldSub, oldCat, oldEnabled) = (line.subcategory, line.category, line.isEnabled)
            undo.append { line.subcategory = oldSub; line.category = oldCat; line.isEnabled = oldEnabled }
            let atSubcategory = line.subcategory != nil
            let destinationHasLine = allLines.contains { other in
                other !== line && !movedLines.contains { $0 === other } && other.plan === line.plan && (atSubcategory
                    ? other.subcategory?.persistentModelID == destination.persistentModelID
                    : (other.subcategory == nil
                        && other.category?.persistentModelID == destinationCategory?.persistentModelID))
            }
            if atSubcategory {
                line.subcategory = destination
                line.category = destinationCategory
            } else {
                line.category = destinationCategory
            }
            if destinationHasLine { line.isEnabled = false }
        }
        for budget in budgets {
            let (oldRelation, oldCSV) = (budget.subcategories, budget.subcategoryIDs)
            undo.append { budget.subcategories = oldRelation; budget.subcategoryIDs = oldCSV }
            // Del CSV y no solo de la relación: la relación puede no estar cargada todavía (CloudKit) y reescribir
            // el espejo desde ella borraría filtros que sí tenía.
            var csv = (CSVMirrorCodec.decode(budget.subcategoryIDs) ?? []).subtracting(sourceShortcutIDs)
            csv.insert(destination.shortcutID)
            var relation = (budget.subcategories ?? []).filter { !isSource($0) }
            if !relation.contains(where: { $0.persistentModelID == destination.persistentModelID }) {
                relation.append(destination)
            }
            budget.subcategories = relation
            budget.subcategoryIDs = CSVMirrorCodec.encode(csv)
        }

        // 3 · Borrar. `deleteCategory` borra la categoría y sus subcategorías y guarda: lo de arriba va en ese
        // mismo guardado.
        deletionService.setContext(context)
        do {
            try deletionService.deleteCategory(category, withSubcategories: sourceSubcategories)
        } catch {
            for revert in undo.reversed() { revert() }
            throw error
        }
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
        return rows.count
    }
}
