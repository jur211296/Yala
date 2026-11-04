//
//  PaymentMethodAccountLogic.swift
//  Yala
//
//  El medio de pago que el usuario NOMBRA al dictar o escribir un gasto («25 almuerzo yape», «paid cash», «con mi BCP»)
//  y la cuenta suya que le corresponde. Lo usan las tres capturas que leen una frase con `TranscriptionParserService`:
//  el chat de Yala IA, la nota de voz y Siri.
//
//  Dos reglas que no se tocan sin reabrirlo (card «Yala IA: detectar medio de pago», 2026-11-04):
//  1. **Nunca se inventa.** La mención tiene que estar ESCRITA en la frase del usuario: la palabra que devuelve el modelo
//     (`paymentHint`) se descarta si no aparece en el texto. Y una mención que casa con dos cuentas no elige ninguna:
//     el borrador sale sin cuenta, como antes, y la persona la elige.
//  2. **El modelo solo copia palabras; la cuenta la decide Swift**, contra las cuentas del usuario. Así el prompt no
//     lleva los nombres de las cuentas (ni más tokens ni más datos fuera del teléfono).
//

import Foundation

nonisolated enum PaymentMethodAccountLogic {

    /// Lo que la lógica necesita de una cuenta. Solo cuentas elegibles: sin archivar, sin las de sistema de Grupos y sin
    /// las líneas de una tarjeta con varias divisas (la divisa elige la línea después, `AccountCardLogic.route`).
    struct Candidate: Equatable, Sendable {
        let id: UUID
        let name: String
        let kind: AccountKind
    }

    /// El tipo de la cuenta, en lo que importa aquí. Quien lee el `@Model` lo traduce de `AccountType`
    /// (`DraftBuilder.paymentCandidates`): corriente y ahorros son `bank`; «General» y lo desconocido, `other`.
    enum AccountKind: Equatable, Sendable {
        case cash
        case creditCard
        case bank
        case other
    }

    /// La clase de medio de pago que dice una mención cuando no nombra ninguna cuenta.
    enum Kind: Equatable, Sendable {
        case cash
        case creditCard
        case debitCard
        /// «tarjeta», «card»: cualquiera que tenga tarjeta (crédito, corriente o ahorros).
        case card
    }

    // MARK: - Léxico

    /// Una línea por clase: las palabras de los idiomas de la app, sin tildes ni mayúsculas. Varias palabras se comparan
    /// como secuencia de palabras; las de escritura sin espacios (japonés, chino), como texto.
    static let cashPhrases = ["efectivo", "cash", "contanti", "bargeld", "bar", "especes", "liquide", "dinheiro", "contant", "contanten", "gotowka", "gotowke", "現金", "现金"]
    static let creditCardPhrases = ["credito", "tarjeta de credito", "credit", "credit card", "kreditkarte", "carte de credit", "carta di credito", "cartao de credito", "karta kredytowa", "creditcard", "クレジット", "クレジットカード", "信用卡"]
    static let debitCardPhrases = ["debito", "tarjeta de debito", "debit", "debit card", "debitkarte", "ec karte", "girocard", "carte bancaire", "bancomat", "cartao de debito", "karta debetowa", "pin", "gepind", "pinnen", "pinpas", "デビット", "デビットカード", "借记卡", "银行卡"]
    static let cardPhrases = ["tarjeta", "card", "karte", "carte", "carta", "cartao", "karta", "karta", "kaart", "visa", "mastercard", "amex", "カード", "卡", "刷卡"]

    /// Los nombres de billeteras y medios que la gente dice tal cual («yape», «plin», «pix»). Solo sirven para buscar en
    /// la frase cuando el modelo no contestó el campo (gateway sin desplegar, Siri en el dispositivo): con el campo, el
    /// modelo ya decide qué es un medio de pago y la cuenta se busca por su nombre.
    static let walletPhrases = ["yape", "plin", "tunki", "bim", "mercado pago", "mercadopago", "nequi", "daviplata", "pix", "bizum", "paypal", "venmo", "revolut", "apple pay", "google pay", "微信", "微信支付", "支付宝"]

    /// Palabras del léxico que en otros idiomas son corrientes («un bar», «el PIN», «una carta», «crédito» de un préstamo):
    /// sin el modelo no se buscan en la frase.
    static let ambiguousWithoutModel: Set<String> = ["bar", "pin", "carta", "credito", "credit", "debit", "debito"]

    /// Palabras que acompañan a la mención y no la identifican («con mi», «with my», «mit der»).
    static let fillerWords: Set<String> = [
        "con", "la", "el", "mi", "mis", "de", "del", "en", "por", "a", "al", "y", "lo", "los", "las", "tu", "su",
        "with", "my", "the", "on", "in", "by", "via", "using", "paid", "pay",
        "mit", "der", "die", "das", "meiner", "meinem", "per", "uber",
        "avec", "ma", "mon", "le", "par",
        "com", "o", "meu", "minha", "no", "na", "pelo", "pela",
        "col", "il", "mia", "mio",
        "met", "mijn",
        "przez", "moja", "moim", "z",
    ]

    // MARK: - Mención

    /// La mención del medio de pago de UN movimiento leído de `sourceText` (lo que el usuario escribió o dijo).
    ///
    /// - Con el campo contestado por el modelo (`hintAnswered == true`) manda el modelo, que reparte la mención entre los
    ///   movimientos de una frase con varios; su palabra solo vale si está escrita en la frase.
    /// - Sin el campo (gateway que no lo conoce, lectura en el dispositivo) y con UN solo movimiento, se busca en la frase
    ///   una palabra del léxico, y solo si hay exactamente una distinta. Con varios movimientos no se reparte: no se sabe
    ///   a cuál va.
    static func mention(hint: String?, hintAnswered: Bool?, sourceText: String, batchCount: Int) -> String? {
        if hintAnswered == true {
            guard let hint = hint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty else { return nil }
            return appears(hint, in: sourceText) ? hint : nil
        }
        guard batchCount == 1 else { return nil }
        let lexicon = cashPhrases + creditCardPhrases + debitCardPhrases + cardPhrases + walletPhrases
        let found = Set(lexicon.filter { !ambiguousWithoutModel.contains($0) && appears($0, in: sourceText) }.map(fold))
        // «tarjeta de credito» contiene «tarjeta»: se queda la más larga de las que se solapan.
        let longest = found.filter { phrase in !found.contains { $0 != phrase && $0.contains(phrase) } }
        return longest.count == 1 ? longest.first : nil
    }

    /// `true` si `phrase` está escrita en `text`: palabra a palabra (sin tildes ni mayúsculas), o como texto si es de una
    /// escritura sin espacios. Las formas verbales de las billeteras peruanas cuentan («yapeé», «plineo»).
    static func appears(_ phrase: String, in text: String) -> Bool {
        let foldedPhrase = fold(phrase)
        guard !foldedPhrase.isEmpty else { return false }
        if containsUnspacedScript(foldedPhrase) { return fold(text).contains(foldedPhrase) }
        return isRun(tokens(foldedPhrase).map(canonicalWallet), in: tokens(fold(text)).map(canonicalWallet))
    }

    // MARK: - Cuenta

    /// La cuenta que nombra `mention`, o `nil` si no nombra ninguna o nombra más de una.
    ///
    /// 1. Por el NOMBRE de la cuenta: todas las palabras de la mención (sin las de relleno) están en el nombre
    ///    («yape» → «Yape BCP»), o el nombre entero está en la mención («con mi BCP Soles» → «BCP Soles»).
    ///    Dos cuentas que casan = ninguna: no se sigue a la clase, porque la persona nombró algo concreto.
    /// 2. Si ninguna cuenta se llama así, por la CLASE de medio de pago y el tipo de cuenta: efectivo → la única cuenta de
    ///    efectivo; crédito → la única tarjeta de crédito; débito → la única cuenta corriente o de ahorros; «tarjeta» → la
    ///    única entre las tres. Las cuentas «General» no entran: son la cuenta de todo, no un medio de pago.
    static func account(for mention: String?, among candidates: [Candidate]) -> UUID? {
        guard let mention else { return nil }
        let mentionText = fold(mention)
        guard !mentionText.isEmpty else { return nil }
        let mentionTokens = tokens(mentionText).map(canonicalWallet)
        let meaningful = mentionTokens.filter { !fillerWords.contains($0) }

        let byName = candidates.filter { candidate in
            let nameText = fold(candidate.name)
            guard !nameText.isEmpty else { return false }
            if containsUnspacedScript(nameText) || containsUnspacedScript(mentionText) {
                return mentionText.contains(nameText) || nameText.contains(mentionText)
            }
            let nameTokens = tokens(nameText).map(canonicalWallet)
            guard !nameTokens.isEmpty else { return false }
            if isRun(nameTokens, in: mentionTokens) { return true }
            return !meaningful.isEmpty && Set(meaningful).isSubset(of: Set(nameTokens))
        }
        if byName.count == 1 { return byName[0].id }
        if byName.count > 1 { return nil }

        guard let kind = kind(of: mention) else { return nil }
        let allowed: Set<AccountKind>
        switch kind {
        case .cash: allowed = [.cash]
        case .creditCard: allowed = [.creditCard]
        case .debitCard: allowed = [.bank]
        case .card: allowed = [.creditCard, .bank]
        }
        let byType = candidates.filter { allowed.contains($0.kind) }
        return byType.count == 1 ? byType[0].id : nil
    }

    /// La clase que dice la mención, de la más concreta a la más general (crédito y débito antes que «tarjeta»).
    static func kind(of mention: String) -> Kind? {
        if creditCardPhrases.contains(where: { appears($0, in: mention) }) { return .creditCard }
        if debitCardPhrases.contains(where: { appears($0, in: mention) }) { return .debitCard }
        if cashPhrases.contains(where: { appears($0, in: mention) }) { return .cash }
        if cardPhrases.contains(where: { appears($0, in: mention) }) { return .card }
        return nil
    }

    // MARK: - Texto

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Palabras: letras y cifras seguidas. «EC-Karte» son dos palabras, como «ec karte».
    static func tokens(_ folded: String) -> [String] {
        folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    /// «yapeé», «yapeo», «yapear» → «yape»; «plineé», «plinear» → «plin». Solo las dos billeteras que se conjugan.
    static func canonicalWallet(_ token: String) -> String {
        if token.hasPrefix("yape") { return "yape" }
        if token.hasPrefix("plinea") || token.hasPrefix("plinee") || token.hasPrefix("plineo") { return "plin" }
        return token
    }

    /// `needle` aparece seguida, en orden, dentro de `hay`.
    private static func isRun(_ needle: [String], in hay: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= hay.count else { return false }
        for start in 0...(hay.count - needle.count) where Array(hay[start..<start + needle.count]) == needle {
            return true
        }
        return false
    }

    /// Japonés y chino se escriben sin espacios: ahí se compara texto, no palabras.
    private static func containsUnspacedScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF: return true
            default: return false
            }
        }
    }
}
