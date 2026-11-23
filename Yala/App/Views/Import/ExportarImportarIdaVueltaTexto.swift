//
//  ExportarImportarIdaVueltaTexto.swift
//  Yala
//
//  Los textos de la ida y vuelta del export (23-nov-2026, H8 de la auditoría del import): las columnas `kind` y
//  `transfer_id`, sus errores y el saldo inicial que fija un import (`exportarImportarIdaVuelta.*` en
//  `ExportarImportarIdaVuelta.strings`, los 16 idiomas), leídos con el idioma de la app (variante → padre → main → la
//  clave), como `L10n.ImportarLote1`.
//

import Foundation

extension L10n {
    enum ExportarImportarIdaVuelta {
        static let tabla = "ExportarImportarIdaVuelta"

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

        private static func s(_ key: String) -> String { string("exportarImportarIdaVuelta.\(key)") }

        /// La forma de uno o de varios: `.one` lleva el 1 escrito; `.other`, un `%d`.
        private static func counted(_ key: String, _ count: Int) -> String {
            count == 1
                ? s("\(key).one")
                : String(format: s("\(key).other"), locale: LanguageManager.resolved.locale, count)
        }

        // MARK: Columnas del export

        static var columnKind: String { s("column.kind") }
        static var columnKindDesc: String { s("column.kind.description") }
        static var columnTransferID: String { s("column.transferID") }
        static var columnTransferIDDesc: String { s("column.transferID.description") }

        // MARK: Errores por fila

        /// «Fila 4: no entendemos el tipo «gastito»…».
        static func invalidKind(_ row: Int, _ value: String) -> String {
            String(format: s("error.kind"), locale: LanguageManager.resolved.locale, row, value)
        }

        /// «Fila 2: «Banco» ya tiene otro saldo inicial…».
        static func initialBalanceConflict(_ row: Int, _ account: String) -> String {
            String(format: s("error.initialBalance"), locale: LanguageManager.resolved.locale, row, account)
        }

        // MARK: Saldo inicial

        /// En la vista previa: «Fija el saldo inicial de 2 cuentas».
        static func previewInitialBalances(_ count: Int) -> String { counted("preview.initialBalances", count) }
        /// En el resultado: «También fijamos el saldo inicial de 2 cuentas.»
        static func resultInitialBalances(_ count: Int) -> String { counted("result.initialBalances", count) }
    }
}
