//
//  SiriAndApplePayScreensTruthTests.swift
//  YalaTests
//
//  Lote 03 de las necesarias 2.3, puntos 3 y 4: dos pantallas de Ajustes que decían algo falso.
//  - Siri y Atajos decía «Requiere Yala Pro» a quien puede usar Siri gratis con el modelo del iPhone (ticket
//    `siri-shortcuts-screen-says-pro-required-for-on-device-users`).
//  - La guía de Apple Pay pedía elegir un campo «Nombre» que el atajo no tiene, y su contador de pagos pendientes no decía
//    si había llegado alguno.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Siri y Apple Pay — las pantallas dicen la verdad")
struct SiriAndApplePayScreensTruthTests {

    // MARK: - Siri y Atajos

    /// La pantalla y el intent deciden lo mismo: «Requiere Yala Pro» solo cuando Siri abriría la hoja de Pro.
    @Test(arguments: SiriOnDeviceModelState.allCases)
    func siriProNote_matchesWhatTheIntentDoes(model: SiriOnDeviceModelState) {
        for isPro in [false, true] {
            for onDeviceEnabled in [false, true] {
                let route = SiriEntryRoute.decide(isPro: isPro, onDeviceEnabled: onDeviceEnabled, model: model)
                #expect(
                    SiriShortcutsProNoteLogic.showsProRequirement(isPro: isPro, onDeviceEnabled: onDeviceEnabled, model: model)
                        == (route == .upgrade)
                )
            }
        }
    }

    @Test func siriProNote_freeUserWithTheModelReady_seesNoProRequirement() {
        #expect(!SiriShortcutsProNoteLogic.showsProRequirement(isPro: false, onDeviceEnabled: true, model: .available))
    }

    @Test func siriProNote_freeUserWithoutTheModel_stillSeesIt() {
        #expect(SiriShortcutsProNoteLogic.showsProRequirement(isPro: false, onDeviceEnabled: true, model: .deviceNotEligible))
        #expect(SiriShortcutsProNoteLogic.showsProRequirement(isPro: false, onDeviceEnabled: false, model: .available))
    }

    // MARK: - Guía de Apple Pay: cabecera

    private let es = Locale(identifier: "es_PE")

    @Test func applePayHeader_withoutAnyPayment_saysNoneArrivedYet() {
        #expect(ApplePayGuideStatusLogic.lines(lastArrival: nil, pendingCount: 0, locale: es) == [L10n.Tutorials.applePayNoPaymentYet])
    }

    /// Con pagos ya aprobados y ninguno pendiente decía «en tu bandeja: 0», igual que sin automatización.
    @Test func applePayHeader_withPaymentsButNonePending_saysWhenTheLastOneArrived() {
        let day = Date(timeIntervalSince1970: 1_793_000_000)
        let lines = ApplePayGuideStatusLogic.lines(lastArrival: day, pendingCount: 0, locale: es)
        #expect(lines.count == 1)
        let formatted = day.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(es))
        #expect(lines.first == L10n.Tutorials.applePayLastPayment(formatted))
    }

    @Test func applePayHeader_withPendingOnes_addsTheCount() {
        let lines = ApplePayGuideStatusLogic.lines(lastArrival: Date(timeIntervalSince1970: 1_793_000_000), pendingCount: 2, locale: es)
        #expect(lines.count == 2)
        #expect(lines.last == L10n.Tutorials.applePayPendingDrafts(2))
    }

    // MARK: - Guía de Apple Pay: paso 4

    /// El atajo tiene dos campos, Cantidad y Comercio (`ApplePayTransactionIntent`). El paso 4 nombra los dos con el
    /// mismo nombre que el atajo, en cada idioma, y no pide ningún campo «Nombre».
    @Test(arguments: ["es-419", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt-PT", "zh-Hans"])
    func applePayStep4_namesTheShortcutsTwoFields(locale: String) throws {
        let strings = try Self.strings(locale)
        let step = try #require(strings["tutorials.applePay.step3.desc"])
        let amount = try #require(strings["shortcut.applePay.param.amount"])
        let merchant = try #require(strings["shortcut.applePay.param.merchant"])
        #expect(step.contains(amount), "\(locale): el paso 4 no nombra «\(amount)».")
        #expect(step.components(separatedBy: merchant).count - 1 >= 2, "\(locale): el paso 4 no dice qué elegir en «\(merchant)».")
        for stale in ["respectivamente", "respectively", "rispettivamente", "respectivement", "respetivamente", "Nombre", "Name", "Nom", "Nome", "Naam", "Nazwa", "名前", "名称"] {
            #expect(!step.contains(stale), "\(locale): el paso 4 sigue diciendo «\(stale)».")
        }
    }

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
        let dict = try #require(NSDictionary(contentsOf: url) as? [String: String])
        return dict
    }
}
