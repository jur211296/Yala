//
//  ChatGuidedGroupDetector.swift
//  Yala
//
//  Las frases que piden un guiado de Grupos y lo que ya dicen. Como el resto del detector, se decide en el teléfono.
//
//  - Crear un grupo: el verbo de crear y «grupo» juntos («crea un grupo», «nuevo grupo para el viaje a Cusco»). Sin
//    «agrega» ni «registra»: «agrega al grupo…» es anotar en uno que ya existe.
//  - Una deuda de antes: «deuda de antes», «saldo inicial» del grupo, «Luis me debía 50 de antes».
//  - Un gasto de grupo: con una cifra, «gasto de grupo», «en el grupo X» o «divide / reparte… entre»; o con una cifra y
//    el nombre de alguien de tus grupos detrás de «con» o «entre» («pagué 120 de la cena con Ana y Luis»). Sin nadie de
//    tus grupos, «pagué 120 de la cena» sigue siendo un registro personal.
//

import Foundation

extension ChatGuidedIntentDetector {

    // MARK: - ¿Qué guiado de Grupos?

    /// Crear un grupo, una deuda de antes o un gasto de grupo dicho con todas las letras. Lo llama `kind(of:)` sobre el
    /// texto ya plegado. El gasto que solo se reconoce por los nombres de las personas lo decide `groupExpenseByPeople`.
    static func groupKind(_ folded: String) -> ChatGuidedKind? {
        if matchesAny(folded, groupCreatePatterns) { return .group }
        if matchesAny(folded, openingBalancePatterns) { return .groupOpeningBalance }
        if folded.rangeOfCharacter(from: .decimalDigits) != nil, matchesAny(folded, groupExpensePatterns) {
            return .groupExpense
        }
        return nil
    }

