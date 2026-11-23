//
//  ImportarLote1Texto.swift
//  Yala
//
//  Los textos del lote 1 de Importar registros (22-nov-2026): duplicados al reimportar, «Deshacer importación», el
//  orden de las fechas y las transferencias sin pareja (`importarLote1.*` en `ImportarLote1.strings`, los 16 idiomas),
//  leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.LimiteTarjeta`.
//

import Foundation

extension L10n {
    enum ImportarLote1 {
        static let tabla = "ImportarLote1"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            var value = resolution.bundle.localizedString(forKey: key, value: sentinel, table: tabla)
            if value == sentinel, let parent = resolution.parentBundle {
                value = parent.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            if value == sentinel {
                value = Bundle.main.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            return value == sentinel ? key : value
        }

        private static func s(_ key: String) -> String { string("importarLote1.\(key)") }

        /// La forma de uno o de varios: `.one` lleva el 1 escrito; `.other`, un `%d`.
        private static func counted(_ key: String, _ count: Int) -> String {
            count == 1
                ? s("\(key).one")
                : String(format: s("\(key).other"), locale: LanguageManager.resolved.locale, count)
        }

        // MARK: Duplicados (H11)

        /// «3 registros parecen ya importados».
        static func duplicatesTitle(_ count: Int) -> String { counted("duplicates.title", count) }
        static var duplicatesHint: String { s("duplicates.hint") }
        /// El resumen cuando todo lo del archivo ya estaba.
        static var allAlreadyImported: String { s("duplicates.allAlready") }
        /// El interruptor que los importa igual.
        static var duplicatesToggle: String { s("duplicates.toggle") }
        /// En el resultado: «2 registros no se importaron porque ya estaban.»
        static func skippedDuplicates(_ count: Int) -> String { counted("result.skippedDuplicates", count) }

        // MARK: Transferencias (H9)

        static func looseTransfers(_ count: Int) -> String { counted("loose", count) }

        // MARK: Fechas (H10)

        /// «Las fechas se leen como día/mes, el orden de tu teléfono: 03/04/2026 es el 3 abr 2026.»
        static func dateOrder(_ order: ImportDateOrder, example: String, readAs: String) -> String {
            String(
                format: s(order == .dayFirst ? "dateOrder.dayFirst" : "dateOrder.monthFirst"),
                locale: LanguageManager.resolved.locale, example, readAs)
        }
        static var dateOrderHint: String { s("dateOrder.hint") }

        // MARK: Deshacer (H12)

        static var undoButton: String { s("undo.button") }
        static var undoConfirmTitle: String { s("undo.confirmTitle") }
        static func undoConfirmMessage(_ count: Int) -> String { counted("undo.confirmMessage", count) }
        static var undoConfirmAction: String { s("undo.confirmAction") }
        static var undoDoneTitle: String { s("undo.doneTitle") }
        static func undoDone(_ count: Int) -> String { counted("undo.done", count) }
        static var undoFailed: String { s("undo.failed") }
        static func lastImport(_ count: Int) -> String { counted("undo.lastImport", count) }
        /// «Deshaciendo la importación… 750 de 3000».
        static func undoProgress(_ done: Int, _ total: Int) -> String {
            String(format: s("undo.inProgress"), locale: LanguageManager.resolved.locale, done, total)
        }
    }
}
