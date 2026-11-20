//
//  PrimerosPasosPaso7Text.swift
//  Yala
//
//  Los textos nuevos del encargo del 2026-11-20 (paso 7 como historias, progreso en el mazo, «Pruébalo ahora» y la
//  oferta tras el paso 2), en su propia tabla (`PrimerosPasosPaso7.strings`), leídos con el idioma de la app como
//  `PrimerosPasosPulidoText`.
//

import Foundation

enum PrimerosPasosPaso7Text {
    static let table = "PrimerosPasosPaso7"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "primerosPasosPaso7.\(key)"
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

    // MARK: - Paso 7: historias

    enum Story {
        /// «Tutorial · 2 de 4 · Apple Pay».
        static func eyebrow(_ position: Int, _ count: Int, _ name: String) -> String {
            format("story.eyebrow", position, count, name)
        }
        static var howTo: String { string("story.howTo") }
        static var finish: String { string("story.finish") }

        static var widgetTitle: String { string("story.widget.title") }
        static var widgetMessage: String { string("story.widget.message") }
        static var widgetSpent: String { string("story.widget.spent") }

        static var applePayTitle: String { string("story.applePay.title") }
        static var applePayMessage: String { string("story.applePay.message") }
        static var applePayMerchant: String { string("story.applePay.merchant") }
        static var applePayInboxDetail: String { string("story.applePay.inboxDetail") }
        static var applePayApprove: String { string("story.applePay.approve") }

        static var shareTitle: String { string("story.share.title") }
        static var shareMessage: String { string("story.share.message") }
        static var shareSentBy: String { string("story.share.sentBy") }
        static var shareMerchant: String { string("story.share.merchant") }
        static var shareRead: String { string("story.share.read") }

        static var mailTitle: String { string("story.mail.title") }

        static var siriTitle: String { string("story.siri.title") }
        static var siriMessage: String { string("story.siri.message") }
        static var siriNewRecordAnswer: String { string("story.siri.newRecordAnswer") }
        static var siriAllPhrases: String { string("story.siri.allPhrases") }
    }

    // MARK: - El mazo

    enum Deck {
        /// El nombre corto de un paso, para la fila de los siete.
        static func shortName(_ step: SetupStepID) -> String {
            switch step {
            case .firstAccount: string("deck.step.firstAccount")
            case .firstExpense: string("deck.step.firstExpense")
            case .firstBudget: string("deck.step.firstBudget")
            case .scheduledPayment: string("deck.step.scheduledPayment")
            case .groups: string("deck.step.groups")
            case .whereMoneyGoes: string("deck.step.whereMoneyGoes")
            case .homeScreen: string("deck.step.homeScreen")
            case .tryVoiceInput, .tryImageInput: step.localizedTitle
            }
        }
        /// «Hechos: 2 · Para después: 4 · Toca un paso para abrirlo».
        static func summary(done: Int, later: Int) -> String { format("deck.summary", done, later) }
        static var valueDone: String { string("deck.value.done") }
        static var valueCurrent: String { string("deck.value.current") }
        static var valuePending: String { string("deck.value.pending") }
        /// Al terminar: «Dejaste para después: presupuesto, grupos. Toca uno abajo para hacerlo ahora.»
        static func doneWithLater(_ list: String) -> String { format("deck.doneWithLater", list) }
    }

    // MARK: - «¡Listo! Tienes Pro»

    enum TryNow {
        static var header: String { string("tryNow.header") }
        static var voiceTitle: String { string("tryNow.voice.title") }
        static var voiceDetail: String { string("tryNow.voice.detail") }
        static var photoTitle: String { string("tryNow.photo.title") }
        static var photoDetail: String { string("tryNow.photo.detail") }
        static var aiTitle: String { string("tryNow.ai.title") }
        static var aiDetail: String { string("tryNow.ai.detail") }
        static var extras: String { string("tryNow.extras") }
    }

    // MARK: - La oferta del paso 2

    enum Offer {
        static var notNow: String { string("offer.notNow") }
        static var triedTitleOneMonth: String { string("offer.triedTitleOneMonth") }
        static func triedTitleDays(_ days: Int) -> String { format("offer.triedTitleDays", days) }
        static var triedVoice: String { string("offer.tried.voice") }
        static var triedPhoto: String { string("offer.tried.photo") }
        static var triedAI: String { string("offer.tried.ai") }
        static var featureVoice: String { string("offer.feature.voice") }
        static var featurePhoto: String { string("offer.feature.photo") }
        static var featureAI: String { string("offer.feature.ai") }
        /// «Hoy no pagas · te avisamos el 18 dic. · cobro el 20 dic.».
        static func timelineWithReminder(_ reminder: String, _ charge: String) -> String {
            format("offer.timelineWithReminder", reminder, charge)
        }
        /// Sin permiso de avisos no se promete el aviso.
        static func timelineCharge(_ charge: String) -> String { format("offer.timelineCharge", charge) }
    }
}
