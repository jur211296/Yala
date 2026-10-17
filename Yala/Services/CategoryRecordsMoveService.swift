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

    /// Mueve a `destination` TODO lo que cuelga de la categoría —registros, pagos planificados, favoritos y
    /// borradores pendientes de la Bandeja— y después elimina la categoría con sus subcategorías, en un solo
    /// guardado. Devuelve cuántos registros movió.
    ///
    /// **Se vuelve a leer todo aquí**, no se fía del recuento que enseñó la confirmación: entre la pregunta y el
    /// «sí» pudo llegar un registro por sync, y con el recuento viejo se quedaría sin categoría.
    ///
    /// Los planificados, favoritos y borradores se mueven también porque, si no, al borrar las subcategorías se
    /// quedarían sin ninguna (la relación se anula) y el próximo pago nacería sin categoría.
    @discardableResult
    static func moveAllAndDelete(
        from category: Category,
        to destination: Subcategory,
        context: ModelContext,
        deletionService: EntityDeletionService
    ) throws -> Int {
        guard !category.isSystem else { throw Failure.systemCategory }
        guard isValidDestination(destination, for: category) else { throw Failure.invalidDestination }
        let destinationCategory = destination.category

        let rows = try records(of: category, context: context)
        for row in rows {
            row.subcategory = destination
            row.category = destinationCategory
        }

        let sourceSubcategories = category.subcategories ?? []
        let sourceIDs = Set(sourceSubcategories.map(\.persistentModelID))
        if !sourceIDs.isEmpty {
            for payment in try context.fetch(FetchDescriptor<ScheduledPayment>())
            where payment.subcategory.map({ sourceIDs.contains($0.persistentModelID) }) == true {
                payment.subcategory = destination
            }
            for favorite in try context.fetch(FetchDescriptor<FavoritePayment>())
            where favorite.subcategory.map({ sourceIDs.contains($0.persistentModelID) }) == true {
                favorite.subcategory = destination
            }
            let pending = DraftStatus.pending.rawValue
            for draft in try context.fetch(
                FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.statusRaw == pending }))
            where draft.subcategory.map({ sourceIDs.contains($0.persistentModelID) }) == true {
                draft.subcategory = destination
            }
        }

        // `deleteCategory` borra la categoría y sus subcategorías y guarda: los movimientos de arriba van en
        // ese mismo guardado.
        deletionService.setContext(context)
        try deletionService.deleteCategory(category, withSubcategories: sourceSubcategories)
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
        return rows.count
    }
}
