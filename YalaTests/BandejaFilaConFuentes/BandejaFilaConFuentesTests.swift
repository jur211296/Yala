//
//  BandejaFilaConFuentesTests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 3: la fila de un pendiente unido dice de qué fuentes viene, dos pendientes que pueden ser
//  el mismo consumo salen juntos como «¿Es el mismo gasto?» («Es el mismo» los une, «Son distintos» no vuelve a
//  preguntar), y lo que se parece a algo ya guardado dice «Ya registrado». Escenarios de
//  `docs/propuestas/bandeja-sin-duplicados/README.md` §2.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Qué se pregunta (lógica pura)

@MainActor
struct BandejaParejasLogicaTests {

    private func day(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func entry(
        _ source: InboxMatchLogic.Source, _ amount: Double, at date: Date, exact: Bool, plain: Bool = true,
        createdAt: Date? = nil, merchant: String? = nil, key: String? = nil
    ) -> InboxSameExpensePairing.Entry {
        let candidate = InboxMatchLogic.Candidate(
            source: source, amount: amount, currencyCode: "PEN", date: date, hasExactTime: exact,
            accountID: nil, merchant: merchant)
        return InboxSameExpensePairing.Entry(
            consumption: InboxMatchLogic.Consumption(candidate), isPlain: plain, createdAt: createdAt ?? date,
            key: key ?? "\(source.rawValue)@\(date.timeIntervalSinceReferenceDate)")
    }

    @Test("Apple Pay a las 23:50 y el correo del día siguiente con propina: se pregunta, y se une el más reciente")
    func doubtfulPair_isAsked_newestJoins() {
        let applePay = entry(.applePay, -89.90, at: day(20, 23, 50), exact: true, merchant: "Rappi")
        let email = entry(.bankEmail, -92.40, at: day(21, 12), exact: false, createdAt: day(21, 12, 5), merchant: "RAPPI*PE")
        let pairs = InboxSameExpensePairing.pairs([applePay, email], distinct: [])
        #expect(pairs == [InboxSameExpensePairing.Pair(holder: 0, arriving: 1, level: .doubtful)])
    }

    @Test("Dos compras iguales por la misma fuente no se preguntan nunca (E8)")
    func sameSource_isNeverAsked() {
        let first = entry(.applePay, -12, at: day(20, 8, 10), exact: true)
        let second = entry(.applePay, -12, at: day(20, 18, 40), exact: true)
        #expect(InboxSameExpensePairing.pairs([first, second], distinct: []).isEmpty)
    }

    @Test("Un gasto y un reembolso del mismo importe no se preguntan (E9)")
    func expenseAndRefund_areNotAsked() {
        let expense = entry(.applePay, -42.5, at: day(20, 13), exact: true)
        let refund = entry(.bankEmail, 42.5, at: day(20, 12), exact: false)
        #expect(InboxSameExpensePairing.pairs([expense, refund], distinct: []).isEmpty)
    }

    @Test("Lo que la persona marcó como distinto no se vuelve a preguntar")
    func distinct_isNotAskedAgain() {
        let applePay = entry(.applePay, -89.90, at: day(20, 23, 50), exact: true, key: "a")
        let email = entry(.bankEmail, -92.40, at: day(21, 12), exact: false, key: "b")
        #expect(InboxSameExpensePairing.pairs([applePay, email],
                                              distinct: [InboxSameExpenseDistinct.pairKey("b", "a")]).isEmpty)
    }

    @Test("Uno a uno: un Apple Pay con dos correos parecidos se empareja solo con el más cercano")
    func oneToOne_closestWins() {
        let applePay = entry(.applePay, -89.90, at: day(20, 23, 50), exact: true)
        let near = entry(.bankEmail, -91.00, at: day(21, 12), exact: false)
        let far = entry(.bankEmail, -91.50, at: day(22, 12), exact: false)
        let pairs = InboxSameExpensePairing.pairs([applePay, near, far], distinct: [])
        #expect(pairs.count == 1)
        #expect(pairs.first.map { Set([$0.holder, $0.arriving]) } == [0, 1])
    }

    @Test("Dos pendientes que ya juntan otras fuentes no se preguntan entre sí: ninguno puede unirse al otro")
    func twoJoined_areNotAsked() {
        let first = entry(.applePay, -89.90, at: day(20, 23, 50), exact: true, plain: false)
        let second = entry(.bankEmail, -92.40, at: day(21, 12), exact: false, plain: false)
        #expect(InboxSameExpensePairing.pairs([first, second], distinct: []).isEmpty)
    }

    @Test("Con uno ya unido, se une el que no tiene nada aunque haya llegado antes")
    func plainJoinsTheJoinedOne() {
        let joined = entry(.bankEmail, -92.40, at: day(21, 12), exact: false, plain: false, createdAt: day(21, 13))
        let plain = entry(.applePay, -89.90, at: day(20, 23, 50), exact: true, createdAt: day(20, 23, 51))
        let pairs = InboxSameExpensePairing.pairs([joined, plain], distinct: [])
        #expect(pairs == [InboxSameExpensePairing.Pair(holder: 0, arriving: 1, level: .doubtful)])
    }

    @Test("La clave de una pareja no depende del orden")
    func pairKey_isSymmetric() {
        #expect(InboxSameExpenseDistinct.pairKey("x", "y") == InboxSameExpenseDistinct.pairKey("y", "x"))
    }
}

