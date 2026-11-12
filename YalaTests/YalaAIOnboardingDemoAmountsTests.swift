//
//  YalaAIOnboardingDemoAmountsTests.swift
//  YalaTests
//
//  La presentación de Yala IA enseña importes en la divisa principal (ticket
//  `ai-onboarding-demo-speaks-english-and-dollars`). Cubre el escalado y redondeo de los
//  importes y el contrato de las cadenas: los huecos que el código rellena, sin rayas y con
//  «Yala IA» en las locales cuyo chat ya se llama así.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct YalaAIOnboardingDemoAmountsTests {

    // MARK: - Importes

    @Test func usd_keepsTheBaseFigures() {
        #expect(YalaAIOnboardingDemoAmounts.amounts(for: .usd) == YalaAIOnboardingDemoAmounts.baseUSD)
    }

    /// El caso del ticket: en MXN el almuerzo ya no son «12» sino una cifra de pesos.
    @Test func mxn_scalesAndRoundsEveryFigure() {
        let a = YalaAIOnboardingDemoAmounts.amounts(for: .mxn)   // 1 USD = 17,2 MXN
        #expect(a.lunch == 210)                    // 206,4
        #expect(a.coffeeThisMonth == 770)          // 774
        #expect(a.coffeeAboveAverage == 140)       // 137,6
        #expect(a.deliverySavingPerMonth == 1_400) // 1.376
        #expect(a.deliverySavingPerYear == 16_800)
        #expect(a.saverSavingPerMonth == 690)      // 688
    }

    @Test func jpy_matchesWhatTheJapaneseCopyUsedToSay() {
        let a = YalaAIOnboardingDemoAmounts.amounts(for: .jpy)   // 1 USD = 150 JPY
        #expect(a.lunch == 1_800)
        #expect(a.deliverySavingPerMonth == 12_000)
    }

    /// «son X al año» tiene que ser verdad en toda divisa: el anual es el mensual × 12.
    @Test func everyCurrency_yieldsPositiveAmounts_andAnHonestYear() {
        for currency in CurrencyCode.allCases {
            let a = YalaAIOnboardingDemoAmounts.amounts(for: currency)
            let all = [a.lunch, a.coffeeThisMonth, a.coffeeAboveAverage,
                       a.deliverySavingPerMonth, a.saverSavingPerMonth]
            #expect(all.allSatisfy { $0 >= 1 && $0.isFinite }, "\(currency)")
            #expect(a.deliverySavingPerYear == a.deliverySavingPerMonth * 12, "\(currency)")
        }
    }

    @Test func rounding_givesFiguresSomeoneWouldSay() {
        #expect(YalaAIOnboardingDemoAmounts.roundedForDemo(0.4) == 1)
        #expect(YalaAIOnboardingDemoAmounts.roundedForDemo(7.36) == 7)
        #expect(YalaAIOnboardingDemoAmounts.roundedForDemo(12) == 12)
        #expect(YalaAIOnboardingDemoAmounts.roundedForDemo(206.4) == 210)
        #expect(YalaAIOnboardingDemoAmounts.roundedForDemo(52_560) == 53_000)
        #expect(YalaAIOnboardingDemoAmounts.roundedForDemo(.nan) == 1)
    }

    @Test func formatted_usesTheAppIdentifier_withoutDecimals() {
        #expect(YalaAIOnboardingDemoAmounts.formatted(210, identifier: "$") == "$ 210")
        #expect(YalaAIOnboardingDemoAmounts.formatted(86, identifier: "MXN") == "MXN 86")
    }

    // MARK: - Contrato de las cadenas

    /// Clave → número de huecos `%@` que rellena el código.
    private static let amountKeys: [String: Int] = [
        "yalaAI.onboarding.step1.demoScenario1User": 1,
        "yalaAI.onboarding.step1.demoScenario1Bot": 1,
        "yalaAI.onboarding.step1.demoScenario2Bot": 2,
        "yalaAI.onboarding.step1.demoScenario3Bot": 2,
        "yalaAI.onboarding.step4.focusSaverQuote": 1,
    ]

    /// `LocalizationParityTests.placeholders_matchAcrossLocales` no cuenta los `%@` sueltos, y un
    /// `%` sin escapar en «12%» rompería el `String(format:)`. Aquí se comprueban los dos.
    @Test func amountKeys_haveTheirSlots_andNoBarePercent_inEveryLocale() throws {
        let slot = try Regex(#"%(\d\$)?@"#)
        let bare = try Regex(#"%(?!%|@|\d\$@)"#)
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            for (key, expected) in Self.amountKeys {
                let value = try #require(strings[key], "\(locale.code) sin \(key)")
                let unescaped = value.replacingOccurrences(of: "%%", with: "")
                #expect(unescaped.matches(of: slot).count == expected, "\(locale.code) \(key): \(value)")
                #expect(unescaped.matches(of: bare).isEmpty, "\(locale.code) \(key): \(value)")
            }
        }
    }

    @Test func demoCopy_hasNoEmDash_inEveryLocale() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            for key in Self.amountKeys.keys {
                #expect(strings[key]?.contains("—") == false, "\(locale.code) \(key)")
            }
        }
    }

    /// En las locales cuyo chat se llama «Yala IA», la presentación también.
    @Test func romanceLocales_sayYalaIA_inThePresentation() {
        let locales = ["es", "es-419", "es-AR", "es-ES", "fr", "it", "pt", "pt-BR", "pt-PT"]
        let keys = ["yalaAI.onboarding.step1.title", "yalaAI.onboarding.step1.a11yLabel",
                    "yalaAI.onboarding.step2.subtitle"]
        for code in locales {
            let strings = StringsFileParser.parseStrings(forLocale: code)
            #expect(strings["chat.assistantName"] == "Yala IA", "\(code)")
            for key in keys {
                let value = strings[key] ?? ""
                #expect(value.contains("Yala IA") && !value.contains("Yala AI"), "\(code) \(key): \(value)")
            }
        }
    }

    /// Las cadenas se formatean de verdad sin dejar huecos ni `%` sueltos (es-419 como muestra).
    @Test func formattedCopy_insertsTheAmounts() {
        let strings = StringsFileParser.parseStrings(forLocale: "es-419")
        let format = strings["yalaAI.onboarding.step1.demoScenario3Bot"] ?? ""
        let text = String(format: format, "$ 1,400", "$ 16,800")
        #expect(text == "💡 Tus delivery subieron 20% vs el mes pasado. Volviendo a tu ritmo normal ahorras $ 1,400 al mes: son $ 16,800 al año.")
    }
}
