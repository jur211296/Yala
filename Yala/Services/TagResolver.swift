//
//  TagResolver.swift
//  Yala
//
//  Helper para resolver `Set<UUID>` de tag IDs (del CSV mirror) a objetos `[Tag]`
//  vía fetch by id. Centraliza el patrón compartido entre TransactionService,
//  RecordsViewModel y DraftService.
//

import Foundation
import SwiftData

enum TagResolver {

    /// Fetch Tags whose `id` está en el set provisto.
    /// Retorna `[]` para set vacío sin emitir query (optimización del fast path).
    /// Throws si la fetch falla — el caller decide cómo manejar (preferible a
    /// `try?` que silencia y produce clobber accidental).
    static func fetch(ids: Set<UUID>, in context: ModelContext) throws -> [Tag] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { ids.contains($0.id) })
        return try context.fetch(descriptor)
    }

    /// Convenience para form-pre-population: lee CSV-mirror SSOT del record,
    /// resuelve a `[Tag]` via fetch, retorna `[]` con log DEBUG si la fetch falla.
    /// Reemplaza el bloque `do { try fetch } catch { print; [] }` repetido en 5+ callsites
    /// (NewTransactionView edit/clone-favorite, InboxDraftEditSheet, FavoriteEditorView,
    /// ScheduledPaymentEditorView). `errorContext` aparece en el log DEBUG.
    static func fetchOrEmpty(
        ids: Set<UUID>,
        in context: ModelContext,
        errorContext: String
    ) -> [Tag] {
        do {
            return try fetch(ids: ids, in: context)
        } catch {
            #if DEBUG
            print("TagResolver.fetchOrEmpty [\(errorContext)] error: \(error)")
            #endif
            return []
        }
    }
}
