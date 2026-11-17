//
//  ChatGuidedIntentDetector.swift
//  Yala
//
//  ¿La frase pide crear algo que Yala IA sabe guiar? Y si es así, ¿qué dice ya? Se decide en el teléfono, antes del
//  clasificador (`ChatIntentClassifierService.guidedFlow(for:)`): no sale nada nuevo del teléfono, funciona igual con los
//  datos en iCloud y en la cuenta de Yala, no gasta la cuota de preguntas y responde al instante.
//
//  Reglas, de más fuerte a más débil:
//  - una pregunta («¿cuánto gasté en comida?», «cómo voy con mis presupuestos») nunca abre un guiado;
//  - un presupuesto: la palabra («presupuesto», «budget», «orçamento»…) con algo que la pida (un verbo de crear o
//    querer, o una cifra), o «ahorrar en…» / «gastar menos en…»;
//  - un pago planificado: «pago fijo / recurrente / mensual», «suscripción», «recuérdame pagar…», «pago X cada mes»;
//  - una cuenta, una categoría o un favorito: el verbo de crear y la cosa juntos (`ChatGuidedCreateDetector`).
//
//  Lo que dice la frase rellena las respuestas: monto, moneda nombrada, período o frecuencia, día del mes, categorías
//  (por su nombre, el de sus subcategorías o las palabras del día a día del buscador) y el nombre del pago.
//

import Foundation
import SwiftData

/// Lo que el detector necesita saber de la persona. Se arma con `ChatGuidedDataSource.catalog(...)`.
struct ChatGuidedCatalog {
    struct CategoryEntry {
        let id: PersistentIdentifier
        /// El nombre de la categoría, los de sus subcategorías y sus palabras del día a día, ya plegados.
        let words: [String]
        /// El nombre de la categoría sola, plegado: nombrarla cuenta todas sus subcategorías.
        var nameWords: [String] = []
        var subcategories: [SubcategoryEntry] = []
    }

    struct SubcategoryEntry {
        let id: PersistentIdentifier
        /// `Subcategory.shortcutID`: lo que guarda el presupuesto.
        let shortcutID: UUID
        /// Su nombre y sus palabras del día a día, ya plegados.
        let words: [String]
        /// Su nombre solo, plegado. El presupuesto solo deja una subcategoría sola si la frase la nombra así: las
        /// palabras del día a día son anchas («comida» es de Restaurantes, y «para comida» es toda la comida).
        var name: String = ""
    }

    var categories: [CategoryEntry] = []
    /// La moneda principal.
    var mainCurrency: String
    /// Las monedas de las cuentas activas, sin repetir. Con una sola, la moneda del presupuesto no se pregunta.
    var accountCurrencies: [String] = []
    /// Tus grupos con sus personas: el gasto de grupo se reconoce por sus nombres.
    var groups: [ChatGuidedGroupOption] = []
}

/// Lo detectado: qué guiado y qué ya se sabe.
struct ChatGuidedDetection: Equatable {
    let kind: ChatGuidedKind
    var answers: ChatGuidedAnswers
    var prefilled: Set<ChatGuidedField>
}

enum ChatGuidedIntentDetector {

    // MARK: - ¿Qué guiado?

    static func kind(of text: String) -> ChatGuidedKind? {
        let folded = normalized(text)
        guard !folded.isEmpty, !isQuestion(folded), !matchesAny(folded, viewingPatterns) else { return nil }
        let asksForIt = matchesAny(folded, creationVerbPatterns) || folded.rangeOfCharacter(from: .decimalDigits) != nil
        // «Presupuesto» dicho con todas las letras gana: «un presupuesto para mis suscripciones» es un presupuesto.
        if matchesAny(folded, budgetNounPatterns) { return asksForIt ? .budget : nil }
        // Crear una cuenta, una categoría o un favorito: el verbo y la cosa juntos (`ChatGuidedCreateDetector`).
        if let create = createKind(folded) { return create }
        // Grupos: crear uno, una deuda de antes o un gasto de grupo dicho con todas las letras (`ChatGuidedGroupDetector`).
        if let group = groupKind(folded) { return group }
        if matchesAny(folded, paymentRequestPatterns) { return .scheduledPayment }
        if matchesAny(folded, scheduledPaymentPatterns), asksForIt { return .scheduledPayment }
        if matchesAny(folded, budgetSavingPatterns) { return .budget }
        return nil
    }

