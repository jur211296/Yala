//
//  UXAudit22Decidido15Tests.swift
//  YalaTests
//
//  Lote decidido 2.2 · 15 (Ajustes, ayuda y preferencias). La lógica pura de cada decisión, su cableado en las vistas
//  (source-scan sobre el CÓDIGO, sin comentarios) y los textos en los 16 locales.
//

import AVFoundation
import Foundation
import Photos
import StoreKit
import Testing
import UserNotifications
@testable import Yala

// MARK: - Lógica pura

@Suite("Lote decidido 15 · lógica")
struct UXAudit22Decidido15LogicTests {

    // L16-2
    @Test("El nombre de serie sale como campo vacío; uno escrito por la persona se respeta")
    func personalName_defaultIsAnEmptyField() {
        #expect(PersonalNameFieldLogic.fieldValue(stored: "Usuario", defaultName: "Usuario") == "")
        #expect(PersonalNameFieldLogic.fieldValue(stored: "Lucía", defaultName: "Usuario") == "Lucía")
        #expect(PersonalNameFieldLogic.fieldValue(stored: "usuario", defaultName: "Usuario") == "usuario")
    }

    // L16-4
    @Test("Bajo 0,01 la tasa se invierte; desde 0,01 se lee tal cual")
    func rates_invertBelowOneCent() {
        #expect(ExchangeRateRowLogic.display(rate: 3.55) == .direct(3.55))
        #expect(ExchangeRateRowLogic.display(rate: 0.01) == .direct(0.01), "el borde no se invierte")
        let pyg = 0.0004581
        #expect(ExchangeRateRowLogic.display(rate: pyg) == .inverted(1 / pyg))
        if case .inverted(let units) = ExchangeRateRowLogic.display(rate: pyg) {
            #expect(units > 2_000 && units < 2_300, "1 PEN son unos 2.183 PYG: \(units)")
        }
        #expect(ExchangeRateRowLogic.display(rate: nil) == nil)
        #expect(ExchangeRateRowLogic.display(rate: 0) == nil)
        #expect(ExchangeRateRowLogic.display(rate: .infinity) == nil)
    }

    @Test("La tasa invertida se escribe con dos decimales")
    func rates_invertedHasTwoDecimals() {
        #expect(ExchangeRateRowLogic.invertedString(2117.4863, locale: Locale(identifier: "en_US")) == "2,117.49")
        #expect(ExchangeRateRowLogic.invertedString(8190, locale: Locale(identifier: "en_US")) == "8,190.00")
    }

    @Test("El buscador encuentra por código y por nombre, sin tildes ni mayúsculas")
    func rates_searchMatchesCodeAndName() {
        #expect(ExchangeRateRowLogic.matches(query: "", code: "PYG", name: "Guaraní Paraguayo"))
        #expect(ExchangeRateRowLogic.matches(query: "pyg", code: "PYG", name: "Guaraní Paraguayo"))
        #expect(ExchangeRateRowLogic.matches(query: "guarani", code: "PYG", name: "Guaraní Paraguayo"))
        #expect(ExchangeRateRowLogic.matches(query: "  Paraguayo ", code: "PYG", name: "Guaraní Paraguayo"))
        #expect(!ExchangeRateRowLogic.matches(query: "euro", code: "PYG", name: "Guaraní Paraguayo"))
    }

    // L16-15
    @Test("Valorar abre «Escribir una reseña» de Yala; recomendar comparte su ficha")
    func appStoreLinks() {
        #expect(AppStoreLinks.writeReviewURL.absoluteString == "https://apps.apple.com/app/id6758253109?action=write-review")
        #expect(AppStoreLinks.listingURL.absoluteString == "https://apps.apple.com/app/id6758253109")
    }

