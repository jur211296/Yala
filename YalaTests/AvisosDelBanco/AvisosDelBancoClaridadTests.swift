//
//  AvisosDelBancoClaridadTests.swift
//  YalaTests
//
//  Encargo del 23-nov-2026 sobre «Avisos del banco»: (a) los bancos de Perú solo se ofrecen en Perú o con el sol como
//  moneda principal; (b) entrar a un banco no lo activa: lo activa «Ya lo configuré» o un aviso real, y se puede quitar.
//  El App Group va con un dominio aislado por test.
//

import Foundation
import Testing

@testable import Yala

@Suite("Avisos del banco · región y activación", .serialized)
@MainActor
struct AvisosDelBancoClaridadTests {

    private func isolated() -> UserDefaults {
        testDefaults(suiteName: "test.banknotice.claridad.\(UUID().uuidString)")!
    }

    // MARK: - (a) Bancos por región o moneda

    @Test func enPeru_seOfrecenLosBancosConReglas() {
        let banks = BankNoticeChoiceLogic.addableBanks(regionCode: "PE", mainCurrencyCode: "PEN", active: [])
        #expect(banks == BankNoticeBank.allCases)
        #expect(banks.contains(.bcp) && banks.contains(.yape) && banks.contains(.other))
    }

    @Test func fueraDePeru_soloQuedaTuBancoOApp() {
        #expect(BankNoticeChoiceLogic.addableBanks(regionCode: "MX", mainCurrencyCode: "MXN", active: []) == [.other])
        #expect(BankNoticeChoiceLogic.addableBanks(regionCode: "ES", mainCurrencyCode: "EUR", active: []) == [.other])
        #expect(BankNoticeChoiceLogic.addableBanks(regionCode: nil, mainCurrencyCode: nil, active: []) == [.other])
    }

    /// La región o la moneda bastan por separado: un peruano con el iPhone en otra región sigue en soles, y quien vive en
    /// Perú puede llevar Yala en dólares.
    @Test func laRegionOLaMonedaBastanPorSeparado() {
        #expect(BankNoticeChoiceLogic.offersPeruvianBanks(regionCode: "US", mainCurrencyCode: "PEN"))
        #expect(BankNoticeChoiceLogic.offersPeruvianBanks(regionCode: "PE", mainCurrencyCode: "USD"))
        #expect(BankNoticeChoiceLogic.offersPeruvianBanks(regionCode: "pe", mainCurrencyCode: nil))
        #expect(!BankNoticeChoiceLogic.offersPeruvianBanks(regionCode: "US", mainCurrencyCode: "USD"))
    }

    @Test func losActivosNoSeVuelvenAOfrecer() {
        let peru = BankNoticeChoiceLogic.addableBanks(regionCode: "PE", mainCurrencyCode: "PEN", active: [.bcp, .other])
        #expect(!peru.contains(.bcp) && !peru.contains(.other) && peru.contains(.yape))
        #expect(BankNoticeChoiceLogic.addableBanks(regionCode: "MX", mainCurrencyCode: "MXN", active: [.other]).isEmpty)
    }

