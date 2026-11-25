//
//  L10n+CapturaAtajoParte2.swift
//  Yala
//
//  Textos del encargo «Captura por foto y atajo del banco, parte 2» (22-nov-2026): la pantalla «Avisos del banco» (B2),
//  el correo de Mail (B3) y los avisos de precio y de baja de los pagos planificados (S2). En su propia tabla
//  (`CapturaAtajoParte2.strings`), leída con el idioma de la app como `L10n.CuentaSolaAlLeer`.
//

import Foundation

extension L10n {
    enum CapturaAtajoParte2 {
        static let table = "CapturaAtajoParte2"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            let fullKey = "atajoParte2.\(key)"
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

        // MARK: - Avisos del banco (B2)

        enum Bank {
            static var rowTitle: String { string("bank.row.title") }
            static var pickerTitle: String { string("bank.picker.title") }
            static var pickerSubtitle: String { string("bank.picker.subtitle") }
            static var pickerReady: String { string("bank.picker.ready") }
            static var pickerOther: String { string("bank.picker.other") }
            static var pickerOtherDetail: String { string("bank.picker.otherDetail") }
            static var pickerBeta: String { string("bank.picker.beta") }
            static var activeSection: String { string("bank.picker.activeSection") }
            static var addSection: String { string("bank.picker.addSection") }
            static var privacyFooter: String { string("bank.privacyFooter") }

            static var waitingTitle: String { string("bank.status.waiting.title") }
            static var waitingDetail: String { string("bank.status.waiting.detail") }
            static var workingTitle: String { string("bank.status.working.title") }
            /// «Último aviso: hoy, 9:41».
            static func lastNotice(_ when: String) -> String { format("bank.status.lastNotice", when) }
            /// «Último aviso: hoy, 9:41 · S/ 45,90 en Tambo+».
            static func lastNoticeWith(_ when: String, _ what: String) -> String {
                format("bank.status.lastNoticeWith", when, what)
            }
            /// «S/ 45,90 en TAMBO+ MIRAFLORES».
            static func amountAt(_ amount: String, _ merchant: String) -> String { format("bank.status.amountAt", amount, merchant) }
            /// «Hace 9 días que no llega nada».
            static func silentTitle(_ days: Int) -> String { format("bank.status.silent.title", days) }
            static var silentDetail: String { string("bank.status.silent.detail") }
            static var pausedTitle: String { string("bank.status.paused.title") }
            static var pausedDetail: String { string("bank.status.paused.detail") }

            static var monthSection: String { string("bank.month.section") }
            static var monthRead: String { string("bank.month.read") }
            static var monthNotUnderstood: String { string("bank.month.notUnderstood") }
            static var monthNotPurchases: String { string("bank.month.notPurchases") }
            static var monthFooter: String { string("bank.month.footer") }

            static var settingsSection: String { string("bank.settings.section") }
            static var defaultAccount: String { string("bank.defaultAccount") }
            static var defaultAccountNone: String { string("bank.defaultAccount.none") }
            static var defaultAccountFooter: String { string("bank.defaultAccount.footer") }
            static var pause: String { string("bank.pause") }

            // Encargo del 23-nov-2026: la entrada explica qué es un aviso y cómo funciona; fuera de Perú solo queda
            // «Tu banco o app»; con los datos en la cuenta de Yala, los correos van a «Correo del banco».
            static var pickerOtherAlone: String { string("bank.picker.otherAlone") }
            static var pickerOtherAloneFooter: String { string("bank.picker.otherAloneFooter") }
            static var howSection: String { string("bank.how.section") }
            static var howNotice: String { string("bank.how.notice") }
            static var howShortcut: String { string("bank.how.shortcut") }
            static var howInbox: String { string("bank.how.inbox") }
            static var howFooter: String { string("bank.how.footer") }
            static var emailSection: String { string("bank.email.section") }
            static var emailRowTitle: String { string("bank.email.row.title") }
            static var emailRowDetail: String { string("bank.email.row.detail") }

            /// Un banco que la persona abrió pero aún no confirmó ni recibió ningún aviso.
            static var notSetUpTitle: String { string("bank.status.notSetUp.title") }
            static var notSetUpDetail: String { string("bank.status.notSetUp.detail") }

            static var introSection: String { string("bank.intro.section") }
            /// «… para que cada aviso de BCP le llegue a Yala».
            static func introDetail(_ bank: String) -> String { format("bank.intro.detail", bank) }
            /// «tu banco»: el nombre en la guía cuando el banco es `.other`.
            static var guideYourBank: String { string("bank.guide.yourBank") }
            /// «la app de BCP».
            static func guideAppOf(_ bank: String) -> String { format("bank.guide.appOf", bank) }
            static var guideYourBankApp: String { string("bank.guide.yourBankApp") }

