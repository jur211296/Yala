//
//  OfertaProBeneficiosLogic.swift
//  Yala
//
//  Qué promete la oferta Pro de Primeros pasos (opción A de Jürgen, 20-nov-2026). Solo las ocho puertas de
//  `ProFeature`, agrupadas en cuatro bloques, y la tabla Gratis | Pro de «Qué incluye Yala Pro». Las cifras se leen del
//  código (`freeLimit`, `AppTheme.isPro`, `AppIconOption.isPremium`): cambiar un límite cambia el texto, nunca al revés.
//  Nada que la app no tenga: ni «Reportes avanzados» ni soporte prioritario, y Grupos sigue gratis.
//

import Foundation

enum OfertaProBeneficiosLogic {

    /// Las cifras que salen en la oferta y en la tabla.
    struct Counts: Equatable {
        /// `nil`: sin límite en Gratis (hoy ninguna; si un límite desaparece, la tabla dice «Sin límite» en las dos).
        var freeAccounts: Int?
        var freeBudgets: Int?
        var freeThemes: Int
        var allThemes: Int
        var freeIcons: Int
        var allIcons: Int

        /// Los que solo trae Pro: «5 temas y 3 iconos exclusivos».
        var exclusiveThemes: Int { allThemes - freeThemes }
        var exclusiveIcons: Int { allIcons - freeIcons }
    }

    static func counts(themes: [AppTheme] = AppTheme.allCases,
                       icons: [AppIconOption] = AppIconOption.allCases,
                       accountsLimit: Int? = ProFeature.accounts.freeLimit,
                       budgetsLimit: Int? = ProFeature.budgets.freeLimit) -> Counts {
        Counts(freeAccounts: accountsLimit,
               freeBudgets: budgetsLimit,
               freeThemes: themes.filter { !$0.isPro }.count,
               allThemes: themes.count,
               freeIcons: icons.filter { !$0.isPremium }.count,
               allIcons: icons.count)
    }

    // MARK: - Los cuatro bloques de la oferta

    enum Block: CaseIterable, Identifiable {
        case capture, ai, limits, style

        var id: Self { self }

        /// Las puertas Pro que nombra el bloque: entre los cuatro, las ocho.
        var features: [ProFeature] {
            switch self {
            case .capture: [.voiceInput, .imageInput]
            case .ai: [.chatAssistant, .smartInsightsAI]
            case .limits: [.accounts, .budgets]
            case .style: [.proThemes, .premiumIcons]
            }
        }

        var icon: String {
            switch self {
            case .capture: "waveform"
            case .ai: "sparkles"
            case .limits: "infinity"
            case .style: "paintpalette.fill"
            }
        }

        var title: String {
            switch self {
            case .capture: OfertaProBeneficiosText.Block.captureTitle
            case .ai: OfertaProBeneficiosText.Block.aiTitle
            case .limits: OfertaProBeneficiosText.Block.limitsTitle
            case .style: OfertaProBeneficiosText.Block.styleTitle
            }
        }

        func detail(_ counts: Counts) -> String {
            switch self {
            case .capture: OfertaProBeneficiosText.Block.captureDetail
            case .ai: OfertaProBeneficiosText.Block.aiDetail
            case .limits: OfertaProBeneficiosText.Block.limitsDetail
            case .style: OfertaProBeneficiosText.Block.styleDetail(themes: counts.exclusiveThemes,
                                                                    icons: counts.exclusiveIcons)
            }
        }
    }

    // MARK: - La tabla Gratis | Pro

    enum Mark: Equatable {
        case included
        case notIncluded
        case count(Int)
        case unlimited

        /// Lo que se lee en la casilla (y lo que dice VoiceOver): «4», «Sin límite», «sí», «no».
        var spoken: String {
            switch self {
            case .included: OfertaProBeneficiosText.Page.included
            case .notIncluded: OfertaProBeneficiosText.Page.notIncluded
            case .count(let value): value.formatted(.number.locale(LanguageManager.resolved.locale))
            case .unlimited: OfertaProBeneficiosText.Page.unlimited
            }
        }

        static func limit(_ value: Int?) -> Mark { value.map(Mark.count) ?? .unlimited }
    }

    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let free: Mark
        let pro: Mark
        /// La puerta Pro que la fila describe; `nil` en «A mano», que es gratis para todos.
        let feature: ProFeature?
    }

    struct BenefitGroup: Identifiable, Equatable {
        let id: String
        let title: String
        let rows: [Row]
    }

    static func groups(_ counts: Counts = counts()) -> [BenefitGroup] {
        typealias P = OfertaProBeneficiosText.Page
        return [
            BenefitGroup(id: "capture", title: P.groupCapture, rows: [
                Row(id: "manual", title: P.rowManual, free: .included, pro: .included, feature: nil),
                Row(id: "voice", title: P.rowVoice, free: .notIncluded, pro: .included, feature: .voiceInput),
                Row(id: "image", title: P.rowImage, free: .notIncluded, pro: .included, feature: .imageInput),
            ]),
            BenefitGroup(id: "ai", title: P.groupAI, rows: [
                Row(id: "ask", title: P.rowAsk, free: .notIncluded, pro: .included, feature: .chatAssistant),
                Row(id: "summaries", title: P.rowSummaries, free: .notIncluded, pro: .included,
                    feature: .smartInsightsAI),
            ]),
            BenefitGroup(id: "organize", title: P.groupOrganize, rows: [
                Row(id: "accounts", title: P.rowAccounts, free: .limit(counts.freeAccounts), pro: .unlimited,
                    feature: .accounts),
                Row(id: "budgets", title: P.rowBudgets, free: .limit(counts.freeBudgets), pro: .unlimited,
                    feature: .budgets),
            ]),
            BenefitGroup(id: "style", title: P.groupStyle, rows: [
                Row(id: "themes", title: P.rowThemes, free: .count(counts.freeThemes), pro: .count(counts.allThemes),
                    feature: .proThemes),
                Row(id: "icons", title: P.rowIcons, free: .count(counts.freeIcons), pro: .count(counts.allIcons),
                    feature: .premiumIcons),
            ]),
        ]
    }

    /// VoiceOver lee la fila entera: «Cuentas: gratis 4, Pro sin límite».
    static func spokenRow(_ row: Row) -> String {
        OfertaProBeneficiosText.Page.rowSpoken(row.title, free: row.free.spoken, pro: row.pro.spoken)
    }
}
