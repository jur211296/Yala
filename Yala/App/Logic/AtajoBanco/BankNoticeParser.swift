//
//  BankNoticeParser.swift
//  Yala
//
//  Lee un aviso del banco con las reglas de `BankNoticeRules`. Pura y síncrona, para los tests y para correr igual en
//  el proceso de la acción de Atajos que en la app.
//
//  Orden (cada paso decide solo si el anterior no lo hizo):
//  1. Compra rechazada → no es un movimiento.
//  2. Anulación o devolución → no se entiende sola (borrador para completar).
//  3. Publicidad → no es un movimiento.
//  4. Las reglas del banco del aviso, y luego las demás y las genéricas → movimiento.
//  5. Seguridad, cuenta o saldo → no es un movimiento.
//  6. Nada → `nil`: lo intenta el modelo del iPhone y, si tampoco, «No entendimos este aviso».
//
//  El texto que entrega la automatización de Notificación es «título␤cuerpo» (medido en el iPhone 14, iOS 27.2.1, prueba
//  B0): los saltos de línea se leen como espacios.
//

import Foundation

nonisolated enum BankNoticeParser {

    /// El texto de un aviso tal como se lee: espacios simples, sin saltos de línea.
    static func normalized(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// El banco del aviso: el que dice el atajo instalado o, si no, el que nombra el texto.
    static func bank(text: String, hint: BankNoticeBank?) -> BankNoticeBank? {
        hint ?? BankNoticeBank.detect(in: text)
    }

    /// Lo que dicen las reglas. `nil` si ninguna sabe leerlo.
    static func read(_ text: String, bankHint: BankNoticeBank? = nil, rules: [BankNoticeRule] = BankNoticeRules.all) -> BankNoticeReading? {
        let line = normalized(text)
        guard !line.isEmpty else { return nil }
        if matches(BankNoticeRules.declinedPattern, in: line) { return .notAMovement }
        if matches(BankNoticeRules.reversalPattern, in: line) { return .notUnderstood }
        if matches(BankNoticeRules.promotionPattern, in: line) { return .notAMovement }
        let bank = bank(text: line, hint: bankHint)
        for rule in ordered(rules, for: bank) {
            if let movement = apply(rule, to: line) {
                return .movement(movement, ruleID: rule.id)
            }
        }
        if matches(BankNoticeRules.notAMovementPattern, in: line) { return .notAMovement }
        return nil
    }

    /// Primero las reglas del banco del aviso, luego las de los demás bancos, y al final las genéricas.
    static func ordered(_ rules: [BankNoticeRule], for bank: BankNoticeBank?) -> [BankNoticeRule] {
        let own = rules.filter { $0.bank != nil && $0.bank == bank }
        let others = rules.filter { $0.bank != nil && $0.bank != bank }
        let generic = rules.filter { $0.bank == nil }
        return own + others + generic
    }

    /// El movimiento que lee una regla, o `nil` si no casa o el importe no se deja leer.
    static func apply(_ rule: BankNoticeRule, to line: String) -> BankNoticeMovement? {
        guard let regex = regex(rule.pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let amountText = group("amt", of: match, in: line),
              let amount = BankNoticeAmount.decimal(from: amountText) else { return nil }
        let currency = BankNoticeAmount.currency(of: group("cur", of: match, in: line) ?? "")
        var who = group("who", of: match, in: line).map(cleanCounterparty)
        if who == nil, rule.merchantAfterEn, let matchEnd = Range(match.range, in: line)?.upperBound {
            who = merchant(after: line[matchEnd...])
        }
        return BankNoticeMovement(
            amount: amount,
            currencyCode: currency.code,
            ambiguousSymbol: currency.ambiguous,
            isExpense: rule.isExpense,
            counterparty: who.flatMap { $0.isEmpty ? nil : $0 },
            cardLast4: last4(in: line)
        )
    }

    /// «… en TAMBO+ MIRAFLORES.» → «TAMBO+ MIRAFLORES». Corta en el punto final, en «el 12/11», «a las …» o «con tu …».
    static func merchant(after tail: Substring) -> String? {
        let text = String(tail)
        let pattern = #"\ben (?<who>.+?)(?:\.\s|\.$| el \d| a las | con tu | con la |(?= en \S)|$)"#
        guard let regex = regex(pattern) else { return nil }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let who = group("who", of: match, in: text) else { continue }
            let cleaned = cleanCounterparty(who)
            // «en tu cuenta», «en tu tarjeta ****1234»: no es un comercio; se mira el siguiente «en».
            let lowered = cleaned.lowercased()
            if cleaned.isEmpty || lowered.hasPrefix("tu ") || lowered.hasPrefix("su ") || lowered.hasPrefix("la cuenta") {
                continue
            }
            return cleaned
        }
        return nil
    }

    /// Los últimos cuatro dígitos de la tarjeta: «****4821», «terminada en 4821», «xxxx4821».
    static func last4(in line: String) -> String? {
        let pattern = #"(?:\*{2,}|[xX]{2,}|terminada en |termina en |terminación )\s?(?<last4>\d{4})\b"#
        guard let regex = regex(pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        return group("last4", of: match, in: line)
    }

    // MARK: - Ayudas

    static func cleanCounterparty(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;:!¡")))
    }

    static func matches(_ pattern: String, in line: String) -> Bool {
        guard let regex = regex(pattern) else { return false }
        return regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        do {
            return try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            #if DEBUG
            print("BankNoticeParser: Error: \(error)")
            #endif
            return nil
        }
    }

    private static func group(_ name: String, of match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(withName: name)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
