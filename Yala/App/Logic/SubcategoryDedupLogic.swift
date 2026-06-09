//
//  SubcategoryDedupLogic.swift
//  Yala
//
//  Pure-logic para deduplicar subcategorías seed duplicadas DENTRO de una misma
//  categoría. Estas copias se materializan cuando el mirror de CloudKit reconcilia
//  un registro local marcado dirty (p. ej. la regeneración masiva de `shortcutID`
//  en la migración V3) con el mismo objeto lógico entrante que tiene distinto
//  `recordName`. El dedup de categorías (`CategoryDeduplicationService`) no cubre
//  este caso — solo actúa cuando la propia Categoría está duplicada.
//
//  Testeable sin `ModelContext` (R8): opera sobre `[Subcategory]` construidas con
//  `init`; lee propiedades y ordena, sin tocar el contexto.
//

import Foundation
import SwiftData

enum SubcategoryDedupLogic {

    /// Un grupo de copias de la misma subcategoría seed: el `keeper` a conservar
    /// y las `duplicates` a fusionar en él.
    struct SubcatGroup {
        let keeper: Subcategory
        let duplicates: [Subcategory]
    }

    /// Identidad de una subcategoría elegible para dedup, o `nil` si NO debe tocarse.
    ///
    /// Elegible solo si `isDefaultSeed && !isAnySystem && category != nil`:
    /// - Custom (`isDefaultSeed == false`): el usuario puede tener homónimas legítimas.
    /// - System (`isAnySystem`): rompería el bridge de grupos / "Ajuste de saldo".
    /// - Huérfana (`category == nil`): borrarla perdería transacciones.
    ///
    /// Identidad = `categoryKey | sortOrder | iconName | name`:
    /// - `categoryKey` (icon+color+isIncome) agrupa SIEMPRE dentro de la misma categoría
    ///   (hay iconos repetidos cross-categoría como `ellipsis.circle.fill`).
    /// - `sortOrder` + `iconName` son idioma-agnósticos (discriminadores primarios).
    /// - `name` entra como filtro de seguridad: dos subcats seed con igual sortOrder+icon
    ///   pero distinto `name` NO se fusionan (peor caso = queda 1 duplicado, nunca pérdida).
    static func identityKey(for sub: Subcategory) -> String? {
        guard sub.isDefaultSeed, !sub.isAnySystem, let category = sub.category else { return nil }
        // Misma fórmula que CategoryDeduplicationService.identityKey (icon+color+isIncome),
        // inline para no acoplar Logic → Service.
        let categoryKey = "\(category.iconName ?? "nil")|\(category.colorHex)|\(category.isIncome)"
        return "\(categoryKey)|\(sub.sortOrder)|\(sub.iconName ?? "nil")|\(sub.name)"
    }

    /// Orden determinista para elegir keeper (el que "va antes" se conserva).
    /// `sortOrder` asc → `name` asc → `shortcutID.uuidString` asc (desempate local).
    /// Determinista para que dos devices converjan al mismo keeper; aunque difieran
    /// transitoriamente, el reparenteo por unión garantiza cero pérdida de datos.
    static func keeperRanksBefore(_ a: Subcategory, _ b: Subcategory) -> Bool {
        if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
        if a.name != b.name { return a.name < b.name }
        return a.shortcutID.uuidString < b.shortcutID.uuidString
    }

    /// Grupos con >1 copia por identidad. Cada grupo trae keeper (orden determinista)
    /// + duplicados a fusionar. Pure: solo lee propiedades + ordena.
    static func duplicateGroups(in subcategories: [Subcategory]) -> [SubcatGroup] {
        let eligible = subcategories.compactMap { sub in
            identityKey(for: sub).map { (key: $0, sub: sub) }
        }
        let grouped = Dictionary(grouping: eligible, by: \.key)
        var result: [SubcatGroup] = []
        for (_, members) in grouped where members.count > 1 {
            let sorted = members.map(\.sub).sorted { keeperRanksBefore($0, $1) }
            result.append(SubcatGroup(keeper: sorted[0], duplicates: Array(sorted.dropFirst())))
        }
        return result
    }
}
