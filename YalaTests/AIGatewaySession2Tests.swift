//
//  AIGatewaySession2Tests.swift
//  YalaTests
//
//  Sesión 2 del gateway de IA (`ai-every-call-sends-its-task-and-passes-the-bench`), lo que no es la cabecera:
//
//  - La voz sigue el idioma de Yala (no el del iPhone) y cubre los 10 idiomas; nada cae a inglés.
//  - El cupo de prueba agotado (403 `yala_trial_exhausted`) se cuenta como tal en voz y en foto, con salida a Pro.
//  - La foto sube reducida al lado mayor que publica el gateway, sin ampliarse nunca.
//  - El «$» a secas lo decide la divisa principal del usuario; los símbolos de los 10 idiomas están en el prompt.
//  - `/config` trae el lado mayor y un snapshot viejo sigue decodificando.
//

import Foundation
import Testing
import UIKit
@testable import Yala

// MARK: - Idioma de voz

@Suite("Voz — el idioma sigue al de la app y cubre los 10")
struct VoiceLanguageSession2Tests {

    @Test("«Idioma de la app» toma el idioma de Yala, con sus variantes regionales")
    func appLanguageFollowsTheApp() {
        let cases: [(String, String)] = [
            ("es-PE", "es"), ("es-419", "es"), ("es-ES", "es"), ("es-AR", "es"),
            ("en", "en"), ("en-GB", "en"), ("pt-BR", "pt"), ("pt-PT", "pt"),
            ("fr", "fr"), ("de", "de"), ("it", "it"), ("nl", "nl"), ("pl", "pl"), ("ja", "ja"), ("zh-Hans", "zh"),
        ]
        for (app, expected) in cases {
            #expect(VoiceLanguage.isoCode(for: .system, appLocale: Locale(identifier: app)) == expected, "app en \(app)")
        }
    }

    @Test("un idioma elegido a mano manda el suyo aunque la app esté en otro")
    func explicitLanguageWins() {
        #expect(VoiceLanguage.isoCode(for: .japanese, appLocale: Locale(identifier: "es-PE")) == "ja")
        #expect(VoiceLanguage.isoCode(for: .english, appLocale: Locale(identifier: "pl")) == "en")
    }

    @Test("el selector ofrece «Idioma de la app» y los 10 idiomas, sin «Sistema»")
    func selectorCoversTheTen() {
        #expect(VoiceLanguage.allCases.count == 11)
        let codes = Set(VoiceLanguage.allCases.filter { $0 != .system }.map(\.rawValue))
        #expect(codes == ["es", "en", "pt", "fr", "de", "it", "nl", "pl", "ja", "zh"])
        #expect(VoiceLanguage.system.displayName == L10n.VoiceLanguage.appLanguage)
        // El valor persistido de antes («Sistema») sigue leyéndose: pasa a seguir el idioma de la app.
        #expect(VoiceLanguage(rawValue: "system") == .system)
    }

    @Test("ningún idioma de la app cae a inglés por no reconocerse (antes: cualquier idioma fuera de la lista → en)")
    func noSilentEnglish() {
        for locale in SupportedLocale.allCases where !locale.code.hasPrefix("en") {
            #expect(VoiceLanguage.isoCode(for: .system, appLocale: Locale(identifier: locale.code)) != "en", "\(locale.code)")
        }
    }
}

@Suite("Voz — los términos del usuario para el motor")
struct VoiceKeywordsSession2Tests {
    @Test("comercios primero, sin repetir (mayúsculas aparte), sin vacíos ni larguísimos, con tope")
    func terms() {
        let t = VoiceTranscriptionKeywords.terms(merchants: ["Plaza Vea", "plaza vea", " ", "Rappi"], subcategories: ["Mercado", "Taxi", String(repeating: "x", count: 80)])
        #expect(t == ["Plaza Vea", "Rappi", "Mercado", "Taxi"])
        #expect(VoiceTranscriptionKeywords.terms(merchants: (0..<120).map { "Comercio \($0)" }, subcategories: []).count == VoiceTranscriptionKeywords.maxTerms)
    }
}

// MARK: - Cupo de prueba agotado