// MARK: - Con la Bandeja real

@Suite(.serialized, .lastUsedAccountIsolated)
@MainActor
struct BandejaFilaConFuentesTests {

    private func day(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// El mismo delivery: Apple Pay el 20 a las 23:50 y el correo del banco el 21 con propina (2,8 % más).
    private func rappiPair(_ context: ModelContext, account: Account) throws -> (applePay: InboxDraft, email: InboxDraft) {
        let applePay = InboxDraft(
            note: "Rappi", amount: -89.90, date: day(20, 23, 50), account: account, sourceType: .applePay,
            rawText: "S/89.90", evidence: "Rappi", needsUserInput: [DraftInputRequirement.subcategory])
        applePay.createdAt = day(20, 23, 51)
        context.insert(applePay)
        let email = InboxDraft(
            note: "RAPPI*PE", amount: -92.40, date: day(21, 12), account: account, sourceType: .emailAlert,
            rawText: "BCP · ****4821", evidence: "BCP · ****4821", needsUserInput: [DraftInputRequirement.subcategory])
        email.createdAt = day(21, 12, 5)
        context.insert(email)
        try context.save()
        return (applePay, email)
    }

    private func pending(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>()).filter { $0.status == .pending }
    }

    private func viewModel(_ context: ModelContext, defaults: UserDefaults) -> InboxViewModel {
        let vm = InboxViewModel()
        vm.distinctDefaults = defaults
        vm.setContext(context)
        return vm
    }

