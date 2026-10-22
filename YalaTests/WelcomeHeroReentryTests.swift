//
//  WelcomeHeroReentryTests.swift
//  YalaTests
//
//  W1 (decisión del owner 2026-08-11, punto 2 de MODO-NUBE-REVISION-FLUJOS-NOTAS):
//  **la reentrada es decisión del usuario**. El Hero ofrecía un alert «Detectamos tu
//  cuenta» disparado por `RestoreOfferGate.hasReturningSignal`, y esa señal solo habla de
//  la cuenta iCloud del container: empujaba hacia esa mitad a quien puede tener su cuenta
//  en la nube (Apple/Google). Quien vuelve entra por "Ya tengo una cuenta", que ofrece las
//  tres vías.
//
//  Lo que se retiró NO deja aserción de comportamiento posible —no queda lógica que
//  decida, que es justamente el punto—, así que el pin es estructural: que el disparo no
//  vuelva, y que las keys no reaparezcan por copia de otro flujo.
//

import Foundation
import Testing

@testable import Yala

@Suite("W1 · el Hero no decide la reentrada (source-scan)")
struct WelcomeHeroReentryTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Solo el CÓDIGO: los docblocks de las tres piezas nombran a propósito lo que se
    /// retiró (`RestoreOfferGate`, el alert, la señal del KV), así que un `!contains`
    /// sobre el fichero crudo se rompería al documentar el invariante — la misma trampa
    /// que ya cazó `WelcomeNewChooserWiringTests.cloudCard_startsTheBornCloudSignUp`.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let heroPath = "Yala/App/Views/Onboarding/WelcomeHeroView.swift"
    private static let containerPath = "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"

    @Test("el Hero no consulta la señal de returning-user: continúa siempre igual")
    func hero_doesNotConsultTheReturningSignal() throws {
        let src = try Self.code(Self.heroPath)
        #expect(!src.contains("RestoreOfferGate"),
                "volver a consultar el gate aquí reintroduce el empuje hacia la cuenta iCloud del container")
        #expect(!src.contains("lastOnboardingTimestamp"))
        #expect(!src.contains("lastWipeTimestamp"))
        // El callback SIN payload es lo que hace imposible el alert: sin decisión que
        // transportar, el container no tiene sobre qué ramificar.
        #expect(src.contains("var onContinue: () -> Void"))
        #expect(!src.contains("HeroDecision"))
    }

    @Test("el container no presenta ningún alert tras el Hero")
    func container_presentsNoAlertAfterTheHero() throws {
        let src = try Self.code(Self.containerPath)
        #expect(!src.contains("DetectedData"))
        #expect(!src.contains(".alert("),
                "el único alert de esta pantalla era «Detectamos tu cuenta»; uno nuevo aquí es un rediseño, no un retoque")
        #expect(!src.contains("onLoadMyData"),
                "el callback murió con el alert: era su única salida")
    }

    /// Punto 1 del mismo chip: el Hero se queda sin subtítulo. Las 8 cards que rotan encima
    /// ya cuentan qué hace Yala y la línea repetía la primera de ellas.
    @Test("el Hero no pinta subtítulo")
    func hero_hasNoSubtitle() throws {
        let src = try Self.code(Self.heroPath)
        #expect(!src.contains("Hero.subtitle"))
        #expect(!src.contains("titleAndSubtitle"),
                "el nombre viejo prometía un subtítulo que ya no existe")
    }

    /// Sin el conteo de locales esto pasaría en verde con el escáner roto o con las
    /// `.lproj` fuera del bundle — la familia de «Executed 0 tests».
    @Test("las keys retiradas no existen en ninguno de los 16 locales")
    func detectedDataKeys_areGoneFromEveryLocale() {
        let retired = [
            "welcome.detectedData.title",
            "welcome.detectedData.message",
            "welcome.detectedData.loadMyData",
            "welcome.detectedData.startFresh",
            "welcome.hero.subtitle",
        ]
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            for key in retired {
                #expect(strings[key] == nil, "'\(key)' reapareció en \(locale.code)")
            }
        }
        #expect(scanned == 16, "se esperaban 16 locales con strings, se leyeron \(scanned)")
    }
}