@MainActor
@Suite("Cupo de prueba agotado — voz y foto lo cuentan y ofrecen Pro")
struct TrialExhaustedSession2Tests {

    private struct Stub: Error {}
    private var trial: Error { ProxyErrorMapper.trialExhaustedResponse() }

    @Test("el sobre del gateway se decodifica con su tipo")
    func envelopeDecodes() {
        #expect(ProxyErrorMapper.gatewayType(from: trial) == "yala_trial_exhausted")
        #expect(ProxyErrorMapper.isTrialExhausted(trial))
        #expect(!ProxyErrorMapper.isTrialExhausted(Stub()))
    }

    @Test("voz: el 403 al transcribir o al leer la nota → «ya usaste tus notas de prueba», con o sin red")
    func voice() {
        for connected in [true, false] {
            #expect(VoiceEntryFlowLogic.failure(for: TranscriptionError.networkError(trial), isConnected: connected) == .trialUsedUp)
            #expect(VoiceEntryFlowLogic.failure(for: ParserError.networkError(trial), isConnected: connected) == .trialUsedUp)
        }
        // Un fallo de red cualquiera sigue siendo lo de antes.
        #expect(VoiceEntryFlowLogic.failure(for: TranscriptionError.networkError(Stub()), isConnected: true) == .generic)
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.networkError(Stub()), isConnected: false) == .noConnection)
        // Repetir el mismo audio no lo arregla.
        #expect(!VoiceEntryFailure.trialUsedUp.retriesSameAudio)
    }

    @Test("foto: el 403 → «ya usaste tus fotos de prueba», y manda sobre el resto de fallos de la tanda")
    func image() {
        #expect(ImageEntryFlowLogic.failure(for: .networkError(trial), isConnected: true) == .trialUsedUp)
        #expect(ImageEntryFlowLogic.failure(for: .networkError(Stub()), isConnected: true) == .generic)
        #expect(!ImageEntryFailure.trialUsedUp.retriesSamePhotos)
        let outcomes: [ImageReadOutcome] = [.failed(.noConnection), .failed(.trialUsedUp), .failed(.noAmount)]
        #expect(ImageEntryFlowLogic.result(for: outcomes) == .failure(.trialUsedUp))
        // Si alguna foto se leyó, se revisa lo leído como siempre.
        #expect(ImageEntryFlowLogic.result(for: [.read, .failed(.trialUsedUp)]) == .review(failedPhotos: 1))
    }
}

// MARK: - Tamaño de la foto

@MainActor
@Suite("Foto — sube al lado mayor que aprovecha el modelo")
struct PhotoUploadSizingSession2Tests {

    @Test("el lado mayor del gateway se usa si es razonable; si no, 1536")
    func maxEdgeFromRemote() {
        #expect(PhotoUploadSizing.maxEdge(remote: nil) == 1536)
        #expect(PhotoUploadSizing.maxEdge(remote: 1024) == 1024)
        #expect(PhotoUploadSizing.maxEdge(remote: 2048) == 2048)
        #expect(PhotoUploadSizing.maxEdge(remote: 50) == 1536)
        #expect(PhotoUploadSizing.maxEdge(remote: 20_000) == 1536)
    }

    @Test("reduce conservando la proporción y nunca amplía")
    func target() {
        #expect(PhotoUploadSizing.targetPixelSize(for: CGSize(width: 4032, height: 3024), maxEdge: 1536) == CGSize(width: 1536, height: 1152))
        #expect(PhotoUploadSizing.targetPixelSize(for: CGSize(width: 3024, height: 4032), maxEdge: 1536) == CGSize(width: 1152, height: 1536))
        #expect(PhotoUploadSizing.targetPixelSize(for: CGSize(width: 1200, height: 800), maxEdge: 1536) == nil)
        #expect(PhotoUploadSizing.targetPixelSize(for: CGSize(width: 1536, height: 1000), maxEdge: 1536) == nil)
    }

    @Test("el JPEG que sube mide eso en píxeles, también con una imagen @3x")
    func uploadJPEG() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        // 1000×800 pt a @3x = 3000×2400 px.
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 800), format: format).image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1000, height: 800))
        }
        let data = try #require(ImageVisionService.uploadJPEG(image, maxEdge: 1536))
        let decoded = try #require(UIImage(data: data))
        #expect(decoded.size.width * decoded.scale == 1536)
        #expect(decoded.size.height * decoded.scale == 1229)
    }
}

