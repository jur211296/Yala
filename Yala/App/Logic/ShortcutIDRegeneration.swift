//
//  ShortcutIDRegeneration.swift
//  Yala
//
//  Pure-logic helpers para regenerar UUIDs en colecciones de @Model SwiftData.
//  Asignar el mismo valor a un property no marca el record dirty (SwiftData
//  optimiza el self-assignment), así que un default `UUID()` evaluado al
//  deserializar nunca se persiste. Escribir un UUID distinto fuerza el dirty
//  flag y el siguiente save lo escribe a CKRecord.
//
//  `@MainActor`: mutamos @Model vía keyPath; SwiftData requiere mutaciones en
//  el actor del modelo. Callers deben ser main-actor isolated.
//

import Foundation

/// Regenera UUIDs duplicados en una colección de modelos. Solo toca records
/// cuyo UUID actual aparece 2+ veces (defaults colapsados). UUIDs únicos se
/// preservan — útil para campos viejos donde algunos records ya tienen UUIDs
/// estables sincronizados desde otros devices.
///
/// Cuando N records comparten el mismo UUID, los N se regeneran (ninguno se
/// preserva — todos son sospechosos de ser defaults colapsados).
///
/// - Returns: número de records cuyo UUID fue regenerado.
@MainActor
@discardableResult
func regenerateDuplicateUUIDs<Item: AnyObject>(
    _ items: [Item],
    keyPath: ReferenceWritableKeyPath<Item, UUID>
) -> Int {
    var counts: [UUID: Int] = [:]
    for item in items {
        counts[item[keyPath: keyPath], default: 0] += 1
    }

    var regen = 0
    for item in items where (counts[item[keyPath: keyPath]] ?? 0) > 1 {
        item[keyPath: keyPath] = UUID()
        regen += 1
    }
    return regen
}

/// Regenera el UUID de TODOS los items en la colección. Pensado para campos
/// sin historia de persistencia confiable, o cuando el edge case "1 record"
/// (count==1, no detectable por la heurística por duplicados) requiere
/// forzar persistencia.
///
/// - Returns: número de records cuyo UUID fue reasignado (== `items.count`).
@MainActor
@discardableResult
func regenerateAllUUIDs<Item: AnyObject>(
    _ items: [Item],
    keyPath: ReferenceWritableKeyPath<Item, UUID>
) -> Int {
    for item in items {
        item[keyPath: keyPath] = UUID()
    }
    return items.count
}