    @Test("La pareja dudosa sale en una tarjeta, en el día del más reciente, y sin ella los dos van sueltos")
    func pair_isShownTogether_inTheNewestDay() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "BCP Visa")
        let (applePay, email) = try rappiPair(context, account: account)

        let vm = viewModel(context, defaults: makeIsolatedDefaults())
        #expect(vm.sameExpensePairs.count == 1)
        let pair = try #require(vm.sameExpensePairs.first)
        #expect(pair.holder === applePay)
        #expect(pair.arriving === email)

        let sections = vm.listSections(for: .pending, pairsSameExpense: true)
        let pairSection = try #require(sections.first { section in
            section.items.contains { if case .pair = $0 { return true } else { return false } }
        })
        #expect(pairSection.date == Calendar.current.startOfDay(for: day(21, 12)))
        let loose = sections.flatMap(\.items).compactMap { item -> InboxDraft? in
            if case .draft(let draft) = item { return draft } else { return nil }
        }
        #expect(!loose.contains { $0 === applePay || $0 === email }, "los de la pareja no salen también sueltos")

        let unpaired = vm.listSections(for: .pending, pairsSameExpense: false).flatMap(\.items)
        #expect(unpaired.allSatisfy { if case .draft = $0 { return true } else { return false } })
        #expect(unpaired.count == 2)
    }

    @Test("«Son distintos»: la pareja no vuelve a salir")
    func distinct_hidesThePair() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "BCP Visa")
        let (applePay, email) = try rappiPair(context, account: account)
        let defaults = makeIsolatedDefaults()

        InboxSameExpenseDistinct.markDistinct([applePay, email], defaults)
        let vm = viewModel(context, defaults: defaults)
        #expect(vm.sameExpensePairs.isEmpty)
        #expect(defaults.stringArray(forKey: InboxSameExpenseDistinct.key)?.count == 1)
    }

    @Test("«Es el mismo»: queda un pendiente con el importe del banco, sus dos fuentes y «Separar» los devuelve")
    func same_joinsWithBankAmount_andSeparateUndoes() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "BCP Visa")
        let (applePay, email) = try rappiPair(context, account: account)

        #expect(InboxArrivalJoin.joinPending(email, into: applePay, context: context))
        let left = try pending(context)
        #expect(left.count == 1)
        let holder = try #require(left.first)
        #expect(holder === applePay)
        #expect(holder.amount == -92.40, "manda el importe del banco (decisión 3)")
        #expect(holder.note == "Rappi", "manda el comercio de Apple Pay")
        let sources = try #require(holder.joinedSources)
        #expect(sources.map(\.name) == [
            InboxDraft.sourceDisplayName(sourceType: .applePay, evidence: "Rappi", hasAmount: true),
            InboxDraft.sourceDisplayName(sourceType: .emailAlert, evidence: "BCP · ****4821", hasAmount: true),
        ])
        #expect(InboxJoinedSourcesSection.sources(of: holder) == [.applePay, .bankEmail])

        let separated = try #require(InboxArrivalJoin.separate(holder, context: context))
        #expect(separated.count == 1)
        #expect(try pending(context).count == 2)
        #expect(holder.amount == -89.90)
        #expect(holder.joinedSources == nil)
    }

    @Test("«Separar» y luego la lista: con lo separado marcado como distinto, no se vuelve a preguntar")
    func separatedAndMarked_isNotAskedAgain() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "BCP Visa")
        let (applePay, email) = try rappiPair(context, account: account)
        let defaults = makeIsolatedDefaults()
        #expect(InboxArrivalJoin.joinPending(email, into: applePay, context: context))

        let separated = try #require(InboxArrivalJoin.separate(applePay, context: context))
        InboxSameExpenseDistinct.markDistinct([applePay] + separated, defaults)
        #expect(viewModel(context, defaults: defaults).sameExpensePairs.isEmpty)
        #expect(viewModel(context, defaults: makeIsolatedDefaults()).sameExpensePairs.count == 1,
                "control: sin la marca, la lista volvería a preguntar")
    }

    @Test("«Es el mismo» no une dos de la misma fuente ni uno que ya tiene algo unido")
    func same_refusesWhatTheJoinWouldNot() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "BCP Visa")
        let first = InboxDraft(note: "Café", amount: -12, date: day(20, 8, 10), account: account, sourceType: .applePay,
                               rawText: "S/12.00", needsUserInput: [DraftInputRequirement.subcategory])
        let second = InboxDraft(note: "Café", amount: -12, date: day(20, 18, 40), account: account, sourceType: .applePay,
                                rawText: "S/12.00", needsUserInput: [DraftInputRequirement.subcategory])
        context.insert(first)
        context.insert(second)
        try context.save()
        #expect(!InboxArrivalJoin.joinPending(second, into: first, context: context))
        #expect(try pending(context).count == 2)
    }

    @Test("«Ya registrado»: un pendiente con un registro guardado igual lo dice, con la fecha del registro")
    func alreadyRecorded_isFound() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "BCP Visa")
        let draft = InboxDraft(note: "Almuerzo", amount: -42.50, date: day(20, 13), account: account, sourceType: .manual,
                               needsUserInput: [DraftInputRequirement.subcategory])
        context.insert(draft)
        let alone = InboxDraft(note: "Taxi", amount: -18.40, date: day(20, 9), account: account, sourceType: .manual,
                               needsUserInput: [DraftInputRequirement.subcategory])
        context.insert(alone)
        let twin = TransactionItem(date: day(20, 12), amount: -42.50, currencyCode: "PEN")
        twin.note = "Almuerzo"
        twin.account = account
        context.insert(twin)
        try context.save()

        let vm = viewModel(context, defaults: makeIsolatedDefaults())
        let recorded = try #require(vm.alreadyRecorded(for: draft))
        #expect(recorded.dateText == InboxDuplicateCheck.twinDateText(day(20, 12)))
        #expect(recorded.summary.contains("Almuerzo"))
        #expect(vm.alreadyRecorded(for: alone) == nil)
    }

    @Test("Marcar como distintos tres borradores guarda las tres parejas, y la lista tiene tope")
    func markDistinct_storesEveryPair_withALimit() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context)
        let drafts = (0..<3).map { index in
            let draft = InboxDraft(note: "x\(index)", amount: -1, account: account, sourceType: .applePay)
            draft.createdAt = day(20, 10 + index)
            context.insert(draft)
            return draft
        }
        try context.save()
        let defaults = makeIsolatedDefaults()
        InboxSameExpenseDistinct.markDistinct(drafts, defaults)
        #expect(InboxSameExpenseDistinct.pairs(defaults).count == 3)

        defaults.set((0..<InboxSameExpenseDistinct.limit).map { "old\($0)" }, forKey: InboxSameExpenseDistinct.key)
        InboxSameExpenseDistinct.markDistinct(Array(drafts.prefix(2)), defaults)
        let stored = try #require(defaults.stringArray(forKey: InboxSameExpenseDistinct.key))
        #expect(stored.count == InboxSameExpenseDistinct.limit)
        #expect(stored.last == InboxSameExpenseDistinct.pairKey(InboxSameExpenseDistinct.draftKey(of: drafts[0]),
                                                                InboxSameExpenseDistinct.draftKey(of: drafts[1])))
    }
}

