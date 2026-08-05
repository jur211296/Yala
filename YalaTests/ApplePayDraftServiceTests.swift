//
//  ApplePayDraftServiceTests.swift
//  YalaTests
//
//  Cubre ApplePayDraftService.processPending (commits a3b68405 / db397ce7): materialización de
//  la cola de gastos de Apple Pay (App Group) como InboxDrafts, DESDE la app.
//
//  Verifica: resolución de divisa/cuenta, drop de monto cero/no-parseable, matching de
//  MerchantMemory (umbrales 0.95 autoAssign / 0.8 suggest), consume-after-save (la señal
//  pendiente se limpia tras crear el draft) e idempotencia (segunda llamada no duplica).
//
//  NOTA sobre acceso al App Group: `ApplePayDraftService.processPending` llama a
//  `ApplePayPendingStore.peekAll()` / `.remove()` y a `LastUsedAccountStore.read()` SIN inyección
//  de `UserDefaults` — usan el App Group real del proceso. Por eso esta suite es
//  `@Suite(.serialized)` (además del contrato de `makeTestContext`). La cola pending va por la API
//  pública de `ApplePayPendingStore` (que sí acepta `defaults` inyectable) apuntando al MISMO App
//  Group que lee `processPending`, para no depender de detalles internos del suite name.
//
//  `lastUsedAccountID` NO es inyectable y vive en el App Group REAL, que sobrevive al proceso y
//  comparten el host de los unit tests y el de los XCUITest. Lo aísla `.lastUsedAccountIsolated`
//  (`SharedStateIsolation.swift`), que lo limpia al entrar y lo devuelve al salir. **Hasta el
//  2026-08-05 esto lo hacía un `removeObject` en el `init()` y este mismo docblock afirmaba que
//  además se limpiaba «en `deinit`»: la suite es un `struct` y no puede tener `deinit`, así que la
//  garantía no existía —solo el borrado— y la última cuenta usada del simulador se perdía en cada
//  corrida.** Medido con un centinela plantado en el App Group: con el código de entonces
//  desaparece; con el trait puesto sobrevive a los 17 tests.
//
//  No devuelvas ese `removeObject` al `init()`. No porque rompa hoy —el scope envuelve también la
//  construcción de la suite, así que el `init()` corre DESPUÉS del capture y el borrado sería
//  redundante con el clear— sino porque su inocuidad depende por completo de que nadie quite el
//  trait, y es el patrón que se copia a la siguiente suite. Lo pinnea
//  `SharedStateIsolationTests.ningunInitDeSuiteBorraLaUltimaCuentaUsada`.
//
//  NOTA (no cubierto): el gate de quiescencia (`iCloudSyncService.shared.isImportQuiescent`) se
//  fuerza a `true` vía `_testReset()` (status .idle + lastImportDate nil → .run). El PATH de
//  "gate NO pasa → no consume" no se testea aquí de forma determinista porque requeriría
//  inyectar un estado de import en curso en el singleton, y `SubcategoryDedupGate.decide` ya
//  tiene su propia cobertura pure-logic. El error-path de save fallido (rollback de inserts) es
//  difícil de forzar sin un context mockeable (el save in-memory no falla) → no cubierto.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized, .lastUsedAccountIsolated)
@MainActor
struct ApplePayDraftServiceTests {

    /// Cola pending AISLADA por-suite: `processPending` lee esta MISMA instancia (vía el nuevo
    /// parámetro `pendingStoreDefaults`). Evita la contaminación cross-test del App Group
    /// compartido del proceso — otro test tocando `applePayPending.*` en paralelo cambiaría lo
    /// que ve el SUT (causa del flaky `noMatchingAccount` en la suite completa). Suite UUID única
    /// por instancia (Swift Testing crea una instancia por @Test) → siempre arranca vacía.
    private let pendingDefaults: UserDefaults

    /// El `init()` NO toca el App Group a propósito: la premisa «se arranca sin última cuenta usada»
    /// la da el clear de `.lastUsedAccountIsolated`, y hacerlo aquí volvería a romper la restauración
    /// (ver el docblock de arriba).
    init() {
        pendingDefaults = UserDefaults(suiteName: "test.applepay.pending.\(UUID().uuidString)")!
        // Quiescencia garantizada: status .idle + lastSuccessfulImportDate nil → gate .run.
        iCloudSyncService.shared._testReset()
    }

    // MARK: - Helpers

    /// Encola un pago en la cola AISLADA (misma instancia que consume `processPending`).
    private func enqueue(rawAmount: String, merchant: String? = nil, savedAt: Double = 1_700_000_000) {
        let expense = ApplePayPendingExpense(rawAmount: rawAmount, merchant: merchant, savedAt: savedAt)
        ApplePayPendingStore.append(expense, defaults: pendingDefaults)
    }

    private func pendingCount() -> Int {
        ApplePayPendingStore.peekAll(defaults: pendingDefaults).count
    }

