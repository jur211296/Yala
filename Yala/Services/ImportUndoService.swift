//
//  ImportUndoService.swift
//  Yala
//
//  «Deshacer importación» (H12 de la auditoría del import 2.2, ticket `import-cannot-be-undone`). Hasta el 2026-11-22,
//  para quitar 3.000 movimientos mal importados había que borrarlos a mano: ningún movimiento sabe de qué import vino.
//
//  Es la opción barata que recomendaba el ticket, sin cambio de esquema: al guardar un import se apunta en un fichero
//  del dispositivo lo que creó —movimientos, categorías, subcategorías, etiquetas y cuentas— y las fechas de saldo
//  inicial que retrocedió, y durante 24 h se puede deshacer. El borrado es el de siempre (`context.delete` + `save`,
//  como `TransactionService`), así que en modo nube viaja como cualquier otro borrado.
//
//  Dos cosas que no se tocan sin pensarlo:
//  - **No se usa `model(for:)`**: fabrica un objeto aunque ya no exista. Los movimientos se leen por la ventana de
//    `createdAt` del import y se reconocen por su instante de creación, fecha e importe; lo demás, de su tabla entera
//    (son pocas filas) y por su identidad estable. **No se guardan `PersistentIdentifier`**: medido el 2026-11-22, con ellos
//    el deshacer no encontraba nada, tampoco el saldo inicial ya guardado (no se aisló si por la vuelta por JSON).
//  - **Lo creado que ya se usa se queda**: una categoría, etiqueta o cuenta que tiene algo más que lo importado (un
//    movimiento escrito a mano, un presupuesto) no se borra.
//

import Foundation
import SwiftData

/// Lo que hace falta para deshacer el último import.
struct ImportUndoRecord: Codable, Equatable {
    /// Cuándo se guardó el import. Caduca a las 24 h.
    let importedAt: Date
    /// La ventana de `createdAt` de los movimientos que creó: el import corre en el hilo principal sin suspenderse, así
    /// que todo lo que creó nace dentro.
    let windowStart: Date
    let windowEnd: Date
    let transactions: [TransactionKey]
    /// Las categorías creadas, por nombre y naturaleza (una categoría no tiene otra identidad obligatoria).
    let categories: [CategoryKey]
    let subcategoryIDs: [UUID]
    let tagIDs: [UUID]
    let accountIDs: [UUID]
    /// Los saldos iniciales cuya fecha retrocedió el import (por la cuenta), con la fecha que tenían.
    let initialBalanceDates: [InitialBalanceDate]

    /// Un movimiento creado: el instante exacto en que nació, su fecha y su importe.
    struct TransactionKey: Codable, Hashable {
        let createdAt: Date
        let date: Date
        let amount: Double
    }

    struct CategoryKey: Codable, Hashable {
        let name: String
        let isIncome: Bool
    }

    struct InitialBalanceDate: Codable, Equatable {
        let accountID: UUID
        let previousDate: Date
    }

    static let lifetime: TimeInterval = 24 * 60 * 60

    var count: Int { transactions.count }

    func isValid(now: Date) -> Bool {
        count > 0 && now >= importedAt && now.timeIntervalSince(importedAt) < Self.lifetime
    }
}

/// Lo que hizo el deshacer.
struct ImportUndoOutcome: Equatable {
    let deletedTransactions: Int
    let deletedCategories: Int
    let deletedTags: Int
    let deletedAccounts: Int
}

@MainActor
enum ImportUndoService {

    /// Dónde vive el registro. Los tests lo apuntan a su carpeta.
    static var fileURL: URL = defaultURL

    static var defaultURL: URL {
        let base: URL
        do {
            base = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            #if DEBUG
            print("ImportUndoService: Error: \(error)")
            #endif
            base = FileManager.default.temporaryDirectory
        }
        return base.appendingPathComponent("ImportUndo", isDirectory: true).appendingPathComponent("ultimo.json")
    }

    // MARK: - Leer y olvidar

