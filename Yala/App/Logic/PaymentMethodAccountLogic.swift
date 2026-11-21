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
//  2. **La cuenta la decide primero Swift**, contra las cuentas del usuario, con la escalera común de todas las capturas
//     (`CuentaSolaAlLeer`, desde el 2026-11-20: últimos 4, nombre entero, palabras, clase, moneda).
//
//  **Qué sale del teléfono (decisión A + B de Jürgen, 2026-11-20, sustituye a «los nombres no salen»):** en la FOTO, con
//  la cuenta en la nube, la IA recibe además los nombres de las cuentas con su clase y su moneda, y devuelve la que cree
//  como segunda capa (`CuentaSolaAlLeer.combinar`). Nunca viajan saldos, números de cuenta ni últimos 4, ni reglas. En
//  iCloud privado no viaja nada nuevo: el permiso de foto solo promete la foto. El chat lo hará en la parte 2 del ticket
//  (`2026-11-20-captura-cuenta-automatica-y-reglas`); voz y Siri siguen sin mandar nombres.
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

    /// La cuenta que nombra `mention`, o `nil` si no nombra ninguna o nombra más de una. Es la escalera común
    /// (`CuentaSolaAlLeer.leer`) sin moneda ni últimos 4 guardados:
    ///
    /// 1. El nombre ENTERO de la cuenta escrito en la mención («con mi BCP Soles» → «BCP Soles»); con varios, el más largo
    ///    («Zip Visa» frente a «Zip»), y con dos igual de largos, ninguna.
    /// 2. Todas las palabras de la mención (sin las de relleno) están en el nombre («yape» → «Yape BCP»). Dos cuentas que
    ///    casan = ninguna: no se sigue a la clase, porque la persona nombró algo concreto.
    /// 3. Si ninguna cuenta se llama así, por la CLASE de medio de pago y el tipo de cuenta: efectivo → la única cuenta de
    ///    efectivo; crédito → la única tarjeta de crédito; débito → la única cuenta corriente o de ahorros; «tarjeta» → la
    ///    única entre las tres. Las cuentas «General» no entran: son la cuenta de todo, no un medio de pago.
    static func account(for mention: String?, among candidates: [Candidate]) -> UUID? {
        let accounts = candidates.map {
            CuentaSolaAlLeer.Cuenta(id: $0.id, name: $0.name, kind: $0.kind, currencyCode: "", accountNumber: nil)
        }
        if case .elegida(let id, _) = CuentaSolaAlLeer.leer(mention: mention, last4: nil, among: accounts) { return id }
        return nil
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
