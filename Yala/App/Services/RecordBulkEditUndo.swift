//
//  RecordBulkEditUndo.swift
//  Yala
//
//  «Deshacer» tras «Editar N registros» (decisión 18 de 2.3, E1: «Deshacer» también en lote, con el mismo aviso que el
//  borrado de uno). Un borrado se puede aplazar —nada toca la base hasta que vence el aviso—, pero un cambio en lote no:
//  la lista tiene que enseñarlo ya. Por eso aquí se guarda una foto de cada registro tocado ANTES del lote y otra
//  DESPUÉS, y deshacer devuelve la de antes.
//
//  Dos reglas, de la review del lote:
//  - Solo se devuelve un registro que sigue igual que tras el lote. Si en los segundos del aviso otro camino lo cambió
//    (su editor, otro dispositivo), deshacer no pisa ese cambio: el mismo criterio que `restoreSubcategory` (L8-9).
//  - Solo se asigna lo que difiere. Asignar el mismo valor ensucia el contexto sin necesidad (`recalculatePreferredCurrency`
//    explica el porqué); lo que sí cambia sube a iCloud como un cambio más, igual que el lote.
//
//  Cuánto cuesta el «antes»: unos 15 valores por registro (sin cadenas largas salvo la nota). Medido en
//  `RecordBulkEditUndoTests` con 3.000 registros (cifras en el PR de la decisión 18).
//

import Foundation
import SwiftData

@MainActor
struct RecordBulkEditUndo {

    /// Lo que la edición en lote puede cambiar de un registro: cuenta, divisa, importe y sus derivadas, el reparto local
    /// (la cuenta en otra divisa lo reexpresa), categoría y subcategoría, nota y etiquetas.
    struct Fields: Equatable {
        let accountID: PersistentIdentifier?
        let categoryID: PersistentIdentifier?
        let subcategoryID: PersistentIdentifier?
        let currencyCode: String
        let amount: Double
        let exchangeRate: Double
        let amountInPreferredCurrency: Double
        let preferredCurrencyCode: String
        let isExchangeRateProvisional: Bool
        let splitTotalAmount: Double?
        let splitMyValue: Double?
        let note: String?
        let tagIDs: Set<UUID>

        /// Lo que la persona ve y eligió. Las derivadas de la divisa (`exchangeRate`, `amountInPreferredCurrency`…) las
        /// puede reescribir el reparador de tasas en segundo plano, y eso no es «otro cambio» que deshacer deba respetar.
        func sameChoices(as other: Fields) -> Bool {
            accountID == other.accountID && categoryID == other.categoryID && subcategoryID == other.subcategoryID
                && currencyCode == other.currencyCode && amount == other.amount && note == other.note
                && tagIDs == other.tagIDs && splitTotalAmount == other.splitTotalAmount && splitMyValue == other.splitMyValue
        }

        func sameDerived(as other: Fields) -> Bool {
            exchangeRate == other.exchangeRate && amountInPreferredCurrency == other.amountInPreferredCurrency
                && preferredCurrencyCode == other.preferredCurrencyCode
                && isExchangeRateProvisional == other.isExchangeRateProvisional
        }

        init(_ tx: TransactionItem) {
            accountID = tx.account?.persistentModelID
            categoryID = tx.category?.persistentModelID
            subcategoryID = tx.subcategory?.persistentModelID
            currencyCode = tx.currencyCode
            amount = tx.amount
            exchangeRate = tx.exchangeRate
            amountInPreferredCurrency = tx.amountInPreferredCurrency
            preferredCurrencyCode = tx.preferredCurrencyCode
            isExchangeRateProvisional = tx.isExchangeRateProvisional
            splitTotalAmount = tx.splitTotalAmount
            splitMyValue = tx.splitMyValue
            note = tx.note
            tagIDs = tx.resolvedTagIDs(scheduleBackfill: false) ?? []
        }
    }

    /// Un registro con su foto de antes. Las relaciones van como objetos, para poder devolverlas sin buscarlas.
    private struct Entry {
        let record: TransactionItem
        let before: Fields
        let account: Account?
        let category: Category?
        let subcategory: Subcategory?
        /// Elegido por la persona. La otra pata de una transferencia entra en la foto, pero no en la cifra del aviso.
        let isSelected: Bool
        var after: Fields?
    }

    private var entries: [Entry]