            static var guideSection: String { string("bank.guide.section") }
            static var guideStep1Title: String { string("bank.guide.step1.title") }
            static var guideStep1Detail: String { string("bank.guide.step1.detail") }
            static var guideStep2Title: String { string("bank.guide.step2.title") }
            static var guideStep2Detail: String { string("bank.guide.step2.detail") }
            /// «Elige «Notificación» y la app de BCP».
            static func guideStep3Title(_ app: String) -> String { format("bank.guide.step3.title", app) }
            static func guideStep3Detail(_ app: String) -> String { format("bank.guide.step3.detail", app) }
            static var guideStep4Title: String { string("bank.guide.step4.title") }
            static var guideStep4Detail: String { string("bank.guide.step4.detail") }
            static var guideStep5Title: String { string("bank.guide.step5.title") }
            /// El valor que se elige en «Banco» dentro de Atajos: el nombre de marca u «Otro banco».
            static func guideStep5Detail(_ bankValue: String) -> String { format("bank.guide.step5.detail", bankValue) }
            static var guideStep6Title: String { string("bank.guide.step6.title") }
            static var guideStep6Detail: String { string("bank.guide.step6.detail") }
            static var confirmSetup: String { string("bank.confirmSetup") }

            static var mailCloudDetail: String { string("bank.mail.cloudDetail") }
            static var mailCloudButton: String { string("bank.mail.cloudButton") }

            static var deactivate: String { string("bank.deactivate") }
            static func deactivateTitle(_ bank: String) -> String { format("bank.deactivate.title", bank) }
            static func deactivateMessage(_ bank: String) -> String { format("bank.deactivate.message", bank) }
            static var deactivateConfirm: String { string("bank.deactivate.confirm") }
            static func guidePreview(_ bank: String) -> String { format("bank.guide.preview", bank, bank) }
            static var guideOtherNote: String { string("bank.guide.otherNote") }
            static var openShortcuts: String { string("bank.openShortcuts") }
            static var addShortcut: String { string("bank.addShortcut") }

            static var mailSection: String { string("bank.mail.section") }
            static var mailDetail: String { string("bank.mail.detail") }

            static var testSection: String { string("bank.test.section") }
            static func testDetail(_ bank: String) -> String { format("bank.test.detail", bank) }
            static var testButton: String { string("bank.test.button") }
            /// «Gasto de S/ 45,90 en TAMBO+ MIRAFLORES».
            static func testExpense(_ amount: String, _ merchant: String) -> String { format("bank.test.expense", amount, merchant) }
            static func testIncome(_ amount: String, _ who: String) -> String { format("bank.test.income", amount, who) }
            static func testAmountOnly(_ amount: String) -> String { format("bank.test.amountOnly", amount) }
            static var testNotUnderstood: String { string("bank.test.notUnderstood") }
            static var testNotAMovement: String { string("bank.test.notAMovement") }

            static var removeSection: String { string("bank.remove.section") }
            static func removeStep1(_ bank: String) -> String { format("bank.remove.step1", bank) }
            static var removeStep2: String { string("bank.remove.step2") }

            // Guía de iOS 27 o posterior (`BankNoticeGuideVersion`, barrido de la build 8): Atajos cambió de forma.
            static var guide27Step2Detail: String { string("bank.guide27.step2.detail") }
            static func guide27Step3Detail(_ app: String) -> String { format("bank.guide27.step3.detail", app) }
            static var guide27Step4Detail: String { string("bank.guide27.step4.detail") }
            static func guide27Step5Detail(_ bankValue: String) -> String { format("bank.guide27.step5.detail", bankValue) }
            static func remove27Step1(_ bank: String) -> String { format("bank.remove27.step1", bank) }
            static var remove27Step2: String { string("bank.remove27.step2") }
        }

        // MARK: - Pagos planificados: cambios de precio y bajas (S2)

        enum Changes {
            /// «Netflix subió a S/ 49,90».
            static func priceUp(_ name: String, _ amount: String) -> String { format("changes.priceUp", name, amount) }
            static func priceDown(_ name: String, _ amount: String) -> String { format("changes.priceDown", name, amount) }
            /// «Los dos últimos cobros fueron de S/ 49,90; tu pago dice S/ 44,90.»
            static func priceDetail(_ charged: String, _ planned: String) -> String {
                format("changes.priceDetail", charged, planned)
            }
            static var update: String { string("changes.update") }
            static var keep: String { string("changes.keep") }
            /// «¿Dejaste de pagar Spotify?»
            static func stoppedTitle(_ name: String) -> String { format("changes.stoppedTitle", name) }
            /// «No hay cobro desde el 5 sept.»
            static func stoppedDetail(_ date: String) -> String { format("changes.stoppedDetail", date) }
            static var pause: String { string("changes.pause") }
            static var stillActive: String { string("changes.stillActive") }
        }
    }
}
