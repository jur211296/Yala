//
//  L10n+UXAudit22Lote7.swift
//  Yala
//
//  Textos de la auditoría UX 2.2, lote 7 (cuentas, categorías, etiquetas, favoritos e importar).
//  Van en su propio fichero para no pisar `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es
/// `private` en su fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l7(_ key: String) -> String {
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
    enum UXL7 {

        // MARK: - Formulario de cuenta (L7-1 … L7-4)

        static var balanceRequiredHint: String { l7("account.form.balanceRequiredHint") }
        static var generalTypeHint: String { l7("account.type.generalHint") }

        // MARK: - Editar el saldo (L7-6)

        enum BalanceEdit {
            static var sectionTitle: String { l7("account.balanceEdit.sectionTitle") }
            static var yalaSays: String { l7("account.balanceEdit.yalaSays") }
            static var question: String { l7("account.balanceEdit.question") }
            static var questionHint: String { l7("account.balanceEdit.questionHint") }
            static var difference: String { l7("account.balanceEdit.difference") }
            static var matches: String { l7("account.balanceEdit.matches") }
            static var howTitle: String { l7("account.balanceEdit.howTitle") }
            static var byEntryTitle: String { l7("account.balanceEdit.byEntryTitle") }
            static var byEntryDesc: String { l7("account.balanceEdit.byEntryDesc") }
            static var initialTitle: String { l7("account.balanceEdit.initialTitle") }
            static var initialDesc: String { l7("account.balanceEdit.initialDesc") }
            static func initialChange(_ before: String, _ after: String) -> String {
                String(format: l7("account.balanceEdit.initialChange"), before, after)
            }
            static func result(_ accountName: String, _ amount: String) -> String {
                String(format: l7("account.balanceEdit.result"), accountName, amount)
            }
        }

        // MARK: - Cambiar la moneda (L7-7)

        static var currencyIncludesInitialBalance: String { l7("account.currencyChange.includesInitialBalance") }
        static func currencyBalanceLine(_ before: String, _ after: String) -> String {
            String(format: l7("account.currencyChange.balanceLine"), before, after)
        }

        /// «1 registro», «70 registros» (plural).
        static func recordsCount(_ count: Int) -> String {
            String.localizedStringWithFormat(l7("records.count"), count)
        }

        // MARK: - Categorías (L7-10 … L7-12)

        enum Categories {
            static var useWhenRecording: String { l7("category.useWhenRecording") }
            static var useWhenRecordingFooter: String { l7("category.useWhenRecording.footer") }
            static var hideAction: String { l7("category.hideAction") }
            static var moveRecordsAction: String { l7("category.moveRecordsAction") }
            static func cannotDeleteChoiceMessage(_ count: Int) -> String {
                String(
                    format: l7("category.cannotDelete.choiceMessage"),
                    String.localizedStringWithFormat(l7("category.cannotDelete.records"), count))
            }
            static var countFailed: String { l7("category.countFailed") }
            static var moveTitle: String { l7("category.move.title") }
            static func moveSubtitle(_ name: String) -> String {
                String(format: l7("category.move.subtitle"), name)
            }
            static var moveNoDestinations: String { l7("category.move.noDestinations") }
            static func moveConfirmTitle(_ name: String) -> String {
                String(format: l7("category.move.confirmTitle"), name)
            }
            static func moveConfirmMessage(_ name: String, _ destination: String, _ records: String) -> String {
                String(format: l7("category.move.confirmMessage"), name, destination, records)
            }
            static var moveConfirmAction: String { l7("category.move.confirmAction") }
            static var moveFailed: String { l7("category.move.failed") }
            static var needExplainer: String { l7("need.explainer") }
        }

        // MARK: - Etiquetas (L7-13)

        enum Tags {
            static func deleteMessage(_ count: Int) -> String {
                count > 0
                    ? String.localizedStringWithFormat(l7("tag.deleteConfirm.message"), count)
                    : l7("tag.deleteConfirm.messageNone")
            }
        }

        // MARK: - Favoritos (L7-14)

        enum Favorites {
            static var createAction: String { l7("favorites.createAction") }
            static var delete: String { l7("favorites.delete") }
            static var deleteConfirmTitle: String { l7("favorites.deleteConfirm.title") }
            static var deleteConfirmMessage: String { l7("favorites.deleteConfirm.message") }
        }

        // MARK: - Importar (L7-15 … L7-17)

        enum ImportScreen {
            static var columnsTitle: String { l7("import.columns.title") }
            static var columnsHint: String { l7("import.columns.hint") }
            static func columnsAccessibility(_ columns: String) -> String {
                String(format: l7("import.columns.accessibility"), columns)
            }
            static var exampleCategory: String { l7("import.columns.exampleCategory") }
            static var exampleSubcategory: String { l7("import.columns.exampleSubcategory") }
            static var createCategoriesOn: String { l7("import.createCategories.on") }
            static var createCategoriesOff: String { l7("import.createCategories.off") }
        }

        enum ImportReview {
            static var title: String { l7("import.preview.title") }
            static func summary(_ count: Int, _ accounts: String) -> String {
                String(format: l7("import.preview.summary"), UXL7.recordsCount(count), accounts)
            }
            static func range(_ first: String, _ last: String) -> String {
                String(format: l7("import.preview.range"), first, last)
            }
            static func singleDay(_ day: String) -> String {
                String(format: l7("import.preview.singleDay"), day)
            }
            static func total(_ amounts: String) -> String {
                String(format: l7("import.preview.total"), amounts)
            }
            static var reviewHint: String { l7("import.preview.reviewHint") }
            static var sampleHeader: String { l7("import.preview.sampleHeader") }
            static func failuresHeader(_ count: Int) -> String {
                String.localizedStringWithFormat(l7("import.preview.failuresHeader"), count)
            }
            static func more(_ count: Int) -> String {
                String.localizedStringWithFormat(l7("import.preview.more"), count)
            }
            static func futureIgnored(_ count: Int) -> String {
                String.localizedStringWithFormat(l7("import.preview.futureIgnored"), count)
            }
            static func importButton(_ count: Int) -> String {
                String.localizedStringWithFormat(l7("import.preview.importButton"), count)
            }
            static var nothingToImport: String { l7("import.preview.nothingToImport") }
            static func notImported(_ count: Int) -> String {
                String.localizedStringWithFormat(l7("import.result.notImported"), count)
            }
        }

        enum ImportErrors {
            static var invalidFileExtension: String { l7("import.error.fileExtension") }
            static var unreadableFile: String { l7("import.error.unreadable") }
            static var emptyFile: String { l7("import.error.empty") }
            static var invalidHeader: String { l7("import.error.header") }
            static func invalidColumnCount(_ row: Int, _ expected: Int, _ found: Int) -> String {
                String(format: l7("import.error.columnCount"), row, expected, found)
            }
            static func invalidDate(_ row: Int, _ value: String) -> String {
                String(format: l7("import.error.date"), row, value)
            }
            static func invalidAmount(_ row: Int, _ value: String) -> String {
                String(format: l7("import.error.amount"), row, value)
            }
            static func invalidCurrency(_ row: Int, _ value: String) -> String {
                String(format: l7("import.error.currency"), row, value)
            }
            static func currencyMismatch(_ row: Int, _ file: String, _ account: String) -> String {
                String(format: l7("import.error.currencyMismatch"), row, file, account)
            }
            static func emptyCategory(_ row: Int) -> String {
                String(format: l7("import.error.emptyCategory"), row)
            }
            static func emptySubcategory(_ row: Int) -> String {
                String(format: l7("import.error.emptySubcategory"), row)
            }
            /// El nombre del interruptor va dentro del texto para que siempre case con la pantalla.
            static func unknownCategory(_ row: Int, _ name: String) -> String {
                String(format: l7("import.error.unknownCategory"), row, name, L10n.Import.createCategories)
            }
            static func unknownSubcategory(_ row: Int, _ category: String, _ name: String) -> String {
                String(
                    format: l7("import.error.unknownSubcategory"), row, category, name, L10n.Import.createCategories)
            }
            static func missingAccountForCurrency(_ row: Int, _ currency: String) -> String {
                String(format: l7("import.error.missingAccount"), row, currency)
            }
            static var xlsxCannotOpen: String { l7("import.error.xlsxOpen") }
            static var xlsxNoSheets: String { l7("import.error.xlsxNoSheets") }
            static var xlsxCannotRead: String { l7("import.error.xlsxRead") }
        }

        // MARK: - Elegir moneda (L7-9)

        enum CurrencyPicker {
            static var current: String { l7("currencyPicker.current") }
            static var searchPrompt: String { l7("currencyPicker.searchPrompt") }
            static func noResults(_ query: String) -> String {
                String(format: l7("currencyPicker.noResults"), query)
            }
            static var secondaryLimit: String { l7("currencyPicker.secondaryLimit") }
            static var secondaryFull: String { l7("currencyPicker.secondaryFull") }
        }

        // MARK: - La moneda nueva en el Panel (L7-8)

        enum Secondary {
            static func addTitle(_ code: String) -> String {
                String(format: l7("account.secondaryCurrency.addTitle"), code)
            }
            static func addMessage(_ code: String, _ preferred: String) -> String {
                String(
                    format: l7("account.secondaryCurrency.addMessage"),
                    code, preferred, L10n.Profile.title, L10n.Settings.currencyAndExchange)
            }
            static var addAccept: String { l7("account.secondaryCurrency.addAccept") }
            static var replaceTitle: String { l7("account.secondaryCurrency.replaceTitle") }
            static func replaceMessage(_ first: String, _ second: String, _ new: String) -> String {
                String(format: l7("account.secondaryCurrency.replaceMessage"), first, second, new)
            }
            static func replaceButton(_ old: String, _ new: String) -> String {
                String(format: l7("account.secondaryCurrency.replaceButton"), old, new)
            }
            static var keep: String { l7("account.secondaryCurrency.keep") }
        }
    }
}
