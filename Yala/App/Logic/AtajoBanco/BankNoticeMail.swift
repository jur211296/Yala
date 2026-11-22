//
//  BankNoticeMail.swift
//  Yala
//
//  Atajo del banco, B3: el mismo «Registrar movimiento desde texto» con el disparador «Correo electrónico» de Atajos, para
//  quien recibe las alertas del banco en la app Mail. Medido en la prueba B0 (iPhone 14, iOS 27.2.1): la variable
//  «Correo electrónico › Contenido» entrega el cuerpo entero y corre sin pedir nada.
//
//  Un correo no es una notificación: trae saludo, una tabla de campos («Monto: S/ 45.90», «Comercio: TAMBO+») y un pie
//  legal que habla de promociones, claves y saldos. Leído tal cual, el pie hacía que las reglas lo dieran por publicidad
//  o por aviso de seguridad. Así que antes de leerlo:
//
//  1. se corta en el pie (la primera línea que empieza como un pie legal) y se limita su largo;
//  2. se leen los campos con etiqueta, que es la forma de las constancias de los bancos peruanos;
//  3. si no hay campos, el texto recortado pasa por las reglas de siempre.
//
//  Nada del correo sale del iPhone. El borrador guarda el texto recortado, como el de una notificación.
//

import Foundation

nonisolated enum BankNoticeMail {

    /// Lo que se guarda y se lee de un correo, como mucho. Una constancia cabe de sobra; un boletín no.
    static let maxCharacters = 1_500

    /// Cómo empieza el pie de un correo de banco. Se corta en la primera LÍNEA que empiece así.
    static let footerStarts = [
        "este correo", "este mensaje", "este e-mail", "este email", "por favor, no respondas", "por favor no respondas",
        "no respondas", "no responda", "si no reconoces", "si no realizaste", "si no fuiste", "atentamente", "saludos",
        "términos y condiciones", "terminos y condiciones", "©", "copyright", "para más información",
        "para mas informacion", "protege tus datos", "recuerda que", "importante:", "aviso legal",
    ]

    /// El correo listo para leer: sin el pie y recortado.
    static func cleaned(_ text: String) -> String {
        var kept: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let lowered = line.lowercased()
            if !kept.isEmpty, footerStarts.contains(where: { lowered.hasPrefix($0) }) { break }
            if !line.isEmpty { kept.append(line) }
        }
        let joined = kept.joined(separator: "\n")
        guard joined.count > maxCharacters else { return joined }
        return String(joined.prefix(maxCharacters))
    }

    // MARK: - Campos con etiqueta

    /// «Monto: S/ 45.90», «Importe total S/. 45,90», «Total: US$ 12.00».
    static let amountField = #"(?:monto|importe|total|valor)(?: total| de la operaci[oó]n| consumido| pagado)?\s*:?\s*"#
        + BankNoticeRules.money

    /// «Comercio: TAMBO+ MIRAFLORES», «Establecimiento: …», «Empresa: …», «Lugar: …».
    static let merchantField = #"(?:comercio|establecimiento|empresa|lugar|negocio)\s*:\s*(?<who>[^\n]+)"#

    /// Que el correo hable de un gasto: sin esta palabra, un correo con «Monto:» puede ser un abono o un estado de cuenta.
    static let expenseWords = #"consumo|compra|pago|cargo|pagaste|compraste|constancia de (?:consumo|compra|pago)"#

    /// Lo que dicen los campos con etiqueta del correo ya recortado, o `nil` si no hay importe con etiqueta o no habla de
    /// un gasto. Solo gastos: un abono por correo lo leen las reglas de siempre («Recibiste S/ 50.00 de …»).
    static func readFields(_ cleaned: String) -> BankNoticeReading? {
        let lines = cleaned.components(separatedBy: .newlines)
        let line = BankNoticeParser.normalized(cleaned)
        guard BankNoticeParser.matches(expenseWords, in: line),
              !BankNoticeParser.matches(BankNoticeRules.declinedPattern, in: line),
              !BankNoticeParser.matches(BankNoticeRules.reversalPattern, in: line) else { return nil }
        guard let amountMatch = firstMatch(amountField, in: line),
              let amountText = group("amt", amountMatch, line),
              let amount = BankNoticeAmount.decimal(from: amountText) else { return nil }
        let currency = BankNoticeAmount.currency(of: group("cur", amountMatch, line) ?? "")
        let who = merchant(in: lines)
        let movement = BankNoticeMovement(
            amount: amount,
            currencyCode: currency.code,
            ambiguousSymbol: currency.ambiguous,
            isExpense: true,
            counterparty: who,
            cardLast4: BankNoticeParser.last4(in: line)
        )
        return .movement(movement, ruleID: "mail.fields")
    }

    /// «Comercio: TAMBO+» en una línea, o la etiqueta sola y el valor en la siguiente (así sale una tabla del correo
    /// pasada a texto). Se busca por LÍNEA: en la línea normalizada se juntaría con la etiqueta siguiente.
    static let merchantLabelOnly = #"^(?:comercio|establecimiento|empresa|lugar|negocio)\s*:?$"#

    static func merchant(in lines: [String]) -> String? {
        for (index, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let match = firstMatch(merchantField, in: line), let who = group("who", match, line) {
                let cleanedWho = BankNoticeParser.cleanCounterparty(who)
                if !cleanedWho.isEmpty { return cleanedWho }
            }
            if firstMatch(merchantLabelOnly, in: line) != nil, index + 1 < lines.count {
                let next = BankNoticeParser.cleanCounterparty(lines[index + 1])
                if !next.isEmpty { return next }
            }
        }
        return nil
    }

    /// La lectura de un correo: los campos con etiqueta y, si no los hay, las reglas de siempre sobre el texto recortado.
    static func read(_ text: String, bankHint: BankNoticeBank?) -> BankNoticeReading? {
        let body = cleaned(text)
        guard !body.isEmpty else { return nil }
        return readFields(body) ?? BankNoticeParser.read(body, bankHint: bankHint)
    }

    // MARK: - Ayudas

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        } catch {
            #if DEBUG
            print("BankNoticeMail: Error: \(error)")
            #endif
            return nil
        }
    }

    private static func group(_ name: String, _ match: NSTextCheckingResult, _ text: String) -> String? {
        let range = match.range(withName: name)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
