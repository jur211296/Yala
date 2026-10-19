//
//  L10n+UXAudit22Lote20Decididas.swift
//  Yala
//
//  Textos de las decisiones de Jürgen sobre el lote 20 (Exportar y Vaciar) y el L19-12/L19-16 de la auditoría UX 2.2,
//  implementadas el 2026-10-19. En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras
//  sesiones. «registros» y no «movimientos»: L7-18 (`docs/glosario.md`).
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l20d(_ key: String) -> String {
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
    enum UXL20D {

        // MARK: - L20-1 · «Llévate tus registros»

        static var exportTitle: String { l20d("l20d.export.title") }
        static var exportSubtitle: String { l20d("l20d.export.subtitle") }
        static var periodAll: String { l20d("l20d.export.periodAll") }
        static var periodDates: String { l20d("l20d.export.periodDates") }
        static var formatExcel: String { l20d("l20d.export.formatExcel") }
        static var formatRecommended: String { l20d("l20d.export.formatRecommended") }
        static var formatCSV: String { l20d("l20d.export.formatCSV") }
        static var formatCSVHint: String { l20d("l20d.export.formatCSVHint") }
        static var moreOptions: String { l20d("l20d.export.moreOptions") }
        static var moreOptionsHint: String { l20d("l20d.export.moreOptionsHint") }
        static var expanded: String { l20d("l20d.export.expanded") }
        static var collapsed: String { l20d("l20d.export.collapsed") }
        static var modeLabel: String { l20d("l20d.export.modeLabel") }

        // MARK: - L20-2 · La cifra y los filtros activos

        static func activeAccounts(_ count: Int) -> String {
            String.localizedStringWithFormat(l20d("l20d.export.active.accounts"), count)
        }
        static func activeCategories(_ count: Int) -> String {
            String.localizedStringWithFormat(l20d("l20d.export.active.categories"), count)
        }
        static func activeTags(_ count: Int) -> String {
            String.localizedStringWithFormat(l20d("l20d.export.active.tags"), count)
        }
        static func activeNeeds(_ count: Int) -> String {
            String.localizedStringWithFormat(l20d("l20d.export.active.needs"), count)
        }
        static func activeCurrencies(_ codes: String) -> String {
            String(format: l20d("l20d.export.active.currencies"), codes)
        }
        static var activeAmount: String { l20d("l20d.export.active.amount") }
        static func activeNote(_ text: String) -> String { String(format: l20d("l20d.export.active.note"), text) }
        static var activeHiding: String { l20d("l20d.export.active.hiding") }
        static func rangeToToday(_ from: String) -> String { String(format: l20d("l20d.export.rangeToToday"), from) }
        static func range(_ from: String, _ to: String) -> String {
            String(format: l20d("l20d.export.range"), from, to)
        }
        static var noneWithFilters: String { l20d("l20d.export.none") }
        /// «Saldrán 2,326 registros». Plural en el `.stringsdict` (flat en las variantes). `localizedStringWithFormat`
        /// agrupa los miles como el idioma.
        static func willExport(_ count: Int) -> String {
            String.localizedStringWithFormat(l20d("l20d.export.willExport"), count)
        }
        /// «Exportar 2,326 registros». Plural en el `.stringsdict`.
        static func exportCount(_ count: Int) -> String {
            String.localizedStringWithFormat(l20d("l20d.export.exportCount"), count)
        }

        // MARK: - L20-3 · Tras compartir

        static func doneIn(_ app: String) -> String { String(format: l20d("l20d.export.doneIn"), app) }
        static var doneShared: String { l20d("l20d.export.doneShared") }
        static var appFiles: String { l20d("l20d.export.app.files") }
        static var appMessages: String { l20d("l20d.export.app.messages") }
        static var appNotes: String { l20d("l20d.export.app.notes") }
        static var continueWipe: String { l20d("l20d.export.continueWipe") }

        // MARK: - L20-4 · La fila y el archivo

        static var fileStem: String { l20d("l20d.export.fileStem") }
        static var exportRecordsRow: String { l20d("l20d.settings.exportRecords") }

        // MARK: - L20-5 · Vaciar datos

        static var wipeSentenceICloud: String { l20d("l20d.wipe.sentence.icloud") }
        static var wipeSentenceCloud: String { l20d("l20d.wipe.sentence.cloud") }
        static var wipeSentenceGroupsOnly: String { l20d("l20d.wipe.sentence.groupsOnly") }
        static var wipeExportCopy: String { l20d("l20d.wipe.exportCopy") }
        static var wipeRowKeepsAccount: String { l20d("l20d.wipe.row.account") }
        static var wipeRowKeepsGroups: String { l20d("l20d.wipe.row.groups") }
        static var wipeRowKeepsNothing: String { l20d("l20d.wipe.row.nothing") }

        // MARK: - L19-12 · Salir de todos mis grupos, en Ajustes de Grupos

        static var leaveAllSection: String { l20d("l20d.groups.leaveAll.section") }
        static var leaveAllButton: String { l20d("l20d.groups.leaveAll.button") }
        static var leaveAllConfirmTitle: String { l20d("l20d.groups.leaveAll.confirmTitle") }
        static var leaveAllConfirmAction: String { l20d("l20d.groups.leaveAll.confirmAction") }
        static func leaveAllConfirmMessage(_ list: String) -> String {
            String(format: l20d("l20d.groups.leaveAll.confirmMessage"), list)
        }
        static var leaveAllConfirmMessageGeneric: String { l20d("l20d.groups.leaveAll.confirmMessageGeneric") }
    }
}
