//
//  L10n+UXAudit22Lote8.swift
//  Yala
//
//  Textos de la auditoría UX 2.2, lote 8 (Registros: ver, borrar, duplicar, cambiar la categoría y seleccionar).
//  Van en su propio fichero para no pisar `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es
/// `private` en su fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l8(_ key: String) -> String {
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
    enum UXL8 {

        // MARK: - Borrar (L8-7)

        /// «¿Eliminar «Uber · S/ 26»?»: el registro que se va a borrar, con su importe.
        static func deleteNamedTitle(_ summary: String) -> String {
            String(format: l8("records.l8.deleteNamedTitle"), summary)
        }
        /// Lo que se borra cuando el registro es una transferencia: sus dos mitades.
        static var deleteTransferAlsoPair: String { l8("records.l8.deleteTransferAlsoPair") }

        // MARK: - Detalle (L8-4, L8-5)

        static var deleteFromGroupHint: String { l8("records.l8.deleteFromGroupHint") }
        static var group: String { l8("records.l8.group") }
        static var youPaid: String { l8("records.l8.youPaid") }
        static var yourShare: String { l8("records.l8.yourShare") }
        static var owedToYou: String { l8("records.l8.owedToYou") }

        // MARK: - Duplicar (L8-8)

        static var duplicateTitle: String { l8("records.l8.duplicateTitle") }
        static var duplicateReady: String { l8("records.l8.duplicateReady") }

        // MARK: - Cambiar la subcategoría (L8-9)

        static var changeSubcategoryTitle: String { l8("records.l8.changeSubcategoryTitle") }
        static var current: String { l8("records.l8.current") }
        static func changedTo(_ subcategory: String) -> String {
            String(format: l8("records.l8.changedTo"), subcategory)
        }
        static func changedToWithNeed(_ subcategory: String, _ category: String, _ need: String) -> String {
            String(format: l8("records.l8.changedToWithNeed"), subcategory, category, need)
        }
        static var undo: String { l8("records.l8.undo") }

        // MARK: - Editar varios (L8-13, revisión)

        /// «Aplicar» falló contra el store y no se cambió nada.
        static var bulkSaveFailed: String { l8("records.l8.bulkSaveFailed") }

        /// «Coinciden en monto y subcategoría, en la misma cuenta.»: con criterios flojos, en la pregunta de Quitar.
        static func duplicatesMatchedOn(_ fields: String) -> String {
            String(format: l8("records.l8.duplicatesMatchedOn"), fields)
        }

        // MARK: - Seleccionar (L8-12)

        static var selectHint: String { l8("records.l8.selectHint") }
    }
}
