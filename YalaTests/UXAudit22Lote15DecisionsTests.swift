//
//  UXAudit22Lote15DecisionsTests.swift
//  YalaTests
//
//  Las siete decisiones de Jürgen sobre el lote 15 de la auditoría UX 2.2 («Desde fuera de la app», 2026-10-18):
//  · L15-4 «Siri y Atajos» con los nombres de Atajos y un botón que abre la página de Yala en Atajos.
//  · L15-6 Sin Pro, Siri abre la hoja de Pro, y el modelo del iPhone detrás de un interruptor apagado.
//  · L15-7 El aviso de la Bandeja con su línea «Borradores de Siri: N».
//  · L15-8 La notificación de Apple Pay: «Pago de … por revisar», en la moneda del borrador.
//  · L15-9 La guía de Apple Pay con capturas de iOS 27.
//  · L15-10 La guía sin «Listo» hasta el último paso, y el avance guardado.
//  Las frases de L15-5 las fija `SiriPhrasesPortugueseTests` (SiriIOS27Tests.swift) contra el bundle.
//

import Foundation
import Testing
import UIKit
@testable import Yala

private enum Lote15Repo {
    static func text(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    /// Sin líneas de comentario: documentar lo que el test prohíbe no puede ponerlo en rojo.
    static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    static func string(_ key: String, lang: String) throws -> String? {
        let source = try text("Yala/Resources/\(lang).lproj/Localizable.strings")
        for line in source.split(separator: "\n") where line.hasPrefix("\"\(key)\" = \"") {
            var value = line.dropFirst("\"\(key)\" = \"".count)
            guard value.hasSuffix("\";") else { continue }
            value = value.dropLast(2)
            return value.replacingOccurrences(of: "\\\"", with: "\"")
        }
        return nil
    }

    /// El tramo de `source` entre `start` y la primera aparición de `end` después de él.
    static func slice(_ source: String, from start: String, to end: String) throws -> String {
        let lower = try #require(source.range(of: start), "No está «\(start)».")
        let upper = try #require(source.range(of: end, range: lower.upperBound..<source.endIndex), "No está «\(end)».")
        return String(source[lower.lowerBound..<upper.lowerBound])
    }

    static let languages = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                            "pt", "pt-BR", "pt-PT", "zh-Hans"]
}

// MARK: - L15-4

@Suite("Lote 15 · L15-4 «Siri y Atajos» con los nombres de Atajos y el botón a su página")
struct SiriShortcutsScreenNamesTests {

    /// Cada fila se llama con la MISMA clave que pinta Atajos (`shortTitle` del `AppShortcut`): casan en los 16 idiomas.
    @Test func lasFilas_usanElNombreDeAtajos() throws {
        let view = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/Views/Settings/SiriShortcutsView.swift"))
        let provider = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/Intents/AppShortcutsProvider.swift"))
        for key in ["shortcut.quickExpense.shortTitle", "shortcut.voiceEntry.shortTitle",
                    "shortcut.imageEntry.shortTitle", "shortcut.applePay.shortTitle", "shortcut.siriNatural.shortTitle"] {
            #expect(view.contains("String(localized: \"\(key)\")"), "La pantalla no usa \(key).")
            #expect(provider.contains("shortTitle: \"\(key)\""), "\(key) ya no es el nombre de un atajo.")
        }
        #expect(!view.contains("siriShortcuts.shortcut."), "Vuelve un nombre propio de la pantalla, distinto del de Atajos.")
        #expect(!view.contains("siriShortcuts.siri.title"))
    }

    /// El botón relleno al pie: el de Yala se ve y el de Apple, encima, recibe el toque (no hay URL a esa página).
    @Test func elBoton_abreLaPaginaDeYalaEnAtajos() throws {
        let view = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/Views/Settings/SiriShortcutsView.swift"))
        let button = try Lote15Repo.slice(view, from: "YalaPrimaryButton(String(localized: \"siriShortcuts.openShortcuts\")",
                                          to: ".padding(.top, DS.Spacing.md)")
        #expect(button.contains(".allowsHitTesting(false)"))
        #expect(button.contains(".overlay { ShortcutsPageButtonOverlay() }"))
        #expect(button.contains(".accessibilityIdentifier(\"siri_shortcuts_open_shortcuts\")"))
        let overlay = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/Views/Settings/ShortcutsPageOpener.swift"))
        #expect(overlay.contains("ShortcutsUIButton(style: .automatic)"))
        // Por debajo de 0,01 UIKit deja de entregarle el toque.
        #expect(overlay.contains("button.alpha = 0.02"))
    }