    // L16-14
    @Test("Cada estado del sistema se traduce a lo que dice la pantalla")
    func permissionStates() {
        #expect(PermissionState.camera(.authorized) == .allowed)
        #expect(PermissionState.camera(.denied) == .denied)
        #expect(PermissionState.camera(.restricted) == .denied)
        #expect(PermissionState.camera(.notDetermined) == .notAsked)
        #expect(PermissionState.microphone(.granted) == .allowed)
        #expect(PermissionState.microphone(.denied) == .denied)
        #expect(PermissionState.microphone(.undetermined) == .notAsked)
        #expect(PermissionState.notifications(.authorized) == .allowed)
        #expect(PermissionState.notifications(.provisional) == .allowed)
        #expect(PermissionState.notifications(.denied) == .denied)
        #expect(PermissionState.notifications(.notDetermined) == .notAsked)
    }

    @Test("Fotos: manda leer la galería si se contestó; si no, solo guardar")
    func photosPermission() {
        #expect(PermissionState.photos(readWrite: .authorized, addOnly: .notDetermined) == .allowed)
        #expect(PermissionState.photos(readWrite: .limited, addOnly: .authorized) == .limited)
        #expect(PermissionState.photos(readWrite: .denied, addOnly: .authorized) == .denied)
        #expect(PermissionState.photos(readWrite: .notDetermined, addOnly: .authorized) == .saveOnly)
        #expect(PermissionState.photos(readWrite: .notDetermined, addOnly: .denied) == .denied)
        #expect(PermissionState.photos(readWrite: .notDetermined, addOnly: .notDetermined) == .notAsked)
    }

    @Test("Sin preguntar no hay botón a Configuración: allí aún no hay interruptor")
    func settingsButton_onlyOnceAsked() {
        #expect(!PermissionState.notAsked.offersSettingsButton)
        for state in [PermissionState.allowed, .limited, .saveOnly, .denied] {
            #expect(state.offersSettingsButton)
        }
    }

    // L16-16
    @Test("«Hacerlo ahora» lleva a la pantalla de cada tutorial")
    @MainActor func tutorialDoItNow_targets() {
        typealias T = TutorialDoItNowLogic
        #expect(T.target(for: .createAccount) == .settings(.accounts))
        #expect(T.target(for: .createCategories) == .settings(.categories))
        #expect(T.target(for: .createTags) == .settings(.tags))
        #expect(T.target(for: .createFavorites) == .settings(.favorites))
        #expect(T.target(for: .importData) == .importFile)
        #expect(T.target(for: .createRecord) == .newRecord)
        #expect(T.target(for: .createBudgets) == .newBudget)
        #expect(T.target(for: .createScheduledPayments) == .newScheduledPayment)
        #expect(T.target(for: .editPanel) == .panel)
        #expect(T.target(for: .panelFiltering) == .panel)
        #expect(T.target(for: .inboxApproval) == .inbox)
    }

    // QA de 2.1 · el consentimiento se pide una vez
    @Test("Aceptado en esta pasada no se vuelve a pedir; si no, sí")
    func consent_signUpSwitch() {
        #expect(CloudConsentRegistrationLogic.signUpSwitch(consentAcceptedThisPass: true) == .alreadyAccepted)
        #expect(CloudConsentRegistrationLogic.signUpSwitch(consentAcceptedThisPass: false) == .askConsent)
    }

    @Test("Sin volver a preguntar, el alta registra el consentimiento una sola vez y consume el pendiente")
    func consent_persistForSignUpSwitch_writesOnce() {
        var pending = true
        var writes = 0
        #expect(CloudConsentRegistrationLogic.persistForSignUpSwitch(pending: &pending) { writes += 1 })
        #expect(writes == 1)
        #expect(!pending, "el pendiente de la re-entrada no puede quedar para otro punto del flujo")
        #expect(!CloudConsentRegistrationLogic.persistForSignUpSwitch(pending: &pending) { writes += 1 })
        #expect(writes == 1, "un segundo paso por el alta no vuelve a escribir")
    }

