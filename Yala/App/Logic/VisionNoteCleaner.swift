//
//  VisionNoteCleaner.swift
//  Yala
//
//  La nota de un movimiento leído de una foto o de un PDF: el comercio limpio y, si aporta, un dato de
//  dónde se gastó. Nunca la frase de plantilla del banco (ticket image-note-uses-bank-template-instead-of-merchant,
//  2026-10-10: «GROK XAI - Consumo con tarjeta de crédito BCP» tenía que ser «Grok (xAI)»).
//
//  El prompt de la foto ya pide `merchant` limpio y `note` vacía o útil. Esta limpieza es la segunda capa:
//  determinista, cubre lo que el modelo deje pasar y las respuestas de modelos viejos.
//
//  El banco de IA (`gateway/bench`) compila ESTE fichero tal cual para medir la nota final: si cambias la
//  firma de `note(merchant:note:)`, cambia también `gateway/bench/lib/noteCleaner.ts`. Solo Foundation.
//

import Foundation

nonisolated enum VisionNoteCleaner {

    /// La nota final: el comercio limpio y, si queda algo útil que no repita al comercio, la nota del modelo
    /// limpia detrás de « - ». Si la limpieza no deja nada, se queda el texto original sin códigos: perder todo
    /// lo leído es peor que una nota con palabras de más.
    static func note(merchant: String?, note: String?) -> String {
        let cleanMerchant = merchant.map(clean) ?? ""
        let cleanDetail = note.map(clean) ?? ""

        var parts: [String] = []
        for part in [cleanMerchant, cleanDetail] where !part.isEmpty {
            let key = fold(part)
            if parts.contains(where: { fold($0).contains(key) }) { continue }
            parts.removeAll { key.contains(fold($0)) }
            parts.append(part)
        }
        if !parts.isEmpty { return parts.joined(separator: " - ") }

        // Todo era plantilla: se conserva lo leído tal cual, solo sin códigos.
        return [merchant, note]
            .compactMap { $0 }
            .map { tokens(of: $0).filter { !isCode($0) }.map { $0.hasSuffix(":") ? String($0.dropLast()) : $0 }.joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }

    /// Limpia un texto (el comercio o la nota): parte por separadores, tira los trozos que son pura
    /// plantilla, recorta la plantilla de los bordes, quita códigos y normaliza las mayúsculas.
    static func clean(_ raw: String) -> String {
        var kept: [String] = []
        for segment in segments(of: raw) {
            if let brand = knownBrand(in: segment) {
                kept.append(brand)
                continue
            }
            var words = tokens(of: segment).filter { !isCode($0) }
            words = dropDescriptorPrefix(words)
            words = trimTemplateEdges(words)
            if words.allSatisfy(isNoise) { continue }
            words = dropTrailingCountryCode(words)
            kept.append(output(words))
        }
        // Sin repetir trozos (el modelo a veces escribe el comercio dos veces).
        var seen = Set<String>()
        return kept.filter { seen.insert(fold($0)).inserted }.joined(separator: " - ")
    }

    // MARK: - Trozos y palabras

    /// Separadores que usan las plantillas y los modelos para pegar comercio y descripción.
    private static let separators = [" - ", " – ", " — ", "|", " · ", "•", "\n", ";", " / "]

    private static func segments(of text: String) -> [String] {
        var parts = [text]
        for separator in separators {
            parts = parts.flatMap { $0.components(separatedBy: separator) }
        }
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Las palabras del trozo. El asterisco de los descriptores de tarjeta («UBER *TRIP», «****1234») separa. Los
    /// dos puntos se quedan hasta la salida: marcan un rótulo («Comercio:»).
    private static func tokens(of segment: String) -> [String] {
        segment
            .replacingOccurrences(of: "*", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",;#[]")) }
            .filter { !$0.isEmpty }
    }

    /// El trozo como se escribe: mayúsculas normales, sin los dos puntos de los rótulos y sin el punto final de
    /// una frase (el de una inicial o una abreviatura corta, «Laura M.» o «S.A.», se queda).
    private static func output(_ words: [String]) -> String {
        var text = casing(words.map { $0.hasSuffix(":") ? String($0.dropLast()) : $0 }).joined(separator: " ")
        if text.hasSuffix("."), let last = words.last, fold(last).count > 2 { text.removeLast() }
        return text
    }

    /// Minúsculas, sin tildes y solo letras y dígitos: la clave con la que se comparan las palabras.
    static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return String(String.UnicodeScalarView(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    // MARK: - Qué es plantilla

    /// Plantilla FUERTE de banco y billetera (ES, EN y PT): dice «esto es una alerta», nunca dónde se gastó. Una
    /// racha de borde que la lleve se recorta entera, y un trozo hecho solo de plantilla y relleno se tira.
    private static let strongWords: Set<String> = [
        // Movimiento
        "consumo", "consumos", "compra", "compras", "pago", "pagos", "pagaste", "operacion", "operaciones",
        "transaccion", "transacciones", "purchase", "purchases", "payment", "payments", "paid", "transaction",
        "transactions", "charge",
        // Medio de pago y rieles
        "tarjeta", "tarj", "tc", "td", "credito", "debito", "visa", "mastercard", "amex", "card", "credit", "debit",
        "pos", "contactless", "cartao", "ach", "zelle", "bizum", "pix",
        // Verbos y estado de la alerta
        "realizaste", "realizada", "realizado", "hiciste", "exitosa", "exitoso", "aprobada", "aprobado", "aprovada",
        "aprovado", "approved", "successful", "yapeaste", "yapeo", "yapearon", "plineaste", "plin", "yape",
        "enviaste", "enviado", "enviada", "recibiste", "recibido", "recibida", "received", "sent", "alerta",
        "notificacion", "constancia", "comprobante", "voucher", "aviso", "alert",
        // Rótulos de códigos
        "nro", "numero", "num", "op", "ref", "referencia", "codigo", "cod", "terminal", "term", "autorizacion", "auth",
        // Divisa
        "s", "usd", "pen", "us",
        // Bancos (el banco nunca es el comercio: ya es la cuenta)
        "bcp", "interbank", "ibk", "bbva", "scotiabank", "scotia", "banbif", "pichincha", "banco", "bank",
    ]

    /// Plantilla DÉBIL: palabras que en un extracto también describen el movimiento («Internal Transfer», «Retiro
    /// cajero», «Comercio Local»). Solo se recortan si la racha acaba en preposición junto al nombre
    /// («Transferencia a PEDRO G.» → «Pedro G.»).
    private static let weakWords: Set<String> = [
        "transferencia", "transferiste", "transfer", "online", "internet", "retiro", "abono", "cargo", "movimiento",
        "comercio", "establecimiento", "merchant", "concepto", "descripcion", "description", "detalle", "lugar",
    ]

    /// Relleno: no se recorta solo, pero un trozo hecho de relleno y plantilla se tira entero.
    private static let fillerWords: Set<String> = Set([
        "con", "de", "del", "en", "a", "al", "por", "para", "tu", "su", "una", "un", "y", "has", "you", "your", "made",
        "with", "by", "at", "to", "on", "of", "for", "an", "and", "from", "app", "web", "digital", "movil", "sin",
        "contacto", "banca", "cuenta", "ahorros", "ahorro", "savings", "checking", "soles", "dolares", "dollars",
        "continental", "no", "na", "do", "da", "final", "ending", "terminada", "termina", "thank", "gracias",
    ]).union(articles)

    /// Los artículos van en la racha de borde solo si les sigue más plantilla: «COMPRA EL CORTE INGLES» conserva el «El».
    private static let articles: Set<String> = ["la", "el", "los", "las", "the"]

    /// Preposiciones que, al final de una racha de borde, dicen «aquí empieza el nombre».
    private static let prepositions: Set<String> = ["a", "al", "en", "de", "del", "con", "por", "para", "at", "to", "from", "with", "by", "on", "for", "no", "na"]

    /// Plantilla fuerte, o un rótulo cualquiera («Comercio:»).
    private static func isStrong(_ word: String) -> Bool { strongWords.contains(fold(word)) || (word.hasSuffix(":") && word.count > 1) }

    private static func isNumber(_ word: String) -> Bool {
        let key = fold(word)
        return !key.isEmpty && key.allSatisfy(\.isNumber)
    }

    private static func isNoise(_ word: String) -> Bool {
        let key = fold(word)
        return key.isEmpty || strongWords.contains(key) || weakWords.contains(key) || fillerWords.contains(key) || isNumber(word)
    }

    /// Números de operación, tarjetas enmascaradas, montos, fechas y referencias: 4 o más dígitos, o una
    /// referencia alfanumérica larga («2K4X91LQ»). «7-Eleven» o «Mall 2» se quedan.
    private static func isCode(_ word: String) -> Bool {
        let key = fold(word)
        let digits = key.filter(\.isNumber).count
        if digits >= 4 { return true }
        if key.count >= 6, digits >= 2, key.contains(where: \.isLetter) { return true }
        return false
    }

    /// Recorta de cada borde la racha de plantilla, relleno y números: «Compra con tu tarjeta en WONG» → «WONG». La
    /// racha se recorta si trae plantilla fuerte, o débil terminada en preposición; «La Lucha» o «Internal
    /// Transfer» se quedan como están.
    private static func trimTemplateEdges(_ words: [String]) -> [String] {
        var result = words
        let leading = edgeRun(Array(result.prefix(while: isNoise)))
        if shouldTrim(leading) { result.removeFirst(leading.count) }
        let trailing = edgeRun(Array(result.reversed().prefix(while: isNoise)))
        if shouldTrim(trailing) { result.removeLast(trailing.count) }
        // Lo que queda tiene que parecer un nombre: «Pago a tercero» no se queda en «tercero». Si todo lo que queda
        // va en minúscula, era una descripción y se deja entera.
        let isName = result.contains { word in word.first.map { $0.isUppercase || $0.isNumber } ?? false }
        return isName || result.isEmpty ? result : words
    }

    /// La racha, ordenada desde el borde hacia el nombre, sin los artículos que tocan al nombre.
    private static func edgeRun(_ run: [String]) -> [String] {
        var run = run
        while let inner = run.last, articles.contains(fold(inner)) {
            run.removeLast()
        }
        return run
    }

    private static func shouldTrim(_ run: [String]) -> Bool {
        guard !run.isEmpty else { return false }
        if run.contains(where: isStrong) { return true }
        let hasWeak = run.contains { weakWords.contains(fold($0)) }
        return hasWeak && run.last.map { prepositions.contains(fold($0)) } == true
    }

    /// Prefijos de pasarela de los descriptores de tarjeta: «SQ *», «TST*», «DLO*», «MP*»…
    private static let descriptorPrefixes: Set<String> = ["sq", "tst", "sp", "py", "dlo", "dl", "mp", "iz", "wpy", "pp"]

    private static func dropDescriptorPrefix(_ words: [String]) -> [String] {
        guard words.count > 1, let first = words.first, descriptorPrefixes.contains(fold(first)) else { return words }
        return Array(words.dropFirst())
    }

    /// El país de dos letras con que acaban los descriptores («… LIMA PE»). Solo en mayúsculas.
    private static let countryCodes: Set<String> = ["PE", "US", "ES", "MX", "CO", "CL", "AR", "BR", "EC", "BO", "GB", "IE", "NL", "DE", "FR"]

    private static func dropTrailingCountryCode(_ words: [String]) -> [String] {
        guard words.count > 1, let last = words.last, countryCodes.contains(last) else { return words }
        return Array(words.dropLast())
    }

    // MARK: - Marcas conocidas

    /// Servicios que se cobran con un descriptor de tarjeta ilegible: se escriben con su nombre conocido. El
    /// orden importa (Uber Eats antes que Uber; PayPal el último, porque «PAYPAL *NETFLIX» es Netflix).
    private static let brands: [(keys: [[String]], name: String)] = [
        ([["grok"], ["xai"], ["x", "ai"]], "Grok (xAI)"),
        ([["chatgpt"], ["openai"]], "ChatGPT (OpenAI)"),
        ([["anthropic"], ["claudeai"], ["claude", "ai"]], "Claude (Anthropic)"),
        ([["netflix"], ["netflixcom"]], "Netflix"),
        ([["mcdonalds"], ["mcdonald"], ["mc", "donalds"], ["mc", "donald"]], "McDonald's"),
        ([["spotify"]], "Spotify"),
        ([["youtube"], ["youtubepremium"]], "YouTube"),
        ([["disneyplus"], ["disney"]], "Disney+"),
        ([["ubereats"], ["uber", "eats"]], "Uber Eats"),
        ([["uber"], ["ubercom"]], "Uber"),
        ([["rappi"]], "Rappi"),
        ([["pedidosya"]], "PedidosYa"),
        ([["cabify"]], "Cabify"),
        ([["didi"]], "DiDi"),
        ([["airbnb"]], "Airbnb"),
        ([["amzn"], ["amazon"]], "Amazon"),
        ([["applecom"], ["itunes"], ["apple", "com"]], "Apple"),
        ([["google"]], "Google"),
        ([["microsoft"], ["msft"]], "Microsoft"),
        ([["github"]], "GitHub"),
        ([["paypal"]], "PayPal"),
    ]

    /// La marca conocida del trozo, si la hay. Cada palabra cuenta entera y, además, partida por puntos,
    /// barras y guiones («HELP.UBER.COM» → uber, com).
    private static func knownBrand(in segment: String) -> String? {
        let words = tokens(of: segment).flatMap { word -> [String] in
            let pieces = word.split(whereSeparator: { $0 == "." || $0 == "/" || $0 == "-" }).map { fold(String($0)) }
            return pieces.count > 1 ? pieces : [fold(word)]
        }
        let glued = tokens(of: segment).map(fold)
        for brand in brands {
            for key in brand.keys where contains(words, sequence: key) || contains(glued, sequence: key) {
                return brand.name
            }
        }
        return nil
    }

    private static func contains(_ words: [String], sequence: [String]) -> Bool {
        guard !sequence.isEmpty, words.count >= sequence.count else { return false }
        for start in 0...(words.count - sequence.count) where Array(words[start..<start + sequence.count]) == sequence {
            return true
        }
        return false
    }

    // MARK: - Mayúsculas

    /// Siglas con vocal que se quedan en mayúsculas (las cortas sin vocal, «KFC» o «CVS», ya se quedan solas).
    private static let acronyms: Set<String> = ["sa", "sac", "sl", "srl", "llc", "inc", "ltd", "eirl", "usa", "atm", "ach", "itf", "ibm", "ups", "ikea", "bbva", "bcp", "ibk"]

    /// Lo que se queda en minúscula detrás de la primera palabra.
    private static let lowerConnectors: Set<String> = ["de", "del", "y", "e", "of", "and"]

    /// Un texto TODO EN MAYÚSCULAS («GROK XAI», «WONG SAN ISIDRO») se escribe con mayúsculas normales; las
    /// siglas cortas («KFC») se quedan. Un texto que ya trae minúsculas no se toca.
    private static func casing(_ words: [String]) -> [String] {
        let joined = words.joined()
        guard joined.contains(where: \.isLetter), !joined.contains(where: \.isLowercase) else { return words }
        return words.enumerated().map { index, word in
            let key = fold(word)
            if index > 0, lowerConnectors.contains(key) { return word.lowercased() }
            if acronyms.contains(key) { return word }
            if key.count <= 3, key.contains(where: \.isLetter), !key.contains(where: { "aeiou".contains($0) }) { return word }
            return capitalized(word)
        }
    }

    /// Primera letra en mayúscula, y la de después de un guion («7-ELEVEN» → «7-Eleven»); el resto en minúscula.
    private static func capitalized(_ word: String) -> String {
        var result = ""
        var upperNext = true
        for character in word.lowercased() {
            if character.isLetter {
                result += upperNext ? character.uppercased() : String(character)
                upperNext = false
            } else {
                result.append(character)
                if character == "-" { upperNext = true }
            }
        }
        return result
    }
}