    /// «También: «A» · «B»» con las dos frases alternativas y las comillas del idioma.
    @Test func laLineaDeAlternativas_llevaLasDosFrases() {
        let line = SiriShortcutsView.alsoSay
        #expect(line.contains(String(localized: "siriShortcuts.siri.alt1")))
        #expect(line.contains(String(localized: "siriShortcuts.siri.alt2")))
        #expect(SiriShortcutsView.quoted("X") != "X")
    }

    @Test(arguments: Lote15Repo.languages)
    func losTextosNuevos_estanEnCadaIdioma(_ lang: String) throws {
        for key in ["siriShortcuts.openShortcuts", "siriShortcuts.siri.alsoSay", "siriShortcuts.quotedPhrase",
                    "siriShortcuts.desc.quick", "siriShortcuts.desc.voice", "siriShortcuts.desc.image",
                    "siriShortcuts.desc.applePay"] {
            let value = try #require(try Lote15Repo.string(key, lang: lang), "Falta \(key) en \(lang).")
            #expect(!value.isEmpty)
        }
        // Las alternativas son la frase sola: las comillas las pone la pantalla.
        for key in ["siriShortcuts.siri.alt1", "siriShortcuts.siri.alt2"] {
            let value = try #require(try Lote15Repo.string(key, lang: lang))
            #expect(!value.contains("\""), "\(lang) · \(key) trae comillas: «\(value)».")
        }
        // La imagen ya no dice «con la cámara»: también lee archivos y PDF.
        let image = try #require(try Lote15Repo.string("siriShortcuts.desc.image", lang: lang))
        #expect(image.contains("PDF") || image.lowercased().contains("pdf"), "\(lang): «\(image)».")
    }
}

// MARK: - L15-6

@Suite("Lote 15 · L15-6 Sin Pro, Siri abre la hoja de Pro")
struct SiriEntryRouteTests {

    @Test func pro_leeEnElServidor_sinMirarElTelefono() {
        #expect(SiriEntryRoute.decide(isPro: true, onDeviceEnabled: false, onDeviceAvailable: false) == .server)
        #expect(SiriEntryRoute.decide(isPro: true, onDeviceEnabled: true, onDeviceAvailable: true) == .server)
    }

    @Test func sinPro_abreLaHojaDePro_salvoConElModeloDelTelefonoEncendidoYDisponible() {
        #expect(SiriEntryRoute.decide(isPro: false, onDeviceEnabled: false, onDeviceAvailable: true) == .upgrade)
        #expect(SiriEntryRoute.decide(isPro: false, onDeviceEnabled: true, onDeviceAvailable: false) == .upgrade)
        #expect(SiriEntryRoute.decide(isPro: false, onDeviceEnabled: false, onDeviceAvailable: false) == .upgrade)
        #expect(SiriEntryRoute.decide(isPro: false, onDeviceEnabled: true, onDeviceAvailable: true) == .onDevice)
    }

    /// Pro se mira ANTES de pedir el texto: dictarlo para tirarlo era perderlo. Y la salida abre Yala en la hoja de Pro
    /// de la voz (el atajo `voice-entry`, que sin Pro la presenta).
    @Test func elCableado_preguntaProAntesDelTexto_yAbreYala() throws {
        let source = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/Intents/QuickExpenseIntent.swift"))
        let intent = try Lote15Repo.slice(source, from: "struct SiriNaturalEntryIntent", to: "enum LastUsedAccountStore")
        let decide = try #require(intent.range(of: "SiriEntryRoute.decide("))
        let ask = try #require(intent.range(of: "$text.requestValue("))
        #expect(decide.lowerBound < ask.lowerBound, "Se pide el texto antes de mirar Pro.")
        #expect(intent.contains("static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }"))
        let exit = try Lote15Repo.slice(intent, from: "private func openProSheet()", to: "static func parseTransactions(")
        #expect(exit.contains("try await continueInForeground(nil, alwaysConfirm: false)"))
        #expect(exit.contains("return dialog"), "El aviso tiene que ir en el resultado.")
        #expect(exit.contains("WidgetURLHelper.url(for: \"voice-entry\")"))
        #expect(!intent.contains("guard isProUser else"), "Vuelve la puerta vieja, que contestaba y no llevaba a ningún sitio.")
    }