    @Test("Sin pendiente no se escribe nada")
    func consent_persistForSignUpSwitch_withoutPending() {
        var pending = false
        var writes = 0
        #expect(!CloudConsentRegistrationLogic.persistForSignUpSwitch(pending: &pending) { writes += 1 })
        #expect(writes == 0)
    }

    // Tema de Pro
    @Test("El tema vuelve solo si es de Pro y Pro ya no está")
    @MainActor func themeWillReset() {
        let proTheme = AppTheme.rosa
        #expect(proTheme.isPro, "el escenario necesita un tema de Pro")
        #expect(ProPlanStatusLogic.themeWillReset(isProUser: false, currentTheme: proTheme))
        #expect(!ProPlanStatusLogic.themeWillReset(isProUser: true, currentTheme: proTheme))
        #expect(!ProPlanStatusLogic.themeWillReset(isProUser: false, currentTheme: .liquidGlass))
    }

    @Test("La hoja de fin de Pro sale también solo por el tema")
    func endedSheet_alsoForTheTheme() {
        #expect(ProPlanStatusLogic.endedSheetIsNeeded(hasExcess: false, iconWillReset: false, themeWillReset: true))
        #expect(!ProPlanStatusLogic.endedSheetIsNeeded(hasExcess: false, iconWillReset: false, themeWillReset: false))
    }

    // «1 mes gratis»
    @Test("Un mes de calendario se anuncia como mes; otras duraciones, no")
    func trialIsOneMonth() {
        #expect(PaywallPricingLogic.trialIsOneMonth(periodUnit: .month, periodValue: 1))
        #expect(!PaywallPricingLogic.trialIsOneMonth(periodUnit: .month, periodValue: 2))
        #expect(!PaywallPricingLogic.trialIsOneMonth(periodUnit: .day, periodValue: 30))
        #expect(!PaywallPricingLogic.trialIsOneMonth(periodUnit: .week, periodValue: 1))
        #expect(!PaywallPricingLogic.trialIsOneMonth(periodUnit: nil, periodValue: 1))
    }

    @Test("Los precios de prueba de los XCUITest son de un mes, como Configuration.storekit")
    @MainActor func fakeOffers_areOneMonth() {
        let withTrial = StoreKitManager.fakeOffers(trialAvailable: true).map(\.trialIsOneMonth)
        let withoutTrial = StoreKitManager.fakeOffers(trialAvailable: false).map(\.trialIsOneMonth)
        #expect(withTrial == [true, true])
        #expect(withoutTrial == [false, false])
    }
}

// MARK: - Cableado (source-scan)