    /// El guiado con lo que la frase ya dice, o `nil` si no pide ninguno. Un gasto de grupo que solo se reconoce por
    /// las personas nombradas («pagué 120 de la cena con Ana y Luis») necesita el catálogo: entra aquí y no en `kind(of:)`.
    static func detect(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection? {
        guard let kind = kind(of: text) ?? (groupExpenseByPeople(text, catalog: catalog) ? .groupExpense : nil) else {
            return nil
        }
        switch kind {
        case .budget: return budget(text, catalog: catalog)
        case .scheduledPayment: return scheduledPayment(text, catalog: catalog)
        case .account: return account(text, catalog: catalog)
        case .category: return category(text, catalog: catalog)
        case .favorite: return favorite(text, catalog: catalog)
        case .group: return group(text, catalog: catalog)
        case .groupOpeningBalance: return openingBalance(text, catalog: catalog)
        case .groupExpense: return groupExpense(text, catalog: catalog)
        }
    }

    // MARK: - Presupuesto

    static func budget(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection {
        let folded = normalized(text)
        var answers = ChatGuidedAnswers()
        var prefilled: Set<ChatGuidedField> = []

        let categories = matchedCategories(folded, catalog: catalog)
        if !categories.isEmpty {
            answers.allExpenses = false
            answers.categoryIDs = categories
            prefilled.insert(.categories)
            // «taxi» nombra una subcategoría de Transporte: solo esa cuenta, y no se vuelve a preguntar.
            if let removed = removedSubcategories(folded, categoryIDs: categories, catalog: catalog) {
                answers.removedSubcategoryIDs = removed
                prefilled.insert(.subcategories)
            }
        } else if matchesAny(folded, allExpensesPatterns) {
            answers.allExpenses = true
            prefilled.insert(.categories)
        }
        if matchesAny(folded, oncePatterns) {
            answers.period = .once
            prefilled.insert(.period)
        } else if let period = period(folded) {
            answers.period = period
            prefilled.insert(.period)
        }
        if let amount = amount(in: folded) {
            answers.amount = amount
            prefilled.insert(.amount)
        }
        if let currency = currency(folded, mainCurrency: catalog.mainCurrency) {
            answers.currencyCode = currency
            prefilled.insert(.currency)
        } else if Set(catalog.accountCurrencies + [catalog.mainCurrency]).count <= 1 {
            // Con una sola moneda no hay nada que preguntar.
            answers.currencyCode = catalog.mainCurrency
        }
        return ChatGuidedDetection(kind: .budget, answers: answers, prefilled: prefilled)
    }

    // MARK: - Pago planificado

    static func scheduledPayment(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection {
        var folded = normalized(text)
        var answers = ChatGuidedAnswers()
        var prefilled: Set<ChatGuidedField> = []

        // «cada 2 semanas», «cada 15 días»: frecuencia y cada cuántos. Se quita antes de buscar el día y el monto.
        if let every = interval(folded) {
            answers.frequency = every.frequency
            answers.interval = every.value
            prefilled.insert(.frequency)
            folded = folded.replacingOccurrences(of: every.matched, with: " ")
        }
        let day = monthDay(folded)
        if answers.frequency != nil {
            // Ya la dijo con «cada N».
        } else if let frequency = frequency(folded) {
            answers.frequency = frequency
            prefilled.insert(.frequency)
        } else if day != nil {
            // «el 5 de cada mes» ya lo dice; «el día 5» a secas, también es mensual.
            answers.frequency = .monthly
            prefilled.insert(.frequency)
        }
        if let day, answers.frequency == .monthly {
            answers.dayOfMonth = day.value
            prefilled.insert(.day)
        }
        let withoutDay = day.map { folded.replacingOccurrences(of: $0.matched, with: " ") } ?? folded
        if let amount = amount(in: withoutDay) {
            answers.amount = amount
            prefilled.insert(.amount)
        }
        if let currency = currency(folded, mainCurrency: catalog.mainCurrency) {
            answers.currencyCode = currency
            prefilled.insert(.currency)
        }
        if let name = paymentName(text) {
            answers.paymentName = name
            prefilled.insert(.name)
            if let brand = SubscriptionBrandCatalog.match(name: name) {
                answers.isSubscription = true
                answers.paymentName = brand.name
            }
        }
        if matchesAny(folded, subscriptionWordPatterns) { answers.isSubscription = true }
        // «la luz», «el alquiler»: la subcategoría, si la frase nombra exactamente una.
        let named = matchedSubcategories(folded, catalog: catalog)
        if named.count == 1, let only = named.first {
            answers.subcategoryID = only.id
            prefilled.insert(.subcategories)
        }
        return ChatGuidedDetection(kind: .scheduledPayment, answers: answers, prefilled: prefilled)
    }

    // MARK: - Las piezas (todas sobre el texto plegado: minúsculas y sin tildes)

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Plegado y con los números dichos con palabras en cifras («trescientos» → «300»): lo que leen las reglas.
    static func normalized(_ text: String) -> String {
        ChatGuidedNumberWords.replacingNumberWords(in: fold(text))
    }

    /// Una pregunta sobre lo que ya hay, no un pedido. «¿Me ayudas a crear un presupuesto?» sí es un pedido.
    static func isQuestion(_ folded: String) -> Bool {
        let opening = folded.trimmingCharacters(in: CharacterSet(charactersIn: "¿¡ "))
        if matchesAny(opening, statusQuestionPatterns) { return true }
        let asks = folded.hasPrefix("¿") || folded.hasSuffix("?") || folded.hasSuffix("？")
        return asks && !matchesAny(folded, creationVerbPatterns)
    }

    /// Las categorías nombradas, en el orden en que aparecen. Una palabra cuenta entera («pan» no casa con «pantalón»).
    static func matchedCategories(_ folded: String, catalog: ChatGuidedCatalog) -> [PersistentIdentifier] {
        var found: [(position: String.Index, id: PersistentIdentifier)] = []
        for entry in catalog.categories {
            let positions = entry.words.compactMap { word -> String.Index? in
                guard word.count >= 3 else { return nil }
                return wholeWordRange(of: word, in: folded)?.lowerBound
            }
            if let first = positions.min() { found.append((first, entry.id)) }
        }
        return found.sorted { $0.position < $1.position }.map(\.id)
    }

    /// Lo que se quita de las categorías nombradas cuando la frase nombra subcategorías sueltas por su nombre y no la
    /// categoría: «mercado» deja solo Mercado de Alimentación. `nil` si no nombra ninguna (se pregunta).
    static func removedSubcategories(_ folded: String, categoryIDs: [PersistentIdentifier],
                                     catalog: ChatGuidedCatalog) -> [UUID]? {
        var removed: [UUID] = []
        var namedAny = false
        for id in categoryIDs {
            guard let entry = catalog.categories.first(where: { $0.id == id }), !entry.subcategories.isEmpty else {
                return nil
            }
            let namesCategory = entry.nameWords.contains { $0.count >= 3 && wholeWordRange(of: $0, in: folded) != nil }
            if namesCategory { continue }
            let named = entry.subcategories.filter { subcategory in
                subcategory.name.count >= 3 && wholeWordRange(of: subcategory.name, in: folded) != nil
            }
            // Llegó por una palabra del día a día, sin nombrar una subcategoría: se pregunta con todas marcadas.
            guard !named.isEmpty else { return nil }
            namedAny = true
            let keep = Set(named.map(\.shortcutID))
            removed += entry.subcategories.map(\.shortcutID).filter { !keep.contains($0) }
        }
        return namedAny ? removed : nil
    }

    /// Las subcategorías que la frase nombra por su nombre o sus palabras del día a día.
    static func matchedSubcategories(_ folded: String, catalog: ChatGuidedCatalog) -> [ChatGuidedCatalog.SubcategoryEntry] {
        var found: [ChatGuidedCatalog.SubcategoryEntry] = []
        for entry in catalog.categories {
            for subcategory in entry.subcategories
            where subcategory.words.contains(where: { $0.count >= 3 && wholeWordRange(of: $0, in: folded) != nil }) {
                if !found.contains(where: { $0.id == subcategory.id }) { found.append(subcategory) }
            }
        }
        return found
    }

    /// «cada 2 semanas», «cada 15 dias», «every 3 months», «a cada 2 semanas», «every other week», «quincenal».
    static func interval(_ folded: String) -> (frequency: ChatGuidedFrequency, value: Int, matched: String)? {
        let units: [(pattern: String, frequency: ChatGuidedFrequency)] = [
            (#"(?:dias|days|dia|day)"#, .daily),
            (#"(?:semanas|weeks|semana|week)"#, .weekly),
            (#"(?:meses|months|mes|month|mois|monate|mesi|maanden)"#, .monthly),
        ]
        for unit in units {
            let pattern = #"\b(?:cada|every|a\s+cada|toutes\s+les|alle|ogni|elke|co)\s+(\d{1,3})\s+"# + unit.pattern + #"\b"#
            guard let regex = compiled(pattern) else { continue }
            let range = NSRange(folded.startIndex..., in: folded)
            guard let match = regex.firstMatch(in: folded, range: range),
                  let numberRange = Range(match.range(at: 1), in: folded),
                  let whole = Range(match.range, in: folded),
                  let value = Int(folded[numberRange]), (1...365).contains(value) else { continue }
            return (unit.frequency, value, String(folded[whole]))
        }
        let biweekly = [#"\b(quincenal(?:es|mente)?|cada\s+otra\s+semana|every\s+other\s+week|biweekly|bi-weekly|fortnightly|quinzenal)\b"#]
        for pattern in biweekly {
            guard let regex = compiled(pattern) else { continue }
            let range = NSRange(folded.startIndex..., in: folded)
            if let match = regex.firstMatch(in: folded, range: range), let whole = Range(match.range, in: folded) {
                return (.weekly, 2, String(folded[whole]))
            }
        }
        return nil
    }

    static func period(_ folded: String) -> ChatGuidedPeriod? {
        if matchesAny(folded, weeklyPatterns) { return .weekly }
        if matchesAny(folded, yearlyPatterns) { return .yearly }
        if matchesAny(folded, monthlyPatterns) { return .monthly }
        return nil
    }

    static func frequency(_ folded: String) -> ChatGuidedFrequency? {
        if matchesAny(folded, oncePatterns) { return .once }
        if matchesAny(folded, dailyPatterns) { return .daily }
        return period(folded).map {
            switch $0 {
            case .monthly: .monthly
            case .weekly: .weekly
            case .yearly: .yearly
            case .once: .once
            }
        }
    }

    /// «el 5 de cada mes», «el día 15», «cada 30», «on the 5th». El texto casado se quita antes de buscar el monto.
    static func monthDay(_ folded: String) -> (value: Int, matched: String)? {
        let patterns = [
            #"\b(?:el\s+)?dia\s+(\d{1,2})\b"#,
            #"\bel\s+(\d{1,2})\s+de\s+cada\s+mes\b"#,
            #"\b(?:todos\s+los|cada)\s+(\d{1,2})\b(?!\s*(?:soles|dolares|euros|pesos|%|s/|usd|eur|\.|,\d|dias|semanas|meses|anos))"#,
            #"\bel\s+(\d{1,2})\b(?=\s*(?:$|de\s+cada|del\s+mes|,|\.|y\b))"#,
            #"\bon\s+the\s+(\d{1,2})(?:st|nd|rd|th)?\b"#,
            #"\bevery\s+(\d{1,2})(?:st|nd|rd|th)\b"#,
            #"\b(?:no\s+)?dia\s+(\d{1,2})\b"#,
            #"\ble\s+(\d{1,2})\s+(?:de\s+chaque|du)\s+mois\b"#,
            #"\bam\s+(\d{1,2})\.(?=\s)"#,
        ]
        for pattern in patterns {
            guard let regex = compiled(pattern) else { continue }
            let range = NSRange(folded.startIndex..., in: folded)
            guard let match = regex.firstMatch(in: folded, range: range),
                  let numberRange = Range(match.range(at: 1), in: folded),
                  let whole = Range(match.range, in: folded),
                  let value = Int(folded[numberRange]), isValidMonthDay(value) else { continue }
            return (value, String(folded[whole]))
        }
        return nil
    }

    /// El monto: el número que lleva moneda al lado; si ninguno la lleva, el mayor. Entiende «1,200.50», «1.200,50»,
    /// «300», «2k» y «2 mil».
    static func amount(in folded: String) -> Double? {
        let pattern = #"(s/|r\$|\$|€|£|usd|pen|eur)?\s*(\d+(?:[.,]\d+)*)\s*(k\b|mil\b|lucas\b)?\s*(soles|sol\b|dolares|dollars|bucks|usd|euros?|eur|pesos|reales|reais|pen|s/|libras|pounds)?"#
        guard let regex = compiled(pattern) else { return nil }
        let range = NSRange(folded.startIndex..., in: folded)
        var withCurrency: [Double] = []
        var plain: [Double] = []
        for match in regex.matches(in: folded, range: range) {
            guard let numberRange = Range(match.range(at: 2), in: folded),
                  var value = number(String(folded[numberRange])) else { continue }
            // «2 semanas», «15 dias», «3 veces»: una cantidad de tiempo, no el monto.
            if let whole = Range(match.range, in: folded), isFollowedByTimeUnit(folded[whole.upperBound...]) { continue }
            if match.range(at: 3).location != NSNotFound { value *= 1000 }
            let hasCurrency = match.range(at: 1).location != NSNotFound || match.range(at: 4).location != NSNotFound
            if hasCurrency { withCurrency.append(value) } else { plain.append(value) }
        }
        let value = withCurrency.first ?? plain.max()
        guard let value, ChatGuidedEngine.isValidAmount(value) else { return nil }
        return value
    }

    private static func isFollowedByTimeUnit(_ rest: Substring) -> Bool {
        let pattern = #"^\s*(dias?|semanas?|meses|mes|anos?|veces|days?|weeks?|months?|years?|times|semaines?|mois|wochen|tage|monate|giorni|settimane|mesi|vezes)\b"#
        return String(rest).range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// «1,200.50» → 1200.5 · «1.200,50» → 1200.5 · «1,200» → 1200 · «12,5» → 12.5.
    static func number(_ raw: String) -> Double? {
        let lastComma = raw.lastIndex(of: ",")
        let lastDot = raw.lastIndex(of: ".")
        var normalized = raw
        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            let decimal: Character = comma > dot ? "," : "."
            let thousands: Character = decimal == "," ? "." : ","
            normalized = raw.replacingOccurrences(of: String(thousands), with: "")
                .replacingOccurrences(of: String(decimal), with: ".")
        case let (separatorIndex?, nil), let (nil, separatorIndex?):
            let separator = raw[separatorIndex]
            let decimals = raw.distance(from: raw.index(after: separatorIndex), to: raw.endIndex)
            let count = raw.filter { $0 == separator }.count
            if count == 1, decimals != 3 {
                normalized = raw.replacingOccurrences(of: String(separator), with: ".")
            } else {
                normalized = raw.replacingOccurrences(of: String(separator), with: "")
            }
        case (nil, nil):
            break
        }
        return Double(normalized)
    }

    /// La moneda que la frase nombra. El «$» a secas no decide (lo usan muchas monedas): queda la que toque.
    static func currency(_ folded: String, mainCurrency: String) -> String? {
        let table: [(pattern: String, code: String)] = [
            (#"(s/|\bsoles?\b|\bpen\b)"#, "PEN"),
            (#"(\bdolares?\b|\bdollars?\b|\busd\b|\bbucks\b|us\$)"#, "USD"),
            (#"(€|\beuros?\b|\beur\b)"#, "EUR"),
            (#"(r\$|\breales\b|\breais\b|\bbrl\b)"#, "BRL"),
            (#"(£|\blibras\b|\bpounds?\b|\bgbp\b)"#, "GBP"),
            (#"(\bzl\b|\bzlotys?\b|\bpln\b)"#, "PLN"),
        ]
        for entry in table where matchesAny(folded, [entry.pattern]) {
            return entry.code
        }
        if matchesAny(folded, [#"\bpesos?\b"#]),
           ["MXN", "ARS", "COP", "CLP", "UYU", "DOP", "PHP"].contains(mainCurrency.uppercased()) {
            return mainCurrency.uppercased()
        }
        return nil
    }

    /// El nombre del pago: un servicio conocido («Netflix»), o lo que sigue a «pagar» / «pago de» / «suscripción a»,
    /// sin artículos, hasta una cifra o una palabra de tiempo. Con la mayúscula de la frase.
    static func paymentName(_ text: String) -> String? {
        for brand in SubscriptionBrandCatalog.all {
            for candidate in [brand.name] + brand.aliases {
                let normalized = SubscriptionBrandCatalog.normalize(candidate)
                if normalized.count >= 3, wholeWordRange(of: normalized, in: SubscriptionBrandCatalog.normalize(text)) != nil {
                    return brand.name
                }
            }
        }
        let original = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let tokens = original.map { fold($0).trimmingCharacters(in: .punctuationCharacters) }
        guard let anchor = tokens.firstIndex(where: { nameAnchors.contains($0) }) else { return nil }
        var index = anchor + 1
        var picked: [String] = []
        while index < tokens.count, picked.count < 3 {
            let token = tokens[index]
            if token.isEmpty || token.rangeOfCharacter(from: .decimalDigits) != nil || nameStops.contains(token)
                || ChatGuidedNumberWords.isNumberWord(token)
                || token.hasPrefix("s/") || token.hasPrefix("$") {
                if picked.isEmpty, nameSkips.contains(token) {
                    index += 1
                    continue
                }
                break
            }
            if picked.isEmpty, nameSkips.contains(token) {
                index += 1
                continue
            }
            picked.append(original[index].trimmingCharacters(in: .punctuationCharacters))
            index += 1
        }
        guard !picked.isEmpty else { return nil }
        let name = picked.joined(separator: " ")
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    // MARK: - Patrones

    private static let creationVerbPatterns = [
        #"\b(crea|crear|creame|hace|hacer|haz|hazme|arma|armar|armame|pon|poner|ponme|configura|configurar|quiero|quisiera|necesito|ayuda|ayudame|ayudarme|nuevo|nueva|agrega|agregar|anade|anadir|registra|registrar|establece|establecer|define|definir|fijar|fija)\b"#,
        #"\b(create|make|set\s+up|setup|start|add|new|want|need|help\s+me|i'?d\s+like|build|plan)\b"#,
        #"\b(criar|cria|crie|fazer|faca|quero|preciso|novo|nova|adicionar|adiciona|montar|monta|definir)\b"#,
        #"\b(creer|cree|creez|faire|fais|je\s+veux|nouveau|nouvelle|ajoute|ajouter|aide-moi)\b"#,
        #"\b(erstell\w*|anleg\w*|neue[nsr]?|mach\w*|ich\s+(?:mochte|will|brauche)|hilf\s+mir)\b"#,
        #"\b(crea|creare|fai|fare|voglio|vorrei|nuovo|nuova|aggiungi|aiutami)\b"#,
        #"\b(maak|maken|nieuwe?|wil|help\s+me|voeg\s+toe)\b"#,
        #"\b(utworz|stworz|zrob|chce|nowy|nowa|dodaj|pomoz)\b"#,
    ]

    private static let budgetNounPatterns = [
        #"\b(presupuestos?|presupuestar|budgets?|budgeting|orcamentos?|haushalt|budzet\w*|begroting|bilancio)\b"#,
        #"(予算|预算)"#,
    ]

    private static let budgetSavingPatterns = [
        #"\b(ahorrar|gastar\s+menos|controlar\s+(?:mis\s+|lo\s+que\s+gasto\s+en\s+)?gastos?)\s+(en|con|de)\b"#,
        #"\b(save\s+(?:money\s+)?on|spend\s+less\s+on|cut\s+(?:back|down)\s+on)\b"#,
        #"\b(economizar|gastar\s+menos)\s+(em|com|no|na)\b"#,
        #"\b(economiser|depenser\s+moins)\s+(sur|en|pour)\b"#,
        #"\b(sparen\s+bei|weniger\s+\w+\s+ausgeben)\b"#,
        #"\b(risparmiare|spendere\s+meno)\s+(su|in|per)\b"#,
        #"\b(besparen\s+op|minder\s+uitgeven\s+aan)\b"#,
        #"\b(oszczedzac\s+na|wydawac\s+mniej\s+na)\b"#,
    ]

    private static let allExpensesPatterns = [
        #"\b(todos?\s+mis\s+gastos|todo\s+lo\s+que\s+gasto|en\s+general|general|total)\b"#,
        #"\b(all\s+(?:my\s+)?(?:expenses|spending)|overall|everything)\b"#,
        #"\b(todos\s+os\s+(?:meus\s+)?gastos|tous\s+mes\s+depenses|alle\s+(?:meine\s+)?ausgaben|tutte\s+le\s+(?:mie\s+)?spese)\b"#,
    ]

    /// Un pago que se repite, nombrado: abre el guiado si además se pide (un verbo de crear o una cifra).
    private static let scheduledPaymentPatterns = [
        #"\bpagos?\s+(fijos?|recurrentes?|mensual(?:es)?|semanal(?:es)?|anual(?:es)?|planificados?|programados?|automaticos?|periodicos?)\b"#,
        #"\bpagos?\s+que\s+se\s+repite"#,
        #"\b(suscripcion(?:es)?|subscripcion|cobros?\s+(?:fijos?|recurrentes?|mensual(?:es)?))\b"#,
        #"\b(recurring|scheduled|monthly|weekly|yearly|annual|fixed)\s+(payments?|bills?|charges?|expenses?)\b"#,
        #"\b(subscriptions?)\b"#,
        #"\b(pagamentos?\s+(?:recorrentes?|fixos?|mensais|mensal|programados?)|assinaturas?)\b"#,
        #"\b(paiements?\s+(?:recurrents?|mensuels?|programmes?)|abonnements?)\b"#,
        #"\b(dauerauftrag|wiederkehrende\s+zahlung\w*|abonnements?|abos?)\b"#,
        #"\b(pagamenti?\s+(?:ricorrent[ei]|mensil[ei]|programmat[oi])|abbonament[oi])\b"#,
        #"\b(terugkerende\s+betaling\w*|vaste\s+lasten|abonnementen?)\b"#,
        #"\b(platnosc\w*\s+cykliczn\w*|subskrypcj\w*|abonament\w*)\b"#,
        #"(定期|サブスク|订阅|定期付款)"#,
    ]

    /// Un pedido de pago que se repite aunque no lleve verbo de crear: «recuérdame pagar…», «pago X cada mes».
    private static let paymentRequestPatterns = [
        #"\b(recuerdame|recordarme|avisame|avisarme)\s+(?:que\s+)?(?:tengo\s+que\s+)?pagar\b"#,
        #"\b(pago|pagamos|pagan|me\s+cobran|cobran)\b.*\b(cada|todos\s+los)\s+(?:\d{1,3}\s+)?(mes|meses|semana|semanas|dia|dias|ano|anos|lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b"#,
        #"\b(bill\s+reminder|remind\s+me\s+to\s+pay)\b"#,
        #"\b(i\s+pay|we\s+pay|they\s+charge\s+me)\b.*\b(every|each)\s+(?:\d{1,3}\s+)?(months?|weeks?|years?|days?)\b"#,
        #"\b(lembre-me\s+de\s+pagar|rappelle-moi\s+de\s+payer|erinnere\s+mich\s+(?:daran\s+)?zu\s+zahlen|ricordami\s+di\s+pagare|przypomnij\s+mi\s+zaplacic)\b"#,
    ]

    /// Mirar lo que ya existe no es crear: «quiero ver mis presupuestos», «muéstrame mis suscripciones».
    private static let viewingPatterns = [
        #"\b(ver|mirar|revisar|muestrame|mostrar|muestra|ensename|lista|listar|listame|cuales|show|see|list|view|check|review|mostra|mostre|montre|zeig\w*|mostrami|toon|pokaz)\b"#,
    ]

    private static let subscriptionWordPatterns = [
        #"\b(suscripcion|subscription|assinatura|abonnement|abo|abbonamento|subskrypcja)\b"#,
    ]

    /// «cómo voy con mis presupuestos», «cuánto me queda»: preguntas aunque no lleven signos.
    private static let statusQuestionPatterns = [
        #"^(cuant[oa]s?|cual(es)?|cuando|donde|por\s*que|como\s+(voy|va|van|vamos|estoy|ando))\b"#,
        #"^(how\s+(much|many|am|is|are|does|did)|what|which|when|where|why|am\s+i|is\s+my|are\s+my|do\s+i|did\s+i)\b"#,
        #"^(quant[oa]s?|qual|quais|quando|onde|combien|quel(le)?s?|pourquoi|wie\s+viel|welche[rsn]?|warum|quant[ie]|quale|hoeveel|welke|ile|jaki)\b"#,
        #"\b(como\s+(?:voy|va)\s+(?:con|mi)|how'?s\s+my|how\s+am\s+i\s+doing)\b"#,
    ]

    private static let monthlyPatterns = [
        #"\b(mensual(?:es|mente)?|al\s+mes|por\s+mes|cada\s+mes|todos\s+los\s+meses|del\s+mes|este\s+mes|de\s+cada\s+mes|el\s+mes)\b"#,
        #"\b(monthly|a\s+month|per\s+month|each\s+month|every\s+month|this\s+month|month)\b"#,
        #"\b(mensal(?:mente)?|por\s+mes|todo\s+mes|mensuel(?:le)?|par\s+mois|chaque\s+mois|monatlich|pro\s+monat|mensile|al\s+mese|ogni\s+mese|maandelijks|per\s+maand|miesieczn\w*|co\s+miesiac)\b"#,
    ]

    private static let weeklyPatterns = [
        #"\b(semanal(?:es|mente)?|a\s+la\s+semana|por\s+semana|cada\s+semana|todas\s+las\s+semanas)\b"#,
        #"\b(weekly|a\s+week|per\s+week|each\s+week|every\s+week)\b"#,
        #"\b(hebdomadaire|par\s+semaine|chaque\s+semaine|wochentlich|pro\s+woche|settimanale|a\s+settimana|wekelijks|per\s+week|tygodniow\w*|co\s+tydzien)\b"#,
        #"\b(cada|todos\s+los)\s+(lunes|martes|miercoles|jueves|viernes|sabados?|domingos?)\b"#,
    ]

    private static let yearlyPatterns = [
        #"\b(anual(?:es|mente)?|al\s+ano|por\s+ano|cada\s+ano|todos\s+los\s+anos)\b"#,
        #"\b(yearly|annual(?:ly)?|a\s+year|per\s+year|each\s+year|every\s+year)\b"#,
        #"\b(anuel(?:le)?|par\s+an|chaque\s+annee|jahrlich|pro\s+jahr|annuale|all'anno|jaarlijks|per\s+jaar|roczn\w*|co\s+rok)\b"#,
    ]

    /// «todos los días», «cada día», «diario», «every day», «daily», «todos os dias».
    private static let dailyPatterns = [
        #"\b(todos\s+los\s+dias|cada\s+dia|diari[oa]s?|diariamente|every\s+day|each\s+day|daily|todos\s+os\s+dias|todo\s+dia|tous\s+les\s+jours|jeden\s+tag|taglich|ogni\s+giorno|elke\s+dag|codziennie)\b"#,
    ]

    private static let oncePatterns = [
        // «una vez al mes» no es una sola vez: es mensual.
        #"\b(una\s+(?:sola\s+)?vez|solo\s+una\s+vez|por\s+unica\s+vez|pago\s+unico|one\s+time|one-time|just\s+once|only\s+once|uma\s+(?:so\s+)?vez|une\s+fois|einmalig|una\s+tantum|eenmalig|jednorazow\w*)\b(?!\s+(?:al|por|cada|a\s+la|a|per|par|pro|en|em|ao|a\s+cada)\b)"#,
    ]

    /// Lo que anuncia el nombre: «pagar el alquiler», «pago de la luz», «suscripción a Spotify».
    private static let nameAnchors: Set<String> = [
        "pagar", "pago", "pagos", "suscripcion", "suscripciones", "cobro", "pay", "payment", "subscription", "bill",
        "for", "pagamento", "assinatura", "payer", "paiement", "abonnement", "zahlen", "zahlung", "pagare",
        "abbonamento", "betalen", "zaplacic",
    ]

    /// Palabras que se saltan delante del nombre.
    private static let nameSkips: Set<String> = [
        "el", "la", "los", "las", "mi", "mis", "de", "del", "a", "al", "un", "una", "para", "por", "the", "my", "a", "an",
        "for", "of", "to", "o", "os", "as", "meu", "minha", "le", "les", "mon", "ma", "mes", "du", "des", "der", "die",
        "das", "il", "lo", "mio", "mia", "het", "mijn", "fijo", "fija", "fijos", "recurrente", "recurrentes", "mensual",
        "semanal", "anual", "nuevo", "nueva", "recurring", "monthly", "weekly", "yearly", "new",
    ]

    /// Palabras que cortan el nombre.
    private static let nameStops: Set<String> = [
        "cada", "todos", "todas", "el", "al", "por", "con", "en", "que", "y", "every", "each", "on", "per", "a", "and",
        "with", "in", "at", "soles", "sol", "dolares", "dollars", "euros", "pesos", "usd", "pen", "eur", "mensual",
        "semanal", "anual", "monthly", "weekly", "yearly", "de", "of", "um", "uma", "chaque", "jeden", "ogni", "elke",
        "jeder", "jede",
    ]

    // MARK: - Utilidades

    static func isValidMonthDay(_ day: Int) -> Bool { ChatGuidedEngine.isValidMonthDay(day) }

    static func matchesAny(_ folded: String, _ patterns: [String]) -> Bool {
        let range = NSRange(folded.startIndex..., in: folded)
        for pattern in patterns {
            if let regex = compiled(pattern), regex.firstMatch(in: folded, range: range) != nil { return true }
        }
        return false
    }

    /// Un patrón de este fichero, sin distinguir mayúsculas. Un patrón mal escrito se avisa y no casa nada.
    private static func compiled(_ pattern: String) -> NSRegularExpression? {
        do {
            return try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            #if DEBUG
            print("ChatGuidedIntentDetector: Error: bad pattern \(pattern): \(error)")
            #endif
            return nil
        }
    }

    static func wholeWordRange(of word: String, in folded: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = #"(?<![\p{L}\p{N}])"# + escaped + #"(?![\p{L}\p{N}])"#
        return folded.range(of: pattern, options: [.regularExpression, .caseInsensitive])
    }
}
