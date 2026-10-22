//
//  DraftBuilderTests.swift
//  YalaTests
//
//  Tests para DraftBuilder. Cubre los helpers pure-logic (findAccount con array,
//  computeNeedsUserInput, matchesNature) y —desde el 2026-09-08— la coherencia entre el tipo del
//  borrador y la naturaleza de la subcategoría que le pone la memoria de comercios, que sí necesita
//  `ModelContext` porque `MerchantMemoryService` fetchea.
//
//  La cabecera decía hasta hoy que el overload con `context:` y `build()` no se cubrían aquí por una
//  «race condition de CloudKit en simulador con `makeTestContext()`». Esa premisa se MIDIÓ el
//  2026-09-08 en este árbol antes de escribir estos tests y ya no se sostiene: `SiriDraftServiceTests`
//  —misma forma, mismo helper, `@MainActor` + `@Suite(.serialized)`— lleva usándolo desde entonces en
//  verde, y el helper cambió por debajo (reuso de container por `#fileID`, wipe de los 31 modelos del
//  schema). Lo que queda cubierto solo en device es el flujo con red del parser, no esto.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct DraftBuilderTests {

    // MARK: - Helpers (Account sin SwiftData context)

    private func makeAccount(name: String = "A", currencyCode: String, archived: Bool = false) -> Account {
        let acc = Account(
            name: name,
            currencyCode: currencyCode,
            colorHex: "#000000",
            iconName: "creditcard.fill",
            type: "bank"
        )
        acc.isArchived = archived
        return acc
    }

    // MARK: - findAccount (pure-logic overload)

    @Test func findAccount_singleMatch_returnsAccount() {
        let accounts = [makeAccount(name: "BCP", currencyCode: "PEN")]
        let result = DraftBuilder.findAccount(byCurrency: "PEN", in: accounts)
        #expect(result?.name == "BCP")
    }

    @Test func findAccount_caseInsensitive() {
        let accounts = [makeAccount(currencyCode: "USD")]
        let result = DraftBuilder.findAccount(byCurrency: "usd", in: accounts)
        #expect(result != nil)
    }

    @Test func findAccount_currencyHasWhitespace_trimmed() {
        let accounts = [makeAccount(currencyCode: "EUR")]
        let result = DraftBuilder.findAccount(byCurrency: "  EUR  ", in: accounts)
        #expect(result != nil)
    }

    @Test func findAccount_noMatch_returnsNil() {
        let accounts = [makeAccount(currencyCode: "PEN")]
        let result = DraftBuilder.findAccount(byCurrency: "EUR", in: accounts)
        #expect(result == nil)
    }

    @Test func findAccount_multipleMatches_returnsNil() {
        let accounts = [
            makeAccount(name: "A1", currencyCode: "PEN"),
            makeAccount(name: "A2", currencyCode: "PEN"),
        ]
        let result = DraftBuilder.findAccount(byCurrency: "PEN", in: accounts)
        #expect(result == nil, "2 matches → ambiguo → nil")
    }

    @Test func findAccount_emptyCurrency_returnsNil() {
        let accounts = [makeAccount(currencyCode: "PEN")]
        let result = DraftBuilder.findAccount(byCurrency: "", in: accounts)
        #expect(result == nil)
    }

    @Test func findAccount_archivedExcluded() {
        let accounts = [makeAccount(currencyCode: "EUR", archived: true)]
        let result = DraftBuilder.findAccount(byCurrency: "EUR", in: accounts)
        #expect(result == nil)
    }

    @Test func findAccount_oneArchivedOneActive_returnsActive() {
        let active = makeAccount(name: "active", currencyCode: "PEN")
        let archived = makeAccount(name: "old", currencyCode: "PEN", archived: true)
        let result = DraftBuilder.findAccount(byCurrency: "PEN", in: [active, archived])
        #expect(result?.name == "active")
    }

    @Test func findAccount_emptyAccounts_returnsNil() {
        let result = DraftBuilder.findAccount(byCurrency: "PEN", in: [])
        #expect(result == nil)
    }

    // MARK: - computeNeedsUserInput

    @Test func computeNeedsUserInput_allMissing_returnsAll() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: false, hasAccount: false, hasSubcategory: false
        )
        #expect(needs == ["account", "subcategory", "amount"])
    }

    @Test func computeNeedsUserInput_allPresent_returnsEmpty() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: true, hasAccount: true, hasSubcategory: true
        )
        #expect(needs.isEmpty)
    }

    @Test func computeNeedsUserInput_onlyAccountMissing() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: true, hasAccount: false, hasSubcategory: true
        )
        #expect(needs == ["account"])
    }

    @Test func computeNeedsUserInput_onlySubcategoryMissing() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: true, hasAccount: true, hasSubcategory: false
        )
        #expect(needs == ["subcategory"])
    }

    @Test func computeNeedsUserInput_orderIsStable_accountSubcategoryAmount() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: false, hasAccount: false, hasSubcategory: true
        )
        #expect(needs == ["account", "amount"])
    }

    @Test func computeNeedsUserInput_amountAndSubcategoryMissing() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: false, hasAccount: true, hasSubcategory: false
        )
        #expect(needs == ["subcategory", "amount"])
    }

    // MARK: - matchesNature

    @Test func matchesNature_expenseSubcategory_matchesExpenseDraft() throws {
        let context = try makeTestContext()
        let sub = makeTestSubcategory(
            context: context,
            name: "Panadería",
            category: makeTestCategory(context: context, name: "Comida", isIncome: false)
        )

        #expect(DraftBuilder.matchesNature(sub, isExpense: true) == true)
        #expect(DraftBuilder.matchesNature(sub, isExpense: false) == false)
    }

    @Test func matchesNature_incomeSubcategory_matchesIncomeDraft() throws {
        let context = try makeTestContext()
        let sub = makeTestSubcategory(
            context: context,
            name: "Sueldo",
            category: makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        )

        #expect(DraftBuilder.matchesNature(sub, isExpense: false) == true)
        #expect(DraftBuilder.matchesNature(sub, isExpense: true) == false)
    }

    /// Ata el borde que documenta el docblock: una subcategoría sin categoría —CloudKit puede
    /// entregar la relación `nil` mientras el record va en vuelo— cae en el placeholder de
    /// `safeCategory`, que es `isIncome: false`, y por tanto cuenta como de GASTO. Si alguien cambia
    /// ese placeholder, el criterio se movería en silencio en el menú del card y en `updateDraft`.
    @Test func matchesNature_subcategoryWithoutCategory_countsAsExpense() {
        let orphan = Subcategory(name: "Huérfana", iconName: "cart.fill", category: nil)

        #expect(DraftBuilder.matchesNature(orphan, isExpense: true) == true)
        #expect(DraftBuilder.matchesNature(orphan, isExpense: false) == false)
    }

    // MARK: - suggestSubcategory (memoria de comercios × naturaleza)

    /// Siembra una memoria de comercio que ya supera el umbral de `decideSuggestion`
    /// (`countApproved >= 5` y `correctionRate <= 0.1` → `.autoAssign`).
    @discardableResult
    private func seedMerchantMemory(
        context: ModelContext,
        merchant: String,
        subcategory: Subcategory
    ) -> MerchantMemory {
        let memory = MerchantMemory(
            merchantCanonical: MerchantCanonicalizer.canonicalize(merchant),
            subcategory: subcategory,
            countApproved: 5,
            countCorrected: 0,
            lastApprovedAt: Date.now,
            aliases: [merchant]
        )
        context.insert(memory)
        return memory
    }

    /// **El caso del ticket.** El comercio se aprendió sobre ingresos y el texto llegó como gasto
    /// —el prompt del parser asume gasto por defecto—: la subcategoría recordada se descarta.
    @Test func suggestSubcategory_rememberedIncomeSubcategory_expenseDraft_returnsNil() throws {
        let context = try makeTestContext()
        let income = makeTestSubcategory(
            context: context,
            name: "Reintegros",
            category: makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        )
        seedMerchantMemory(context: context, merchant: "Reintegro Nómina", subcategory: income)

        let suggested = DraftBuilder.suggestSubcategory(
            merchant: "Reintegro Nómina",
            isExpense: true,
            context: context
        )

        #expect(suggested == nil)
    }

    /// Control positivo del test anterior: MISMA siembra, tipo coherente. Sin él, un fallo que
    /// devolviera siempre `nil` —una memoria que no se encuentra, un umbral mal puesto— pasaría por
    /// arreglo.
    @Test func suggestSubcategory_rememberedIncomeSubcategory_incomeDraft_returnsIt() throws {
        let context = try makeTestContext()
        let income = makeTestSubcategory(
            context: context,
            name: "Reintegros",
            category: makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        )
        seedMerchantMemory(context: context, merchant: "Reintegro Nómina", subcategory: income)

        let suggested = DraftBuilder.suggestSubcategory(
            merchant: "Reintegro Nómina",
            isExpense: false,
            context: context
        )

        #expect(suggested === income)
    }

    /// El camino común —comercio de gasto, borrador de gasto— sigue rellenando la subcategoría.
    @Test func suggestSubcategory_rememberedExpenseSubcategory_expenseDraft_returnsIt() throws {
        let context = try makeTestContext()
        let expense = makeTestSubcategory(
            context: context,
            name: "Supermercado",
            category: makeTestCategory(context: context, name: "Comida", isIncome: false)
        )
        seedMerchantMemory(context: context, merchant: "Wong", subcategory: expense)

        let suggested = DraftBuilder.suggestSubcategory(
            merchant: "Wong",
            isExpense: true,
            context: context
        )

        #expect(suggested === expense)
    }

    // MARK: - build (el borrador del chat, de punta a punta)

    private func parsed(
        note: String,
        isExpense: Bool,
        amount: Decimal? = 50,
        subcategoryHint: String? = nil
    ) -> ParsedTransaction {
        ParsedTransaction(
            amount: amount,
            date: nil,
            note: note,
            isExpense: isExpense,
            subcategoryHint: subcategoryHint,
            tagHints: [],
            currencyHint: "PEN",
            confidence: ParsedTransaction.TransactionConfidence(
                amount: 1, date: 0, merchant: 0, subcategory: 0, tags: 0
            )
        )
    }

    /// La forma en que el usuario lo vive: dicta algo que el parser resuelve como gasto sobre un
    /// comercio que su memoria tiene aprendido en ingresos. El borrador nace SIN subcategoría y
    /// pidiéndola, en vez de nacer marcado gasto con una subcategoría de ingreso — que es lo que
    /// acababa persistido como «ingreso negativo», restando del total de ingresos mientras el widget
    /// de inicio lo sumaba.
    @Test func build_rememberedSubcategoryContradictsType_leavesItEmptyAndAsksForIt() throws {
        let context = try makeTestContext()
        let income = makeTestSubcategory(
            context: context,
            name: "Reintegros",
            category: makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        )
        seedMerchantMemory(context: context, merchant: "Reintegro Nómina", subcategory: income)
        makeTestAccount(context: context, currencyCode: "PEN")

        let draft = DraftBuilder.build(
            parsed: parsed(note: "Reintegro Nómina", isExpense: true),
            defaultCurrency: "PEN",
            context: context
        )

        #expect(draft.isExpense == true)
        #expect(draft.subcategoryID == nil)
        #expect(draft.needsUserInput.contains("subcategory") == true)
    }

    /// Control positivo del anterior por el camino completo: con la naturaleza coherente, la memoria
    /// del comercio sigue rellenando la subcategoría y el borrador no pide nada.
    @Test func build_rememberedSubcategoryMatchesType_fillsItFromMerchantMemory() throws {
        let context = try makeTestContext()
        let expense = makeTestSubcategory(
            context: context,
            name: "Supermercado",
            category: makeTestCategory(context: context, name: "Comida", isIncome: false)
        )
        seedMerchantMemory(context: context, merchant: "Wong", subcategory: expense)
        makeTestAccount(context: context, currencyCode: "PEN")

        let draft = DraftBuilder.build(
            parsed: parsed(note: "Wong", isExpense: true),
            defaultCurrency: "PEN",
            context: context
        )

        #expect(draft.subcategoryID == expense.persistentModelID)
        #expect(draft.needsUserInput.isEmpty == true)
    }
}
