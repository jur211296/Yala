//
//  VoiceLiveListeningTests.swift
//  YalaTests
//
//  Card tjws (propuesta A): la onda de barras y la frase en vivo del registro por voz. La lógica pura de la onda y de
//  la frase, y dos contratos que no se ven en pantalla: el reconocedor no toca la sesión de audio ni el grabador, y la
//  hoja lo apaga antes de parar la grabación. El texto real y el audio idéntico en un iPhone van al device-QA.
//

import Foundation
import Testing

@testable import Yala

@Suite("Registro por voz · onda")
struct VoiceWaveformLogicTests {

    @Test func appending_addsToTheRight_andDropsTheOldestBeyondCapacity() {
        var history: [Double] = []
        for level in [0.1, 0.5, 0.9] {
            history = VoiceLiveListeningLogic.appending(level, to: history, capacity: 2)
        }
        #expect(history == [0.5, 0.9])
    }

    @Test func appending_clampsToZeroOne_andSilenceIsAThinBar() {
        let silent = VoiceLiveListeningLogic.silentLevel
        #expect(VoiceLiveListeningLogic.appending(-1, to: []) == [silent])
        #expect(VoiceLiveListeningLogic.appending(0, to: []) == [silent])
        #expect(VoiceLiveListeningLogic.appending(3, to: []) == [1])
        #expect(VoiceLiveListeningLogic.appending(.nan, to: []) == [silent])
        #expect(VoiceLiveListeningLogic.appending(0.5, to: [], capacity: 0).isEmpty)
    }

    @Test func appending_keepsTheDefaultCapacity() {
        var history: [Double] = []
        for _ in 0..<(VoiceLiveListeningLogic.waveformCapacity + 10) {
            history = VoiceLiveListeningLogic.appending(0.5, to: history)
        }
        #expect(history.count == VoiceLiveListeningLogic.waveformCapacity)
    }

    @Test func visibleBars_padsSilenceOnTheLeft_soTheWaveEntersFromTheRight() {
        let silent = VoiceLiveListeningLogic.silentLevel
        #expect(VoiceLiveListeningLogic.visibleBars([0.7], count: 3) == [silent, silent, 0.7])
        #expect(VoiceLiveListeningLogic.visibleBars([0.1, 0.2, 0.3, 0.4], count: 2) == [0.3, 0.4])
        #expect(VoiceLiveListeningLogic.visibleBars([0.1], count: 0).isEmpty)
    }

    @Test func demoLevel_staysInRange() {
        for tick in 0..<200 {
            let level = VoiceLiveListeningLogic.demoLevel(elapsed: Double(tick) / 10)
            #expect(level >= 0 && level <= 1)
        }
        #expect(VoiceLiveListeningLogic.demoLevel(elapsed: .infinity) == 0)
    }
}

@Suite("Registro por voz · frase en vivo")
struct VoiceLiveTranscriptLogicTests {

    @Test func split_lastThreeWordsArePrimary_restIsSecondary() {
        let parts = VoiceLiveListeningLogic.split("Gasté 25 en el almuerzo con la tarjeta")
        #expect(parts.older == "Gasté 25 en el almuerzo")
        #expect(parts.recent == "con la tarjeta")
    }

    @Test func split_shortPhrase_isAllPrimary() {
        let parts = VoiceLiveListeningLogic.split("Gasté 25")
        #expect(parts.older.isEmpty)
        #expect(parts.recent == "Gasté 25")
    }

    @Test func split_emptyOrBlank_isEmpty() {
        #expect(VoiceLiveListeningLogic.split("").older.isEmpty)
        #expect(VoiceLiveListeningLogic.split("   \n").recent.isEmpty)
    }

    @Test func split_collapsesExtraSpaces() {
        let parts = VoiceLiveListeningLogic.split("  uno   dos  tres   cuatro ")
        #expect(parts.older == "uno")
        #expect(parts.recent == "dos tres cuatro")
    }

