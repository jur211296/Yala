//
//  L10n+ReceiptSplit.swift
//  Yala
//
//  Textos de «Desde un recibo» en Nuevo gasto de un grupo (card «Grupos: repartir un recibo con IA», 2.3).
//  En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func lrs(_ key: String) -> String {
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
    enum ReceiptSplit {
        // Entrada, en Nuevo gasto
        static var entryButton: String { lrs("receiptSplit.entry.button") }
        static var entryHint: String { lrs("receiptSplit.entry.hint") }

        // Captura
        static var title: String { lrs("receiptSplit.title") }
        static var photoTitle: String { lrs("receiptSplit.photo.title") }
        static var camera: String { lrs("receiptSplit.photo.camera") }
        static var library: String { lrs("receiptSplit.photo.library") }
        static var changePhoto: String { lrs("receiptSplit.photo.change") }
        static var phraseLabel: String { lrs("receiptSplit.phrase.label") }
        static var phrasePlaceholder: String { lrs("receiptSplit.phrase.placeholder") }
        static var phraseFooter: String { lrs("receiptSplit.phrase.footer") }
        static var splitButton: String { lrs("receiptSplit.split") }
        static var voiceTitle: String { lrs("receiptSplit.voice.title") }
        static var voiceHint: String { lrs("receiptSplit.voice.hint") }
        static var voiceExample: String { lrs("receiptSplit.voice.example") }
        static var listening: String { lrs("receiptSplit.voice.listening") }
        static var stopRecording: String { lrs("receiptSplit.voice.stop") }
        static var reading: String { lrs("receiptSplit.reading") }

        // Revisión
        static var reviewTitle: String { lrs("receiptSplit.review.title") }
        static var linesSection: String { lrs("receiptSplit.review.lines") }
        static var linesFooter: String { lrs("receiptSplit.review.linesFooter") }
        static var extrasSection: String { lrs("receiptSplit.review.extras") }
        static var extrasFooter: String { lrs("receiptSplit.review.extrasFooter") }
        static var perPersonSection: String { lrs("receiptSplit.review.perPerson") }
        static var everyone: String { lrs("receiptSplit.review.everyone") }
        static var whoHadIt: String { lrs("receiptSplit.review.whoHadIt") }
        static var total: String { lrs("receiptSplit.review.total") }
        static var useSplit: String { lrs("receiptSplit.review.use") }
        static var nothingToSplit: String { lrs("receiptSplit.review.nothingToSplit") }
        static var negativeShare: String { lrs("receiptSplit.review.negativeShare") }
        static func printedTotalMismatch(printed: String, lines: String) -> String {
            String(format: lrs("receiptSplit.review.totalMismatch"), printed, lines)
        }
        static func unmatchedNames(_ names: String) -> String {
            String(format: lrs("receiptSplit.review.unmatched"), names)
        }
        static var shareExcluded: String { lrs("receiptSplit.share.excluded") }
        static var shareProportional: String { lrs("receiptSplit.share.proportional") }
        static var shareEqual: String { lrs("receiptSplit.share.equal") }
        static var sharePeople: String { lrs("receiptSplit.share.people") }
        static var addSurcharge: String { lrs("receiptSplit.surcharge.add") }
        /// «Propina 10 %» / «Servicio 10 %»: el atajo y la descripción de la línea que añade.
        static func surchargeTitle(kind: ReceiptLineKind, percent: Int) -> String {
            let key = kind == .service ? "receiptSplit.surcharge.service" : "receiptSplit.surcharge.tip"
            return String(format: lrs(key), percent)
        }
        static func kindLabel(_ kind: ReceiptLineKind) -> String {
            switch kind {
            case .item: ""
            case .tip: lrs("receiptSplit.kind.tip")
            case .tax: lrs("receiptSplit.kind.tax")
            case .service: lrs("receiptSplit.kind.service")
            case .discount: lrs("receiptSplit.kind.discount")
            }
        }

        // Fallos propios (los de permisos, prueba agotada y cupo reusan los de voz y foto)
        static var failureReadTitle: String { lrs("receiptSplit.failure.read.title") }
        static var failureReadMessage: String { lrs("receiptSplit.failure.read.message") }
        static var failureNoLinesTitle: String { lrs("receiptSplit.failure.noLines.title") }
        static var failureNoLinesMessage: String { lrs("receiptSplit.failure.noLines.message") }
        static var failureNoConnectionMessage: String { lrs("receiptSplit.failure.noConnection.message") }
        static var failureMicMessage: String { lrs("receiptSplit.failure.mic.message") }
    }
}
