//
//  L10n+UXAudit22Decidido15.swift
//  Yala
//
//  Textos del lote decidido 2.2 · 15 (Ajustes, ayuda y preferencias: L16-1…L16-19 y las cards que se le sumaron).
//  En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l15(_ key: String) -> String {
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
    enum UXL15 {

        // MARK: - L16-2 · Detalles personales

        static var personalDataNote: String { l15("l15.personal.dataNote") }
        static var moreAboutYourData: String { l15("l15.personal.moreAboutData") }

        // MARK: - L16-4 · Tipos de cambio

        static var searchCurrency: String { l15("l15.rates.search") }

        // MARK: - L16-7 · Personalización: dónde se ve cada ajuste

        static var voiceLanguageFooter: String { l15("l15.personalization.voiceLanguageFooter") }
        static var colorfulIconsFooter: String { l15("l15.personalization.colorfulIconsFooter") }
        static var averageLineFooter: String { l15("l15.personalization.averageLineFooter") }
        static var currencyFormatFooter: String { l15("l15.personalization.currencyFormatFooter") }

        // MARK: - L16-13 · Pestañas de abajo

        static var tabBarRules: String { l15("l15.tabBar.rules") }

        // MARK: - L16-14 · Permisos de Yala

        static var permissionsTitle: String { l15("l15.permissions.title") }
        static var permissionsFooter: String { l15("l15.permissions.footer") }
        static var permissionsNotAskedHint: String { l15("l15.permissions.notAskedHint") }
        static var permissionsChangeInSettings: String { l15("l15.permissions.changeInSettings") }
        static var permissionNotifications: String { l15("l15.permissions.notifications") }
        static var permissionNotificationsDetail: String { l15("l15.permissions.notificationsDetail") }
        static var permissionCamera: String { l15("l15.permissions.camera") }
        static var permissionCameraDetail: String { l15("l15.permissions.cameraDetail") }
        static var permissionMicrophone: String { l15("l15.permissions.microphone") }
        static var permissionMicrophoneDetail: String { l15("l15.permissions.microphoneDetail") }
        static var permissionPhotos: String { l15("l15.permissions.photos") }
        static var permissionPhotosDetail: String { l15("l15.permissions.photosDetail") }
        static var permissionAllowed: String { l15("l15.permissions.status.allowed") }
        static var permissionLimited: String { l15("l15.permissions.status.limited") }
        static var permissionSaveOnly: String { l15("l15.permissions.status.saveOnly") }
        static var permissionDenied: String { l15("l15.permissions.status.denied") }
        static var permissionNotAsked: String { l15("l15.permissions.status.notAsked") }

        // MARK: - L16-15 · Recomendar Yala

        static var recommendYala: String { l15("l15.recommend.row") }
        static var recommendMessage: String { l15("l15.recommend.message") }

        // MARK: - L16-16 · Tutoriales

        static var tutorialDoItNow: String { l15("l15.tutorials.doItNow") }
        static var tutorialDone: String { l15("l15.tutorials.done") }

        // MARK: - L16-17 · Preguntas frecuentes

        static var faqSectionCurrencies: String { l15("l15.faq.section.currencies") }
        static var faqSectionGroups: String { l15("l15.faq.section.groups") }
        static var faqNotHereTitle: String { l15("l15.faq.notHere") }
        static var faqWriteToUs: String { l15("l15.faq.writeToUs") }
        static var faqExchangeRateQ: String { l15("l15.faq.exchangeRate.q") }
        static var faqExchangeRateA: String { l15("l15.faq.exchangeRate.a") }
        static var faqGroupsQ: String { l15("l15.faq.groups.q") }
        static var faqGroupsA: String { l15("l15.faq.groups.a") }
        static var faqYalaAIQ: String { l15("l15.faq.yalaAI.q") }
        static var faqYalaAIA: String { l15("l15.faq.yalaAI.a") }
        static var faqWhereDataQ: String { l15("l15.faq.whereData.q") }
        static var faqWhereDataA: String { l15("l15.faq.whereData.a") }
        static var faqFaceIDQ: String { l15("l15.faq.faceID.q") }
        static var faqFaceIDA: String { l15("l15.faq.faceID.a") }
        static var faqWidgetsQ: String { l15("l15.faq.widgets.q") }
        static var faqWidgetsA: String { l15("l15.faq.widgets.a") }

        // MARK: - L16-18 · Soporte

        /// «Se abre tu correo para enviarlo a %@…».
        static func supportSendFooter(_ email: String) -> String {
            String(format: l15("l15.support.sendFooter"), email)
        }

        // MARK: - Quitar mis datos de este iPhone (decisión A, 2026-10-19)

        static var removeDataNoCopyConfirm: String { l15("l15.removeData.noCopyConfirm") }
        static var removeDataExportDiscard: String { l15("l15.removeData.exportDiscard") }
        static func removeDataExportPendingMessage(_ count: Int) -> String {
            String(format: l15("l15.removeData.exportPending"), count)
        }
        static var removeDataExportPendingMessageUnknown: String { l15("l15.removeData.exportPendingUnknown") }

        // MARK: - Fin de Pro: el tema (decisión B, 2026-10-21)

        static var themeResetNote: String { l15("l15.pro.themeResetNote") }

        // MARK: - «1 mes gratis» (decisión B, 2026-10-21)

        static func oneMonthThenYearly(_ price: String) -> String {
            String(format: l15("l15.pro.oneMonthThenYearly"), price)
        }
        static func oneMonthThenMonthly(_ price: String) -> String {
            String(format: l15("l15.pro.oneMonthThenMonthly"), price)
        }
        static var startTrialOneMonth: String { l15("l15.pro.startTrialOneMonth") }
        static var gateStartTrialOneMonth: String { l15("l15.pro.gateStartTrialOneMonth") }
        static var settingsFreeWithTrialOneMonth: String { l15("l15.pro.settingsFreeWithTrialOneMonth") }
    }
}
