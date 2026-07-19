//
//  GroupExpenseIconResolver.swift
//  Yala
//
//  Pure-logic resolver del icono+color de un gasto compartido (Grupos).
//
//  Cadena de resolución (bridge-first + fallback self-contained):
//    1. Bridge personal (gana): la subcategoría que el usuario ELIGIÓ en su TX espejo
//       personal — es su clasificación real y debe ganar en un device normal.
//    2. Nombre del creador: `SplitExpense.subcategoryName` (nombre LOCALIZADO del creador,
//       viaja self-contained por CloudKit y backend) casado contra las subcategorías locales
//       por nombre NORMALIZADO. Cubre el caso device fresco / re-onboardeado donde las TX
//       bridge personales murieron con el wipe → el mapa de bridges queda vacío pero el gasto
//       de grupo sigue portando su `subcategoryName` (fue el bug device-QA H-2026-07-18-9:
//       lista de gastos con iconos genéricos mientras Estadísticas clasificaba bien, porque
//       Stats ya usaba este nombre). También sana a no-participantes y `.groupInvite`, que
//       antes veían genérico SIEMPRE (no tienen bridge).
//    3. Genérico: `fallbackIconName`, sin color (el callsite decide qué pintar — el feed usa
//       el badge del tipo de división; Stats aplica su paleta de fallback determinística).
//
//  GOTCHA (por qué el nombre es un fallback, no la fuente canónica): el matching por nombre
//  LOCALIZADO es frágil cross-idioma — si el creador clasificó "Comida" y el que mira tiene la
//  app en inglés ("Food"), el nombre NO casa y el icono degrada a genérico. Esa degradación es
//  INTENCIONAL: el icono es cosmético (no clasifica montos ni balances), así que un icono
//  genérico es aceptable frente al riesgo de una clase entera de bugs (el bridge por nombre
//  traducido rompía al cambiar idioma — fix prod 52704d55). La clave canónica en `SplitExpense`
//  (id de subcategoría estable, independiente del idioma) es el fix de raíz futuro: exige campo
//  de schema + deploy a CloudKit + columna en backend, fuera de scope de este fix.
//
//  El bridge SIEMPRE gana sobre el nombre: en un device normal el usuario ve la subcategoría
//  que él eligió, no la del creador (pueden diferir). El nombre solo entra cuando no hay bridge.
//

import Foundation

/// Resultado de resolver el icono de un gasto compartido.
///
/// - `iconName`: SF Symbol a renderizar. En el caso genérico es el `fallbackIconName` que pasó
///   el callsite (el feed lo IGNORA y pinta el badge del tipo de división cuando `isGeneric`).
/// - `colorHex`: hex del color de la subcategoría, o `nil` en el caso genérico (sin color propio).
/// - `isGeneric`: `true` cuando ni el bridge ni el nombre resolvieron → el callsite aplica su
///   fallback visual (badge de división en el feed, paleta determinística en Stats).
struct ResolvedIcon: Equatable {
    let iconName: String
    let colorHex: String?
    let isGeneric: Bool
}

enum GroupExpenseIconResolver {

    /// Resuelve el icono+color de un gasto compartido (ver la cadena en el doc del archivo).
    ///
    /// - Parameters:
    ///   - bridgeIcon: icono+color de la subcategoría del TX bridge personal (ya filtrada a
    ///     no-sistema y con el fallback de icono propio del callsite), o `nil` si no hay bridge.
    ///   - subcategoryName: nombre localizado del creador (`SplitExpense.subcategoryName`).
    ///   - nameLookup: `[nombre normalizado: (icono, colorHex)]` de las subcategorías locales
    ///     (construir con `buildNameLookup(from:)` para compartir la misma regla).
    ///   - fallbackIconName: SF Symbol del caso genérico (p. ej. `"tag.fill"`).
    static func resolve(
        bridgeIcon: (iconName: String, colorHex: String)?,
        subcategoryName: String?,
        nameLookup: [String: (iconName: String, colorHex: String)],
        fallbackIconName: String
    ) -> ResolvedIcon {
        // 1. Bridge personal gana.
        if let bridge = bridgeIcon {
            return ResolvedIcon(iconName: bridge.iconName, colorHex: bridge.colorHex, isGeneric: false)
        }
        // 2. Nombre del creador contra subcategorías locales (normalizado, case-insensitive).
        if let subcategoryName {
            let key = normalizedKey(subcategoryName)
            if !key.isEmpty, let hit = nameLookup[key] {
                return ResolvedIcon(iconName: hit.iconName, colorHex: hit.colorHex, isGeneric: false)
            }
        }
        // 3. Genérico.
        return ResolvedIcon(iconName: fallbackIconName, colorHex: nil, isGeneric: true)
    }

    /// Construye el lookup `[nombre normalizado: (icono, colorHex)]` desde las subcategorías
    /// locales YA fetcheadas (sin `ModelContext`). SSOT de la regla de icono/color por nombre —
    /// compartido por el feed de gastos (`GroupDetailViewModel`) y el donut de Estadísticas
    /// (`GroupStatsViewModel`) para no duplicar la derivación icono/color.
    ///
    /// Primera aparición gana (igual que el `dict[...] == nil` previo). NO filtra subcategorías
    /// de sistema: `subcategoryName` es la clasificación que eligió el creador y el lookup debe
    /// poder casarla tal cual (la exclusión de sistema del feed vive en el bridge, no aquí).
    static func buildNameLookup(from subcategories: [Subcategory]) -> [String: (iconName: String, colorHex: String)] {
        var dict: [String: (iconName: String, colorHex: String)] = [:]
        for sub in subcategories {
            let key = normalizedKey(sub.name)
            guard !key.isEmpty, dict[key] == nil else { continue }
            let icon = sub.iconName ?? sub.safeCategory.iconName ?? "tag.fill"
            dict[key] = (icon, sub.colorHex ?? sub.safeCategory.colorHex)
        }
        return dict
    }

    /// Normalización canónica del nombre para el matching (trim + lowercased). Case-insensitive:
    /// endurece el casamiento cross-device frente a diferencias de mayúsculas/espacios del nombre
    /// del creador. Debe usarse TANTO al construir el lookup como al resolver, para que casen.
    static func normalizedKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
