//
//  ChatVoiceInputGateTests.swift
//  YalaTests
//
//  Ticket `chat-microphone-sends-audio-with-the-chat-consent`, decisión A: el micrófono del chat pide el permiso de
//  voz y foto antes de grabar, como Siri y los botones de Voz y Foto.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Yala IA · el micrófono del chat pide el permiso de voz y foto")
struct ChatVoiceInputGateTests {

    @Test("Sin el permiso de voz y foto, tocar el micrófono lo pide y no graba")
    func asksConsentFirst() {
        #expect(ChatVoiceInputGateLogic.action(isRecording: false, dataConsentAccepted: false) == .askConsent)
    }

    @Test("Con el permiso, graba")
    func startsWithConsent() {
        #expect(ChatVoiceInputGateLogic.action(isRecording: false, dataConsentAccepted: true) == .start)
    }

    @Test("Grabando, el toque termina la grabación en los dos casos")
    func stopsWhileRecording() {
        #expect(ChatVoiceInputGateLogic.action(isRecording: true, dataConsentAccepted: true) == .stop)
        #expect(ChatVoiceInputGateLogic.action(isRecording: true, dataConsentAccepted: false) == .stop)
    }

    // MARK: - Cableado

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test("El micrófono del chat pasa por la regla y la alerta es la del permiso de voz y foto")
    func wiring() throws {
        let code = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala/App/Views/Chat/ChatSheetView.swift"), encoding: .utf8)
        let inicio = try #require(code.range(of: "private func toggleVoiceInput() async {"))
        let cuerpo = code[inicio.upperBound...].prefix(900)
        #expect(cuerpo.contains("dataConsentAccepted: appPreferences.aiDataConsentAccepted"))
        #expect(cuerpo.contains("case .askConsent:"))
        #expect(cuerpo.contains("showVoiceConsentAlert = true"))
        // La única llamada a grabar fuera de la regla es la del «Activar» de la alerta.
        #expect(code.components(separatedBy: "viewModel.startVoiceInput()").count - 1 == 2)
        #expect(code.contains(".aiConsentAlert(isPresented: $showVoiceConsentAlert"))
    }
}
