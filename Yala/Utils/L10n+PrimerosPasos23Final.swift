//
//  L10n+PrimerosPasos23Final.swift
//  Yala
//
//  Textos de Primeros pasos 2.3, paso 7 y final (Y23-16 «Anota sin abrir Yala» y Y23-18 «Primeros pasos completos» con
//  la oferta de Pro; docs/onboarding-2-3/SPEC.md). Los exactos de la ficha y del prototipo oficial v35; los que la ficha
//  marca «de la app» (guía de Apple Pay, frases de Siri, beneficios de Pro) se leen de sus claves de siempre. En su
//  propio fichero para no pisar los de otros lotes de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su fichero.
private func pp23f(_ key: String) -> String {
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

private func pp23f(_ key: String, _ args: CVarArg...) -> String {
    String(format: pp23f(key), arguments: args)
}

extension L10n.PrimerosPasos23 {
    /// Paso 7 · «Anota sin abrir Yala» (Y23-16).
    enum Home {
        static var eyebrow: String { pp23f("pasos23.home.eyebrow") }
        static var start: String { pp23f("pasos23.home.start") }
        static func methodEyebrow(_ position: Int, _ total: Int, _ name: String) -> String {
            pp23f("pasos23.home.methodEyebrow", position, total, name)
        }
        static func progress(_ done: Int, _ total: Int) -> String { pp23f("pasos23.home.progress", done, total) }
        static var keepGoing: String { pp23f("pasos23.home.keepGoing") }
        static func nowNext(_ name: String) -> String { pp23f("pasos23.home.now", name) }
        static var finish: String { pp23f("pasos23.home.finish") }

        // Los nombres cortos de cada manera.
        static var widgetName: String { pp23f("pasos23.home.widget.name") }
        static var applePayName: String { pp23f("pasos23.home.applePay.name") }
        static var shareName: String { pp23f("pasos23.home.share.name") }
        static var siriName: String { pp23f("pasos23.home.siri.name") }

        // La página corta: una parte por manera.
        static var widgetPartTitle: String { pp23f("pasos23.home.widget.part.title") }
        static var widgetPartMessage: String { pp23f("pasos23.home.widget.part.message") }
        static var applePayPartTitle: String { pp23f("pasos23.home.applePay.part.title") }
        static var applePayPartMessage: String { pp23f("pasos23.home.applePay.part.message") }
        static func applePayPartPaid(_ amount: String) -> String { pp23f("pasos23.home.applePay.part.paid", amount) }
        static func applePayPartPush(_ amount: String) -> String { pp23f("pasos23.home.applePay.part.push", amount) }
        static var sharePartTitle: String { pp23f("pasos23.home.share.part.title") }
        static var sharePartMessage: String { pp23f("pasos23.home.share.part.message") }
        static var siriPartTitle: String { pp23f("pasos23.home.siri.part.title") }
        static var siriPartMessage: String { pp23f("pasos23.home.siri.part.message") }
        static var siriPartAsk: String { pp23f("pasos23.home.siri.part.ask") }
        static var siriPartAnswer: String { pp23f("pasos23.home.siri.part.answer") }
        static var shareSheetCaption: String { pp23f("pasos23.home.share.sheetCaption") }

        // Mini tutorial 1 · widget.
        static var widgetTitle: String { pp23f("pasos23.home.widget.title") }
        static var widgetSubtitle: String { pp23f("pasos23.home.widget.subtitle") }
        static var widgetStep1: String { pp23f("pasos23.home.widget.step1") }
        static var widgetStep2: String { pp23f("pasos23.home.widget.step2") }
        static var widgetStep2Hint: String { pp23f("pasos23.home.widget.step2.hint") }
        static var widgetStep3: String { pp23f("pasos23.home.widget.step3") }
        static var widgetStep4: String { pp23f("pasos23.home.widget.step4") }
        static var widgetDone: String { pp23f("pasos23.home.widget.done") }
        static var widgetName2: String { pp23f("pasos23.home.widget.widgetName") }

        // Mini tutorial 2 · Apple Pay (los pasos son los de Tutoriales).
        static var applePayDone: String { pp23f("pasos23.home.applePay.done") }

        // Mini tutorial 3 · compartir.
        static var shareTitle: String { pp23f("pasos23.home.share.title") }
        static var shareSubtitle: String { pp23f("pasos23.home.share.subtitle") }
        static var shareStep1: String { pp23f("pasos23.home.share.step1") }
        static var shareStep2: String { pp23f("pasos23.home.share.step2") }
        static var shareStep3: String { pp23f("pasos23.home.share.step3") }

        // Mini tutorial 4 · Siri.
        static var siriTitle: String { pp23f("pasos23.home.siri.title") }
        static var siriSubtitle: String { pp23f("pasos23.home.siri.subtitle") }
        static var siriNewRecordPhrase: String { pp23f("pasos23.home.siri.newRecordPhrase") }

        // La pantalla entre una manera y la siguiente.
        static var applePayNextDetail: String { pp23f("pasos23.home.applePay.next") }
        static var shareNextDetail: String { pp23f("pasos23.home.share.next") }
        static var siriNextDetail: String { pp23f("pasos23.home.siri.next") }
        static var applePayNextAction: String { pp23f("pasos23.home.applePay.nextAction") }
        static var shareNextAction: String { pp23f("pasos23.home.share.nextAction") }
        static var siriNextAction: String { pp23f("pasos23.home.siri.nextAction") }

        // Mini tutorial del correo del banco (Y23-19): «Tu dirección de Yala».
        static var mailName: String { pp23f("pasos23.home.mail.name") }
        static var mailPartTitle: String { pp23f("pasos23.home.mail.part.title") }
        static var mailPartMessage: String { pp23f("pasos23.home.mail.part.message") }
        static func mailPartMail(_ amount: String) -> String { pp23f("pasos23.home.mail.part.mail", amount) }
        static var mailPartFrom: String { pp23f("pasos23.home.mail.part.from") }
        static func mailPartPush(_ amount: String) -> String { pp23f("pasos23.home.mail.part.push", amount) }
        static var mailTitle: String { pp23f("pasos23.home.mail.title") }
        static var mailSubtitle: String { pp23f("pasos23.home.mail.subtitle") }
        static var mailAddressCaption: String { pp23f("pasos23.home.mail.addressCaption") }
        static var mailCopy: String { pp23f("pasos23.home.mail.copy") }
        static var mailStep1: String { pp23f("pasos23.home.mail.step1") }
        static var mailStep2: String { pp23f("pasos23.home.mail.step2") }
        static var mailStep3: String { pp23f("pasos23.home.mail.step3") }
        static var mailStep3Detail: String { pp23f("pasos23.home.mail.step3.detail") }
        static var mailSoon: String { pp23f("pasos23.home.mail.soon") }
        static var mailNextDetail: String { pp23f("pasos23.home.mail.next") }
        static var mailNextAction: String { pp23f("pasos23.home.mail.nextAction") }
    }

    /// Un texto que ya existe en la app (frases de «Siri y Atajos», «Omitido»), leído con la misma búsqueda que los de
    /// este lote: si la persona eligió otro idioma dentro de Yala, la pantalla no mezcla dos.
    static func appText(_ key: String) -> String { pp23f(key) }

    /// Final · «¡Primeros pasos completos!» y la oferta de Pro (Y23-18).
    enum Final {
        static var doneTitle: String { pp23f("pasos23.final.done.title") }
        static var doneMessage: String { pp23f("pasos23.final.done.message") }

        static var offerTitleOneMonth: String { pp23f("pasos23.final.offer.titleOneMonth") }
        static func offerTitleDays(_ days: Int) -> String { pp23f("pasos23.final.offer.titleDays", days) }
        static var offerSubtitle: String { pp23f("pasos23.final.offer.subtitle") }
        static var mostChosen: String { pp23f("pasos23.final.offer.mostChosen") }
        static var cheaperPerMonth: String { pp23f("pasos23.final.offer.cheaperPerMonth") }
        static var reminderBody: String { pp23f("pasos23.final.offer.timeline.reminder") }
        static var chargeBody: String { pp23f("pasos23.final.offer.timeline.charge") }
        static var ctaOneMonth: String { pp23f("pasos23.final.offer.ctaOneMonth") }
        static func ctaDays(_ days: Int) -> String { pp23f("pasos23.final.offer.ctaDays", days) }
        static var keepFree: String { pp23f("pasos23.final.offer.keepFree") }

        static var voiceDetail: String { pp23f("pasos23.final.feature.voice") }
        static var photoDetail: String { pp23f("pasos23.final.feature.photo") }
        static var aiDetail: String { pp23f("pasos23.final.feature.ai") }
        static var accountsDetail: String { pp23f("pasos23.final.feature.accounts") }
        static var budgetsDetail: String { pp23f("pasos23.final.feature.budgets") }
        static var looksDetail: String { pp23f("pasos23.final.feature.looks") }

        static var successTitle: String { pp23f("pasos23.final.success.title") }
        static func successOneMonth(_ until: String, _ reminder: String) -> String {
            pp23f("pasos23.final.success.oneMonth", until, reminder)
        }
        static func successDays(_ days: Int, _ until: String, _ reminder: String) -> String {
            pp23f("pasos23.final.success.days", days, until, reminder)
        }
        static func successOneMonthUntil(_ until: String) -> String { pp23f("pasos23.final.success.oneMonthUntil", until) }
        static func successDaysUntil(_ days: Int, _ until: String) -> String {
            pp23f("pasos23.final.success.daysUntil", days, until)
        }
        static var startUsing: String { pp23f("pasos23.final.success.startUsing") }

        static var reminderTitle: String { pp23f("pasos23.final.reminder.title") }
        static func reminderMessage(_ chargeDay: String) -> String { pp23f("pasos23.final.reminder.body", chargeDay) }
    }
}