    @Test func fueraDePeru_otroBancoSeLlamaTuBancoOApp() {
        #expect(BankNoticeBankView.displayName(.other, offersPeruvianBanks: false)
                == L10n.CapturaAtajoParte2.Bank.pickerOtherAlone)
        #expect(BankNoticeBankView.displayName(.other, offersPeruvianBanks: true)
                == L10n.CapturaAtajoParte2.Bank.pickerOther)
        #expect(BankNoticeBankView.displayName(.bcp, offersPeruvianBanks: false) == "BCP")
    }

    // MARK: - (b) Entrar no activa

    @Test func sinConfirmarNiAvisos_noEstaActivo() {
        #expect(!BankNoticeChoiceLogic.isActive(settings: BankNoticeSettings(), activity: BankNoticeActivity()))
        // La pausa o la cuenta por defecto tampoco lo activan: solo la confirmación.
        let touched = BankNoticeSettings(isPaused: true, defaultAccountShortcutID: UUID(), isSetUp: false)
        #expect(!BankNoticeChoiceLogic.isActive(settings: touched, activity: BankNoticeActivity()))
    }

    @Test func yaLoConfigure_loActivaSinTocarLoDemas() {
        let account = UUID()
        let before = BankNoticeSettings(isPaused: true, defaultAccountShortcutID: account, isSetUp: false)
        let after = BankNoticeChoiceLogic.confirmingSetup(before)
        #expect(after.isSetUp)
        #expect(after.isPaused && after.defaultAccountShortcutID == account)
        #expect(BankNoticeChoiceLogic.isActive(settings: after, activity: BankNoticeActivity()))
    }

    @Test func elPrimerAvisoLoActivaSinConfirmar() {
        let defaults = isolated()
        BankNoticeActivityStore.record(
            .notAMovement, bank: .yape, at: Date(timeIntervalSince1970: 1_800_000_000), defaults: defaults)
        #expect(BankNoticeChoiceLogic.isActive(
            settings: BankNoticeActivityStore.settings(for: .yape, defaults: defaults),
            activity: BankNoticeActivityStore.activity(for: .yape, defaults: defaults)))
        #expect(BankNoticeActivityStore.knownBanks(defaults: defaults) == [.yape])
    }

    /// Lo que la pantalla guarda al abrirse (los ajustes tal cual) no deja el banco en «Activos».
    @Test func guardarLosAjustesAlAbrir_noLoPoneEnActivos() {
        let defaults = isolated()
        BankNoticeActivityStore.save(BankNoticeActivityStore.settings(for: .bcp, defaults: defaults), for: .bcp,
                                     defaults: defaults)
        #expect(BankNoticeActivityStore.knownBanks(defaults: defaults).isEmpty)
        BankNoticeActivityStore.save(BankNoticeChoiceLogic.confirmingSetup(BankNoticeSettings()), for: .bcp,
                                     defaults: defaults)
        #expect(BankNoticeActivityStore.knownBanks(defaults: defaults) == [.bcp])
    }

    /// Cableado: la pantalla de un banco ya no se marca sola al cargar. Antes, `reload()` ponía `isSetUp = true`.
    @Test func abrirLaPantalla_noMarcaElBanco() throws {
        let src = try Self.source("Yala/App/Views/Settings/AtajoBanco/BankNoticeBankView.swift")
        let reload = try #require(Self.body(of: "private func reload()", in: src))
        #expect(!reload.contains("isSetUp"), "reload() vuelve a tocar isSetUp:\n\(reload)")
        let confirm = try #require(Self.body(of: "private func confirmSetup()", in: src))
        #expect(confirm.contains("BankNoticeChoiceLogic.confirmingSetup(settings)"))
    }

    // MARK: - Quitar de Activos

    @Test func quitar_loSacaDeActivosYBorraLoQueSabia() {
        let defaults = isolated()
        BankNoticeActivityStore.save(BankNoticeSettings(isPaused: true, defaultAccountShortcutID: UUID(), isSetUp: true),
                                     for: .bcp, defaults: defaults)
        BankNoticeActivityStore.record(.notUnderstood, bank: .bcp, at: Date(timeIntervalSince1970: 1_800_000_000),
                                       defaults: defaults)
        BankNoticeActivityStore.save(BankNoticeChoiceLogic.confirmingSetup(BankNoticeSettings()), for: .plin,
                                     defaults: defaults)
        #expect(BankNoticeActivityStore.knownBanks(defaults: defaults) == [.bcp, .plin])

        BankNoticeActivityStore.deactivate(.bcp, defaults: defaults)

        #expect(BankNoticeActivityStore.knownBanks(defaults: defaults) == [.plin])
        #expect(BankNoticeActivityStore.settings(for: .bcp, defaults: defaults) == BankNoticeSettings())
        #expect(BankNoticeActivityStore.activity(for: .bcp, defaults: defaults) == BankNoticeActivity())
    }

    // MARK: - Fuente

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// El cuerpo de una función, de su firma a la llave que la cierra (cuenta llaves).
    private static func body(of signature: String, in src: String) -> String? {
        guard let start = src.range(of: signature) else { return nil }
        var depth = 0
        var opened = false
        var index = start.upperBound
        while index < src.endIndex {
            let char = src[index]
            if char == "{" { depth += 1; opened = true }
            if char == "}" { depth -= 1 }
            index = src.index(after: index)
            if opened && depth == 0 { return String(src[start.lowerBound..<index]) }
        }
        return nil
    }
}
