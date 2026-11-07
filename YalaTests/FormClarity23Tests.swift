//
//  FormClarity23Tests.swift
//  YalaTests
//
//  Mejoras necesarias 2.3 · Formulario: monedas claras y salida manual disponible. La regla del aviso de moneda (M1) y
//  el cableado de la salida «Apuntarlo a mano» del muro de Pro de voz y foto (V3).
//

import Foundation
import Testing
@testable import Yala

@Suite("M1 · el aviso de cambio de moneda del importe")
struct AmountCurrencyNoticeLogicTests {

    private func snap(_ code: String, _ amount: Double) -> AmountCurrencySnapshot {
        AmountCurrencySnapshot(currencyCode: code, amount: amount)
    }

    @Test("con el importe escrito, elegir una cuenta en otra moneda deja el aviso")
    func changeWithAmountWritten_leavesTheNotice() {
        let notice = AmountCurrencyNoticeLogic.notice(
            from: snap("PEN", 45), to: snap("USD", 45), current: nil, accountName: "Ahorros USD", isTransfer: false)
        #expect(notice == AmountCurrencyNotice(currencyCode: "USD", accountName: "Ahorros USD"))
    }

    @Test("volver a la moneda principal con el importe escrito también se dice")
    func changeBack_isAlsoSaid() {
        let current = AmountCurrencyNotice(currencyCode: "USD", accountName: "Ahorros USD")
        let notice = AmountCurrencyNoticeLogic.notice(
            from: snap("USD", 45), to: snap("PEN", 45), current: current, accountName: "Cuenta Principal",
            isTransfer: false)
        #expect(notice == AmountCurrencyNotice(currencyCode: "PEN", accountName: "Cuenta Principal"))
    }

    @Test("sin importe escrito no hay nada que reinterpretar")
    func changeWithoutAmount_noNotice() {
        let notice = AmountCurrencyNoticeLogic.notice(
            from: snap("PEN", 0), to: snap("USD", 0), current: nil, accountName: "Ahorros USD", isTransfer: false)
        #expect(notice == nil)
    }

    @Test("si el importe llega en el mismo cambio (un favorito), no se avisa")
    func amountArrivesWithTheChange_noNotice() {
        let notice = AmountCurrencyNoticeLogic.notice(
            from: snap("PEN", 45), to: snap("USD", 12), current: nil, accountName: "Ahorros USD", isTransfer: false)
        #expect(notice == nil)
    }

    @Test("escribir otro número con la misma moneda conserva el aviso que hubiera")
    func amountEdit_keepsTheNotice() {
        let current = AmountCurrencyNotice(currencyCode: "USD", accountName: "Ahorros USD")
        let notice = AmountCurrencyNoticeLogic.notice(
            from: snap("USD", 45), to: snap("USD", 450), current: current, accountName: "Ahorros USD",
            isTransfer: false)
        #expect(notice == current)
    }

    @Test("en una transferencia no hay aviso: cada importe dice su cuenta")
    func transfer_noNotice() {
        let notice = AmountCurrencyNoticeLogic.notice(
            from: snap("PEN", 45), to: snap("USD", 45), current: nil, accountName: "Ahorros USD", isTransfer: true)
        #expect(notice == nil)
    }

    @Test("se pinta solo con su moneda, con importe y fuera de transferencias")
    func isShown() {
        let notice = AmountCurrencyNotice(currencyCode: "USD", accountName: "Ahorros USD")
        #expect(AmountCurrencyNoticeLogic.isShown(notice, currencyCode: "usd", amount: 45, isTransfer: false))
        #expect(!AmountCurrencyNoticeLogic.isShown(notice, currencyCode: "PEN", amount: 45, isTransfer: false))
        #expect(!AmountCurrencyNoticeLogic.isShown(notice, currencyCode: "USD", amount: 0, isTransfer: false))
        #expect(!AmountCurrencyNoticeLogic.isShown(notice, currencyCode: "USD", amount: 45, isTransfer: true))
        #expect(!AmountCurrencyNoticeLogic.isShown(nil, currencyCode: "USD", amount: 45, isTransfer: false))
    }

    @Test("el texto lleva la moneda, su código y la cuenta; una divisa sin nombre, solo el código")
    func text() {
        let known = AmountCurrencyNoticeLogic.text(for: AmountCurrencyNotice(currencyCode: "USD", accountName: "Ahorros"))
        #expect(known.contains("USD"))
        #expect(known.contains("Ahorros"))
        #expect(known.contains(CurrencyCode.usd.shortPluralName))
        let unknown = AmountCurrencyNoticeLogic.text(for: AmountCurrencyNotice(currencyCode: "XYZ", accountName: "Caja"))
        #expect(unknown.contains("XYZ"))
        #expect(unknown.contains("Caja"))
        #expect(!unknown.contains("formClarity."), "La clave tiene que existir en el idioma de la prueba.")
    }
}

@Suite("V3 · el muro de Pro de voz y foto cablea «Apuntarlo a mano»")
struct ProGateManualEntryWiringTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cada muro `.proFeature` de voz o foto que dice «Apuntar a mano sigue gratis» pasa la salida al formulario.
    @Test("cada muro de voz y foto pasa su salida manual", arguments: [
        "Yala/App/Views/Panel/PanelSheetsModifier.swift",
        "Yala/App/Views/Records/RecordsStandaloneView.swift",
        "Yala/App/Views/Statistics/DetailContainerView.swift",
        "Yala/App/Views/Voice/VoiceRecordingView.swift",
        "Yala/App/Views/Image/ImageSelectionView.swift",
        "Yala/App/Views/Groups/GroupReceiptSplitView.swift",
    ])
    func everyVoiceAndPhotoGate_passesItsManualExit(path: String) throws {
        let text = try source(path)
        let gates = text.components(separatedBy: ".proUpgradeSheet(").dropFirst()
            .map { String($0.prefix(600)) }
            .filter { $0.contains(".voiceInput") || $0.contains(".imageInput") }
        #expect(!gates.isEmpty, "\(path): no se encontró su muro de voz o foto.")
        for gate in gates {
            #expect(gate.contains("onManualEntry:"), "\(path): un muro de voz o foto sin «Apuntarlo a mano».")
        }
    }

    /// El botón solo se pinta donde hay a dónde ir, y solo en el muro que lo promete.
    @Test("el muro solo pinta el botón con salida y en voz o foto")
    func sheetOnlyShowsTheButtonWithAnExit() throws {
        let text = try source("Yala/App/Views/Shared/UpgradePromptSheet.swift")
        #expect(text.contains("upgrade_prompt_manual_entry"))
        #expect(text.contains("ProGateManualEntryLogic.offersManualEntry("))
    }

    @Test("lógica: voz y foto en contexto de función Pro, con salida")
    func logic() {
        #expect(ProGateManualEntryLogic.offersManualEntry(feature: .voiceInput, context: .proFeature, hasExit: true))
        #expect(ProGateManualEntryLogic.offersManualEntry(feature: .imageInput, context: .proFeature, hasExit: true))
        #expect(!ProGateManualEntryLogic.offersManualEntry(feature: .voiceInput, context: .proFeature, hasExit: false))
        #expect(!ProGateManualEntryLogic.offersManualEntry(feature: .voiceInput, context: .trialExpired, hasExit: true))
        #expect(!ProGateManualEntryLogic.offersManualEntry(feature: .budgets, context: .limitReached, hasExit: true))
        #expect(!ProGateManualEntryLogic.offersManualEntry(feature: .chatAssistant, context: .proFeature, hasExit: true))
    }
}