    private func fetchDrafts(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>())
    }

    /// Crea una MerchantMemory con N aprobaciones y M correcciones para un merchant canónico.
    @discardableResult
    private func makeMerchantMemory(
        context: ModelContext,
        merchant: String,
        subcategory: Subcategory,
        countApproved: Int,
        countCorrected: Int
    ) -> MerchantMemory {
        let memory = MerchantMemory(
            merchantCanonical: MerchantCanonicalizer.canonicalize(merchant),
            subcategory: subcategory,
            countApproved: countApproved,
            countCorrected: countCorrected,
            lastApprovedAt: Date.now,
            aliases: [merchant]
        )
        context.insert(memory)
        return memory
    }

    // MARK: - Empty / no-op

    @Test func emptyQueue_createsNothing() throws {
        let context = try makeTestContext()
        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)
        #expect(created == 0)
        #expect(try fetchDrafts(context).isEmpty)
    }

    // MARK: - Amount handling

    @Test func parseableAmount_createsExpenseDraftAsNegative() throws {
        let context = try makeTestContext()
        enqueue(rawAmount: "$32.04", merchant: "Cafe")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let drafts = try fetchDrafts(context)
        #expect(drafts.count == 1)
        // Apple Pay siempre es gasto → monto negativo (-abs).
        #expect(drafts.first?.amount == -32.04)
        #expect(drafts.first?.sourceType == .applePay)
    }

    @Test func zeroAmount_droppedNotMaterialized() throws {
        let context = try makeTestContext()
        enqueue(rawAmount: "$0.00", merchant: "Hold")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 0)
        #expect(try fetchDrafts(context).isEmpty)
        // Los descartados se borran de la cola aunque no se materialicen (no reintentar).
        #expect(pendingCount() == 0)
    }

    @Test func unparseableAmount_droppedNotMaterialized() throws {
        let context = try makeTestContext()
        enqueue(rawAmount: "no numbers here", merchant: "Junk")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 0)
        #expect(try fetchDrafts(context).isEmpty)
        #expect(pendingCount() == 0)
    }

    // MARK: - Currency / account resolution

    @Test func unambiguousCurrency_matchesSingleAccountByCurrency() throws {
        let context = try makeTestContext()
        let eurAccount = makeTestAccount(context: context, name: "Euros", currencyCode: "EUR")
        try context.save()
        enqueue(rawAmount: "€50", merchant: "Shop")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let draft = try fetchDrafts(context).first
        // Comparar por shortcutID (UUID de identidad estable), NO persistentModelID: bajo la
        // concurrencia del container reusado de tests, el persistentModelID in-memory es frágil.
        #expect(draft?.account?.shortcutID == eurAccount.shortcutID)
        // Cuenta resuelta → "account" NO está en needsUserInput.
        #expect(draft?.needsUserInput.contains(DraftInputRequirement.account) == false)
    }

    @Test func ambiguousDollar_resolvedByLastUsedAccountCurrency() throws {
        let context = try makeTestContext()
        // Dos cuentas $ ambiguas: ARS y USD. Sin desambiguar, "$" → USD default → 0 match ARS,
        // pero con lastUsed apuntando a la cuenta ARS, la divisa se refina a ARS.
        let arsAccount = makeTestAccount(context: context, name: "Pesos", currencyCode: "ARS")
        _ = makeTestAccount(context: context, name: "Dolares", currencyCode: "USD")
        // shortcutID es var; lo usamos como la "última cuenta usada" del App Group.
        let arsShortcut = UUID()
        arsAccount.shortcutID = arsShortcut
        try context.save()
        LastUsedAccountStore.write(arsShortcut.uuidString)

        enqueue(rawAmount: "$120", merchant: "Kiosco")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let draft = try fetchDrafts(context).first
        // Divisa refinada a ARS por la última cuenta usada → matchea la cuenta ARS única.
        #expect(draft?.account?.currencyCode == "ARS")
    }

    @Test func noMatchingAccount_draftCreatedWithNilAccountAndNeedsInput() throws {
        let context = try makeTestContext()
        // Cuenta en PEN, pago en EUR → 0 match → draft con account nil (D3).
        _ = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        try context.save()
        enqueue(rawAmount: "€75", merchant: "Tienda")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let draft = try fetchDrafts(context).first
        #expect(draft?.account == nil)
        #expect(draft?.needsUserInput.contains(DraftInputRequirement.account) == true)
    }

    @Test func systemAccountsExcludedFromCurrencyMatch() throws {
        let context = try makeTestContext()
        // Solo hay una cuenta EUR pero es de sistema → excluida → 0 cuentas reales → account nil.
        let system = makeTestAccount(context: context, name: "System EUR", currencyCode: "EUR")
        system.isSystemAccount = true
        try context.save()
        enqueue(rawAmount: "€40", merchant: "X")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        #expect(try fetchDrafts(context).first?.account == nil)
    }

    @Test func twoAccountsSameCurrency_noAutoMatch() throws {
        let context = try makeTestContext()
        // 2 cuentas EUR → match ambiguo → nil (el usuario elige al aprobar).
        _ = makeTestAccount(context: context, name: "EUR A", currencyCode: "EUR")
        _ = makeTestAccount(context: context, name: "EUR B", currencyCode: "EUR")
        try context.save()
        enqueue(rawAmount: "€10", merchant: "Y")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        #expect(try fetchDrafts(context).first?.account == nil)
    }

    // MARK: - MerchantMemory matching (umbrales 0.95 / 0.8)

    @Test func merchantMemory_autoAssign_setsConfidence095() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context, name: "Comida")
        let sub = makeTestSubcategory(context: context, name: "Supermercado", category: category)
        // countApproved >= 5 && correctionRate <= 0.1 → autoAssign.
        makeMerchantMemory(context: context, merchant: "Wong", subcategory: sub,
                           countApproved: 6, countCorrected: 0)
        try context.save()
        enqueue(rawAmount: "$25", merchant: "Wong")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let draft = try fetchDrafts(context).first
        #expect(draft?.subcategory?.shortcutID == sub.shortcutID)
        #expect(draft?.confidenceSubcategory == 0.95)
    }

    @Test func merchantMemory_suggest_setsConfidence08() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context, name: "Transporte")
        let sub = makeTestSubcategory(context: context, name: "Taxi", category: category)
        // countApproved >= 3 && correctionRate <= 0.3 (pero NO autoAssign) → suggest.
        makeMerchantMemory(context: context, merchant: "Uber", subcategory: sub,
                           countApproved: 3, countCorrected: 0)
        try context.save()
        enqueue(rawAmount: "$15", merchant: "Uber")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let draft = try fetchDrafts(context).first
        #expect(draft?.subcategory?.shortcutID == sub.shortcutID)
        #expect(draft?.confidenceSubcategory == 0.8)
    }

    @Test func merchantMemory_belowThreshold_noSubcategory() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context, name: "Ocio")
        let sub = makeTestSubcategory(context: context, name: "Cine", category: category)
        // countApproved < 3 → .none → sin subcategoría ni confidence.
        makeMerchantMemory(context: context, merchant: "Cineplanet", subcategory: sub,
                           countApproved: 1, countCorrected: 0)
        try context.save()
        enqueue(rawAmount: "$20", merchant: "Cineplanet")

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let draft = try fetchDrafts(context).first
        #expect(draft?.subcategory == nil)
        #expect(draft?.confidenceSubcategory == nil)
        #expect(draft?.needsUserInput.contains(DraftInputRequirement.subcategory) == true)
    }

    @Test func emptyMerchant_skipsMemoryLookup() throws {
        let context = try makeTestContext()
        // Merchant nil → sin lookup → sin subcategoría, note vacío.
        enqueue(rawAmount: "$18", merchant: nil)

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let draft = try fetchDrafts(context).first
        #expect(draft?.subcategory == nil)
        #expect(draft?.note == "")
    }

    // MARK: - Consume-after-save

    @Test func consumeAfterSave_clearsPendingQueue() throws {
        let context = try makeTestContext()
        enqueue(rawAmount: "$10", merchant: "A")
        #expect(pendingCount() == 1)

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        // La señal pendiente se limpia tras crear el draft (consume-after-save).
        #expect(pendingCount() == 0)
    }

    // MARK: - Idempotencia

    @Test func idempotent_secondCallDoesNotDuplicate() throws {
        let context = try makeTestContext()
        enqueue(rawAmount: "$44", merchant: "B")

        let first = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)
        let second = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(first == 1)
        #expect(second == 0)
        // Solo un draft: la cola quedó vacía tras el primer pase.
        #expect(try fetchDrafts(context).count == 1)
    }

    // MARK: - Múltiples pagos en un pase

    @Test func multiplePending_materializedInOnePass() throws {
        let context = try makeTestContext()
        enqueue(rawAmount: "$5", merchant: "One", savedAt: 1_700_000_001)
        enqueue(rawAmount: "$7", merchant: "Two", savedAt: 1_700_000_002)

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 2)
        #expect(try fetchDrafts(context).count == 2)
        #expect(pendingCount() == 0)
    }

    @Test func mixedValidAndZero_onlyValidMaterialized_bothConsumed() throws {
        let context = try makeTestContext()
        enqueue(rawAmount: "$0", merchant: "Zero", savedAt: 1_700_000_001)
        enqueue(rawAmount: "$9", merchant: "Valid", savedAt: 1_700_000_002)

        let created = ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)

        #expect(created == 1)
        let drafts = try fetchDrafts(context)
        #expect(drafts.count == 1)
        #expect(drafts.first?.amount == -9)
        // El válido se consume tras save; el cero se descarta → cola vacía.
        #expect(pendingCount() == 0)
    }
}