    /// La foto de antes, tomada justo antes de aplicar el lote. `records` son los elegidos; sus parejas de transferencia
    /// entran solas, porque las etiquetas, la nota y el importe se propagan a ellas.
    static func capture(_ records: [TransactionItem], context: ModelContext) -> RecordBulkEditUndo {
        var seen: Set<PersistentIdentifier> = []
        var entries: [Entry] = []
        entries.reserveCapacity(records.count)
        func add(_ tx: TransactionItem, isSelected: Bool) {
            guard seen.insert(tx.persistentModelID).inserted else { return }
            entries.append(Entry(
                record: tx, before: Fields(tx), account: tx.account, category: tx.category, subcategory: tx.subcategory,
                isSelected: isSelected))
        }
        for tx in records { add(tx, isSelected: true) }
        for tx in records where tx.transferPairID != nil {
            if let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: tx, in: context) {
                add(partner, isSelected: false)
            }
        }
        return RecordBulkEditUndo(entries: entries)
    }

    /// La foto de después, una vez guardado el lote.
    mutating func sealAfter() {
        for index in entries.indices {
            let record = entries[index].record
            guard !record.isDeleted, record.modelContext != nil else { continue }
            entries[index].after = Fields(record)
        }
    }

    /// Cuántos de los ELEGIDOS cambió de verdad el lote: la cifra del aviso, que tiene que casar con «Aplicar a N».
    var changedCount: Int {
        entries.filter { $0.isSelected && $0.after != nil && $0.after != $0.before }.count
    }

    /// Cuántos registros de la foto cambió el lote, parejas de transferencia incluidas: si es 0, no hay nada que deshacer.
    var changedRecordCount: Int {
        entries.filter { $0.after != nil && $0.after != $0.before }.count
    }

    /// Devuelve la foto de antes a los registros que siguen igual que tras el lote, y guarda una vez. Devuelve cuántos
    /// devolvió.
    @discardableResult
    func restore(context: ModelContext) -> Int {
        var restored = 0
        for entry in entries {
            guard let after = entry.after, after != entry.before else { continue }
            let tx = entry.record
            guard !tx.isDeleted, tx.modelContext != nil else { continue }
            // Cambió por otro camino en estos segundos: no se pisa.
            let current = Fields(tx)
            guard current.sameChoices(as: after) else { continue }
            // Una relación de antes que ya no existe (se borró la cuenta o la categoría) no se puede devolver.
            guard Self.isAlive(entry.account), Self.isAlive(entry.category), Self.isAlive(entry.subcategory) else {
                continue
            }
            let before = entry.before
            do {
                if after.tagIDs != before.tagIDs {
                    tx.setTags(from: try TagResolver.fetch(ids: before.tagIDs, in: context))
                }
            } catch {
                #if DEBUG
                print("RecordBulkEditUndo: Error fetching tags to restore: \(error)")
                #endif
                continue
            }
            if after.accountID != before.accountID { tx.account = entry.account }
            if after.categoryID != before.categoryID { tx.category = entry.category }
            if after.subcategoryID != before.subcategoryID { tx.subcategory = entry.subcategory }
            if after.currencyCode != before.currencyCode { tx.currencyCode = before.currencyCode }
            if after.amount != before.amount { tx.amount = before.amount }
            if current.sameDerived(as: after) {
                if after.exchangeRate != before.exchangeRate { tx.exchangeRate = before.exchangeRate }
                if after.amountInPreferredCurrency != before.amountInPreferredCurrency {
                    tx.amountInPreferredCurrency = before.amountInPreferredCurrency
                }
                if after.preferredCurrencyCode != before.preferredCurrencyCode {
                    tx.preferredCurrencyCode = before.preferredCurrencyCode
                }
                if after.isExchangeRateProvisional != before.isExchangeRateProvisional {
                    tx.isExchangeRateProvisional = before.isExchangeRateProvisional
                }
            } else if after.amount != before.amount || after.currencyCode != before.currencyCode {
                // El reparador de tasas ya recalculó las derivadas del importe del lote: se recalculan para el de antes.
                tx.recalculatePreferredCurrency(context: context)
            }
            if after.splitTotalAmount != before.splitTotalAmount { tx.splitTotalAmount = before.splitTotalAmount }
            if after.splitMyValue != before.splitMyValue { tx.splitMyValue = before.splitMyValue }
            if after.note != before.note { tx.note = before.note }
            restored += 1
        }
        guard restored > 0 else { return 0 }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("RecordBulkEditUndo: Error saving undo: \(error)")
            #endif
            context.rollback()
            return 0
        }
        return restored
    }

    private static func isAlive(_ model: (any PersistentModel)?) -> Bool {
        guard let model else { return true }
        return !model.isDeleted && model.modelContext != nil
    }
}