    /// El modelo del teléfono va APAGADO en producción hasta que Jürgen decida encenderlo.
    @Test func elModeloDelTelefono_vaApagadoFueraDeDebug() throws {
        let source = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/Intents/SiriOnDeviceEntry.swift"))
        let flag = try Lote15Repo.slice(source, from: "static var isEnabled: Bool {", to: "static var isAvailable")
        let release = try Lote15Repo.slice(flag, from: "#else", to: "#endif")
        #expect(release.split(whereSeparator: \.isWhitespace) == ["#else", "false"], "Fuera de DEBUG: «\(release)».")
    }
}

// MARK: - L15-7

@Suite("Lote 15 · L15-7 El aviso de la Bandeja cuenta los borradores de Siri en su línea")
@MainActor
struct InboxAlertSiriLineTests {

    @Test func cadaBorrador_cuentaSegunDeDondeVino() {
        var n = PendingInboxNotification()
        for raw in ["scheduledPayment", "subscription", "applePay", "automation", "siri", "siri", "voice",
                    "receiptPhoto", "groupExpense"] {
            n.count(sourceTypeRaw: raw)
        }
        #expect(n == PendingInboxNotification(scheduledPayments: 1, subscriptions: 1, automations: 2, siriDrafts: 2))
    }

    /// Solo Siri: el aviso genérico de la Bandeja y la línea.
    @Test func soloSiri_esLaLinea() {
        let n = PendingInboxNotification(siriDrafts: 3)
        #expect(!n.isEmpty)
        #expect(n.notificationType == .mixed)
        #expect(InboxAlertModal.message(for: n) == L10n.Inbox.Alert.siriDrafts(3))
    }

    /// Con otros tipos, su mensaje de siempre y la línea debajo; sin Siri, el mensaje de siempre (control).
    @Test func conOtros_elMensajeDeSiempreYLaLineaDebajo() {
        let withSiri = PendingInboxNotification(scheduledPayments: 2, siriDrafts: 1)
        #expect(InboxAlertModal.message(for: withSiri)
                == L10n.Inbox.Alert.Message.scheduled(2) + "\n" + L10n.Inbox.Alert.siriDrafts(1))
        let without = PendingInboxNotification(scheduledPayments: 2)
        #expect(InboxAlertModal.message(for: without) == L10n.Inbox.Alert.Message.scheduled(2))
        #expect(withSiri.notificationType == without.notificationType, "Siri no decide el tipo del aviso.")
    }

    @Test(arguments: Lote15Repo.languages)
    func laLinea_estaEnCadaIdioma(_ lang: String) throws {
        let value = try #require(try Lote15Repo.string("inbox.alert.siriDrafts", lang: lang))
        #expect(value.contains("%d") && value.contains("Siri"), "\(lang): «\(value)».")
    }

    /// El recuento de verdad pasa por `count(sourceTypeRaw:)`: un `switch` propio en el arranque dejaría fuera a Siri.
    @Test func elArranque_cuentaConLaMismaRegla() throws {
        let source = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/AppBootstrapper.swift"))
        let check = try Lote15Repo.slice(source, from: "private func checkForPendingInboxDrafts(", to: "func commitPendingInboxAlertSignatures()")
        #expect(check.contains("notification.count(sourceTypeRaw: draft.sourceTypeRaw)"))
        #expect(!check.contains("notification.automations += 1"))
    }
}

// MARK: - L15-8

@Suite("Lote 15 · L15-8 La notificación de Apple Pay dice que hay algo por revisar, en la moneda del borrador")
@MainActor
struct ApplePayNotificationCopyTests {

    /// Última cuenta «A»: sin símbolo, la Bandeja lo enseña en soles; con `$`, en soles (la regla de siempre); con `kr`, sin
    /// cuenta que case (la moneda por defecto).
    private let hint = ApplePayCurrencyHint(lastUsedAccountID: "A", noSymbolCurrency: "PEN", currencyBySymbol: ["$": "PEN"])

