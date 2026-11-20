//
//  L10n+OfertaProBeneficios.swift
//  Yala
//
//  Oferta Pro de Primeros pasos con todos los beneficios (opción A de Jürgen, 20-nov-2026): los cuatro bloques, «Ver
//  todos los beneficios» y la página «Qué incluye Yala Pro». En su propia tabla (`OfertaProBeneficios.strings`), leída
//  con el idioma de la app como `PrimerosPasosPaso7Text`. Las cifras no van en el texto: las pone
//  `OfertaProBeneficiosLogic`, leídas del código.
//

import Foundation

enum OfertaProBeneficiosText {
    static let table = "OfertaProBeneficios"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "ofertaProBeneficios.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    private static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: LanguageManager.resolved.locale, arguments: args)
    }

    /// «Todo lo de Yala, más rápido y sin límites.»: la línea bajo el título cuando no probó voz, foto ni IA.
    static var subtitle: String { string("subtitle") }

    // MARK: - Los cuatro bloques de la oferta

    enum Block {
        static var captureTitle: String { string("block.capture.title") }
        static var captureDetail: String { string("block.capture.detail") }
        static var aiTitle: String { string("block.ai.title") }
        static var aiDetail: String { string("block.ai.detail") }
        static var limitsTitle: String { string("block.limits.title") }
        static var limitsDetail: String { string("block.limits.detail") }
        static var styleTitle: String { string("block.style.title") }
        /// «5 temas y 3 iconos exclusivos».
        static func styleDetail(themes: Int, icons: Int) -> String { format("block.style.detail", themes, icons) }
    }

    static var seeAll: String { string("seeAll") }

    // MARK: - «Qué incluye Yala Pro»

    enum Page {
        static var title: String { string("page.title") }
        static var free: String { string("page.free") }
        static var pro: String { string("page.pro") }
        static var unlimited: String { string("page.unlimited") }
        static var footer: String { string("page.footer") }

        static var groupCapture: String { string("group.capture") }
        static var groupAI: String { string("group.ai") }
        static var groupOrganize: String { string("group.organize") }
        static var groupStyle: String { string("group.style") }

        static var rowManual: String { string("row.manual") }
        static var rowVoice: String { string("row.voice") }
        static var rowImage: String { string("row.image") }
        static var rowAsk: String { string("row.ask") }
        static var rowSummaries: String { string("row.summaries") }
        static var rowAccounts: String { string("row.accounts") }
        static var rowBudgets: String { string("row.budgets") }
        static var rowThemes: String { string("row.themes") }
        static var rowIcons: String { string("row.icons") }

        /// VoiceOver: «sí» / «no» en una casilla de la tabla.
        static var included: String { string("a11y.included") }
        static var notIncluded: String { string("a11y.notIncluded") }
        /// VoiceOver: «Cuentas: gratis 4, Pro sin límite».
        static func rowSpoken(_ title: String, free: String, pro: String) -> String {
            format("a11y.row", title, free, pro)
        }
    }
}
