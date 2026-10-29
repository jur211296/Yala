//
//  LiveSpeechPreviewService.swift
//  Yala
//
//  La frase que el registro por voz enseña mientras hablas (card tjws, propuesta A). Sale del reconocimiento de voz de
//  Apple DENTRO del iPhone (`SpeechAnalyzer` + `SpeechTranscriber`, iOS 26): no usa la red, no se guarda y no viaja a la
//  IA. Lo que se transcribe y se lee sigue siendo el audio de `AudioRecorderService`, que este servicio no toca.
//
//  Escucha con un `AVAudioEngine` propio, en paralelo al `AVAudioRecorder` de la grabación, sobre la misma sesión de
//  audio que activó el grabador. No activa ni desactiva la sesión: eso sigue siendo solo de `AudioRecorderService`.
//
//  Todo fallo es silencioso a propósito: sin el idioma en el teléfono, sin el modelo descargado o sin el motor, la hoja
//  enseña solo la onda y la grabación sigue igual.
//

@preconcurrency import AVFoundation
import Foundation
import Speech

@MainActor @Observable
final class LiveSpeechPreviewService {
    /// Lo entendido hasta ahora: lo cerrado más lo que el reconocedor todavía puede cambiar.
    private(set) var text = ""

    private var finalized = ""
    private var volatile = ""

    private var engine: AVAudioEngine?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?
    private var sessionTask: Task<Void, Never>?
    /// Cada `start` abre una generación; lo que llega de una anterior (un `await` que vuelve tarde) se ignora.
    private var generation = 0

    // MARK: - Ciclo

    /// Empieza a escuchar en el idioma del registro por voz (código ISO 639-1). Llamar con la grabación ya en marcha:
    /// la sesión de audio la activa `AudioRecorderService`.
    func start(languageCode: String) {
        stop()
        generation += 1
        let current = generation
        sessionTask = Task { [weak self] in
            await self?.run(languageCode: languageCode, generation: current)
        }
    }

    /// Deja de escuchar y borra el texto. Va ANTES de parar la grabación: así el motor suelta la entrada antes de que el
    /// grabador desactive la sesión.
    func stop() {
        generation += 1
        sessionTask?.cancel()
        sessionTask = nil
        tearDownEngine()
        continuation?.finish()
        continuation = nil
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
        finalized = ""
        volatile = ""
        text = ""
    }

    private func tearDownEngine() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }

    // MARK: - Escuchar

    private func run(languageCode: String, generation current: Int) async {
        guard SpeechTranscriber.isAvailable else { return }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: languageCode)) else {
            return
        }
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        let status = await AssetInventory.status(forModules: [transcriber])
        guard status == .installed else {
            // Con el idioma admitido pero sin bajar, se pide para la próxima vez; esta grabación sigue solo con la onda.
            if status == .supported { Self.requestInstallation(for: transcriber) }
            return
        }
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            return
        }
        guard current == generation, !Task.isCancelled else { return }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat) else { return }

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self, bufferingPolicy: .bufferingNewest(64))
        Self.installTap(on: input, inputFormat: inputFormat, converter: converter, outputFormat: analyzerFormat, into: continuation)
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            #if DEBUG
            print("LiveSpeechPreviewService: Error starting the audio engine: \(error)")
            #endif
            return
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.engine = engine
        self.continuation = continuation
        self.analyzer = analyzer

        let results = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let piece = String(result.text.characters)
                    self?.receive(piece, isFinal: result.isFinal, generation: current)
                }
            } catch {
                #if DEBUG
                print("LiveSpeechPreviewService: Error reading results: \(error)")
                #endif
            }
        }
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            #if DEBUG
            print("LiveSpeechPreviewService: Error starting the analyzer: \(error)")
            #endif
            results.cancel()
            if current == generation { stop() }
            return
        }
        await withTaskCancellationHandler {
            _ = await results.result
        } onCancel: {
            results.cancel()
        }
    }

    private func receive(_ piece: String, isFinal: Bool, generation current: Int) {
        guard current == generation else { return }
        if isFinal {
            finalized = VoiceLiveListeningLogic.combined(finalized: finalized, volatile: piece)
            volatile = ""
        } else {
            volatile = piece
        }
        text = VoiceLiveListeningLogic.combined(finalized: finalized, volatile: volatile)
    }

    // MARK: - Hilo de audio

    /// El tap corre en el hilo de audio, fuera del main actor: por eso es `nonisolated` y solo convierte y entrega.
    nonisolated private static func installTap(
        on input: AVAudioInputNode,
        inputFormat: AVAudioFormat,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat,
        into continuation: AsyncStream<AnalyzerInput>.Continuation
    ) {
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let converted = convert(buffer, with: converter, to: outputFormat) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }
    }

    nonisolated private static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        nonisolated(unsafe) var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil, output.frameLength > 0 else { return nil }
        return output
    }

    // MARK: - Modelo

    private static func requestInstallation(for transcriber: SpeechTranscriber) {
        Task.detached(priority: .utility) {
            do {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    try await request.downloadAndInstall()
                }
            } catch {
                #if DEBUG
                print("LiveSpeechPreviewService: Error installing the speech model: \(error)")
                #endif
            }
        }
    }
}