    @Test func sinSimbolo_laMonedaEnQueLoEnsenaraLaBandeja() {
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: nil, ambiguousSymbol: nil, hint: hint, lastUsedAccountID: "A", defaultCurrency: "EUR") == "PEN")
        let noAccount = ApplePayCurrencyHint(lastUsedAccountID: "A", noSymbolCurrency: nil, currencyBySymbol: [:])
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: nil, ambiguousSymbol: nil, hint: noAccount, lastUsedAccountID: "A", defaultCurrency: "EUR") == "EUR")
    }

    @Test func conSimboloAmbiguo_laQuePondraElBorrador() {
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: "USD", ambiguousSymbol: "$", hint: hint, lastUsedAccountID: "A", defaultCurrency: nil) == "PEN")
        // `kr` sin cuenta que case: la Bandeja lo enseña en la moneda por defecto, y la notificación también.
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: "NOK", ambiguousSymbol: "kr", hint: hint, lastUsedAccountID: "A", defaultCurrency: "EUR") == "EUR")
    }

    @Test func unaMonedaInequivoca_manda() {
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: "EUR", ambiguousSymbol: nil, hint: hint, lastUsedAccountID: "A", defaultCurrency: nil) == "EUR")
    }

    /// Una pista de OTRA cuenta no vale: la última cuenta usada cambió y aún no se reescribió. Y sin ninguna pista
    /// escrita (Yala sin abrir desde la instalación), tampoco: `nil == nil` no la da por buena.
    @Test func unaPistaDeOtraCuenta_noVale() {
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: nil, ambiguousSymbol: nil, hint: hint, lastUsedAccountID: "B", defaultCurrency: "EUR") == "EUR")
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: nil, ambiguousSymbol: nil, hint: nil, lastUsedAccountID: nil, defaultCurrency: nil) == "USD")
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: "USD", ambiguousSymbol: "$", hint: hint, lastUsedAccountID: "B", defaultCurrency: nil) == "USD")
        let none = ApplePayCurrencyHint(lastUsedAccountID: nil, noSymbolCurrency: "PEN", currencyBySymbol: [:])
        #expect(ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: nil, ambiguousSymbol: nil, hint: none, lastUsedAccountID: nil, defaultCurrency: "EUR") == "PEN")
    }

    @Test func laPista_seGuardaYSeLee() {
        let defaults = makeIsolatedDefaults()
        ApplePayCurrencyHint.write(hint, defaults: defaults)
        #expect(ApplePayCurrencyHint.read(defaults: defaults) == hint)
        ApplePayCurrencyHint.write(nil, defaults: defaults)
        #expect(ApplePayCurrencyHint.read(defaults: defaults) == nil)
    }

    /// «Pago de S/ 25,90 en Tambo por revisar»; sin comercio, «Pago de S/ 25,90 por revisar».
    @Test func elTitulo_llevaImporteYComercio() {
        let withMerchant = L10n.Shortcut.Notification.applePayTitle(amount: "S/ 25.90", merchant: "Tambo")
        #expect(withMerchant.contains("S/ 25.90") && withMerchant.contains("Tambo"))
        let without = L10n.Shortcut.Notification.applePayTitle(amount: "S/ 25.90", merchant: "")
        #expect(without.contains("S/ 25.90") && !without.contains("  "))
        #expect(!L10n.Shortcut.Notification.applePayBody.isEmpty)
    }

    @Test(arguments: Lote15Repo.languages)
    func losTextos_estanEnCadaIdioma(_ lang: String) throws {
        let title = try #require(try Lote15Repo.string("shortcut.applePay.notification.title", lang: lang))
        #expect(title.contains("%1$@") && title.contains("%2$@"), "\(lang): «\(title)».")
        let short = try #require(try Lote15Repo.string("shortcut.applePay.notification.titleNoMerchant", lang: lang))
        #expect(short.contains("%@"), "\(lang): «\(short)».")
        #expect(try Lote15Repo.string("shortcut.applePay.notification.body", lang: lang) != nil)
        #expect(try Lote15Repo.string("shortcut.notification.title", lang: lang) == nil, "\(lang) conserva «Nuevo registro automático».")
    }

    /// El atajo usa la pista y no cae a dólares.
    @Test func elAtajo_leeLaPista() throws {
        let source = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/Intents/QuickExpenseIntent.swift"))
        let applePay = try Lote15Repo.slice(source, from: "struct ApplePayTransactionIntent", to: "struct SiriNaturalEntryIntent")
        #expect(applePay.contains("ApplePayCurrencyHint.notificationCurrency("))
        #expect(!applePay.contains("parsed.currency ?? \"USD\""))
        #expect(applePay.contains("L10n.Shortcut.Notification.applePayTitle("))
    }
}

