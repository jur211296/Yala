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
}
