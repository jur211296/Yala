// Transcripción en el dispositivo con el framework Speech de Apple (SpeechAnalyzer), para el banco de voz.
//
//   swiftc -O -parse-as-library transcribe.swift -o ../../.cache/voice/apple-transcribe
//   apple-transcribe --module speech|dictation --locale es-MX [--keywords-file k.txt] a.m4a b.m4a …
//
// Escribe una línea JSON por fichero: {"file", "text", "ms", "error"?}. `ms` mide desde que se abre el fichero
// hasta el resultado final (el modelo ya cargado), que es lo que esperaría la persona en la app.
//
// Dos módulos, porque cubren idiomas distintos (medido en macOS 27.0.1 el 2026-10-07):
//   - speech    → `SpeechTranscriber`, el modelo nuevo (iOS/macOS 26+). No tiene neerlandés ni polaco.
//   - dictation → `DictationTranscriber`, el modelo del dictado de siempre. Tiene los 10 idiomas de Yala.
// `DictationTranscriber` va con `.longDictation`: con `.shortDictation` el último resultado llega sin marcar como final
// (medido), y aun así se guarda el último resultado provisional si no llega ninguno final.
// Si el modelo del idioma no está instalado, se descarga con `AssetInventory` antes de empezar.
// Las palabras del contexto (subcategorías y comercios) van como `AnalysisContext.contextualStrings`.

import AVFoundation
import Foundation
import Speech

struct Line: Encodable {
    let file: String
    let text: String
    let ms: Int
    let error: String?
}

func emit(_ line: Line) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.withoutEscapingSlashes]
    if let data = try? enc.encode(line), let s = String(data: data, encoding: .utf8) {
        print(s)
        fflush(stdout)
    }
}

enum Module: String { case speech, dictation }

@main
struct AppleTranscribe {
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        func take(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            let v = args[i + 1]
            args.removeSubrange(i...(i + 1))
            return v
        }
        guard let moduleRaw = take("--module"), let module = Module(rawValue: moduleRaw), let localeID = take("--locale") else {
            FileHandle.standardError.write("uso: --module speech|dictation --locale xx-YY [--keywords-file f] ficheros…\n".data(using: .utf8)!)
            exit(2)
        }
        var keywords: [String] = []
        if let kf = take("--keywords-file") {
            do {
                keywords = try String(contentsOfFile: kf, encoding: .utf8).split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            } catch {
                FileHandle.standardError.write("no puedo leer \(kf): \(error)\n".data(using: .utf8)!)
            }
        }
        let files = args
        let locale = Locale(identifier: localeID)

        // Instala el modelo del idioma una vez, antes de medir nada. Una app solo puede tener 5 idiomas reservados
        // («Too many allocated locales, 5 maximum», medido): se sueltan los demás antes de reservar este.
        do {
            for l in await AssetInventory.reservedLocales where l.identifier(.bcp47) != locale.identifier(.bcp47) {
                _ = await AssetInventory.release(reservedLocale: l)
            }
            _ = try await AssetInventory.reserve(locale: locale)
            let probe: any SpeechModule = module == .speech
                ? SpeechTranscriber(locale: locale, preset: .transcription)
                : DictationTranscriber(locale: locale, preset: .longDictation)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
                FileHandle.standardError.write("descargando el modelo \(module.rawValue) \(localeID)…\n".data(using: .utf8)!)
                try await request.downloadAndInstall()
            }
        } catch {
            for f in files { emit(Line(file: f, text: "", ms: 0, error: "asset: \(error)")) }
            return
        }

        for f in files {
            let started = ContinuousClock.now
            do {
                let text = try await transcribe(url: URL(fileURLWithPath: f), module: module, locale: locale, keywords: keywords)
                let d = ContinuousClock.now - started
                emit(Line(file: f, text: text, ms: Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000), error: nil))
            } catch {
                emit(Line(file: f, text: "", ms: 0, error: "\(error)"))
            }
        }
    }

    static func transcribe(url: URL, module: Module, locale: Locale, keywords: [String]) async throws -> String {
        let file = try AVAudioFile(forReading: url)
        switch module {
        case .speech:
            let t = SpeechTranscriber(locale: locale, preset: .transcription)
            let analyzer = SpeechAnalyzer(modules: [t])
            return try await run(analyzer: analyzer, file: file, keywords: keywords) {
                var finals = "", lastVolatile = ""
                for try await r in t.results {
                    if r.isFinal { finals += String(r.text.characters) } else { lastVolatile = String(r.text.characters) }
                }
                return finals.isEmpty ? lastVolatile : finals
            }
        case .dictation:
            let t = DictationTranscriber(locale: locale, preset: .longDictation)
            let analyzer = SpeechAnalyzer(modules: [t])
            return try await run(analyzer: analyzer, file: file, keywords: keywords) {
                var finals = "", lastVolatile = ""
                for try await r in t.results {
                    if r.isFinal { finals += String(r.text.characters) } else { lastVolatile = String(r.text.characters) }
                }
                return finals.isEmpty ? lastVolatile : finals
            }
        }
    }

    static func run(analyzer: SpeechAnalyzer, file: AVAudioFile, keywords: [String], collect: @escaping @Sendable () async throws -> String) async throws -> String {
        if !keywords.isEmpty {
            let ctx = AnalysisContext()
            ctx.contextualStrings[.general] = keywords
            try await analyzer.setContext(ctx)
        }
        let collector = Task { try await collect() }
        if let last = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: last)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collector.value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
