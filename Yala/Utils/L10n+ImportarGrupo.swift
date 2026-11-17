//
//  L10n+ImportarGrupo.swift
//  Yala
//
//  Textos de «Traer un grupo de Splitwise o Tricount» (2.3, gancho de llegada de Grupos): la entrada en Crear grupo, la
//  vista previa del archivo, los errores y el emparejamiento de quien se une después. En su propio fichero para no pisar
//  `L10n.swift` con otros lotes de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su fichero.
private func ig(_ key: String) -> String {
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
    enum ImportarGrupo {
        /// Nombre de la app de origen. No se traduce: es una marca.
        static func sourceName(_ source: ImportedGroupSnapshot.Source) -> String {
            switch source {
            case .splitwise: "Splitwise"
            case .tricount: "Tricount"
            }
        }

        // MARK: Entrada en Crear grupo

        static var entryTitle: String { ig("groups.import.entry.title") }
        static var entrySubtitle: String { ig("groups.import.entry.subtitle") }
        static func entryChosenTitle(_ source: String) -> String {
            String(format: ig("groups.import.entry.chosenTitle"), source)
        }
        static var entryChosenSubtitle: String { ig("groups.import.entry.chosenSubtitle") }
        static var entryRemove: String { ig("groups.import.entry.remove") }

        // MARK: Vista previa

        static var previewTitle: String { ig("groups.import.preview.title") }
        static func previewSource(_ source: String) -> String {
            String(format: ig("groups.import.preview.source"), source)
        }
        static var previewPeople: String { ig("groups.import.preview.people") }
        static var previewExpenses: String { ig("groups.import.preview.expenses") }
        static var previewPayments: String { ig("groups.import.preview.payments") }
        static var previewDates: String { ig("groups.import.preview.dates") }
        static var previewBalancesTitle: String { ig("groups.import.preview.balancesTitle") }
        static var previewOwed: String { ig("groups.import.preview.owed") }
        static var previewOwes: String { ig("groups.import.preview.owes") }
        static var previewSettled: String { ig("groups.import.preview.settled") }
        static var previewCurrenciesNote: String { ig("groups.import.preview.currenciesNote") }
        static var previewWhoAreYou: String { ig("groups.import.preview.whoAreYou") }
        static var previewNotMe: String { ig("groups.import.preview.notMe") }
        static var previewWhoAreYouFooter: String { ig("groups.import.preview.whoAreYouFooter") }
        static var previewUse: String { ig("groups.import.preview.use") }
        static var previewChooseFile: String { ig("groups.import.preview.chooseFile") }
        static var previewHowToExport: String { ig("groups.import.preview.howToExport") }
        static var previewReading: String { ig("groups.import.preview.reading") }
        static var previewPickYourself: String { ig("groups.import.preview.pickYourself") }

        // MARK: Errores

        static var errorTitle: String { ig("groups.import.error.title") }
        static var errorUnrecognized: String { ig("groups.import.error.unrecognized") }
        static var errorNoEntries: String { ig("groups.import.error.noEntries") }
        static func errorUnknownCurrency(_ code: String) -> String {
            String(format: ig("groups.import.error.unknownCurrency"), code)
        }
        static func errorUnreadableAmount(_ row: Int) -> String {
            String(format: ig("groups.import.error.unreadableAmount"), row)
        }
        static func errorRowDoesNotAddUp(_ row: Int) -> String {
            String(format: ig("groups.import.error.rowDoesNotAddUp"), row)
        }
        static func errorBalancesDoNotAddUp(_ code: String) -> String {
            String(format: ig("groups.import.error.balancesDoNotAddUp"), code)
        }
        static var errorUnreadableFile: String { ig("groups.import.error.unreadableFile") }
        static var errorTryAnother: String { ig("groups.import.error.tryAnother") }

        // MARK: Lo que espera, dentro del grupo

        static func pendingBannerTitle(_ source: String) -> String {
            String(format: ig("groups.import.pending.bannerTitle"), source)
        }
        static func pendingBannerBody(_ names: String) -> String {
            String(format: ig("groups.import.pending.bannerBody"), names)
        }
        static var pendingBannerAction: String { ig("groups.import.pending.bannerAction") }

        // MARK: Emparejar

        static var matchTitle: String { ig("groups.import.match.title") }
        static var matchIntro: String { ig("groups.import.match.intro") }
        static var matchNotYet: String { ig("groups.import.match.notYet") }
        static var matchDone: String { ig("groups.import.match.done") }
        static var matchApply: String { ig("groups.import.match.apply") }
        static var matchWaitingFooter: String { ig("groups.import.match.waitingFooter") }
        static var matchFailed: String { ig("groups.import.match.failed") }
        static var matchDiscard: String { ig("groups.import.match.discard") }
        static var matchDiscardTitle: String { ig("groups.import.match.discardTitle") }
        static var matchDiscardBody: String { ig("groups.import.match.discardBody") }
        static func matchPickerLabel(_ person: String) -> String {
            String(format: ig("groups.import.match.pickerLabel"), person)
        }
    }
}
