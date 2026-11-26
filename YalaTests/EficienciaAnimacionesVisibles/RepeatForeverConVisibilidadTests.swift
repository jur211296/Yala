//
//  RepeatForeverConVisibilidadTests.swift
//  YalaTests
//
//  Lote 2 del plan de eficiencia (26-nov-2026). Medido en el iPhone 14: el pulso de la gráfica de tendencia latía sin
//  fin con el Panel montado detrás de otra pestaña y tenía la app al 35-38 % de un núcleo estando quieta. Toda
//  animación `repeatForever` de la app cuelga ahora de `animaSoloVisible` (página a la vista y app activa). Este barrido
//  lo fija: un `repeatForever` nuevo sin esa condición lo pone en rojo.
//

import Foundation
import Testing

@Suite("Eficiencia · ninguna animación sin fin corre fuera de la vista")
struct RepeatForeverConVisibilidadTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Las que quedan fuera, con su motivo. Ninguna vive en una página de pestaña, que es lo que se queda montado oculto:
    /// se van con su pantalla. Quitarle el `repeatForever` a una obliga a sacarla de aquí (ver el último test).
    private static let excepciones: [String: String] = [
        "Yala/App/Views/SplashScreenView.swift": "el splash se desmonta al entrar en la app",
        "Yala/App/Views/Onboarding/WelcomeShowcaseDemoView.swift": "demo del Welcome, en su cover, antes de la app",
        "Yala/App/Views/Image/ImageSelectionView.swift": "foto leyéndose de la entrada por imagen, en su hoja; fuera del lote 2",
        "Yala/App/Views/Voice/VoiceLiveListeningViews.swift": "escucha del registro por voz, en su hoja; fuera del lote 2",
    ]

    private static func codeOnly(_ text: String) -> String {
        var raw = text.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func appSources() throws -> [(path: String, code: String)] {
        let appDir = root.appendingPathComponent("Yala/App")
        let enumerator = try #require(FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil))
        var files: [(String, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let path = url.path.replacingOccurrences(of: root.path + "/", with: "")
            files.append((path, codeOnly(try String(contentsOf: url, encoding: .utf8))))
        }
        return files
    }

    @Test func todoRepeatForeverTieneCondicionDeVisibilidad() throws {
        let files = try Self.appSources()
        #expect(files.count > 200, "Solo se leyeron \(files.count) ficheros de Yala/App")
        let offenders = files
            .filter { $0.code.contains(".repeatForever(") && !$0.code.contains(".animaSoloVisible(") }
            .map(\.path)
            .filter { Self.excepciones[$0] == nil }
        #expect(offenders.isEmpty, "repeatForever sin animaSoloVisible en: \(offenders)")
    }

    /// Cada `repeatForever` de un fichero con condición se enciende con su estado: `<estado> ? … .repeatForever …`.
    /// Una animación fija (`.animation(.linear(…).repeatForever(…), value:)`) seguiría corriendo al ocultarse.
    @Test func cadaRepeatForeverVaDetrasDeSuEstado() throws {
        let condicionada = try NSRegularExpression(pattern: #"\?\s*\.[a-zA-Z]+\([^)]*\)\s*\.repeatForever\("#)
        var sueltas: [String] = []
        for file in try Self.appSources() where Self.excepciones[file.path] == nil {
            let total = file.code.components(separatedBy: ".repeatForever(").count - 1
            guard total > 0 else { continue }
            let range = NSRange(file.code.startIndex..., in: file.code)
            let conCondicion = condicionada.numberOfMatches(in: file.code, range: range)
            // El menú del botón flotante anima por `phaseAnimator`, cuyas fases ya dependen del estado.
            let porFases = file.code.contains(".phaseAnimator(menuBeating ? ") ? 1 : 0
            if conCondicion + porFases < total { sueltas.append(file.path) }
        }
        #expect(sueltas.isEmpty, "repeatForever sin su estado delante en: \(sueltas)")
    }

    @Test func lasExcepcionesSiguenTeniendoRepeatForever() throws {
        let files = Dictionary(uniqueKeysWithValues: try Self.appSources().map { ($0.path, $0.code) })
        for path in Self.excepciones.keys {
            let code = try #require(files[path], "La excepción \(path) ya no existe: sácala de la lista")
            #expect(code.contains(".repeatForever("), "\(path) ya no anima sin fin: sácala de las excepciones")
        }
    }

    /// El pulso de la tendencia da dos latidos: no vuelve a ser sin fin.
    @Test func elPulsoDeLaTendenciaNoEsSinFin() throws {
        let files = Dictionary(uniqueKeysWithValues: try Self.appSources().map { ($0.path, $0.code) })
        let trend = try #require(files["Yala/App/Views/Panel/TrendChartView.swift"])
        #expect(!trend.contains(".repeatForever("))
        #expect(trend.contains(".repeatCount(2, autoreverses: false)"))
        #expect(trend.contains(".animaSoloVisible($pulseAnimate"))
    }

    /// Control negativo del patrón de condición.
    @Test func elPatronDistingueCondicionadaDeFija() throws {
        let condicionada = try NSRegularExpression(pattern: #"\?\s*\.[a-zA-Z]+\([^)]*\)\s*\.repeatForever\("#)
        func matches(_ text: String) -> Bool {
            condicionada.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
        #expect(matches("x ? .linear(duration: 1.5).repeatForever(autoreverses: false) : nil"))
        #expect(!matches(".animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: s)"))
        // Solo «Reducir movimiento» delante no es visibilidad: sigue corriendo con la página oculta.
        #expect(!matches("reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true)"))
    }
}
