//
//  SameEmailAndHonestCopyTests.swift
//  YalaTests
//
//  Cards 188b y luc1 (recorrido de la bienvenida, 13-nov-2026): con el mismo correo Apple y Google abren la misma cuenta
//  y ninguna pantalla dice lo contrario; y los textos de entrada y salida dicen lo que acaba de pasar.
//

import Foundation
import Testing
@testable import Yala

@Suite("Apple y Google con el mismo correo · textos y etiqueta")
struct SameEmailCopyTests {

    static func source(_ relative: String) throws -> String {
        try SignOutSwapInFlightWiringTests.source(relative)
    }

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
        let dict = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
        return dict
    }

    static let locales = ["es-419", "es", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt", "pt-PT", "zh-Hans"]

    /// La nota de antes decía «con Apple sería una cuenta nueva»: el servidor enlaza las identidades por correo
    /// verificado (medido el 16-jul y en E10), y Jürgen decidió que siga así.
    @Test("«Vamos a crear tu cuenta» ya no dice que el otro proveedor sería otra cuenta")
    func createAccountNote_saysSameEmailSameAccount() throws {
        let view = try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        #expect(view.contains("Text(L10n.UnifiedAccess.sameEmailNote)"))
        #expect(!view.contains("otherProviderNote"))
        for locale in Self.locales {
            let table = try Self.strings(locale)
            #expect(table["bienvenida23.access.otherProviderNote"] == nil, "\(locale) conserva la nota vieja")
            let note = try #require(table["bienvenida23.access.sameEmailNote"], "\(locale)")
            #expect(note.contains("Apple") && note.contains("Google"), "\(locale): \(note)")
        }
        let es = try Self.strings("es-419")
        #expect(es["bienvenida23.access.sameEmailNote"]?.contains("la misma cuenta") == true)
    }

    /// Apple da el correo solo en la primera autorización; la etiqueta decía «Apple» en cada entrada posterior.
    @Test("la etiqueta del acceso lee primero el correo de la sesión")
    func accessTag_readsTheSessionEmailFirst() throws {
        let view = Self.squashed(try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"))
        #expect(view.contains("let fromSession = CloudAuthService.shared.sessionEmail"))
        #expect(view.contains("return CloudAuthService.shared.capturedEmail()"))
        #expect(!view.contains("verifiedEmail = CloudAuthService.shared.capturedEmail()"))
        #expect(view.components(separatedBy: "verifiedEmail = Self.verifiedAccessEmail()").count - 1 == 2)
    }

    private static func squashed(_ text: String) -> String { text.replacing(/\s+/, with: " ") }
}

@Suite("Textos de entrada y salida que cuentan lo que pasó")
struct HonestEntryExitCopyTests {

    @Test("el nombre propuesto sale con mayúscula inicial si llega todo en mayúsculas o en minúsculas")
    func proposedName_naturalCase() {
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "JURGEN SCHMIDT") == "Jurgen")
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "ana garcía") == "Ana")
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "ÁLVARO") == "Álvaro")
        // Las mayúsculas propias se respetan.
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "McKenzie Lee") == "McKenzie")
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "Ana") == "Ana")
        // Lo que vuelve de una restauración es el nombre que la persona escribió: no se toca.
        #expect(WelcomeConversationLogic.proposedName(providerName: nil, restoredName: "JUAN") == "JUAN")
    }

    @Test("«Tu suscripción Pro no cambia» solo con Pro")
    func wipeProNote_onlyWithPro() {
        let wipe = DestructiveScopeSheet.Config.make(operation: .wipeDataFull, cloudLabel: .icloud, onConfirm: {})
        #expect(wipe.conservationNote == L10n.Settings.wipeScopeConservation)
        #expect(wipe.conservationNoteNeedsPro)
        let signOut = DestructiveScopeSheet.Config.make(operation: .signOutCloud, cloudLabel: .cloudAccount, onConfirm: {})
        #expect(!signOut.conservationNoteNeedsPro)
    }

    @Test("la hoja pinta la nota de Pro solo con Pro (source-scan)")
    func wipeProNote_isGatedWhenPainted() throws {
        let sheet = try SignOutSwapInFlightWiringTests.source("Yala/App/Views/Shared/DestructiveScopeSheet.swift")
            .replacing(/\s+/, with: " ")
        #expect(sheet.contains(
            "if let note = config.conservationNote, !config.conservationNoteNeedsPro || FeatureGateService.shared.isProUser {"))
    }

    /// Jürgen (E05): «cuidado con lo que comunicamos». La nota afirmaba una copia antigua de iCloud también a quien nunca
    /// usó Yala con iCloud.
    @Test("la copia antigua de iCloud se dice como condición, en todos los idiomas")
    func frozenICloudNote_isConditional() throws {
        for locale in SameEmailCopyTests.locales {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
            let note = try #require(table["settings.deleteAccountFrozenICloudNote"], "\(locale)")
            #expect(!note.lowercased().contains("reinstal") && !note.contains("Neuinstallation")
                    && !note.contains("installatie") && !note.contains("instalacji") && !note.contains("再インストール")
                    && !note.contains("重新安装") && !note.contains("installazione"), "\(locale): \(note)")
        }
    }

    @Test("el alta y la entrada del Welcome no nombran iCloud en su consentimiento")
    func welcomeConsent_doesNotMentionICloud() throws {
        let view = try SignOutSwapInFlightWiringTests.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        #expect(!view.contains("L10n.Storage.Consent.footer"))
        #expect(!view.contains("L10n.Storage.Consent.pointAccess"))
        #expect(view.contains("detail: L10n.UnifiedAccess.consentAccessDetail"))
        for locale in SameEmailCopyTests.locales {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
            let detail = try #require(table["bienvenida23.access.consentAccessDetail"], "\(locale)")
            #expect(!detail.contains("iCloud"), "\(locale): \(detail)")
        }
    }

    @Test("una cuenta nueva no dice «¡Tu cuenta está lista!» antes de las tres preguntas")
    func newAccount_saysCreatedThenThreeQuestions() throws {
        let view = try SignOutSwapInFlightWiringTests.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
            .replacing(/\s+/, with: " ")
        #expect(view.contains(#"readyContent(id: "welcome_born_cloud_ready", title: L10n.UnifiedAccess.createdTitle, body: L10n.UnifiedAccess.createdBody, action: onBornCloudCompleted)"#))
    }

    @Test("«Descargando tus datos…» no sale en una cuenta creada en este teléfono")
    func hydrationBanner_hiddenForAnAccountCreatedHere() throws {
        let banner = try SignOutSwapInFlightWiringTests.source("Yala/App/Views/Shared/CloudHydrationBanner.swift")
            .replacing(/\s+/, with: " ")
        #expect(banner.contains("if visible, !Self.accountWasCreatedOnThisDevice() {"))
        #expect(banner.contains("CloudClaimActionStore.shared.action(forUserID: userID) == .seedBornCloud"))
    }
}
