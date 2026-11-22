//
//  CuentaSolaAlLeer.swift
//  Yala
//
//  La cuenta se elige sola al leer una captura (ticket `2026-11-20-captura-cuenta-automatica-y-reglas`, parte 1).
//  Una sola escalera para foto, Apple Pay, avisos del banco, correo del banco, voz, Siri y chat: lo que la captura dice
//  del medio de pago («Tarjeta de crédito», «Zip Visa ••4417», el banco del aviso) contra las cuentas del usuario.
//
//  De lo más seguro a lo menos; la primera que decide gana:
//  1. Reglas del usuario (parte 2, `CuentaSolaAlLeerReglas`): tarjeta de Apple Pay › comercio › palabras juntas ›
//     varias palabras › una palabra. Una regla cumplida gana también a la IA; empate hacia cuentas distintas → no elige.
//  2. Últimos 4 dígitos leídos contra los 4 últimos del «Número de cuenta».
//  3. Nombre ENTERO de la cuenta escrito en el medio de pago; con varias, el nombre más largo (empate → no elige).
//  4. Palabras del nombre (como voz y chat desde el 4-nov). Dos que casan → no elige.
//  5. Clase de medio de pago (efectivo, crédito, débito, tarjeta) → la única cuenta de esa clase.
//  6. Única cuenta en la moneda (lo pone `DraftBuilder.chooseAccount`, como antes, sin estrella).
//  7. Pregunta.
//
//  La IA es una segunda capa (decisión A + B de Jürgen, 20-nov): en la foto, con la cuenta en la nube, la IA recibe los
//  nombres de las cuentas y devuelve la que cree. `combinar` cruza las dos opiniones: si coinciden, sola con estrella; si
//  solo opina la IA, sugerida; si se contradicen, pregunta con las dos. Una cuenta de la IA que no existe, o cuyas
//  palabras no están escritas en el medio de pago, se ignora.
//
//  Puro: sin `@Model`. Quien lee las cuentas las traduce (`DraftBuilder.cuentaSolaCandidates`).
//

import Foundation

