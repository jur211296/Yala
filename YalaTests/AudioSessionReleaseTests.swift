//
//  AudioSessionReleaseTests.swift
//  YalaTests
//
//  Al soltar el micro de la voz, la música de otra app vuelve a sonar. `AudioRecorderService` pone la sesión en
//  `.playAndRecord`, que la interrumpe; solo `setActive(false, options: .notifyOthersOnDeactivation)` le dice a esa
//  app que puede retomar. Card del QA guiado del 2026-10-19 (B · micrófono paso 3), ticket
//  `voice-cancel-does-not-resume-other-apps-audio`.
//
//  Sin AVAudioSession real: la decisión es pura y el cableado se fija con un source-scan del cuerpo, porque en el
//  simulador no hay otra app sonando que pueda medirlo.
//

import AVFoundation
import Foundation
import Testing

@testable import Yala

@Suite("Voz · soltar el micro devuelve el audio a la otra app")
struct AudioSessionReleaseTests {

    @Test func deactivation_notifiesTheOtherApps() {
        #expect(AudioRecorderService.deactivationOptions.contains(.notifyOthersOnDeactivation))
    }

    @Test func cancelWithARecording_releasesTheSession() {
        #expect(AudioRecorderService.releasesSessionOnCancel(wasRecording: true))
    }

    /// Control: sin grabación esta app no activó nada, y desactivar la sesión compartida tocaría el audio de otro.
    /// Ahí el comportamiento de antes —no hacer nada— era el correcto y se conserva.
    @Test func cancelWithoutARecording_leavesTheSessionAlone() {
        #expect(!AudioRecorderService.releasesSessionOnCancel(wasRecording: false))
    }

    // MARK: - Cableado

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Solo el código, con las líneas recortadas: los comentarios nombran `setActive(false)` al explicar el porqué.
    private static func code() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Yala/Services/AudioRecorderService.swift"),
            encoding: .utf8
        )
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.hasPrefix("//") }
        .joined(separator: "\n")
    }

    private static func body(of signature: String, in code: String) throws -> String {
        let start = try #require(code.range(of: signature), "no encuentro \(signature)")
        var depth = 0
        var opened = false
        var index = start.upperBound
        while index < code.endIndex {
            let char = code[index]
            if char == "{" { depth += 1; opened = true }
            if char == "}" { depth -= 1 }
            if opened && depth == 0 { return String(code[start.lowerBound...index]) }
            index = code.index(after: index)
        }
        Issue.record("cuerpo sin cerrar: \(signature)")
        return ""
    }

    /// Un solo sitio desactiva la sesión, y lo hace avisando. Un `setActive(false)` nuevo sin opciones es el bug.
    @Test func theOnlyDeactivation_passesTheOptions() throws {
        let code = try Self.code()
        let deactivations = code.components(separatedBy: "setActive(false").count - 1
        #expect(deactivations == 1)
        #expect(code.contains("setActive(false, options: Self.deactivationOptions)"))
    }

    /// Las tres salidas pasan por él: terminar, cancelar y la grabación que no llega a arrancar.
    @Test func everyExit_releasesTheSession() throws {
        let code = try Self.code()
        #expect(try Self.body(of: "func stopRecording()", in: code).contains("releaseAudioSession()"))
        let cancel = try Self.body(of: "func cancelRecording()", in: code)
        #expect(cancel.contains(
            "guard Self.releasesSessionOnCancel(wasRecording: wasRecording) else { return }\nreleaseAudioSession()"
        ))
        let start = try Self.body(of: "func startRecording()", in: code)
        #expect(start.contains("try beginRecording()\n} catch {\ncleanup()\nreleaseAudioSession()\nthrow error\n}"))
    }
}
