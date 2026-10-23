//
//  L10n+UXAudit22Lote14Decidido.swift
//  Yala
//
//  Textos del lote decidido 2.2 · 07 (Yala IA: L14-6 a L14-11 y L16-8). Van en su propio fichero, como los del
//  lote 14, para no pisar `L10n.swift` con otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func l14d(_ key: String) -> String {
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
    enum UXL14D {

        // MARK: - Nueva conversación (L14-7)

        static var conversationDeleted: String { l14d("chat.l14d.conversationDeleted") }

        // MARK: - Límite del día (L14-8)

        static var limitBox: String { l14d("chat.l14d.limitBox") }

        // MARK: - Tarjeta de registro (L14-9)

        static func saveAll(_ count: Int) -> String {
            String(format: l14d("chat.l14d.draft.saveAll"), count)
        }

        // MARK: - Temas por áreas (L14-6)

        static var areaSpending: String { l14d("chat.l14d.topics.areaSpending") }
        static var areaBudgets: String { l14d("chat.l14d.topics.areaBudgets") }
        static var areaPayments: String { l14d("chat.l14d.topics.areaPayments") }
        static var areaLog: String { l14d("chat.l14d.topics.areaLog") }
        static var spendingTop: String { l14d("chat.l14d.topics.spendingTop") }
        static func spendingCategory(_ name: String) -> String {
            String(format: l14d("chat.l14d.topics.spendingCategory"), name)
        }
        static var spendingVsLastMonth: String { l14d("chat.l14d.topics.spendingVsLastMonth") }
        static func budgetLeft(_ name: String) -> String {
            String(format: l14d("chat.l14d.topics.budgetLeft"), name)
        }
        static func budgetOnTrack(_ name: String) -> String {
            String(format: l14d("chat.l14d.topics.budgetOnTrack"), name)
        }
        static var budgetWorst: String { l14d("chat.l14d.topics.budgetWorst") }
        static var paymentsThisWeek: String { l14d("chat.l14d.topics.paymentsThisWeek") }
        static func paymentWhen(_ name: String) -> String {
            String(format: l14d("chat.l14d.topics.paymentWhen"), name)
        }
        static func logExample(_ name: String) -> String {
            String(format: l14d("chat.l14d.topics.logExample"), name)
        }
        static var logExampleDefault: String { l14d("chat.l14d.topics.logExampleDefault") }
        static var logRowHint: String { l14d("chat.l14d.topics.logRowHint") }

        // MARK: - Privacidad y datos IA (L14-11)

        static var processingLine: String { l14d("aiPrivacy.l14d.processingLine") }
        static var chatLine: String { l14d("aiPrivacy.l14d.chatLine") }
        static var insightsLine: String { l14d("aiPrivacy.l14d.insightsLine") }
        static var cloudExploreLine: String { l14d("aiPrivacy.l14d.cloudExploreLine") }
        /// «¿Desactivar Yala IA?»: el diálogo nombra la función que se apaga.
        static func revokeTitle(_ feature: String) -> String {
            String(format: l14d("aiPrivacy.l14d.revokeTitle"), feature)
        }

        // MARK: - Qué sale en el resumen (L16-8)

        /// «Lo ves en Estadísticas › Resumen.» El camino se arma con los títulos reales de las dos pantallas.
        static func summaryWhere(_ path: String) -> String {
            String(format: l14d("settings.l14d.summaryWhere"), path)
        }
    }
}