@Suite("Lote decidido 15 · cableado")
struct UXAudit22Decidido15WiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Solo el CÓDIGO: los comentarios nombran a propósito lo que ya no se hace.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func body(after marker: String, in source: String, upTo end: String) throws -> String {
        let start = try #require(source.range(of: marker))
        let rest = source[start.upperBound...]
        let stop = rest.range(of: end)?.lowerBound ?? rest.endIndex
        return String(rest[..<stop])
    }

    @Test("L16-1: el avatar del Panel se anuncia como Ajustes")
    func avatar_isSettings() throws {
        let src = try Self.code("Yala/App/Views/Shared/ProfileToolbarButton.swift")
        #expect(src.contains(".accessibilityLabel(L10n.Profile.title)"))
        #expect(!src.contains("L10n.Accessibility.profile"))
    }

    @Test("L16-2: «Listo» a la derecha y el campo sin el nombre de serie")
    func personalDetails() throws {
        let src = try Self.code("Yala/App/Views/Profile/PersonalDetailsView.swift")
        #expect(src.contains("ToolbarItem(placement: .confirmationAction)"))
        #expect(!src.contains("systemName: \"chevron.left\""), "volvió el «‹» de pantalla empujada")
        #expect(src.contains("PersonalNameFieldLogic.fieldValue("))
        #expect(src.contains(".inAppSafari($webPage)"))
    }

    @Test("L16-6: «Activar» sin rojo, en un aviso con «Cancelar»")
    func expensesOnly_alert() throws {
        let src = try Self.code("Yala/App/Views/Settings/PersonalizationSettingsView.swift")
        #expect(!src.contains("confirmationDialog("), "volvió el diálogo anclado, que no pinta «Cancelar»")
        let activate = try Self.body(after: "isPresented: $showingExpensesOnlyActivate", in: src, upTo: "} message:")
        #expect(activate.contains("Button(L10n.Settings.expensesOnlyActivateConfirm)"))
        #expect(!activate.contains(".destructive"), "«Activar» volvió a ser rojo")
        #expect(activate.contains("role: .cancel"))
    }

    @Test("L16-10: elegir un tema no cierra nada")
    func theme_staysOpen() throws {
        let src = try Self.code("Yala/App/Views/Settings/ThemeSettingsView.swift")
        let choose = try Self.body(after: "private func choose(_ appTheme: AppTheme) {", in: src, upTo: "// MARK:")
        #expect(!choose.contains("dismiss()"))
        #expect(!src.contains("onThemeChanged"))
    }

    @Test("L16-14: «Permisos» abre su pantalla, no Configuración")
    func permissions_row() throws {
        let src = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(src.contains("destination: .permissions)"))
        #expect(src.contains("case .permissions:\n                PermissionsSettingsView()"))
        #expect(!src.contains("UIApplication.openSettingsURLString"), "la fila vuelve a saltar a Configuración")
    }

    @Test("L16-15: valorar abre la reseña y recomendar comparte; sin `requestReview`")
    func rateAndRecommend() throws {
        let src = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(src.contains("openURL(AppStoreLinks.writeReviewURL)"))
        #expect(src.contains("ShareLink(item: AppStoreLinks.listingURL"))
        #expect(!src.contains("requestReview"))
    }

    @Test("Quitar mis datos: el aviso de los 45 s elige el verbo por la salida CONFIRMADA, no por la celda de ahora")
    func removeData_exportNotice_usesTheConfirmedExit() throws {
        let src = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(src.contains("if exitInProgressRemovesDeviceData ?? signOutRowRemovesDeviceData {"))
        #expect(src.contains("exitInProgressRemovesDeviceData = DestructiveScopeLogic.signOutRemovesDeviceData(path: scope.path)"))
        #expect(src.contains("exitInProgressRemovesDeviceData = path.map { DestructiveScopeLogic.signOutRemovesDeviceData(path: $0) }"))
    }

    @Test("L16-19: privacidad y términos en la hoja de Safari dentro de Yala")
    func legal_inApp() throws {
        let src = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        let legal = try Self.body(after: "private var legalSection: some View {", in: src, upTo: "// MARK: - Reference Builder")
        #expect(legal.contains("legalPage = InAppWebPage(url: AppConstants.privacyURL)"))
        #expect(legal.contains("legalPage = InAppWebPage(url: AppConstants.termsURL)"))
        #expect(legal.contains(".inAppSafari($legalPage)"))
        #expect(!legal.contains("openURL("))
    }

    @Test("L16-16: el cierre del tutorial ofrece «Hacerlo ahora» y Ajustes lo pone")
    func tutorial_doItNow() throws {
        let completion = try Self.code("Yala/App/Views/Settings/TutorialCompletionView.swift")
        #expect(completion.contains("doItNow.perform(tutorial)"))
        let profile = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains(".environment(\\.tutorialDoItNow, TutorialDoItNowAction { doTutorialNow($0) })"))
        // Nuevo registro y Bandeja los drena el Panel, y solo con el Panel delante (review del lote).
        #expect(profile.contains("leaveSettings(then: [.navigate(.panel), .presentNewTransaction])"))
        #expect(profile.contains("leaveSettings(then: [.navigate(.panel), .presentInboxSheet])"))
        #expect(!profile.contains(".autoOpenBudgetEditor]") && !profile.contains(".autoOpenScheduledEditor]"),
                "«Hacerlo ahora» no abre el editor encima: lleva a la pantalla")
        let list = try Self.code("Yala/App/Views/Settings/TutorialsListView.swift")
        #expect(list.contains("completed.contains(tutorial)"), "la lista vuelve a leer `isCompleted` sin observarlo")
    }

    @Test("L16-17: la lista termina con «Escríbenos», que abre el soporte")
    func faq_footer() throws {
        let src = try Self.code("Yala/App/Views/Settings/FAQView.swift")
        #expect(src.contains("askUsFooter"))
        #expect(src.contains("SupportFormSheet()"))
        for item in ["exchangeRate", "groups", "yalaAI", "whereData", "faceID", "widgets"] {
            #expect(src.contains("case \(item)"), "falta la pregunta «\(item)»")
        }
    }

    @Test("L16-18: el pie de «Enviar» dice a qué dirección va")
    func support_footer() throws {
        let src = try Self.code("Yala/App/Views/Profile/SupportFormSheet.swift")
        #expect(src.contains("L10n.UXL15.supportSendFooter(AppConstants.supportEmail)"))
    }

    @Test("Tema de Pro: ya no vuelve al arrancar; lo devuelve la hoja al confirmar")
    func proTheme_resetsOnConfirm() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(!boot.contains("resetProThemeIfNeeded"))
        let sheet = try Self.code("Yala/App/Views/Subscription/DowngradeResolutionSheet.swift")
        let confirm = try Self.body(after: "private func confirm() {", in: sheet, upTo: "onComplete()")
        #expect(confirm.contains("if themeWillReset {\n            resetProTheme()"))
    }

    @Test("La bienvenida a Pro usa las fichas del paywall")
    func proWelcome_usesTheGrid() throws {
        let src = try Self.code("Yala/App/Views/Subscription/SubscriptionSuccessView.swift")
        #expect(src.contains("ProIncludedGrid()"))
        #expect(!src.contains("featureUnlimitedAccounts, color"))
    }

    @Test("Pasar a crear la cuenta pregunta a la regla del consentimiento")
    func signUpSwitch_wiring() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        let fn = try Self.body(after: "private func switchToSignUp(with signUpProvider: CloudSignInProvider) {",
                               in: src, upTo: "private func progressContent")
        #expect(fn.contains("CloudConsentRegistrationLogic.signUpSwitch(consentAcceptedThisPass: consentAcceptedThisPass)"))
        #expect(fn.contains("case .askConsent:\n            showConsent = true"))
        #expect(fn.contains("CloudConsentRegistrationLogic.persistForSignUpSwitch(pending: &consentPendingPersistence)"))
        #expect(fn.contains("launchFlow { await runBornCloudFlow() }"))
        #expect(src.contains("consentAcceptedThisPass = true"), "nadie marca la aceptación de esta pasada")
    }
}