    /// El último import si aún se puede deshacer; uno caducado se olvida.
    static func current(now: Date = .now) -> ImportUndoRecord? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let record = try JSONDecoder().decode(ImportUndoRecord.self, from: data)
            guard record.isValid(now: now) else {
                forget()
                return nil
            }
            return record
        } catch {
            #if DEBUG
            print("ImportUndoService: Error: \(error)")
            #endif
            forget()
            return nil
        }
    }

    static func forget() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            #if DEBUG
            print("ImportUndoService: Error: \(error)")
            #endif
        }
    }

    static func save(_ record: ImportUndoRecord) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(record).write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("ImportUndoService: Error: \(error)")
            #endif
        }
    }

    // MARK: - Importar y apuntar

    /// Importa y guarda como `importAndSave` y, si entró algo, apunta lo creado para poder deshacerlo. Un import nuevo
    /// sustituye al anterior: solo se deshace el último.
    static func importAndRemember(
        in context: ModelContext,
        now: @escaping () -> Date = { .now },
        _ work: () async throws -> TransactionImportResult
    ) async throws -> TransactionImportResult {
        let windowStart = now()
        var inserted: [any PersistentModel] = []
        let result = try await TransactionCSVImportService.importAndSave(
            in: context, beforeSave: { inserted = $0.insertedModelsArray }, work)
        let windowEnd = now()
        let transactions = inserted.compactMap { $0 as? TransactionItem }
        guard !transactions.isEmpty else { return result }
        save(ImportUndoRecord(
            importedAt: windowEnd,
            windowStart: windowStart,
            windowEnd: windowEnd,
            transactions: transactions.map {
                ImportUndoRecord.TransactionKey(createdAt: $0.createdAt, date: $0.date, amount: $0.amount)
            },
            categories: inserted.compactMap {
                ($0 as? Category).map { ImportUndoRecord.CategoryKey(name: $0.name, isIncome: $0.isIncome) }
            },
            subcategoryIDs: inserted.compactMap { ($0 as? Subcategory)?.shortcutID },
            tagIDs: inserted.compactMap { ($0 as? Tag)?.id },
            accountIDs: inserted.compactMap { ($0 as? Account)?.shortcutID },
            initialBalanceDates: result.initialBalanceChanges.compactMap { change in
                guard let account = change.transaction.account else { return nil }
                return ImportUndoRecord.InitialBalanceDate(accountID: account.shortcutID, previousDate: change.previousDate)
            }
        ))
        return result
    }

    // MARK: - Deshacer

    enum UndoError: Error, Equatable {
        case nothingToUndo
    }

    /// Cuántos movimientos se borran por guardado. Medido el 2026-11-22 en el simulador: guardar el borrado de 3.000 de
    /// una vez tardaba 3,5 s en el hilo principal y el de 10.000, 33 s (crece más que lineal). Por tandas, con una vuelta
    /// del hilo principal entre una y otra, la pantalla sigue respondiendo y enseña el avance.
    static let batchSize = 100

    /// Borra lo que creó el último import y devuelve las fechas de saldo inicial. Guarda por tandas; si una falla, deshace
    /// esa tanda y relanza: lo ya borrado se queda borrado y el registro sigue, así que volver a pedirlo termina el resto.
    @discardableResult
    static func undo(
        in context: ModelContext, now: Date = .now, progress: (Int, Int) -> Void = { _, _ in }
    ) async throws -> ImportUndoOutcome {
        guard let record = current(now: now) else { throw UndoError.nothingToUndo }
        // Lo pendiente de otra pantalla se guarda antes: el rollback de un fallo solo puede llevarse lo de aquí.
        if context.hasChanges { try context.save() }
        do {
            let outcome = try await performUndo(record, in: context, progress: progress)
            forget()
            return outcome
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Borra `transactions` por tandas de `batchSize`, guardando cada una y cediendo el hilo principal entre ellas.
    static func undoInBatches(
        in context: ModelContext, matching transactions: [TransactionItem], progress: (Int, Int) -> Void = { _, _ in }
    ) async throws -> ImportUndoOutcome {
        var done = 0
        for start in stride(from: 0, to: transactions.count, by: batchSize) {
            for transaction in transactions[start..<min(start + batchSize, transactions.count)] {
                context.delete(transaction)
            }
            try context.save()
            done = min(start + batchSize, transactions.count)
            progress(done, transactions.count)
            await Task.yield()
        }
        return ImportUndoOutcome(deletedTransactions: done, deletedCategories: 0, deletedTags: 0, deletedAccounts: 0)
    }

    private static func performUndo(
        _ record: ImportUndoRecord, in context: ModelContext, progress: (Int, Int) -> Void
    ) async throws -> ImportUndoOutcome {
        // 1. Los movimientos, por la ventana del import y su huella (contando: dos iguales nacidos en el mismo instante
        // son dos).
        let start = record.windowStart
        let end = record.windowEnd
        var wanted: [ImportUndoRecord.TransactionKey: Int] = [:]
        for key in record.transactions { wanted[key, default: 0] += 1 }
        let candidates = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.createdAt >= start && $0.createdAt <= end }))
        var imported: [TransactionItem] = []
        for transaction in candidates {
            let key = ImportUndoRecord.TransactionKey(
                createdAt: transaction.createdAt, date: transaction.date, amount: transaction.amount)
            // Si la persona cambió la fecha o el importe después, se reconoce por el instante en que nació.
            let match = wanted[key].map { _ in key }
                ?? wanted.first { $0.key.createdAt == transaction.createdAt && $0.value > 0 }?.key
            guard let match, let left = wanted[match], left > 0 else { continue }
            wanted[match] = left - 1
            imported.append(transaction)
        }
        _ = try await undoInBatches(in: context, matching: imported, progress: progress)

        // 2. Las fechas de saldo inicial que el import retrocedió, si siguen donde las dejó (o antes).
        if !record.initialBalanceDates.isEmpty {
            let previous = Dictionary(
                record.initialBalanceDates.map { ($0.accountID, $0.previousDate) }, uniquingKeysWith: { a, _ in a })
            let initials = try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.balanceAdjustmentType == "initial_balance" }))
            for transaction in initials {
                guard let accountID = transaction.account?.shortcutID, let date = previous[accountID],
                      transaction.date < date else { continue }
                transaction.date = date
            }
        }
        if context.hasChanges { try context.save() }

        // 3. Lo creado que ya nada usa.
        let subcategoryIDs = Set(record.subcategoryIDs)
        var deletedSubcategories: [Subcategory] = []
        for subcategory in try context.fetch(FetchDescriptor<Subcategory>())
        where subcategoryIDs.contains(subcategory.shortcutID) && isUnused(subcategory) {
            context.delete(subcategory)
            deletedSubcategories.append(subcategory)
        }
        let categoryKeys = Set(record.categories)
        var deletedCategories = 0
        for category in try context.fetch(FetchDescriptor<Category>())
        where categoryKeys.contains(.init(name: category.name, isIncome: category.isIncome))
            && isUnused(category, ignoring: deletedSubcategories) {
            context.delete(category)
            deletedCategories += 1
        }
        let tagIDs = Set(record.tagIDs)
        var deletedTags = 0
        for tag in try context.fetch(FetchDescriptor<Tag>()) where tagIDs.contains(tag.id) && isUnused(tag) {
            context.delete(tag)
            deletedTags += 1
        }
        let accountIDs = Set(record.accountIDs)
        var deletedAccounts = 0
        let allAccounts = try context.fetch(FetchDescriptor<Account>())
        for account in allAccounts where accountIDs.contains(account.shortcutID) {
            let hasLines = allAccounts.contains { $0.parentAccountID == account.shortcutID }
            guard !hasLines, isUnused(account) else { continue }
            context.delete(account)
            deletedAccounts += 1
        }
        if context.hasChanges { try context.save() }
        return ImportUndoOutcome(
            deletedTransactions: imported.count, deletedCategories: deletedCategories, deletedTags: deletedTags,
            deletedAccounts: deletedAccounts)
    }

    private static func live<T: PersistentModel>(_ items: [T]?) -> Bool {
        (items ?? []).contains { !$0.isDeleted }
    }

    private static func isUnused(_ subcategory: Subcategory) -> Bool {
        !live(subcategory.transactions) && !live(subcategory.budgets) && !live(subcategory.favoritePayments)
            && !live(subcategory.scheduledPayments) && !live(subcategory.inboxDrafts)
            && !live(subcategory.merchantMemories) && !live(subcategory.cashFlowLines)
    }

    private static func isUnused(_ category: Category, ignoring deleted: [Subcategory]) -> Bool {
        let remaining = (category.subcategories ?? []).filter { sub in !deleted.contains { $0 === sub } && !sub.isDeleted }
        return remaining.isEmpty && !live(category.transactions) && !live(category.budgets)
            && !live(category.cashFlowLines)
    }

    private static func isUnused(_ tag: Tag) -> Bool {
        !live(tag.transactions) && !live(tag.budgets) && !live(tag.favoritePayments) && !live(tag.scheduledPayments)
            && !live(tag.inboxDrafts)
    }

    private static func isUnused(_ account: Account) -> Bool {
        !live(account.transactions) && !live(account.budgets) && !live(account.favoritePayments)
            && !live(account.destinationFavoritePayments) && !live(account.scheduledPayments)
            && !live(account.inboxDrafts)
    }
}
