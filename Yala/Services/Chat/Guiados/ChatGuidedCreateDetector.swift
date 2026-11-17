//
//  ChatGuidedCreateDetector.swift
//  Yala
//
//  Las frases que piden crear una cuenta, una categoría (o subcategorías) o un favorito, y lo que ya dicen. Como el resto
//  del detector, se decide en el teléfono.
//
//  La regla que no se toca: el verbo y la cosa van JUNTOS («crea una cuenta», «nueva categoría», «agrega un favorito»).
//  «Agrega 20 soles a la cuenta BCP» o «registra un gasto en la categoría Comida» son registros y siguen su camino.
//

import Foundation
import SwiftData

extension ChatGuidedIntentDetector {

    // MARK: - ¿Qué se pide crear?

    /// Cuenta, categoría o favorito, o `nil`. Lo llama `kind(of:)` sobre el texto ya plegado.
    static func createKind(_ folded: String) -> ChatGuidedKind? {
        if matchesAny(folded, favoriteRequestPatterns) { return .favorite }
        if matchesAny(folded, categoryRequestPatterns) { return .category }
        if matchesAny(folded, accountRequestPatterns), !matchesAny(folded, notAnAccountPatterns) { return .account }
        return nil
    }

    // MARK: - Cuenta

    static func account(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection {
        let folded = normalized(text)
        var answers = ChatGuidedAnswers()
        var prefilled: Set<ChatGuidedField> = []
        let kind = accountKind(folded)
        if let kind {
            answers.accountKind = kind.rawValue
            prefilled.insert(.accountKind)
        }
        if let named = currency(folded, mainCurrency: catalog.mainCurrency) {
            answers.accountCurrencies = [named]
            prefilled.insert(.currency)
        } else if Set(catalog.accountCurrencies + [catalog.mainCurrency]).count <= 1 {
            // Con una sola moneda en Yala no hay nada que preguntar.
            answers.accountCurrencies = [catalog.mainCurrency.uppercased()]
        }
        if let name = calledName(text) {
            answers.accountName = name
            prefilled.insert(.name)
        }
        // Un saldo dicho con cifra, con una sola moneda. En tarjeta no: «Visa con límite de 5000» no es lo que se debe.
        if kind?.isCard != true, let currencies = answers.accountCurrencies, currencies.count == 1,
           let amount = amount(in: folded), amount.isFinite {
            answers.accountBalances = [currencies[0]: amount]
            prefilled.insert(.balance)
        }
        return ChatGuidedDetection(kind: .account, answers: answers, prefilled: prefilled)
    }

    /// El tipo nombrado: tarjeta, ahorros, corriente o efectivo. «Todo junto» no se dice: se pregunta.
    static func accountKind(_ folded: String) -> FirstAccountFlowLogic.Kind? {
        if matchesAny(folded, [#"\b(tarjetas?|credit\s*cards?|cards?|cartao|cartoes|cartes?|kreditkarten?|karten?|carta|kaart|creditcard|kart[ay])\b"#, #"(カード|信用卡)"#]) {
            return .creditCard
        }
        if matchesAny(folded, [#"\b(ahorros?|savings|poupanca|epargne|spar\w*|risparmi\w*|spaar\w*|oszczednosc\w*)\b"#, #"(貯蓄|储蓄)"#]) {
            return .savings
        }
        if matchesAny(folded, [#"\b(corriente|checking|current\s+account|conta\s+corrente|compte\s+courant|girokonto|conto\s+corrente|betaalrekening|konto\s+osobiste)\b"#, #"(当座|活期)"#]) {
            return .checking
        }
        if matchesAny(folded, [#"\b(efectivo|cash|dinheiro|especes|bargeld|contanti|contant|gotowk\w*)\b"#, #"(現金|现金)"#]) {
            return .cash
        }
        return nil
    }

    // MARK: - Categoría

    static func category(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection {
        let folded = normalized(text)
        var answers = ChatGuidedAnswers()
        var prefilled: Set<ChatGuidedField> = []
        let isSubcategory = matchesAny(folded, [subcategoryNounPattern])
        answers.categoryMode = isSubcategory ? .subcategories : .newCategory
        prefilled.insert(.categoryMode)

        let tokens = words(text)
        let folds = tokens.map { fold($0).trimmingCharacters(in: .punctuationCharacters) }
        guard let noun = folds.firstIndex(where: { isCategoryNoun($0) }) else {
            return ChatGuidedDetection(kind: .category, answers: answers, prefilled: prefilled)
        }
        // «… en Mascotas»: la categoría donde van, si es una de las de la persona.
        var end = folds.count
        if isSubcategory, let inIndex = folds.indices.last(where: { $0 > noun && insideWords.contains(folds[$0]) }) {
            let rest = folds[(inIndex + 1)...].joined(separator: " ")
            if let parent = catalog.categories.first(where: { entry in
                entry.nameWords.contains { $0.count >= 3 && wholeWordRange(of: $0, in: rest) != nil }
            }) {
                answers.parentCategoryID = parent.id
                prefilled.insert(.parentCategory)
            }
            end = inIndex
        }
        // Lo que sigue al nombre: «con veterinario y comida».
        var namesEnd = end
        var subcategories: [String] = []
        if !isSubcategory, let withIndex = folds.indices.first(where: { $0 > noun && $0 < end && withWords.contains(folds[$0]) }) {
            subcategories = nameList(Array(tokens[(withIndex + 1)..<end]))
            namesEnd = withIndex
        }
        let named = nameList(Array(tokens[(noun + 1)..<namesEnd]))
        if isSubcategory {
            if !named.isEmpty {
                answers.subcategoryNames = named
                prefilled.insert(.subcategories)
            }
        } else {
            if let first = named.first {
                answers.categoryName = first
                prefilled.insert(.name)
            }
            if !subcategories.isEmpty {
                answers.subcategoryNames = subcategories
                prefilled.insert(.subcategories)
            }
        }
        return ChatGuidedDetection(kind: .category, answers: answers, prefilled: prefilled)
    }

    static func isCategoryNoun(_ folded: String) -> Bool {
        matchesAny(folded, [#"^(sub-?|sous-|unter|sotto|pod)?(categorias?|categor(?:y|ies)|categories?|kategorie[n]?|kategori\w*)$"#])
    }

    /// Nombres separados por comas, «y», «and»…: «Veterinario y Comida» → [Veterinario, Comida]. Sin artículos ni
    /// «llamada», con la mayúscula de la frase. Como mucho tres palabras por nombre.
    static func nameList(_ tokens: [String]) -> [String] {
        var names: [String] = []
        var current: [String] = []
        func close() {
            if !current.isEmpty {
                let name = current.joined(separator: " ")
                names.append(name.prefix(1).uppercased() + name.dropFirst())
            }
            current = []
        }
        for raw in tokens {
            let endsList = raw.hasSuffix(",")
            let clean = raw.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
            let folded = fold(clean)
            if folded.isEmpty { continue }
            if joinWords.contains(folded) {
                close()
                continue
            }
            if current.isEmpty, nameFillers.contains(folded) { continue }
            if current.count < 3 { current.append(clean) }
            if endsList { close() }
        }
        close()
        var seen: Set<String> = []
        return names.filter { seen.insert(fold($0)).inserted }
    }

    // MARK: - Favorito

    static func favorite(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection {
        let folded = normalized(text)
        var answers = ChatGuidedAnswers()
        var prefilled: Set<ChatGuidedField> = []
        if let type = favoriteType(folded) {
            answers.favoriteType = type.rawValue
            prefilled.insert(.favoriteType)
        }
        if let amount = amount(in: folded) {
            answers.amount = amount
            prefilled.insert(.amount)
        }
        if let name = calledName(text) {
            answers.favoriteName = name
            prefilled.insert(.name)
        }
        if answers.favoriteType != ChatGuidedFavoriteType.transfer.rawValue {
            let named = matchedSubcategories(folded, catalog: catalog)
            if named.count == 1, let only = named.first {
                answers.subcategoryID = only.id
                prefilled.insert(.subcategories)
            }
        }
        return ChatGuidedDetection(kind: .favorite, answers: answers, prefilled: prefilled)
    }

    static func favoriteType(_ folded: String) -> ChatGuidedFavoriteType? {
        if matchesAny(folded, [#"\b(transferencias?|transfers?|virements?|uberweisung\w*|trasferiment\w*|overschrijving\w*|przelew\w*)\b"#, #"(振替|转账)"#]) {
            return .transfer
        }
        if matchesAny(folded, [#"\b(ingresos?|incomes?|receitas?|revenus?|einnahmen?|entrat[ae]|inkomsten?|przychod\w*|sueldo|salario|salary)\b"#, #"(収入|收入)"#]) {
            return .income
        }
        if matchesAny(folded, [#"\b(gastos?|expenses?|despesas?|depenses?|ausgaben?|spes[ae]|uitgaven?|wydat\w*)\b"#, #"(支出)"#]) {
            return .expense
        }
        return nil
    }

    // MARK: - Piezas

    /// Lo que sigue a «llamada», «que se llame», «called»…: hasta cuatro palabras («Café de la mañana»), con la
    /// mayúscula de la frase.
    static func calledName(_ text: String) -> String? {
        let tokens = words(text)
        let folds = tokens.map { fold($0).trimmingCharacters(in: .punctuationCharacters) }
        guard let anchor = folds.indices.last(where: { calledAnchors.contains(folds[$0]) }) else { return nil }
        var picked: [String] = []
        var index = anchor + 1
        while index < tokens.count, picked.count < 4 {
            let folded = folds[index]
            if folded.isEmpty || nameStopsAfterCalled.contains(folded) || folded.rangeOfCharacter(from: .decimalDigits) != nil {
                if picked.isEmpty, calledSkips.contains(folded) {
                    index += 1
                    continue
                }
                break
            }
            if picked.isEmpty, calledSkips.contains(folded) {
                index += 1
                continue
            }
            picked.append(tokens[index].trimmingCharacters(in: .punctuationCharacters.union(CharacterSet(charactersIn: "«»\"'“”"))))
            index += 1
        }
        let name = picked.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    private static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// El verbo de crear y la cosa, juntos (con hasta dos palabras de relleno entre medio: «crea una nueva cuenta»).
    private static func request(_ verbs: String, _ fillers: String, _ nouns: String) -> String {
        #"\b(?:"# + verbs + #")\s+(?:(?:"# + fillers + #")\s+){0,2}(?:"# + nouns + #")\b"#
    }

    private static let spanishVerbs = "crea|crear|creame|creemos|haz|hazme|arma|armame|abre|abrir|abreme|agrega|agregar|agregame|anade|anadir|anademe|nueva|nuevo|nuevas|nuevos|quiero|quisiera|necesito|registra|registrar|guarda|guardar|configura|configurar"
    private static let spanishFillers = "un|una|unas|unos|la|las|los|el|otra|otro|otras|otros|mi|mis|nueva|nuevo|nuevas|nuevos"

    private static let accountRequestPatterns: [String] = [
        request(spanishVerbs, spanishFillers, #"cuentas?|tarjetas?"#),
        request("create|add|new|open|make|set\\s+up|i\\s+want|i\\s+need", "a|an|another|new|my", #"accounts?|cards?|credit\s+cards?"#),
        request("criar|cria|crie|nova|novo|quero|adicionar|adiciona|abrir|abre", "uma|um|outra|minha|nova|novo", #"contas?|cartao|cartoes"#),
        request("creer|cree|creez|ajoute|ajouter|nouveau|nouvelle|ouvrir|ouvre", "un|une|mon|ma|nouveau|nouvelle|autre", #"comptes?|cartes?"#),
        request(#"erstell\w*|anleg\w*|neue[nsr]?|eroffne\w*"#, #"ein(?:e[nm]?)?|mein\w*|neue[nsr]?|weitere[nsr]?"#, #"konto|konten|karte|kreditkarte"#),
        #"\b(konto|kreditkarte)\s+(erstellen|anlegen|eroffnen)\b"#,
        request("crea|creare|nuovo|nuova|aggiungi|apri|aprire", "un|una|il|la|mio|mia|nuovo|nuova|altro|altra", #"conto|conti|carta"#),
        request("maak|nieuwe?|voeg|open", "een|mijn|nieuwe?", #"rekening|kaart|creditcard"#),
        request(#"utworz|stworz|dodaj|nowe|nowa|nowy|zaloz"#, "nowe|nowa|nowy|moje", #"konto|karte|karta"#),
        #"(新しい口座|口座を(作|追加)|新しいカード|新建账户|创建账户|添加账户)"#,
    ]

    /// «Una cuenta» que no es una cuenta de dinero: la de Yala, la de la luz.
    private static let notAnAccountPatterns: [String] = [
        #"\b(cuenta|account|conta|compte|konto|conto)\s+(?:de|en|del|in|on|da|na|bei|di|op)\s+(?:yala|luz|agua|gas|internet|telefono|la\s+luz|el\s+agua)\b"#,
        #"\byala\s+account\b"#,
    ]

    private static let subcategoryNounPattern = #"\b(sub-?categor\w*|sous-categor\w*|unterkategor\w*|sottocategor\w*|podkategor\w*)\b"#

    private static let categoryRequestPatterns: [String] = [
        request(spanishVerbs, spanishFillers, #"(?:sub)?categorias?"#),
        request("create|add|new|make|set\\s+up|i\\s+want|i\\s+need", "a|an|another|new|some|my", #"(?:sub-?)?categor(?:y|ies)"#),
        request("criar|cria|crie|nova|novo|quero|adicionar|adiciona", "uma|um|outra|minha|nova|novas|umas", #"(?:sub)?categorias?"#),
        request("creer|cree|creez|ajoute|ajouter|nouveau|nouvelle|nouvelles", "un|une|des|mon|ma|nouvelle|nouvelles|autre", #"(?:sous-)?categories?"#),
        request(#"erstell\w*|anleg\w*|neue[nsr]?"#, #"ein(?:e[nm]?)?|mein\w*|neue[nsr]?|weitere[nsr]?"#, #"(?:unter)?kategorien?"#),
        request("crea|creare|nuova|nuove|aggiungi", "una|un|la|mia|nuova|nuove|altra", #"(?:sotto)?categori[ae]"#),
        request("maak|nieuwe?|voeg", "een|mijn|nieuwe?", #"(?:sub)?categorie(?:en)?"#),
        request(#"utworz|stworz|dodaj|nowa|nowe"#, "nowa|nowe|moja", #"(?:pod)?kategori\w*"#),
        #"(新しいカテゴリ|カテゴリを(作|追加)|新建分类|创建分类|添加分类)"#,
    ]

    private static let favoriteRequestPatterns: [String] = [
        request(spanishVerbs, spanishFillers, #"favoritos?|atajos?"#),
        request("create|add|new|make|set\\s+up|save|i\\s+want|i\\s+need", "a|an|another|new|my", #"favou?rites?"#),
        request("criar|cria|crie|novo|quero|adicionar|adiciona|salvar|guardar", "um|uma|outro|meu|novo", #"favoritos?"#),
        request("creer|cree|creez|ajoute|ajouter|nouveau", "un|mon|nouveau|autre", #"favoris?"#),
        request(#"erstell\w*|anleg\w*|neue[nsr]?|speicher\w*"#, #"ein(?:e[nm]?)?|mein\w*|neue[nsr]?"#, #"favorit\w*"#),
        request("crea|creare|nuovo|aggiungi|salva", "un|il|mio|nuovo|altro", #"preferit[oi]"#),
        request("maak|nieuwe?|voeg", "een|mijn|nieuwe?", #"favoriet(?:en)?"#),
        request(#"utworz|stworz|dodaj|nowy|nowa"#, "nowy|nowa|moj", #"ulubion\w*"#),
        #"(お気に入りを(作|追加)|新しいお気に入り|添加收藏|新建收藏|创建常用)"#,
    ]

    private static let calledAnchors: Set<String> = [
        "llamada", "llamado", "llamadas", "llamados", "llame", "called", "named", "chamada", "chamado", "appele", "appelee",
        "namens", "genannt", "chiamato", "chiamata", "genaamd", "nazwie", "nombre",
    ]

    /// Lo que puede ir entre «llamada» y el nombre: «que se llame», «con el nombre».
    private static let calledSkips: Set<String> = ["que", "se", "el", "la", "de", "como", "o", "le", "il", "het", "the"]

    private static let nameStopsAfterCalled: Set<String> = [
        "con", "en", "por", "para", "y", "que", "with", "in", "for", "and", "on", "com", "em", "avec", "dans",
        "mit", "fur", "in", "per", "met", "voor", "z", "w",
    ]

    /// Antes de la categoría donde van las subcategorías: «en Mascotas», «dentro de Hogar».
    private static let insideWords: Set<String> = ["en", "dentro", "in", "inside", "under", "na", "no", "dans", "unter", "nella", "nel", "binnen", "w"]

    /// Antes de las subcategorías de una categoría nueva: «con veterinario y comida».
    private static let withWords: Set<String> = ["con", "with", "com", "avec", "mit", "met", "z"]

    private static let joinWords: Set<String> = ["y", "e", "and", "et", "und", "ed", "i", "o", "or", "ou", "oder"]

    private static let nameFillers: Set<String> = [
        "un", "una", "unas", "unos", "la", "las", "el", "los", "nueva", "nuevas", "nuevo", "llamada", "llamadas", "llamado",
        "que", "se", "llame", "llamen", "de", "para", "a", "an", "the", "new", "called", "named", "for", "uma", "um",
        "nova", "novas", "une", "des", "nouvelle", "nouvelles", "eine", "neue", "una", "nuove", "een", "nieuwe", "nowa",
        "nowe",
    ]
}