// MARK: - Textos

@Suite("Lote decidido 15 · textos")
struct UXAudit22Decidido15CopyTests {

    private static let newKeys = [
        "l15.personal.dataNote", "l15.personal.moreAboutData", "l15.rates.search",
        "l15.personalization.voiceLanguageFooter", "l15.personalization.colorfulIconsFooter",
        "l15.personalization.averageLineFooter", "l15.personalization.currencyFormatFooter", "l15.tabBar.rules",
        "l15.permissions.title", "l15.permissions.footer", "l15.permissions.notAskedHint",
        "l15.permissions.changeInSettings", "l15.permissions.notifications", "l15.permissions.notificationsDetail",
        "l15.permissions.camera", "l15.permissions.cameraDetail", "l15.permissions.microphone",
        "l15.permissions.microphoneDetail", "l15.permissions.photos", "l15.permissions.photosDetail",
        "l15.permissions.status.allowed", "l15.permissions.status.limited", "l15.permissions.status.saveOnly",
        "l15.permissions.status.denied", "l15.permissions.status.notAsked", "l15.recommend.row", "l15.recommend.message",
        "l15.tutorials.doItNow", "l15.tutorials.done", "l15.faq.section.currencies", "l15.faq.section.groups",
        "l15.faq.notHere", "l15.faq.writeToUs", "l15.faq.exchangeRate.q", "l15.faq.exchangeRate.a", "l15.faq.groups.q",
        "l15.faq.groups.a", "l15.faq.yalaAI.q", "l15.faq.yalaAI.a", "l15.faq.whereData.q", "l15.faq.whereData.a",
        "l15.faq.faceID.q", "l15.faq.faceID.a", "l15.faq.widgets.q", "l15.faq.widgets.a", "l15.support.sendFooter",
        "l15.removeData.noCopyConfirm", "l15.removeData.exportDiscard", "l15.removeData.exportPending",
        "l15.removeData.exportPendingUnknown", "l15.pro.themeResetNote", "l15.pro.oneMonthThenYearly",
        "l15.pro.oneMonthThenMonthly", "l15.pro.startTrialOneMonth", "l15.pro.gateStartTrialOneMonth",
        "l15.pro.settingsFreeWithTrialOneMonth", "welcome.cloud.otherAccountUsedTitle",
        "welcome.cloud.otherAccountUsedBody", "welcome.cloud.otherAccountUsedBodyGeneric",
    ]

