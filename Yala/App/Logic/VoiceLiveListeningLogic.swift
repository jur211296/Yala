//
//  VoiceLiveListeningLogic.swift
//  Yala
//
//  Lo que pinta el registro por voz mientras escucha (propuesta A de la card tjws, Jürgen 2026-10-25): la onda de barras
//  que corre de derecha a izquierda con el nivel del micrófono, y la frase que va entendiendo el iPhone con las tres
//  últimas palabras resaltadas. Puro, para test.
//

import Foundation

enum VoiceLiveListeningLogic {
    /// Cuántas barras guarda la onda. Sobran para el ancho de cualquier hoja: la vista pinta las últimas que le caben.
    nonisolated static let waveformCapacity = 96

    /// Nivel de una barra en silencio: una raya, no un hueco, para que la onda se lea como «escuchando».
    nonisolated static let silentLevel = 0.04

    /// Las palabras que van en primario; lo anterior va en secundario.
    nonisolated static let recentWordCount = 3

    /// Añade el nivel de ahora a la derecha y suelta el más viejo por la izquierda. El nivel se acota a 0…1 (un
    /// `NaN` del medidor cuenta como silencio).
    nonisolated static func appending(_ level: Double, to history: [Double], capacity: Int = waveformCapacity) -> [Double] {
        guard capacity > 0 else { return [] }
        let clamped = level.isFinite ? min(1, max(0, level)) : 0
        var next = history
        next.append(max(silentLevel, clamped))
        if next.count > capacity {
            next.removeFirst(next.count - capacity)
        }
        return next
    }

    /// Las `count` barras que se pintan, de izquierda (más vieja) a derecha (ahora). Lo que aún no se ha oído se
    /// rellena por la izquierda con silencio, así la onda entra por la derecha.
    nonisolated static func visibleBars(_ history: [Double], count: Int) -> [Double] {
        guard count > 0 else { return [] }
        let tail = Array(history.suffix(count))
        return Array(repeating: silentLevel, count: count - tail.count) + tail
    }

    /// La frase partida en lo anterior (secundario) y las últimas palabras (primario). Los espacios de más se
    /// colapsan; sin texto, las dos partes salen vacías.
    nonisolated static func split(_ text: String, recent: Int = recentWordCount) -> (older: String, recent: String) {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return ("", "") }
        let cut = max(0, words.count - max(0, recent))
        return (words[..<cut].joined(separator: " "), words[cut...].joined(separator: " "))
    }

    /// Une lo ya cerrado por el reconocedor con lo que todavía puede cambiar (el resultado «volátil»).
    nonisolated static func combined(finalized: String, volatile: String) -> String {
        [finalized, volatile]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Seam de XCUITest: cuántas palabras de la frase fija se ven tras `elapsed` segundos (una cada 0,4 s, como
    /// alguien que dicta).
    nonisolated static func demoWordCount(elapsed: TimeInterval, totalWords: Int) -> Int {
        guard elapsed.isFinite, elapsed > 0, totalWords > 0 else { return 0 }
        return min(totalWords, Int(elapsed / 0.4))
    }

    /// Seam de XCUITest: un nivel de voz de mentira (palabras dentro de sílabas) para que la onda se mueva sin micro.
    nonisolated static func demoLevel(elapsed: TimeInterval) -> Double {
        guard elapsed.isFinite else { return 0 }
        let word = max(0, sin(elapsed * 3.1)) * 0.75 + 0.15
        let syllable = 0.55 + 0.45 * abs(sin(elapsed * 17.3) * cos(elapsed * 5.7))
        return min(1, word * syllable)
    }
}
