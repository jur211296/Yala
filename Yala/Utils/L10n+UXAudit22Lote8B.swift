//
//  L10n+UXAudit22Lote8B.swift
//  Yala
//
//  Textos de la auditoría UX 2.2, lote 8 (Registros), cards L8-10 (calendario), L8-11 (duplicados) y
//  L8-13 (editar varios). Van en su propio fichero para no pisar `L10n.swift` con los otros lotes de la tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es
/// `private` en su fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l8b(_ key: String) -> String {
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
    enum UXL8B {

        // MARK: - Calendario (L8-10)

        /// «Gastaste S/ 2,300»: el gasto del día elegido.
        static func daySpent(_ amount: String) -> String {
            String(format: l8b("records.l8b.calendar.daySpent"), amount)
        }
        /// «Entró S/ 354»: lo que entró el día elegido.
        static func dayIncome(_ amount: String) -> String {
            String(format: l8b("records.l8b.calendar.dayIncome"), amount)
        }
        /// Qué es el punto de las celdas.
        static var calendarIncomeLegend: String { l8b("records.l8b.calendar.incomeLegend") }

        // MARK: - Duplicados (L8-11)

        enum Duplicates {
            /// «2 posibles duplicados en 1 grupo».
            static func header(duplicates: Int, groups: Int) -> String {
                String(
                    format: l8b("records.l8b.duplicates.header"),
                    String(format: l8b("records.l8b.duplicates.count"), duplicates),
                    String(format: l8b("records.l8b.duplicates.groups"), groups)
                )
            }
            /// La cabecera de cada grupo: «2 registros iguales».
            static func groupSize(_ count: Int) -> String {
                String(format: l8b("records.l8b.duplicates.groupSize"), count)
            }
            static var keepsFirst: String { l8b("records.l8b.duplicates.keepsFirst") }
            static var remove: String { l8b("records.l8b.duplicates.remove") }
            /// «¿Quitar 3 repetidos?».
            static func removeTitle(_ count: Int) -> String {
                String(format: l8b("records.l8b.duplicates.removeTitle"), count)
            }
            static var keepOnePerGroup: String { l8b("records.l8b.duplicates.keepOnePerGroup") }
            /// Los repetidos que vienen de Grupos y no se borran aquí.
            static func keptShared(_ count: Int) -> String {
                String(format: l8b("records.l8b.duplicates.keptShared"), count)
            }
            static var removeConfirm: String { l8b("records.l8b.duplicates.removeConfirm") }
            static var emptyTitle: String { l8b("records.l8b.duplicates.emptyTitle") }
            /// «Buscamos registros iguales en: monto, nota, subcategoría y fecha.»
            static func emptyLooksAt(_ fields: String) -> String {
                String(format: l8b("records.l8b.duplicates.emptyLooksAt"), fields)
            }
            static var emptyNoCriteria: String { l8b("records.l8b.duplicates.emptyNoCriteria") }
            static var fieldAmount: String { l8b("records.l8b.duplicates.field.amount") }
            static var fieldNote: String { l8b("records.l8b.duplicates.field.note") }
            static var fieldSubcategory: String { l8b("records.l8b.duplicates.field.subcategory") }
            static var fieldDate: String { l8b("records.l8b.duplicates.field.date") }
        }

        // MARK: - Editar varios (L8-13)

        enum BulkEdit {
            /// «Editar 3 registros».
            static func title(_ count: Int) -> String {
                String(format: l8b("records.l8b.bulk.title"), count)
            }
            /// «Hoy: Ahorros».
            static func today(_ value: String) -> String {
                String(format: l8b("records.l8b.bulk.today"), value)
            }
            static func distinctAccounts(_ count: Int) -> String {
                String(format: l8b("records.l8b.bulk.distinctAccounts"), count)
            }
            static func distinctSubcategories(_ count: Int) -> String {
                String(format: l8b("records.l8b.bulk.distinctSubcategories"), count)
            }
            static var distinctNotes: String { l8b("records.l8b.bulk.distinctNotes") }
            static var distinctAmounts: String { l8b("records.l8b.bulk.distinctAmounts") }
            static var noNote: String { l8b("records.l8b.bulk.noNote") }
            /// Por qué el monto no se ofrece.
            static var mixedCurrencies: String { l8b("records.l8b.bulk.mixedCurrencies") }
            /// «Vas a cambiar en 3 registros:».
            static func summaryTitle(_ count: Int) -> String {
                String(format: l8b("records.l8b.bulk.summaryTitle"), count)
            }
            /// «Aplicar a 3 registros».
            static func apply(_ count: Int) -> String {
                String(format: l8b("records.l8b.bulk.apply"), count)
            }
            /// «Los 3 quedarán en S/ 20».
            static func amountResult(count: Int, amount: String) -> String {
                String(format: l8b("records.l8b.bulk.amountResult"), count, amount)
            }
            static var blockedTitle: String { l8b("records.l8b.bulk.blockedTitle") }
            static var discardChange: String { l8b("records.l8b.bulk.discardChange") }
            static var nothingPendingHint: String { l8b("records.l8b.bulk.nothingPendingHint") }
        }
    }
}