// MARK: - Divisas de la foto

@MainActor
@Suite("Foto — el «$» a secas y los símbolos de los 10 idiomas")
struct VisionCurrencySession2Tests {

    @Test("«$» a secas: la divisa principal si se escribe con $; si no, no decide")
    func dollarAlone() {
        #expect(VisionCurrencyContext(mainCurrency: "MXN", accountCurrencies: ["MXN"]).dollarAlone == "MXN")
        #expect(VisionCurrencyContext(mainCurrency: "USD", accountCurrencies: []).dollarAlone == "USD")
        #expect(VisionCurrencyContext(mainCurrency: "COP", accountCurrencies: []).dollarAlone == "COP")
        // Un peruano con cuenta en dólares: «$» solo sigue sin decir qué dólar es (lo elige en la revisión).
        #expect(VisionCurrencyContext(mainCurrency: "PEN", accountCurrencies: ["PEN", "USD"]).dollarAlone == nil)
        #expect(VisionCurrencyContext(mainCurrency: "BRL", accountCurrencies: []).dollarAlone == nil) // R$ no es «$»
        #expect(VisionCurrencyContext.unknown.dollarAlone == nil)
    }

    @Test("el prompt lleva la regla del «$» del usuario y los símbolos de los 10 idiomas")
    func prompt() {
        let mx = ImageVisionService().systemPrompt(currency: VisionCurrencyContext(mainCurrency: "MXN", accountCurrencies: ["MXN", "USD"]))
        #expect(mx.hasPrefix("You are a financial transaction extractor."), "la huella con la que el gateway deduce la tarea")
        #expect(mx.contains("\"$\" symbol alone → \"MXN\""))
        #expect(mx.contains("The user's main currency is MXN and their accounts use MXN, USD."))
        let pe = ImageVisionService().systemPrompt(currency: VisionCurrencyContext(mainCurrency: "PEN", accountCurrencies: []))
        #expect(pe.contains("\"$\" symbol alone → null"))
        #expect(!pe.contains("\"$\" symbol alone or \"US$\" → \"USD\""), "la regla vieja leía todo «$» como dólares")
        for needle in ["\"R$\" symbol → \"BRL\"", "\"zł\" or \"PLN\" → \"PLN\"", "in a Japanese text → \"JPY\"", "in a Chinese text → \"CNY\"", "\"CHF\""] {
            #expect(pe.contains(needle), "falta \(needle)")
        }
        // Sin divisas conocidas no se inventa ninguna.
        let unknown = ImageVisionService().systemPrompt(currency: .unknown)
        #expect(!unknown.contains("The user's main currency"))
    }
}

// MARK: - /config

@Suite("/config — el lado mayor de la foto")
struct RemoteConfigPhotoEdgeSession2Tests {

    @Test("el wire trae ai.photoMaxEdge")
    func wire() throws {
        let json = Data(#"{"v":1,"flags":{},"forceUpdate":{"minSupportedBuild":0},"ai":{"photoMaxEdge":1536}}"#.utf8)
        let wire = try JSONDecoder().decode(RemoteConfigWireResponse.self, from: json)
        #expect(wire.ai?.photoMaxEdge == 1536)
    }

    @Test("un gateway de antes (sin ai) y un snapshot de antes siguen decodificando, sin lado mayor")
    func oldShapes() throws {
        let oldWire = Data(#"{"v":1,"flags":{"cloudModeRolloutPercent":100}}"#.utf8)
        #expect(try JSONDecoder().decode(RemoteConfigWireResponse.self, from: oldWire).ai == nil)
        let oldSnapshot = Data(#"{"cloudModeRolloutPercent":100,"fetchedAt":0}"#.utf8)
        let snap = try JSONDecoder().decode(RemoteFlagsSnapshot.self, from: oldSnapshot)
        #expect(snap.photoMaxEdge == nil)
        #expect(PhotoUploadSizing.maxEdge(remote: snap.photoMaxEdge) == 1536)
    }
}