nonisolated enum CuentaSolaAlLeer {

    /// Lo que la escalera necesita de una cuenta elegible (sin archivar, sin las de sistema de Grupos y sin las líneas de
    /// una tarjeta con varias divisas: se nombra la tarjeta y la divisa elige la línea después).
    struct Cuenta: Equatable, Sendable {
        let id: UUID
        let name: String
        let kind: PaymentMethodAccountLogic.AccountKind
        let currencyCode: String
        /// Los 4 últimos dígitos de su «Número de cuenta», si tiene al menos cuatro.
        let last4: String?
        /// Sus reglas de captura (paso 1).
        let rules: [AccountCaptureRule]

        init(
            id: UUID, name: String, kind: PaymentMethodAccountLogic.AccountKind, currencyCode: String,
            accountNumber: String?, rules: [AccountCaptureRule] = []
        ) {
            self.id = id
            self.name = name
            self.kind = kind
            self.currencyCode = currencyCode
            self.last4 = CuentaSolaAlLeer.last4(ofAccountNumber: accountNumber)
            self.rules = rules
        }
    }

    /// Por qué el teléfono eligió la cuenta.
    enum Motivo: String, Equatable, Sendable {
        /// Una regla de captura del usuario (paso 1).
        case regla
        case last4
        case nombre
        case palabras
        case clase
    }

    /// Lo que decide el teléfono con lo leído (pasos 1 a 5).
    enum Lectura: Equatable, Sendable {
        case elegida(UUID, Motivo)
        /// Dos o más cuentas casan igual de bien: no elige y las enseña.
        case varias([UUID])
        /// Reglas igual de concretas hacia cuentas distintas: no elige y el selector las enseña con su regla.
        case choqueReglas([CuentaSolaAlLeerReglas.Cumplida])
        case ninguna
    }

    /// Lo que se hace con la cuenta tras cruzar el teléfono con la IA.
    enum Resultado: Equatable, Sendable {
        /// La eligió el teléfono (con la IA de acuerdo, o sin IA): va sola, con estrella.
        case sola(UUID, Motivo)
        /// Solo la IA la propone y es una cuenta tuya escrita en el medio de pago: se preselecciona, sin estrella.
        case sugerida(UUID)
        /// El teléfono y la IA dicen cuentas distintas: no elige y el selector enseña las dos con su motivo.
        case choque(telefono: UUID, ia: UUID)
        /// Varias cuentas casan con lo leído: no elige y el selector las pone arriba.
        case varias([UUID])
        /// Dos reglas igual de concretas apuntan a cuentas distintas: no elige y el selector enseña cada una con su regla.
        case choqueReglas([CuentaSolaAlLeerReglas.Cumplida])
        case ninguna

        /// La cuenta que el resultado pone en el borrador, si pone alguna.
        var cuentaPuesta: UUID? {
            switch self {
            case .sola(let id, _), .sugerida(let id): return id
            case .choque, .varias, .choqueReglas, .ninguna: return nil
            }
        }
    }

    /// Lo que la hoja de la foto recuerda de cada borrador para pintar el chip, la línea de «por qué» y el selector.
    /// Vive en memoria mientras la hoja está abierta: el modelo de datos no cambia en la parte 1.
    struct Eleccion: Equatable, Sendable {
        let resultado: Resultado
        /// El medio de pago leído, para «Coinciden con «Visa»».
        let mention: String?
        /// Los últimos 4 que decidieron, para «termina en 4417».
        let last4: String?
        /// La regla que decidió, para «por tu regla «zip»».
        let regla: AccountCaptureRule?
        /// La cuenta con la que nació el borrador (la de la escalera o la única en la moneda). Si la persona la cambia,
        /// «Recordar» le ofrece una regla.
        let cuentaInicial: UUID?

        init(
            resultado: Resultado, mention: String?, last4: String?, regla: AccountCaptureRule? = nil,
            cuentaInicial: UUID? = nil
        ) {
            self.resultado = resultado
            self.mention = mention
            self.last4 = last4 ?? mention.flatMap(CuentaSolaAlLeer.extractLast4(from:))
            self.regla = regla
            self.cuentaInicial = cuentaInicial ?? resultado.cuentaPuesta
        }
    }

    // MARK: - Escalera del teléfono

    /// Los pasos 1 a 5 con lo leído, y la regla que decidió si decidió una. `merchant` es el comercio leído y
    /// `applePayCard`, el nombre de la tarjeta si la captura viene de Apple Pay: solo los miran las reglas.
    static func leerConRegla(
        mention: String?, last4: String?, merchant: String? = nil, applePayCard: String? = nil, among candidates: [Cuenta]
    ) -> (lectura: Lectura, regla: AccountCaptureRule?) {
        // 1. Reglas del usuario.
        let leido = CuentaSolaAlLeerReglas.Lectura(mention: mention, merchant: merchant, applePayCard: applePayCard)
        switch CuentaSolaAlLeerReglas.decidir(leido, among: candidates) {
        case .elegida(let id, let rule): return (.elegida(id, .regla), rule)
        case .choque(let cumplidas): return (.choqueReglas(cumplidas), nil)
        case .ninguna: return (leer(mention: mention, last4: last4, among: candidates), nil)
        }
    }

    /// Los pasos 2 a 5 con lo leído. `mention` es el medio de pago tal como lo dice la captura; `last4`, los dígitos que
    /// la captura trae aparte (aviso del banco, correo). Si no, se buscan en `mention` («••4417», «terminada en 4417»).
    static func leer(mention: String?, last4: String?, among candidates: [Cuenta]) -> Lectura {
        let trimmed = mention?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 2. Últimos 4 dígitos.
        if let digits = last4.flatMap(cleanLast4) ?? extractLast4(from: trimmed) {
            let byDigits = candidates.filter { $0.last4 == digits }
            if byDigits.count == 1 { return .elegida(byDigits[0].id, .last4) }
            if byDigits.count > 1 { return .varias(byDigits.map(\.id)) }
        }

        let text = withoutMaskedDigits(trimmed)
        guard !PaymentMethodAccountLogic.fold(text).isEmpty else { return .ninguna }

        // 3. Nombre entero de la cuenta escrito en el medio de pago; gana el más largo.
        let whole = candidates.filter { nameIsWritten($0.name, in: text) }
        if !whole.isEmpty {
            let lengths = whole.map { PaymentMethodAccountLogic.fold($0.name).count }
            let longest = lengths.max() ?? 0
            let winners = whole.filter { PaymentMethodAccountLogic.fold($0.name).count == longest }
            return winners.count == 1 ? .elegida(winners[0].id, .nombre) : .varias(winners.map(\.id))
        }

        // 4. Las palabras de la mención están todas en el nombre («yape» → «Yape BCP»).
        let words = meaningfulWords(text)
        if !words.isEmpty {
            let foldedText = PaymentMethodAccountLogic.fold(text)
            let byWords = candidates.filter { candidate in
                // Japonés y chino se escriben sin espacios: ahí se compara texto («微信» en «微信支付»).
                let foldedName = PaymentMethodAccountLogic.fold(candidate.name)
                if containsUnspacedScript(foldedName) || containsUnspacedScript(foldedText) {
                    return !foldedName.isEmpty && foldedName.contains(foldedText)
                }
                let nameWords = Set(nameTokens(candidate.name))
                return !nameWords.isEmpty && Set(words).isSubset(of: nameWords)
            }
            if byWords.count == 1 { return .elegida(byWords[0].id, .palabras) }
            if byWords.count > 1 { return .varias(byWords.map(\.id)) }
        }

        // 5. Clase de medio de pago.
        guard let kind = PaymentMethodAccountLogic.kind(of: text) else { return .ninguna }
        let allowed: Set<PaymentMethodAccountLogic.AccountKind>
        switch kind {
        case .cash: allowed = [.cash]
        case .creditCard: allowed = [.creditCard]
        case .debitCard: allowed = [.bank]
        case .card: allowed = [.creditCard, .bank]
        }
        let byKind = candidates.filter { allowed.contains($0.kind) }
        return byKind.count == 1 ? .elegida(byKind[0].id, .clase) : .ninguna
    }

    // MARK: - Segunda capa: la IA

    /// La cuenta que propone la IA, si vale: su nombre es el de una cuenta elegible (sin tildes ni mayúsculas) y al menos
    /// una palabra de ese nombre está escrita en el medio de pago leído. Un nombre inventado o sin rastro en lo leído, `nil`.
    static func cuentaDeIA(_ name: String?, payment: String?, among candidates: [Cuenta]) -> UUID? {
        guard let name, let payment else { return nil }
        let wanted = PaymentMethodAccountLogic.fold(name)
        guard !wanted.isEmpty else { return nil }
        let matches = candidates.filter { PaymentMethodAccountLogic.fold($0.name) == wanted }
        guard matches.count == 1, let match = matches.first else { return nil }
        let paymentText = PaymentMethodAccountLogic.fold(payment)
        if containsUnspacedScript(wanted) { return paymentText.contains(wanted) ? match.id : nil }
        let paymentWords = Set(PaymentMethodAccountLogic.tokens(paymentText).map(PaymentMethodAccountLogic.canonicalWallet))
        let written = nameTokens(match.name).contains { paymentWords.contains($0) }
        return written ? match.id : nil
    }

    /// Cruza lo que decidió el teléfono con lo que propone la IA (`iaAccountID`, ya validada con `cuentaDeIA`).
    static func combinar(_ lectura: Lectura, iaAccountID: UUID?) -> Resultado {
        switch lectura {
        case .elegida(let id, .regla):
            // Una regla del usuario gana a lo que diga la IA (decisión A + B: la IA es segunda capa).
            return .sola(id, .regla)
        case .choqueReglas(let cumplidas):
            return .choqueReglas(cumplidas)
        case .elegida(let id, let motivo):
            guard let ia = iaAccountID, ia != id else { return .sola(id, motivo) }
            return .choque(telefono: id, ia: ia)
        case .varias(let ids):
            if let ia = iaAccountID { return .sugerida(ia) }
            return .varias(ids)
        case .ninguna:
            if let ia = iaAccountID { return .sugerida(ia) }
            return .ninguna
        }
    }

    // MARK: - Lo que se enseña

    /// Cuántas veces sale la línea de «por qué» por persona; desde la siguiente, solo la estrella.
    static let porqueVeces = 3

    static func muestraPorque(vecesMostrada: Int) -> Bool { vecesMostrada < porqueVeces }

    /// El estado del chip de cuenta de un borrador. Si la persona ya cambió la cuenta (o eligió una), vuelve al de siempre.
    enum Chip: Equatable, Sendable {
        case normal
        case elegida(Motivo)
        case sugerida
        /// Sin cuenta, con estas candidatas arriba del selector.
        case elige(coinciden: Int)
    }

    static func chip(for resultado: Resultado?, currentAccountID: UUID?) -> Chip {
        guard let resultado else { return .normal }
        switch resultado {
        case .sola(let id, let motivo):
            return currentAccountID == id ? .elegida(motivo) : .normal
        case .sugerida(let id):
            return currentAccountID == id ? .sugerida : .normal
        case .choque:
            return currentAccountID == nil ? .elige(coinciden: 2) : .normal
        case .varias(let ids):
            return currentAccountID == nil ? .elige(coinciden: ids.count) : .normal
        case .choqueReglas(let cumplidas):
            return currentAccountID == nil ? .elige(coinciden: cumplidas.count) : .normal
        case .ninguna:
            return .normal
        }
    }

    /// Las palabras del medio de pago que se citan en «Coinciden con «Visa»»: sin los dígitos enmascarados.
    static func palabraCitada(_ mention: String?) -> String? {
        guard let mention else { return nil }
        let text = withoutMaskedDigits(mention).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return text.isEmpty ? nil : text
    }

    // MARK: - Últimos 4

    /// Los 4 últimos dígitos de un «Número de cuenta» («1934-1234-4417» → «4417»), si tiene al menos cuatro.
    static func last4(ofAccountNumber number: String?) -> String? {
        guard let number else { return nil }
        let digits = number.filter(\.isASCIIDigitCharacter)
        guard digits.count >= 4 else { return nil }
        return String(digits.suffix(4))
    }

    /// «••4417», «****4417», «xx4417», «terminada en 4417», «ending in 4417» → «4417».
    static func extractLast4(from text: String) -> String? {
        guard let regex = maskedDigitsRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(withName: "last4"), in: text) else { return nil }
        return String(text[range])
    }

    private static func cleanLast4(_ raw: String) -> String? {
        let digits = raw.filter(\.isASCIIDigitCharacter)
        return digits.count >= 4 ? String(digits.suffix(4)) : nil
    }

    private static let maskedDigitsPattern =
        #"(?:[\*•·xX]{2,}\s?|(?:terminada en|termina en|terminación|terminacion|ending in|ends in|ending)\s)(?<last4>\d{4})\b"#

    private static let maskedDigitsRegex: NSRegularExpression? = {
        do {
            return try NSRegularExpression(pattern: maskedDigitsPattern, options: [.caseInsensitive])
        } catch {
            #if DEBUG
            print("CuentaSolaAlLeer: Error: \(error)")
            #endif
            return nil
        }
    }()

    private static func withoutMaskedDigits(_ text: String) -> String {
        guard let regex = maskedDigitsRegex else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
    }

    // MARK: - Palabras

    /// El nombre entero de la cuenta está escrito, palabra a palabra, en el texto.
    private static func nameIsWritten(_ name: String, in text: String) -> Bool {
        let folded = PaymentMethodAccountLogic.fold(name)
        guard !folded.isEmpty else { return false }
        return PaymentMethodAccountLogic.appears(name, in: text)
    }

    /// Las palabras que identifican: sin las de relleno («con mi») ni las que son solo cifras.
    private static func meaningfulWords(_ text: String) -> [String] {
        PaymentMethodAccountLogic.tokens(PaymentMethodAccountLogic.fold(text))
            .map(PaymentMethodAccountLogic.canonicalWallet)
            .filter { !PaymentMethodAccountLogic.fillerWords.contains($0) && !$0.allSatisfy(\.isASCIIDigitCharacter) }
    }

    private static func nameTokens(_ name: String) -> [String] {
        meaningfulWords(name)
    }

    private static func containsUnspacedScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF: return true
            default: return false
            }
        }
    }
}

private extension Character {
    nonisolated var isASCIIDigitCharacter: Bool { isASCII && isNumber }
}
