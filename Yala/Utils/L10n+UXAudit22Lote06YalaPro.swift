//
//  L10n+UXAudit22Lote06YalaPro.swift
//  Yala
//
//  Textos del lote decidido 06 de la auditoría UX 2.2 (Yala Pro: paywall, prueba gratis, fin de la prueba y Pro
//  activo; L17-1…L17-9 y L16-11). En su propio fichero para no pisar `L10n.swift` con los otros lotes.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func lpro(_ key: String) -> String {
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

private func lpro(_ key: String, _ args: CVarArg...) -> String {
    String(format: lpro(key), arguments: args)
}

extension L10n {
    enum UXPro {

        // MARK: - Paywall y oferta (L17-2, L17-5)

        static var paywallSubtitle: String { lpro("uxpro.paywall.subtitle") }
        static func trialThenYearly(_ days: Int, _ price: String) -> String { lpro("uxpro.plan.trialThenYearly", days, price) }
        static func trialThenMonthly(_ days: Int, _ price: String) -> String { lpro("uxpro.plan.trialThenMonthly", days, price) }
        static func priceYearly(_ price: String) -> String { lpro("uxpro.plan.priceYearly", price) }
        static func priceMonthly(_ price: String) -> String { lpro("uxpro.plan.priceMonthly", price) }
        static func monthlyEquivalent(_ price: String) -> String { lpro("uxpro.plan.monthlyEquivalent", price) }
        static var howTrialWorks: String { lpro("uxpro.trial.howTitle") }
        static var trialTodayTitle: String { lpro("uxpro.trial.todayTitle") }
        static var trialTodayBody: String { lpro("uxpro.trial.todayBody") }
        static func trialChargeYearly(_ price: String) -> String { lpro("uxpro.trial.chargeYearly", price) }
        static func trialChargeMonthly(_ price: String) -> String { lpro("uxpro.trial.chargeMonthly", price) }
        static var trialCancelTitle: String { lpro("uxpro.trial.cancelTitle") }
        static var trialCancelBody: String { lpro("uxpro.trial.cancelBody") }
        static func startTrialDays(_ days: Int) -> String { lpro("uxpro.cta.startTrialDays", days) }
        static var includedTitle: String { lpro("uxpro.included.title") }
        static var featureVoice: String { lpro("uxpro.feature.voice") }
        static var featurePhoto: String { lpro("uxpro.feature.photo") }
        static var featureAI: String { lpro("uxpro.feature.ai") }
        static var featureAccounts: String { lpro("uxpro.feature.accounts") }
        static var featureBudgets: String { lpro("uxpro.feature.budgets") }
        static var featureLooks: String { lpro("uxpro.feature.looks") }

        // MARK: - Botones que llevan a Pro (L17-4)

        static var tryProFree: String { lpro("uxpro.cta.tryFree") }
        static var switchToPro: String { lpro("uxpro.cta.switch") }

        // MARK: - «Función Pro» (L17-3, L16-11)

        static func limitTitleBudgets(_ limit: Int) -> String { lpro("uxpro.gate.limitTitle.budgets", limit) }
        static func limitBodyBudgets(_ limit: Int) -> String { lpro("uxpro.gate.limitBody.budgets", limit) }
        static func limitTitleAccounts(_ limit: Int) -> String { lpro("uxpro.gate.limitTitle.accounts", limit) }
        static func limitBodyAccounts(_ limit: Int) -> String { lpro("uxpro.gate.limitBody.accounts", limit) }
        static var gateTitleVoice: String { lpro("uxpro.gate.title.voice") }
        static var gateTitlePhoto: String { lpro("uxpro.gate.title.photo") }
        static var gateTitleInsights: String { lpro("uxpro.gate.title.insights") }
        static var gateTitleChat: String { lpro("uxpro.gate.title.chat") }
        static var gateTitleCashFlow: String { lpro("uxpro.gate.title.cashFlow") }
        static func gateTitleTheme(_ name: String) -> String { lpro("uxpro.gate.title.theme", name) }
        static var gateTitleThemeGeneric: String { lpro("uxpro.gate.title.themeGeneric") }
        static func gateTitleIcon(_ name: String) -> String { lpro("uxpro.gate.title.icon", name) }
        static var gateTitleIconGeneric: String { lpro("uxpro.gate.title.iconGeneric") }
        static var gateBodyManualStaysFree: String { lpro("uxpro.gate.body.manualStaysFree") }
        static var gateBodyDataStaysFree: String { lpro("uxpro.gate.body.dataStaysFree") }
        static var gateBodyThemeStays: String { lpro("uxpro.gate.body.themeStays") }
        static var gateBodyIconStays: String { lpro("uxpro.gate.body.iconStays") }
        static var gateBodyCashFlowStays: String { lpro("uxpro.gate.body.cashFlowStays") }
        static var gatePreviewCaption: String { lpro("uxpro.gate.preview") }
        static func gateTrialBody(_ accounts: Int, _ budgets: Int) -> String { lpro("uxpro.gate.trialBody", accounts, budgets) }
        static func gateStartTrialDays(_ days: Int) -> String { lpro("uxpro.gate.ctaTrialDays", days) }