    /// Una cifra y alguien de tus grupos detrás de «con» o «entre»: un gasto de grupo aunque la frase no lo diga.
    static func groupExpenseByPeople(_ text: String, catalog: ChatGuidedCatalog) -> Bool {
        let folded = normalized(text)
        guard !folded.isEmpty, !isQuestion(folded), amount(in: folded) != nil else { return false }
        let tokens = tokenized(folded)
        let groups = catalog.groups.filter { $0.fits(.groupExpense) }
        for group in groups {
            for member in group.members where !member.isMe {
                for index in positions(of: member, in: tokens) where hasCompanyWord(before: index, in: tokens) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Crear un grupo

    static func group(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection {
        let folded = normalized(text)
        var answers = ChatGuidedAnswers()
        var prefilled: Set<ChatGuidedField> = []
        if let purpose = groupPurpose(folded) {
            answers.groupPurpose = purpose
        }
        if let name = calledName(text) ?? groupNameAfterFor(text) {
            answers.groupName = name
            prefilled.insert(.name)
            if answers.groupPurpose == nil { answers.groupPurpose = groupPurpose(fold(name)) }
        }
        if let code = currency(folded, mainCurrency: catalog.mainCurrency) {
            answers.groupSingleCurrency = true
            answers.currencyCode = code
            prefilled.insert(.currency)
        }
        return ChatGuidedDetection(kind: .group, answers: answers, prefilled: prefilled)
    }

    /// Para qué es, por sus palabras.
    static func groupPurpose(_ folded: String) -> ChatGuidedGroupPurpose? {
        if matchesAny(folded, [#"\b(viajes?|vacaciones|paseo|trips?|travel|holidays?|vacation|viagem|voyage|reise|viaggio|reis|podroz\w*)\b"#]) {
            return .trip
        }
        if matchesAny(folded, [#"\b(casa|depa|departamento|piso|roomies|roommates?|flat|home|house|apartment|appartement|wohnung|wg|appartamento|huis|mieszkani\w*)\b"#]) {
            return .home
        }
        if matchesAny(folded, [#"\b(pareja|novi[oa]|espos[oa]|partner|couple|boyfriend|girlfriend|namorad[oa]|casal|couple|freund(in)?|fidanzat[oa]|vriend(in)?)\b"#]) {
            return .couple
        }
        if matchesAny(folded, [#"\b(amig[oa]s|patas|panas|friends|amis|freunde|amici|vrienden|przyjaciel\w*)\b"#]) {
            return .friends
        }
        return nil
    }

    /// «grupo para el viaje a Cusco» → «Viaje a Cusco». Hasta cuatro palabras, sin pasar de «con» o una cifra.
    static func groupNameAfterFor(_ text: String) -> String? {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let folds = tokens.map { fold($0).trimmingCharacters(in: .punctuationCharacters) }
        guard let noun = folds.firstIndex(where: { groupNounWords.contains($0) }),
              let anchor = folds.indices.first(where: { $0 > noun && groupForWords.contains(folds[$0]) }) else { return nil }
        var picked: [String] = []
        var index = anchor + 1
        while index < tokens.count, picked.count < 4 {
            let folded = folds[index]
            if folded.isEmpty || groupStopWords.contains(folded) || folded.rangeOfCharacter(from: .decimalDigits) != nil { break }
            if picked.isEmpty, groupArticles.contains(folded) {
                index += 1
                continue
            }
            picked.append(tokens[index].trimmingCharacters(in: .punctuationCharacters))
            index += 1
        }
        let name = picked.joined(separator: " ")
        guard !name.isEmpty else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    // MARK: - Deuda de antes

    static func openingBalance(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection {
        let folded = normalized(text)
        let tokens = tokenized(folded)
        var answers = ChatGuidedAnswers()
        var prefilled: Set<ChatGuidedField> = []
        let groups = catalog.groups.filter { $0.fits(.groupOpeningBalance) }
        let group = namedGroup(folded, among: groups) ?? groupOfPeople(tokens, among: groups)
        if let group {
            answers.groupZoneID = group.id
            prefilled.insert(.group)
        }
        if let amount = amount(in: folded) {
            answers.amount = amount
            prefilled.insert(.amount)
        }
        if let group, let me = group.me {
            let named = mentions(in: tokens, group: group).filter { !$0.member.isMe }
            if let verb = tokens.firstIndex(where: { groupOwesVerbs.contains($0) }) {
                let before = named.filter { $0.index < verb }
                let after = named.filter { $0.index > verb }
                // «Luis me debe» / «Luis owes me»: quien habla es a quien le deben.
                let saysMe = (verb > 0 && tokens[verb - 1] == "me") || (verb + 1 < tokens.count && tokens[verb + 1] == "me")
                // «A Luis le debo 50», «I owe Ana»: el verbo en primera persona dice que quien debe eres tú, vaya donde
                // vaya el nombre.
                let firstPerson = groupFirstPersonOwes.contains(tokens[verb]) || (verb > 0 && tokens[verb - 1] == "i")
                if firstPerson {
                    answers.debtorMemberID = me.id
                    answers.creditorMemberID = (after.first ?? before.last)?.member.id
                } else if let debtor = before.last?.member {
                    answers.debtorMemberID = debtor.id
                    answers.creditorMemberID = saysMe ? me.id : after.first?.member.id
                } else if saysMe, let debtor = after.first?.member {
                    answers.debtorMemberID = debtor.id
                    answers.creditorMemberID = me.id
                } else {
                    // «le debía 50 a Ana», «I owe Ana»: quien habla debe.
                    answers.debtorMemberID = me.id
                    answers.creditorMemberID = after.first?.member.id
                }
            }
            if answers.debtorMemberID != nil { prefilled.insert(.debtor) }
            if answers.creditorMemberID != nil, answers.creditorMemberID != answers.debtorMemberID {
                prefilled.insert(.creditor)
            } else {
                answers.creditorMemberID = nil
            }
        }
        return ChatGuidedDetection(kind: .groupOpeningBalance, answers: answers, prefilled: prefilled)
    }

    // MARK: - Gasto de grupo

    static func groupExpense(_ text: String, catalog: ChatGuidedCatalog) -> ChatGuidedDetection {
        let folded = normalized(text)
        let tokens = tokenized(folded)
        var answers = ChatGuidedAnswers()
        var prefilled: Set<ChatGuidedField> = []
        let groups = catalog.groups.filter { $0.fits(.groupExpense) }
        let group = namedGroup(folded, among: groups) ?? groupOfPeople(tokens, among: groups)
        if let group {
            answers.groupZoneID = group.id
            prefilled.insert(.group)
        }
        if let amount = amount(in: folded) {
            answers.amount = amount
            prefilled.insert(.amount)
        }
        if let description = expenseDescription(text, groupName: group?.name) {
            answers.expenseDescription = description
            prefilled.insert(.description)
        }
        guard let group, let me = group.me else {
            return ChatGuidedDetection(kind: .groupExpense, answers: answers, prefilled: prefilled)
        }
        let named = mentions(in: tokens, group: group).filter { !$0.member.isMe }
        // ¿Quién pagó? «pagué» eres tú; «pagó Ana» / «Ana pagó», Ana.
        if matchesAny(folded, groupIPaidPatterns) {
            answers.payerMemberID = me.id
        } else if let paid = tokens.firstIndex(where: { groupOtherPaidWords.contains($0) }) {
            // «Ana pagó» / «pagó Ana»: la persona va pegada al verbo. Plegado, «pagó» es también «pago» (yo pago), así
            // que sin nadie al lado no se decide quién pagó: se pregunta.
            answers.payerMemberID = named.first { abs($0.index - paid) == 1 }?.member.id
        }
        if answers.payerMemberID != nil { prefilled.insert(.payer) }
        // ¿Cómo lo dividen? «entre todos» es todo el grupo; «con Ana y Luis», tú, Ana y Luis en partes iguales.
        if matchesAny(folded, [#"\b(entre\s+todos|between\s+(?:all\s+of\s+us|everyone)|split\s+(?:it\s+)?evenly|entre\s+tous|tra\s+tutti|unter\s+allen|entre\s+todos)\b"#]) {
            answers.splitMode = .equalAll
            prefilled.insert(.participants)
        } else {
            let company = named.filter { hasCompanyWord(before: $0.index, in: tokens) || isListedAfterCompany($0.index, tokens) }
            if !company.isEmpty {
                // Tú entras si pagaste o si la frase te nombra («Ana y yo», «nosotros»); «Ana pagó… con Luis» no te incluye.
                let includesMe = answers.payerMemberID == me.id || tokens.contains { groupSelfWords.contains($0) }
                var ids = (includesMe ? [me.id] : []) + company.map(\.member.id)
                if let payer = answers.payerMemberID, !ids.contains(payer) { ids.append(payer) }
                var seen: Set<String> = []
                ids = ids.filter { seen.insert($0).inserted }
                if Set(ids) == Set(group.members.map(\.id)) {
                    answers.splitMode = .equalAll
                } else {
                    answers.splitMode = .equalSome
                    answers.participantIDs = group.members.map(\.id).filter(ids.contains)
                }
                prefilled.insert(.participants)
            }
        }
        return ChatGuidedDetection(kind: .groupExpense, answers: answers, prefilled: prefilled)
    }

    /// Lo que fue: lo que sigue a la cifra («120 de la cena» → «Cena»), o lo que la precede sin el verbo
    /// («la cena de 120» → «Cena»). Hasta cuatro palabras, sin personas ni el nombre del grupo.
    static func expenseDescription(_ text: String, groupName: String?) -> String? {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let folds = tokens.map { fold($0).trimmingCharacters(in: .punctuationCharacters) }
        guard let number = folds.firstIndex(where: { $0.rangeOfCharacter(from: .decimalDigits) != nil }) else { return nil }
        func collect(_ range: [Int]) -> String? {
            var picked: [String] = []
            for index in range {
                let folded = folds[index]
                if folded.isEmpty || groupCurrencyWords.contains(folded) { if picked.isEmpty { continue } else { break } }
                if groupStopWords.contains(folded) || folded.rangeOfCharacter(from: .decimalDigits) != nil
                    || groupExpenseVerbs.contains(folded) {
                    if picked.isEmpty, !groupExpenseVerbs.contains(folded), folded.rangeOfCharacter(from: .decimalDigits) == nil {
                        continue
                    }
                    break
                }
                if picked.isEmpty, groupArticles.contains(folded) || groupLinkWords.contains(folded) { continue }
                if picked.count == 4 || isVerbLike(folded) { break }
                picked.append(tokens[index].trimmingCharacters(in: .punctuationCharacters))
                // Una coma cierra lo que fue: «90 del taxi, divídelo…».
                if tokens[index].hasSuffix(",") || tokens[index].hasSuffix(";") { break }
            }
            // «la cena de»: sin el enlace que quedó colgando al final.
            while let last = picked.last, groupLinkWords.contains(fold(last)) || groupArticles.contains(fold(last)) {
                picked.removeLast()
            }
            let name = picked.joined(separator: " ")
            guard !name.isEmpty else { return nil }
            if let groupName, fold(name) == fold(groupName) { return nil }
            return name.prefix(1).uppercased() + name.dropFirst()
        }
        if let after = collect(Array((number + 1)..<folds.count)) { return after }
        // Antes de la cifra: desde el final del verbo hacia la cifra, sin el «de» que la une.
        let start = (folds[..<number].lastIndex(where: { groupExpenseVerbs.contains($0) }) ?? -1) + 1
        guard start < number else { return nil }
        var range = Array(start..<number)
        while let last = range.last, groupLinkWords.contains(folds[last]) || groupArticles.contains(folds[last]) { range.removeLast() }
        return collect(range)
    }

    // MARK: - Piezas

    /// «divídelo», «repartan»: un verbo de repartir con su pronombre pegado no es parte de lo que fue.
    private static func isVerbLike(_ folded: String) -> Bool {
        ["divid", "repart", "split", "dividir", "partir"].contains { folded.hasPrefix($0) }
    }

    /// El grupo nombrado en la frase («en el grupo Viaje a Cusco», «para Casa»), si es uno solo.
    static func namedGroup(_ folded: String, among groups: [ChatGuidedGroupOption]) -> ChatGuidedGroupOption? {
        let named = groups.filter { $0.foldedName.count >= 3 && wholeWordRange(of: $0.foldedName, in: folded) != nil }
        return named.count == 1 ? named.first : nil
    }

    /// El único grupo donde están todas las personas nombradas (y al menos una).
    static func groupOfPeople(_ tokens: [String], among groups: [ChatGuidedGroupOption]) -> ChatGuidedGroupOption? {
        var named: [String: Set<String>] = [:]
        for group in groups {
            named[group.id] = Set(mentions(in: tokens, group: group).filter { !$0.member.isMe }.map(\.member.foldedName))
        }
        let all = Set(named.values.flatMap { $0 })
        guard !all.isEmpty else { return nil }
        let fitting = groups.filter { named[$0.id] == all }
        if fitting.count == 1 { return fitting.first }
        // Con varias personas repartidas en grupos distintos, el que tenga más de ellas, si es uno solo.
        let best = groups.map { ($0, named[$0.id]?.count ?? 0) }.filter { $0.1 > 0 }
        guard let top = best.map(\.1).max(), best.filter({ $0.1 == top }).count == 1 else { return nil }
        return best.first { $0.1 == top }?.0
    }

    struct Mention {
        let index: Int
        let member: ChatGuidedGroupOption.Member
    }

    /// Las personas del grupo nombradas en la frase, por su nombre entero o por el primero (si nadie más del grupo lo
    /// comparte), en el orden en que aparecen.
    static func mentions(in tokens: [String], group: ChatGuidedGroupOption) -> [Mention] {
        var result: [Mention] = []
        for member in group.members {
            let sharesFirst = group.members.filter { firstName($0) == firstName(member) }.count > 1
            let found = positions(of: member, in: tokens, allowFirstName: !sharesFirst)
            if let first = found.first { result.append(.init(index: first, member: member)) }
        }
        return result.sorted { $0.index < $1.index }
    }

    private static func positions(of member: ChatGuidedGroupOption.Member, in tokens: [String],
                                  allowFirstName: Bool = true) -> [Int] {
        let parts = member.foldedName.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = parts.first, first.count >= 2 else { return [] }
        var found: [Int] = []
        for index in tokens.indices where tokens[index] == first {
            let whole = parts.count > 1 && index + parts.count <= tokens.count
                && Array(tokens[index..<(index + parts.count)]) == parts
            if whole || (allowFirstName && first.count >= 3) || parts.count == 1 { found.append(index) }
        }
        return found
    }

    private static func firstName(_ member: ChatGuidedGroupOption.Member) -> String {
        member.foldedName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }

    /// «con», «entre», «with»… hasta tres palabras antes (los nombres van en lista: «con Ana, Luis y Sofía»).
    private static func hasCompanyWord(before index: Int, in tokens: [String]) -> Bool {
        let start = max(0, index - 3)
        return tokens[start..<index].contains { groupCompanyWords.contains($0) }
    }

    /// «… con Ana y Luis»: Luis va en la lista que abrió «con».
    private static func isListedAfterCompany(_ index: Int, _ tokens: [String]) -> Bool {
        guard index > 0, groupJoinWords.contains(tokens[index - 1]) else { return false }
        return tokens[..<index].contains { groupCompanyWords.contains($0) }
    }

    /// Las palabras plegadas, sin puntuación.
    static func tokenized(_ folded: String) -> [String] {
        folded.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Patrones

    private static let groupCreateVerbs = "crea|crear|creame|creemos|haz|hazme|hagamos|arma|armar|armame|armemos|abre|abrir|abreme|nuevo|nueva|quiero|quisiera|necesito|configura|configurar"

    private static let groupCreatePatterns: [String] = [
        #"\b(?:"# + groupCreateVerbs + #")\s+(?:(?:un|el|otro|mi|nuevo)\s+){0,2}grupo\b"#,
        #"\b(?:create|make|start|set\s+up|new|i\s+want|i\s+need)\s+(?:(?:a|an|another|new|my)\s+){0,2}group\b"#,
        #"\b(?:criar|cria|crie|novo|quero|montar|monta)\s+(?:(?:um|outro|meu|novo)\s+){0,2}grupo\b"#,
        #"\b(?:creer|cree|creez|nouveau|nouvel)\s+(?:(?:un|mon|nouveau|autre)\s+){0,2}groupe\b"#,
        #"\b(?:erstell\w*|anleg\w*|neue)\s+(?:(?:eine|meine|neue)\s+){0,2}gruppe\b"#,
        #"\b(?:crea|creare|nuovo)\s+(?:(?:un|il|mio|nuovo|altro)\s+){0,2}gruppo\b"#,
        #"\b(?:maak|nieuwe)\s+(?:(?:een|mijn|nieuwe)\s+){0,2}groep\b"#,
        #"\b(?:utworz|stworz|nowa)\s+(?:(?:nowa|moja)\s+){0,2}grup\w*\b"#,
        #"(新しいグループ|グループを作|新建群组|创建群组|创建小组)"#,
    ]

    private static let openingBalancePatterns: [String] = [
        #"\bdeudas?\s+(?:de\s+antes|anterior(?:es)?|previas?|viejas?|pasadas?|desde\s+antes)\b"#,
        #"\b(?:deb[eoi]\w*)\b.*\b(?:de\s+antes|desde\s+antes|antes\s+de\s+yala|antes\s+de\s+usar\s+yala)\b"#,
        #"\bsaldos?\s+inicial(?:es)?\b.*\b(?:grupo|miembro|debe|debia)\b"#,
        #"\b(?:grupo|miembro)\b.*\bsaldos?\s+inicial(?:es)?\b"#,
        #"\b(?:old|previous|prior|existing|past)\s+debts?\b|\bdebts?\s+from\s+before\b|\bowe[sd]?\b.*\bfrom\s+before\b"#,
        #"\bopening\s+balance\b.*\b(?:group|member)\b"#,
        #"\bdividas?\s+(?:de\s+antes|anterior(?:es)?|antigas?)\b|\bdette[s]?\s+(?:d'avant|anterieures?|anciennes?)\b"#,
        #"\balte\s+schulden?\b|\bdebit[oi]\s+(?:di\s+prima|precedenti|vecchi)\b|\boude\s+schulden?\b|\bstare\s+dlugi\b"#,
    ]

    private static let groupExpensePatterns: [String] = [
        #"\bgastos?\s+(?:de\s+grupo|del\s+grupo|grupal(?:es)?|compartidos?)\b"#,
        #"\b(?:en|al|para)\s+(?:el\s+|mi\s+)?grupo\b"#,
        #"\b(?:divid\w*|repart\w*|partir|partamos)\b.*\bentre\b"#,
        #"\b(?:group\s+expenses?|shared\s+expenses?|in\s+the\s+group|to\s+the\s+group|split\b.*\b(?:with|between))\b"#,
        #"\b(?:despesas?\s+(?:do\s+grupo|compartilhadas?)|no\s+grupo|dividir\b.*\bentre)\b"#,
        #"\b(?:depenses?\s+(?:de\s+groupe|partagees?)|dans\s+le\s+groupe|partager\b.*\bentre)\b"#,
        #"\b(?:gruppenausgaben?|in\s+der\s+gruppe|teil\w*\b.*\bzwischen)\b"#,
        #"\b(?:spes[ae]\s+(?:di\s+gruppo|condivis[ae])|nel\s+gruppo|divid\w*\b.*\btra)\b"#,
    ]

    private static let groupIPaidPatterns: [String] = [
        #"\b(?:pague|yo\s+pague|lo\s+pague|i\s+paid|i\s+covered|paguei|j'ai\s+paye|ich\s+habe\s+(?:\w+\s+)?bezahlt|ho\s+pagato|ik\s+heb\s+betaald|zaplacilem|zaplacilam)\b"#,
    ]

    private static let groupOtherPaidWords: Set<String> = ["pago", "pagaron", "paid", "pagou", "paye", "bezahlt", "pagato", "betaald", "zaplacil", "zaplacila"]

    private static let groupOwesVerbs: Set<String> = [
        "debe", "debia", "debian", "deben", "debo", "debiamos", "owes", "owe", "owed", "deve", "devia", "doit", "devait",
        "schuldet", "schuldete", "doveva", "schuldt", "winien",
    ]

    private static let groupFirstPersonOwes: Set<String> = ["debo", "devo", "dois", "schulde", "debbo", "wisze"]
    private static let groupSelfWords: Set<String> = [
        "yo", "me", "mi", "nosotros", "nosotras", "conmigo", "i", "us", "we", "eu", "nos", "moi", "nous", "ich", "uns",
        "wir", "io", "noi", "ik", "wij", "ja", "my",
    ]

    private static let groupNounWords: Set<String> = ["grupo", "group", "groupe", "gruppe", "gruppo", "groep", "grupa", "grupe"]
    private static let groupForWords: Set<String> = ["para", "for", "pour", "fur", "per", "voor", "dla", "del", "de"]
    private static let groupCompanyWords: Set<String> = ["con", "entre", "with", "between", "com", "avec", "mit", "zwischen", "tra", "fra", "met", "z"]
    private static let groupJoinWords: Set<String> = ["y", "e", "and", "et", "und", "ed", "en", "i"]
    private static let groupArticles: Set<String> = ["el", "la", "los", "las", "un", "una", "mi", "the", "a", "an", "my", "o", "le", "les", "der", "die", "das", "il", "lo", "het", "de"]
    private static let groupLinkWords: Set<String> = ["de", "del", "por", "para", "en", "for", "on", "of", "da", "do", "du", "des", "fur", "di", "van", "na"]
    private static let groupStopWords: Set<String> = [
        "con", "entre", "y", "with", "between", "and", "com", "avec", "et", "mit", "und", "tra", "e", "met", "en", "z",
        "que", "pague", "pago", "paid", "hoy", "ayer", "today", "yesterday", "grupo", "group",
        // «un gasto de grupo de 60»: la palabra «gasto» dice qué se pide, no qué fue.
        "gasto", "gastos", "expense", "expenses", "despesa", "depense", "ausgabe", "spesa", "uitgave", "wydatek",
        "compartido", "shared", "deuda", "debt",
    ]
    private static let groupCurrencyWords: Set<String> = [
        "soles", "sol", "s/", "dolares", "dollars", "usd", "euros", "euro", "eur", "pesos", "reales", "reais", "pen", "$",
        "libras", "pounds", "k", "mil", "lucas",
    ]
    private static let groupExpenseVerbs: Set<String> = [
        "pague", "pago", "gaste", "compre", "divide", "dividi", "dividan", "reparte", "repartan", "anota", "registra",
        "agrega", "pon", "paid", "spent", "bought", "split", "add", "paguei", "gastei", "comprei", "costo", "salio",
    ]
}