// MARK: - Cableado y textos

@MainActor
struct BandejaFilaConFuentesCableadoTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("El borrado de datos retira lo marcado como distinto")
    func wipe_removesTheDistinctKey() throws {
        let wipe = try Self.source("Yala/Utils/DataWipeService.swift")
        #expect(wipe.contains("defaults.removeObject(forKey: InboxSameExpenseDistinct.key)"))
    }

    @Test("«Separar» marca como distintos lo que separa, después de separar y antes de cerrar")
    func separate_marksDistinct() throws {
        let sheet = try Self.source("Yala/App/Views/Inbox/InboxDraftEditSheet.swift")
        let start = try #require(sheet.range(of: "private func separateJoinedSources()"))
        let body = String(sheet[start.upperBound...].prefix(700))
        let separate = try #require(body.range(of: "InboxArrivalJoin.separate("))
        let mark = try #require(body.range(of: "InboxSameExpenseDistinct.markDistinct([draft] + separated)"))
        let dismiss = try #require(body.range(of: "dismiss()"))
        #expect(separate.lowerBound < mark.lowerBound && mark.lowerBound < dismiss.lowerBound)
    }

    @Test("La pareja solo se agrupa en «Pendientes» fuera del modo selección, y «Ya registrado» solo en pendientes")
    func inbox_wiresPairsAndRecordedOnlyWhereTheyBelong() throws {
        let inbox = try Self.source("Yala/App/Views/Inbox/InboxView.swift")
        #expect(inbox.contains("pairsSameExpense: selectedFilter == .pending && !isSelectionMode"))
        #expect(inbox.contains(
            "alreadyRecorded: selectedFilter.isPendingList && !isSelectionMode ? viewModel.alreadyRecorded(for: draft) : nil"))
        #expect(inbox.contains("InboxArrivalJoin.joinPending(pair.arriving, into: pair.holder, context: modelContext)"))
        #expect(inbox.contains("approveDraft(draft, skipDuplicateCheck: true)"))
    }

    @Test("Los textos nuevos están en los 16 idiomas, con su hueco donde lo llevan")
    func strings_inEveryLanguage() throws {
        let languages = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl", "pt-BR",
                         "pt-PT", "pt", "zh-Hans"]
        let keys = ["ask.title", "ask.same", "ask.same.hint", "ask.distinct", "ask.distinct.hint", "recorded.title",
                    "recorded.a11y", "recorded.discard", "recorded.saveAnyway", "recorded.saveAnyway.hint",
                    "row.sources.a11y"]
        let withSlot: Set<String> = ["recorded.title", "recorded.a11y", "row.sources.a11y"]
        for language in languages {
            let path = "Yala/Resources/\(language).lproj/BandejaUnir.strings"
            let table = try #require(NSDictionary(contentsOfFile: Self.root(path)) as? [String: String], "\(path)")
            for key in keys {
                let value = try #require(table["bandejaUnir.\(key)"], "\(language): falta \(key)")
                #expect(value.contains("%@") == withSlot.contains(key), "\(language): \(key)")
            }
        }
    }

    private static func root(_ path: String) -> String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(path).path
    }
}