        // MARK: - Fin de Pro (L17-6, L16-11)

        static var endedTrialTitle: String { lpro("uxpro.ended.trialTitle") }
        static func endedChooseBudgets(_ limit: Int) -> String { lpro("uxpro.ended.chooseBudgets", limit) }
        static func endedChooseAccounts(_ limit: Int) -> String { lpro("uxpro.ended.chooseAccounts", limit) }
        static func endedChooseBoth(_ accounts: Int, _ budgets: Int) -> String { lpro("uxpro.ended.chooseBoth", accounts, budgets) }
        static var endedNoteBudgets: String { lpro("uxpro.ended.noteBudgets") }
        static var endedNoteAccounts: String { lpro("uxpro.ended.noteAccounts") }
        static var endedNoteBoth: String { lpro("uxpro.ended.noteBoth") }
        static func chosenBudgets(_ count: Int, _ limit: Int) -> String { lpro("uxpro.ended.chosenBudgets", count, limit) }
        static func chosenAccounts(_ count: Int, _ limit: Int) -> String { lpro("uxpro.ended.chosenAccounts", count, limit) }
        static func keepBudgets(_ count: Int) -> String { lpro("uxpro.ended.keepBudgets", count) }
        static func keepAccounts(_ count: Int) -> String { lpro("uxpro.ended.keepAccounts", count) }
        static var keepBoth: String { lpro("uxpro.ended.keepBoth") }
        static func removeOneBudget(_ name: String) -> String { lpro("uxpro.ended.removeOneBudget", name) }
        static func removeOneAccount(_ name: String) -> String { lpro("uxpro.ended.removeOneAccount", name) }
        static var iconResetNote: String { lpro("uxpro.ended.iconNote") }

        // MARK: - Banner de la prueba (L17-7)

        static func bannerDaysLeft(_ days: Int) -> String {
            switch days {
            case 0: return lpro("uxpro.banner.endsToday")
            case 1: return lpro("uxpro.banner.oneDayLeft")
            default: return lpro("uxpro.banner.daysLeft", days)
            }
        }
        static func bannerThenYearly(_ price: String) -> String { lpro("uxpro.banner.thenYearly", price) }
        static func bannerThenMonthly(_ price: String) -> String { lpro("uxpro.banner.thenMonthly", price) }
        static var bannerManage: String { lpro("uxpro.banner.manage") }

        // MARK: - Pro activo (L17-8)

        static func activeTrialThen(_ date: String, _ priceWithPeriod: String) -> String { lpro("uxpro.active.trialThen", date, priceWithPeriod) }
        static func activeTrialUntil(_ date: String) -> String { lpro("uxpro.active.trialUntil", date) }
        static func activeRenews(_ date: String, _ priceWithPeriod: String) -> String { lpro("uxpro.active.renews", date, priceWithPeriod) }
        static func activeRenewsNoPrice(_ date: String) -> String { lpro("uxpro.active.renewsNoPrice", date) }
        static func activeEnds(_ date: String) -> String { lpro("uxpro.active.ends", date) }
        static var activeManage: String { lpro("uxpro.active.manage") }
        static func activeIfCancel(_ accounts: Int, _ budgets: Int) -> String { lpro("uxpro.active.ifCancel", accounts, budgets) }

        // MARK: - Ajustes (L17-1)

        static func settingsFreeWithTrial(_ days: Int) -> String { lpro("uxpro.settings.freeWithTrial", days) }
        static var settingsFree: String { lpro("uxpro.settings.free") }
        static func settingsTrialEnds(_ date: String) -> String { lpro("uxpro.settings.trialEnds", date) }
        static func settingsRenewsYearly(_ date: String) -> String { lpro("uxpro.settings.renewsYearly", date) }
        static func settingsRenewsMonthly(_ date: String) -> String { lpro("uxpro.settings.renewsMonthly", date) }
        static func settingsEndsYearly(_ date: String) -> String { lpro("uxpro.settings.endsYearly", date) }
        static func settingsEndsMonthly(_ date: String) -> String { lpro("uxpro.settings.endsMonthly", date) }
        static var settingsProActive: String { lpro("uxpro.settings.proActive") }

        // MARK: - Bienvenida (L17-9)

        static var welcomeVoice: String { lpro("uxpro.welcome.voice") }
        static var welcomePhoto: String { lpro("uxpro.welcome.photo") }
        static var welcomeInsights: String { lpro("uxpro.welcome.insights") }
        static var welcomeChat: String { lpro("uxpro.welcome.chat") }
        static var welcomeAccounts: String { lpro("uxpro.welcome.accounts") }
        static var welcomeBudgets: String { lpro("uxpro.welcome.budgets") }
        static var welcomeTheme: String { lpro("uxpro.welcome.theme") }
        static var welcomeIcon: String { lpro("uxpro.welcome.icon") }
        static var welcomeCashFlow: String { lpro("uxpro.welcome.cashFlow") }
    }
}