// MARK: - L15-9

@Suite("Lote 15 · L15-9 La guía de Apple Pay enseña el Atajos de iOS 27")
@MainActor
struct ApplePayGuideIOS27Tests {

    /// «Lo que vas a ver» son las capturas de iOS 27 del catálogo, una por paso, y ya no los vídeos de iOS 26.
    @Test func cadaPaso_tieneSuCaptura_yNoHayVideo() {
        let steps = Tutorial.applePay.steps
        #expect(steps.count == 4)
        for step in steps {
            #expect(step.videoURL == nil, "Vuelve un vídeo de iOS 26 en el paso \(step.id + 1).")
            let name = step.screenshotName
            #expect(name == "tutorial-applePay-step\(step.id)")
            #expect(name.flatMap { UIImage(named: $0) } != nil, "Falta la captura del paso \(step.id + 1).")
        }
    }

    /// Un solo texto para iOS 26 y 27: el paso 1 dice dónde está Automatización en los dos, sin «la sección de».
    @Test(arguments: ["es", "es-419", "es-AR", "es-ES"])
    func elPaso1_valeParaLasDosVersiones(_ lang: String) throws {
        let step0 = try #require(try Lote15Repo.string("tutorials.applePay.step0.desc", lang: lang))
        #expect(step0.contains("Automatización") && step0.contains("Biblioteca"), "\(lang): «\(step0)».")
        #expect(!step0.contains("sección de Automatizaciones"))
    }
}

// MARK: - L15-10

@Suite("Lote 15 · L15-10 La guía no deja terminar hasta el último paso, y guarda el avance")
struct StepGuideFooterAndProgressTests {

    @Test func elAvance_seGuardaPorGuia_ySeBorraAlTerminar() {
        let defaults = makeIsolatedDefaults()
        var progress = StepGuideProgressStore.load("x", total: 4, defaults: defaults)
        #expect(progress.completed == 0 && progress.remaining == 4)
        progress.complete(0)
        progress.complete(1)
        StepGuideProgressStore.save(progress, guideID: "x", defaults: defaults)
        #expect(StepGuideProgressStore.load("x", total: 4, defaults: defaults).completed == 2)
        #expect(StepGuideProgressStore.load("y", total: 4, defaults: defaults).completed == 0, "El avance es de cada guía.")
        StepGuideProgressStore.clear("x", defaults: defaults)
        #expect(StepGuideProgressStore.load("x", total: 4, defaults: defaults).completed == 0)
    }

    /// Un valor guardado fuera de rango (una guía que perdió pasos) no deja la guía terminada ni en negativo.
    @Test func unValorGuardadoFueraDeRango_seAcota() {
        let defaults = makeIsolatedDefaults()
        defaults.set(9, forKey: StepGuideProgressStore.key("x"))
        #expect(StepGuideProgressStore.load("x", total: 3, defaults: defaults).completed == 3)
        defaults.set(-2, forKey: StepGuideProgressStore.key("x"))
        #expect(StepGuideProgressStore.load("x", total: 3, defaults: defaults).completed == 0)
    }

    /// «Listo» solo con todos los pasos hechos; mientras tanto, cuántos faltan.
    @Test func elPie_soloOfreceTerminarConTodoHecho() throws {
        let source = Lote15Repo.codeOnly(try Lote15Repo.text("Yala/App/DesignSystem/StepGuide.swift"))
        let footer = try Lote15Repo.slice(source, from: "private var footer: some View {", to: "Button(action: onStuck)")
        let finished = try #require(footer.range(of: "if progress.isFinished {"))
        let primary = try #require(footer.range(of: "YalaPrimaryButton(successTitle, action: finish)"))
        let otherwise = try #require(footer.range(of: "} else {"))
        #expect(finished.lowerBound < primary.lowerBound && primary.lowerBound < otherwise.lowerBound)
        #expect(footer.contains("L10n.StepGuide.remaining(progress.remaining)"))
        #expect(source.components(separatedBy: "YalaPrimaryButton(").count == 2, "Hay otra salida de éxito en la guía.")
        #expect(source.contains("StepGuideProgressStore.save(progress, guideID: progressID)"))
        #expect(source.contains("StepGuideProgressStore.load(progressID, total: steps.count)"))
    }
}