    @Test func combined_joinsFinalizedAndVolatile_withoutDoubleSpaces() {
        #expect(VoiceLiveListeningLogic.combined(finalized: "Gasté 25", volatile: " en el") == "Gasté 25 en el")
        #expect(VoiceLiveListeningLogic.combined(finalized: "", volatile: "Gasté") == "Gasté")
        #expect(VoiceLiveListeningLogic.combined(finalized: "Gasté 25", volatile: "") == "Gasté 25")
        #expect(VoiceLiveListeningLogic.combined(finalized: "", volatile: "").isEmpty)
    }

    @Test func demoWordCount_oneWordEveryFourTenths_cappedAtTheTotal() {
        #expect(VoiceLiveListeningLogic.demoWordCount(elapsed: 0, totalWords: 8) == 0)
        #expect(VoiceLiveListeningLogic.demoWordCount(elapsed: 0.41, totalWords: 8) == 1)
        #expect(VoiceLiveListeningLogic.demoWordCount(elapsed: 1.21, totalWords: 8) == 3)
        #expect(VoiceLiveListeningLogic.demoWordCount(elapsed: 60, totalWords: 8) == 8)
        #expect(VoiceLiveListeningLogic.demoWordCount(elapsed: .nan, totalWords: 8) == 0)
    }
}

/// Lo que garantiza que a la IA le llega el mismo audio de siempre: el reconocedor escucha por su cuenta y no toca ni
/// la sesión de audio ni el grabador; la hoja lo apaga antes de parar la grabación.
@Suite("Registro por voz · el audio a la IA no cambia")
struct VoiceLivePreviewIsolationTests {

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test func previewNeverTouchesTheAudioSessionOrTheRecorder() throws {
        let preview = try Self.source("Yala/Services/LiveSpeechPreviewService.swift")
        for forbidden in ["setActive(", "setCategory(", "AVAudioSession.sharedInstance", "AudioRecorderService.shared", "AVAudioRecorder("] {
            #expect(!preview.contains(forbidden), "El reconocedor no puede tocar \(forbidden): la sesión y la grabación son del grabador.")
        }
        // Y nada de red: el texto sale del iPhone.
        for forbidden in ["URLSession", "VoiceTranscriptionService", "MetricsService"] {
            #expect(!preview.contains(forbidden), "El texto en vivo no viaja a ningún sitio (\(forbidden)).")
        }
    }

    @Test func recorderKeepsTheSameFileAndFormat() throws {
        let recorder = try Self.source("Yala/Services/AudioRecorderService.swift")
        #expect(recorder.contains("AVFormatIDKey: Int(kAudioFormatMPEG4AAC)"))
        #expect(recorder.contains("AVSampleRateKey: 16000"))
        #expect(recorder.contains("AVNumberOfChannelsKey: 1"))
        #expect(recorder.contains("AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue"))
        #expect(recorder.contains("audioRecorder = try AVAudioRecorder(url: url, settings: settings)"))
        #expect(!recorder.contains("LiveSpeechPreview"), "El grabador no sabe nada del reconocedor.")
    }

    @Test func sheetStopsThePreviewBeforeStoppingOrCancellingTheRecording() throws {
        let sheet = try Self.source("Yala/App/Views/Voice/VoiceRecordingView.swift")
        for anchor in ["private func finishListening()", "private func cancelListening()", "private func tearDown()"] {
            let body = try #require(sheet.range(of: anchor)).upperBound
            let rest = sheet[body...]
            let stop = try #require(rest.range(of: "stopLivePreview()"), "\(anchor) no apaga la frase en vivo.")
            if let recorderCall = rest.range(of: "recorder.") {
                #expect(stop.lowerBound < recorderCall.lowerBound, "\(anchor): la frase en vivo se apaga antes de tocar el grabador.")
            }
        }
        // Y el texto en vivo nunca entra en lo que se transcribe.
        let understand = try #require(sheet.range(of: "private func understand("))
        let understandBody = sheet[understand.upperBound...].prefix(1500)
        #expect(!understandBody.contains("livePreview"), "Lo que se lee sigue siendo el audio, no el texto en vivo.")
    }
}