    @Test("Las keys nuevas están en los 16 locales")
    func newKeys_inEveryLocale() {
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            let missing = Self.newKeys.filter { (strings[$0] ?? "").isEmpty }
            #expect(missing.isEmpty, "\(locale.code): faltan \(missing)")
        }
        #expect(scanned == 16, "se esperaban 16 locales, se leyeron \(scanned)")
    }

    @Test("es-419: la hoja se llama Ajustes y ningún texto manda a «Perfil >»")
    func spanish_settingsName() {
        let strings = StringsFileParser.parseStrings(forLocale: "es-419")
        #expect(strings["profile.title"] == "Ajustes")
        let stale = strings.filter { $0.value.contains("Perfil >") || $0.value.contains("en Perfil") }.map(\.key)
        #expect(stale.isEmpty, "textos que mandan a «Perfil»: \(stale.sorted())")
    }

    @Test("es-419: ningún aviso de App Attest habla de «la verificación de seguridad que pide nuestro servidor»")
    func spanish_attestCopy() {
        let strings = StringsFileParser.parseStrings(forLocale: "es-419")
        let stale = strings.filter { $0.value.contains("verificación de seguridad que pide nuestro servidor") }.map(\.key)
        #expect(stale.isEmpty, "siguen con la frase vieja: \(stale.sorted())")
    }

    @Test("es-419: «7 monedas» se corrigió y ninguna respuesta manda a «Suscripción»")
    func spanish_faq() {
        let strings = StringsFileParser.parseStrings(forLocale: "es-419")
        #expect(!(strings["faq.multiCurrency.a"] ?? "").contains("7 monedas"))
        #expect(!(strings["faq.whatIsPro.a"] ?? "").contains("Suscripción"))
        #expect(!(strings["faq.cancelSub.a"] ?? "").contains("Suscripción"))
    }

    @Test("Ningún texto nuevo nombra al proveedor de IA")
    func noAIProviderName() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            for key in Self.newKeys {
                let value = (strings[key] ?? "").lowercased()
                #expect(!value.contains("openai") && !value.contains("gpt"), "\(locale.code) · \(key)")
            }
        }
    }

    @Test("El cuerpo del aviso de otra cuenta lleva sus dos métodos en todos los locales")
    func otherAccountBody_hasBothPlaceholders() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            let body = strings["welcome.cloud.otherAccountUsedBody"] ?? ""
            #expect(body.contains("%1$@") && body.contains("%2$@"), "\(locale.code): «\(body)»")
        }
    }
}
