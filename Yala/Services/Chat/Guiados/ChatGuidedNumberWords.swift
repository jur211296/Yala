//
//  ChatGuidedNumberWords.swift
//  Yala
//
//  Los números dichos con palabras, en español, inglés y portugués, pasados a cifras antes de que el detector de los
//  guiados lea la frase: «mil quinientos» → «1500», «dos mil cincuenta soles» → «2050 soles», «el cinco de cada mes» →
//  «el 5 de cada mes», «on the fifth» → «on the 5th». La voz del chat a veces escribe así lo que se dicta.
//
//  Trabaja sobre el texto plegado (minúsculas, sin tildes). Las palabras que también son otra cosa no empiezan un número
//  solas: «un», «una», «uno», «a», «an», «one», «um», «uma» solo cuentan delante de «mil», «cien», «hundred»… («un
//  presupuesto» sigue siendo un presupuesto), y «once» solo en español («el once», «once soles»): en inglés es «una
//  vez». En los demás idiomas no hace nada y el guiado pregunta el monto como siempre.
//

import Foundation

nonisolated enum ChatGuidedNumberWords {

    /// La frase con cada número dicho con palabras cambiado por sus cifras. Lo demás queda igual.
    static func replacingNumberWords(in folded: String) -> String {
        let tokens = tokenize(folded)
        guard !tokens.isEmpty else { return folded }
        var result = ""
        var cursor = folded.startIndex
        var index = 0
        while index < tokens.count {
            if let run = numberRun(startingAt: index, tokens: tokens) {
                let first = tokens[index].range.lowerBound
                let last = tokens[run.endIndex].range.upperBound
                result += folded[cursor..<first]
                result += run.text
                cursor = last
                index = run.endIndex + 1
            } else {
                index += 1
            }
        }
        result += folded[cursor...]
        return result
    }

    /// ¿Es una palabra de número? (Para que el nombre de un pago no se lleve «trescientos».)
    static func isNumberWord(_ folded: String) -> Bool {
        let parts = folded.split(separator: "-").map(String.init)
        return !parts.isEmpty && parts.allSatisfy { cardinals[$0] != nil || multipliers[$0] != nil || ordinals[$0] != nil }
    }

    // MARK: - Tokens

    private struct Token {
        let text: String
        let range: Range<String.Index>
    }

    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var start: String.Index?
        var index = text.startIndex
        func isWordChar(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "-" }
        while index < text.endIndex {
            let character = text[index]
            if isWordChar(character) {
                if start == nil { start = index }
            } else if let open = start {
                tokens.append(Token(text: String(text[open..<index]), range: open..<index))
                start = nil
            }
            index = text.index(after: index)
        }
        if let open = start { tokens.append(Token(text: String(text[open...]), range: open..<text.endIndex)) }
        return tokens
    }

    // MARK: - Un número

    private struct Run {
        let endIndex: Int
        let text: String
    }

    /// El número que empieza en `start`, si empieza uno ahí.
    private static func numberRun(startingAt start: Int, tokens: [Token]) -> Run? {
        let first = tokens[start].text
        let previous = start > 0 ? tokens[start - 1].text : nil
        let next = start + 1 < tokens.count ? tokens[start + 1].text : nil

        // Un ordinal solo cuenta como día: «on the fifth (of each month)» → «on the 5th», «el primero de cada mes» →
        // «el 1», «dia primeiro» → «dia 1». «every second week» o «my first apartment» no son días.
        if let ordinal = ordinals[first] {
            guard isDayOrdinalContext(word: first, previous: previous, next: next) else { return nil }
            let spanishOrPortuguese = first == "primero" || first == "primeiro"
            return Run(endIndex: start, text: spanishOrPortuguese ? "\(ordinal)" : "\(ordinal)th")
        }
        if let compound = hyphenatedValue(first), compound.isOrdinal,
           !isDayOrdinalContext(word: first, previous: previous, next: next) {
            return nil
        }

        guard canStart(first, previous: previous, next: next) else { return nil }

        var total = 0
        var current = 0
        var lastNumberIndex: Int?
        var index = start
        while index < tokens.count {
            let word = tokens[index].text
            if let compound = hyphenatedValue(word) {
                // «twenty-five», también «twenty-fifth».
                guard accepts(compound.value, into: current) else { break }
                current += compound.value
                lastNumberIndex = index
                if compound.isOrdinal {
                    return Run(endIndex: index, text: "\(total + current)th")
                }
                index += 1
                continue
            }
            if let multiplier = multipliers[word] {
                if multiplier == 100 {
                    // «hundred»: multiplica lo de delante («three hundred»), o 100 a secas («a hundred» ya puso el 1).
                    guard current < 100 else { break }
                    current = max(current, 1) * 100
                } else {
                    total += max(current, 1) * multiplier
                    current = 0
                }
                lastNumberIndex = index
                index += 1
                continue
            }
            if let value = value(of: word, isFirst: index == start, previous: index > 0 ? tokens[index - 1].text : nil,
                                 next: index + 1 < tokens.count ? tokens[index + 1].text : nil) {
                guard accepts(value, into: current) else { break }
                current += value
                lastNumberIndex = index
                index += 1
                continue
            }
            // «treinta y cinco», «one hundred and fifty», «mil e quinhentos»: el enlace solo vale entre dos números.
            if connectors.contains(word), lastNumberIndex == index - 1, index + 1 < tokens.count,
               let after = value(of: tokens[index + 1].text, isFirst: false, previous: word, next: nil)
                ?? hyphenatedValue(tokens[index + 1].text)?.value,
               accepts(after, into: current) || multipliers[tokens[index + 1].text] != nil {
                index += 1
                continue
            }
            break
        }
        guard let end = lastNumberIndex else { return nil }
        let number = total + current
        guard number > 0 else { return nil }
        return Run(endIndex: end, text: "\(number)")
    }

    /// «the fifth of…», «on the fifth», «el primero de…», «dia primeiro»: el día de un pago.
    private static func isDayOrdinalContext(word: String, previous: String?, next: String?) -> Bool {
        if word == "primero" || word == "primeiro" {
            guard let previous, ["el", "dia", "o"].contains(previous) else { return false }
            return next == nil || ["de", "del", "do", "of"].contains(next ?? "")
        }
        guard previous == "the" else { return false }
        return next == nil || ["of", "each", "every", "and"].contains(next ?? "")
    }

    /// Las palabras ambiguas no empiezan un número solas.
    private static func canStart(_ word: String, previous: String?, next: String?) -> Bool {
        if hyphenatedValue(word) != nil { return true }
        // «2 mil», «1.5 mil»: el multiplicador va con la cifra de delante y lo lee `amount(in:)`; aquí sería otro 1000.
        if let previous, previous.allSatisfy(\.isNumber) { return false }
        if multipliers[word] != nil { return word != "hundred" }
        guard cardinals[word] != nil else { return false }
        if ambiguousOnes.contains(word) {
            if let next, multipliers[next] != nil { return true }
            // «el uno de cada mes».
            return word == "uno" && ["el", "dia"].contains(previous ?? "")
        }
        if word == "dos" {
            // En portugués «dos» es «de los» («orçamento dos gastos»), y «para los dos» son dos personas: solo cuenta
            // pegado a otra cifra o a una moneda, o detrás de lo que en español anuncia un número o un día.
            if let next, cardinals[next] != nil || multipliers[next] != nil || currencies.contains(next) {
                return true
            }
            return ["el", "cada", "son", "dia"].contains(previous ?? "")
        }
        if word == "once" {
            // En inglés «once» es «una vez»: solo cuenta en una frase en español.
            if let previous, ["el", "dia", "los", "cada", "de"].contains(previous) { return true }
            if let next, ["soles", "dolares", "euros", "pesos", "mil"].contains(next) { return true }
            return false
        }
        return true
    }

    private static func value(of word: String, isFirst: Bool, previous: String?, next: String?) -> Int? {
        guard let value = cardinals[word] else { return nil }
        if isFirst, !canStart(word, previous: previous, next: next) { return nil }
        // «a» y «an» solo valen delante de «hundred» / «thousand».
        if ["a", "an"].contains(word), !(next.map { multipliers[$0] != nil } ?? false) { return nil }
        return value
    }

    /// Se puede sumar `value` a lo que va: «trescientos» + «cincuenta» sí, «quince» + «tres» no.
    private static func accepts(_ value: Int, into current: Int) -> Bool {
        guard current > 0 else { return true }
        var place = 1
        while current % (place * 10) == 0 { place *= 10 }
        return value < place
    }

    /// «twenty-five» → 25 · «thirty-first» → 31 (ordinal).
    private static func hyphenatedValue(_ word: String) -> (value: Int, isOrdinal: Bool)? {
        let parts = word.split(separator: "-").map(String.init)
        guard parts.count == 2, let tens = cardinals[parts[0]], tens >= 20, tens % 10 == 0 else { return nil }
        if let unit = cardinals[parts[1]], unit < 10 { return (tens + unit, false) }
        if let unit = ordinals[parts[1]], unit < 10 { return (tens + unit, true) }
        return nil
    }

    // MARK: - Vocabulario (plegado)

    private static let ambiguousOnes: Set<String> = ["un", "una", "uno", "a", "an", "one", "um", "uma"]

    private static let connectors: Set<String> = ["y", "and", "e"]

    private static let currencies: Set<String> = [
        "soles", "sol", "dolares", "euros", "pesos", "reales", "lucas",
    ]

    private static let multipliers: [String: Int] = [
        "hundred": 100,
        "mil": 1000, "thousand": 1000,
        "millon": 1_000_000, "millones": 1_000_000, "million": 1_000_000, "millions": 1_000_000,
        "milhao": 1_000_000, "milhoes": 1_000_000,
    ]

    private static let cardinals: [String: Int] = {
        var table: [String: Int] = [:]
        // Español
        let spanish: [(String, Int)] = [
            ("cero", 0), ("un", 1), ("una", 1), ("uno", 1), ("dos", 2), ("tres", 3), ("cuatro", 4), ("cinco", 5),
            ("seis", 6), ("siete", 7), ("ocho", 8), ("nueve", 9), ("diez", 10), ("once", 11), ("doce", 12),
            ("trece", 13), ("catorce", 14), ("quince", 15), ("dieciseis", 16), ("diecisiete", 17), ("dieciocho", 18),
            ("diecinueve", 19), ("veinte", 20), ("veintiun", 21), ("veintiuno", 21), ("veintiuna", 21),
            ("veintidos", 22), ("veintitres", 23), ("veinticuatro", 24), ("veinticinco", 25), ("veintiseis", 26),
            ("veintisiete", 27), ("veintiocho", 28), ("veintinueve", 29), ("treinta", 30), ("cuarenta", 40),
            ("cincuenta", 50), ("sesenta", 60), ("setenta", 70), ("ochenta", 80), ("noventa", 90), ("cien", 100),
            ("ciento", 100), ("doscientos", 200), ("doscientas", 200), ("trescientos", 300), ("trescientas", 300),
            ("cuatrocientos", 400), ("cuatrocientas", 400), ("quinientos", 500), ("quinientas", 500),
            ("seiscientos", 600), ("seiscientas", 600), ("setecientos", 700), ("setecientas", 700),
            ("ochocientos", 800), ("ochocientas", 800), ("novecientos", 900), ("novecientas", 900),
        ]
        // English
        let english: [(String, Int)] = [
            ("zero", 0), ("a", 1), ("an", 1), ("one", 1), ("two", 2), ("three", 3), ("four", 4), ("five", 5),
            ("six", 6), ("seven", 7), ("eight", 8), ("nine", 9), ("ten", 10), ("eleven", 11), ("twelve", 12),
            ("thirteen", 13), ("fourteen", 14), ("fifteen", 15), ("sixteen", 16), ("seventeen", 17),
            ("eighteen", 18), ("nineteen", 19), ("twenty", 20), ("thirty", 30), ("forty", 40), ("fifty", 50),
            ("sixty", 60), ("seventy", 70), ("eighty", 80), ("ninety", 90),
        ]
        // Português
        let portuguese: [(String, Int)] = [
            ("um", 1), ("uma", 1), ("dois", 2), ("duas", 2), ("quatro", 4), ("sete", 7), ("oito", 8), ("nove", 9),
            ("dez", 10), ("onze", 11), ("doze", 12), ("treze", 13), ("catorze", 14), ("quatorze", 14),
            ("dezesseis", 16), ("dezasseis", 16), ("dezessete", 17), ("dezassete", 17), ("dezoito", 18),
            ("dezenove", 19), ("dezanove", 19), ("vinte", 20), ("trinta", 30), ("quarenta", 40), ("cinquenta", 50),
            ("sessenta", 60), ("oitenta", 80), ("cem", 100), ("cento", 100), ("duzentos", 200),
            ("duzentas", 200), ("trezentos", 300), ("trezentas", 300), ("quatrocentos", 400), ("quatrocentas", 400),
            ("quinhentos", 500), ("quinhentas", 500), ("seiscentos", 600), ("seiscentas", 600),
            ("setecentos", 700), ("setecentas", 700), ("oitocentos", 800), ("oitocentas", 800),
            ("novecentos", 900), ("novecentas", 900),
        ]
        for (word, value) in spanish + english + portuguese { table[word] = value }
        return table
    }()

    /// Los ordinales que se usan para el día: «the fifth», «el primero», «dia primeiro».
    private static let ordinals: [String: Int] = [
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "sixth": 6, "seventh": 7, "eighth": 8,
        "ninth": 9, "tenth": 10, "eleventh": 11, "twelfth": 12, "thirteenth": 13, "fourteenth": 14, "fifteenth": 15,
        "sixteenth": 16, "seventeenth": 17, "eighteenth": 18, "nineteenth": 19, "twentieth": 20, "thirtieth": 30,
        "primero": 1, "primeiro": 1,
    ]
}
