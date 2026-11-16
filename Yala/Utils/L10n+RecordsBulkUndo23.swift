//
//  L10n+RecordsBulkUndo23.swift
//  Yala
//
//  Textos de la selección en lote de Registros con «Deshacer» (decisión 18 de la revisión 2.3, opción E1 + E2,
//  2026-11-09). En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//
//  Las cifras van con el separador de miles del idioma de la app (`String(format:locale:)`): «2.334» o «2,334», nunca
//  «2334».
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func lbu(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum RecordsBulkUndo {
        /// «Seleccionar los 2.334» (E2): dice cuántos marca. Plural en el `.stringsdict`.
        static func selectAll(_ count: Int) -> String {
            String(format: lbu("records.bulk23.selectAll"), locale: AppLocale.current, count)
        }
        /// Cabecera de un día en modo selección (E2).
        static var selectDay: String { lbu("records.bulk23.selectDay") }
        static var deselectDay: String { lbu("records.bulk23.deselectDay") }

        /// La pregunta de borrar varios: «Del 8 nov 2024 al 7 nov 2026».
        static func deleteSpan(from first: String, to last: String) -> String {
            String(format: lbu("records.bulk23.deleteSpan"), first, last)
        }
        /// …o, si todo es de un día, «El 17 oct 2025».
        static func deleteOnDay(_ day: String) -> String {
            String(format: lbu("records.bulk23.deleteOnDay"), day)
        }
        /// «S/ 477,091 en total».
        static func deleteTotal(_ amount: String) -> String {
            String(format: lbu("records.bulk23.deleteTotal"), amount)
        }

        /// Aviso tras cambiar solo la categoría en lote: «3 registros ahora son Transporte público».
        static func editedInto(_ count: Int, _ subcategoryName: String) -> String {
            String(format: lbu("records.bulk23.editedInto"), locale: AppLocale.current, count, subcategoryName)
        }
        /// Aviso tras cualquier otro cambio en lote: «Cambiaste 3 registros».
        static func edited(_ count: Int) -> String {
            String(format: lbu("records.bulk23.edited"), locale: AppLocale.current, count)
        }
    }
}
