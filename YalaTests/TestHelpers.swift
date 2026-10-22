//
//  TestHelpers.swift
//  YalaTests
//
//  Utilities for creating test contexts and mock data
//

import Foundation
import SwiftData

@testable import Yala

// MARK: - Type Aliases (to avoid ambiguity with Foundation types)

typealias YalaCategory = Yala.Category
typealias YalaTag = Yala.Tag

// MARK: - Isolated UserDefaults

/// Crea un `UserDefaults` con suite name único por test (UUID), totalmente aislado
/// de `UserDefaults.standard` y de otros tests corriendo en el mismo proceso.
///
/// Úsalo cuando el SUT acepta `UserDefaults` inyectable. Si el SUT toca
/// `UserDefaults.standard` directamente, este helper no aísla — usa
/// `@Suite(.serialized)` y limpia con `defer { remove }`.
///
/// Ver TESTING-STRATEGY.md (sección "Anti-patrones detectados") para detalles.
func makeIsolatedDefaults(prefix: String = "test") -> UserDefaults {
    let suiteName = "\(prefix).\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Failed to create isolated UserDefaults suite: \(suiteName)")
    }
    return defaults
}

// MARK: - In-Memory SwiftData Context

/// Containers in-memory REUSADOS por archivo de test (`#fileID`), no uno por llamada.
///
/// **Por qué reusar (fix 2026-07-04):** crear un `ModelContainer` nuevo por cada
/// `makeTestContext()` acumula estado global en SwiftData/CoreData
/// (`NSPersistentStoreCoordinator`/`NSManagedObjectModel`) que NO se libera al deallocar
/// el container in-memory. Tras ~15 CREACIONES en un mismo proceso SwiftData dispara un
/// `EXC_BREAKPOINT`/SIGTRAP (no atrapable) al instanciar/insertar `@Model` — crash-loop
/// del runner. Repro confirmada en iOS 26.2 y 26.5, sim recién erasado, con/sin
/// `.serialized`, con `-parallel-testing-enabled NO`; un test suelto (1 container) SIEMPRE
/// pasa, la suite entera (15 containers) crash-loopea. El crash escala con el nº de
/// containers CREADOS, no con los tests → reusar baja la exposición.
///
/// **Por qué por-archivo y no global:** un único container global comparte store entre
/// TODAS las suites, y Swift Testing corre suites distintas en paralelo (aun con
/// `-parallel-testing-enabled NO`, e incluso tests síncronos `@MainActor` se interleavean)
/// → se pisan los datos (fallos flaky de aislamiento cruzado). Un container por archivo da
/// aislamiento entre suites (cada archivo = una suite aquí); `parallel YES` reparte los
/// ~19 archivos entre procesos-clon → pocos containers por proceso → bajo el umbral.
/// Dentro de un archivo, la suite DEBE ser `@Suite(.serialized)` (los tests reusan el
/// container del archivo y no deben solaparse). Ver TESTING-STRATEGY.md.
@MainActor
private var _testContainersByFile: [String: ModelContainer] = [:]

@MainActor
private func testContainer(for fileID: String) throws -> ModelContainer {
    if let container = _testContainersByFile[fileID] { return container }
    let idx = _testContainersByFile.count
    // `cloudKitDatabase: .none` evita que SwiftData adjunte NSPersistentCloudKitContainer
    // (el default `.automatic` lo adjunta por entitlement + schema con relaciones, aun
    // in-memory) → sin loops de CloudKit recovery en sims sin cuenta iCloud (CI).
    // Nombres únicos por container (idx) para no chocar con el container del host ni entre sí.
    let personalConfig = ModelConfiguration(
        "YalaPersonal_test_\(idx)",
        schema: SwiftDataConfiguration.personalSchema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let groupsConfig = ModelConfiguration(
        "YalaGroups_test_\(idx)",
        schema: SwiftDataConfiguration.groupsSchema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    // Sync-meta store (Modo Nube I2): SyncIdentity vive en su propia config (`.none`), igual que en
    // producción. El schema global la incluye → toda config del schema debe tener su store asignado.
    let syncMetaConfig = ModelConfiguration(
        "YalaSyncMeta_test_\(idx)",
        schema: SwiftDataConfiguration.syncMetaSchema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let container = try ModelContainer(
        for: SwiftDataConfiguration.schema,
        configurations: personalConfig, groupsConfig, syncMetaConfig
    )
    _testContainersByFile[fileID] = container
    return container
}

/// Devuelve el `mainContext` del container del archivo llamante, **vaciado** para que cada
/// test arranque con un store vacío (paridad con el comportamiento previo de "container fresco").
///
/// **Aislamiento:** el store se reusa entre tests del MISMO archivo, así que la suite DEBE
/// ser `@Suite(.serialized)` para que sus tests no se solapen. Ver TESTING-STRATEGY.md.
@MainActor
func makeTestContext(fileID: String = #fileID) throws -> ModelContext {
    let container = try testContainer(for: fileID)
    let context = container.mainContext
    // Autosave OFF: el `mainContext` reusado, con autosave ON, difería saves que bajo
    // alta concurrencia (suite completa) aterrizaban DESPUÉS del wipe del siguiente test
    // → residuo cruzado. Con autosave OFF la persistencia es solo explícita/síncrona.
    context.autosaveEnabled = false
    // Reset: descarta cambios pendientes + borra todas las instancias de cada @Model.
    // NO usar `container.deleteAllData()`: en un store in-memory elimina el data store
    // entero → `Fatal error: Container does not have any data stores` al reusar mainContext.
    context.rollback()
    wipeAllModels(context)
    return context
}

/// Borra todas las instancias de cada `@Model` del schema (sin destruir el store).
/// Mantener sincronizado con `SwiftDataConfiguration.schema` (**31 modelos**).
///
/// El conteo importa y por eso lo pinnea `wipeCoversEveryModelInTheSchema`: hasta el
/// 2026-09-02 este docblock decía «22 modelos» y borraba justo esos 22, dejando fuera los
/// **nueve de sync y migración**. Como `makeTestContext()` REUSA el container por `#fileID`,
/// una fila de esos nueve sobrevivía de un test al siguiente del mismo fichero, y el orden
/// dentro de una suite `.serialized` no está garantizado: eso es lo que ponía en rojo a
/// `HandoverGroupsDomainTests.wipeLocalGroupsDomain_killsTheOutbox_butKEEPSTheCursor` en CI
/// —contaba 2 cursores donde esperaba 1— mientras pasaba en local. Un helper que promete
/// «todas las instancias de cada `@Model`» y cumple con 22 de 31 no aísla: filtra.
@MainActor
private func wipeAllModels(_ context: ModelContext) {
    // Fetch + delete por objeto (NO `context.delete(model:)`): el bulk-delete opera a nivel
    // de la entidad del `NSManagedObjectModel` compartido por todos los containers del mismo
    // schema → borra instancias de OTROS containers de test (fallos de aislamiento cruzado en
    // la suite completa). El fetch/delete por objeto queda acotado al store de ESTE contexto.
    func wipe<T: PersistentModel>(_ type: T.Type) {
        do {
            // Fetch + delete por objeto: `context.delete(model:)` (bulk) opera a nivel de la
            // entidad del `NSManagedObjectModel` COMPARTIDO por todos los containers del mismo
            // schema y deja el store del contexto reusado en un estado inconsistente entre tests
            // (fugas de identidad → `persistentModelID` de un test previo contamina al siguiente;
            // p.ej. `dedup_preservesTransactionSubcategoryRef` pasaba a solas pero fallaba tras
            // sus hermanos). El fetch/delete por objeto queda acotado al store de ESTE contexto.
            let objects = try context.fetch(FetchDescriptor<T>())
            for object in objects { context.delete(object) }
        } catch {
            print("makeTestContext: wipe error for \(type): \(error)")
        }
    }
    wipe(YalaCategory.self); wipe(Subcategory.self); wipe(YalaTag.self); wipe(Account.self)
    wipe(TransactionItem.self); wipe(Budget.self); wipe(ExchangeRate.self)
    wipe(FavoritePayment.self); wipe(ScheduledPayment.self); wipe(InboxDraft.self)
    wipe(MerchantMemory.self); wipe(NotificationItem.self); wipe(CashFlowPlan.self)
    wipe(CashFlowLine.self); wipe(CashFlowOverride.self); wipe(GroupBridgePreference.self)
    wipe(SplitGroup.self); wipe(SplitMember.self); wipe(SplitExpense.self)
    wipe(SplitShare.self); wipe(SplitSettlement.self); wipe(SyncIdentity.self)
    // Los nueve de sync y migración. Van DESPUÉS de los de dominio a propósito: los de arriba
    // pueden dejar filas de outbox al borrarse si algún observador las encola, así que vaciar
    // la cola antes que su origen la volvería a llenar.
    wipe(SyncOutbox.self); wipe(SyncCursor.self); wipe(SyncQuarantine.self)
    wipe(SyncDanglingRef.self); wipe(SyncUnitClock.self); wipe(MigrationState.self)
    wipe(CloudMigrationMarker.self); wipe(GroupSyncOutbox.self); wipe(GroupSyncCursor.self)
    if context.hasChanges {
        do { try context.save() } catch { print("makeTestContext: reset save error: \(error)") }
    }
}

// MARK: - Factory Methods

@MainActor
func makeTestAccount(
    context: ModelContext,
    name: String = "Test Account",
    currencyCode: String = "PEN"
) -> Account {
    let account = Account(
        name: name,
        currencyCode: currencyCode,
        colorHex: "#6366F1",
        iconName: "creditcard.fill",
        type: "bank"
    )
    context.insert(account)
    return account
}

@MainActor
func makeTestCategory(
    context: ModelContext,
    name: String = "Test Category",
    isIncome: Bool = false
) -> YalaCategory {
    let category = YalaCategory(
        name: name,
        colorHex: "#EF4444",
        isIncome: isIncome
    )
    context.insert(category)
    return category
}

@MainActor
func makeTestSubcategory(
    context: ModelContext,
    name: String = "Test Subcategory",
    category: YalaCategory,
    need: SubcategoryNeed = .essential
) -> Subcategory {
    let subcategory = Subcategory(
        name: name,
        colorHex: nil,
        natureRawValue: need.rawValue,
        iconName: "cart.fill",
        category: category
    )
    context.insert(subcategory)
    return subcategory
}

@MainActor
func makeTestTag(
    context: ModelContext,
    name: String = "Test Tag"
) -> Tag {
    let tag = Tag(name: name, colorHex: "#8B5CF6", iconName: "tag.fill")
    context.insert(tag)
    return tag
}

@MainActor
func makeTestBudget(
    context: ModelContext,
    name: String = "Test Budget",
    limitAmount: Double = 1000.0,
    periodType: BudgetPeriodType = .monthly,
    isActive: Bool = true,
    accounts: [Account] = [],
    subcategories: [Subcategory] = [],
    tags: [Tag] = [],
    startDate: Date? = nil,
    endDate: Date? = nil,
    subcategoryIDs: String? = nil,
    accountIDs: String? = nil,
    tagIDs: String? = nil
) -> Budget {
    let budget = Budget(
        currencyCode: "PEN",
        limitAmount: limitAmount,
        name: name,
        periodType: periodType.rawValue,
        startDate: startDate,
        endDate: endDate,
        accounts: accounts,
        subcategories: subcategories,
        tags: tags,
        isActive: isActive,
        subcategoryIDs: subcategoryIDs,
        accountIDs: accountIDs,
        tagIDs: tagIDs
    )
    context.insert(budget)
    return budget
}

@MainActor
func makeTestTransaction(
    context: ModelContext,
    amount: Double,
    date: Date = Date(),
    account: Account,
    category: YalaCategory,
    subcategory: Subcategory,
    currencyCode: String? = nil,
    tags: [Tag] = []
) -> TransactionItem {
    let transaction = TransactionItem(
        date: date,
        amount: amount,
        currencyCode: currencyCode ?? account.currencyCode,
        note: nil,
        category: category,
        subcategory: subcategory,
        account: account,
        tags: tags,
        exchangeRate: 1.0,
        amountInPreferredCurrency: amount,
        preferredCurrencyCode: "PEN"
    )
    context.insert(transaction)
    return transaction
}

// MARK: - Date Helpers

/// Get start of current month
func startOfCurrentMonth() -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: Date())
    return calendar.date(from: components) ?? Date()
}

/// Get start of current week
func startOfCurrentWeek() -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
    return calendar.date(from: components) ?? Date()
}

/// Get date N days from now
func dateOffset(days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
}

/// Get date N months from now
func dateOffset(months: Int) -> Date {
    Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
}

// MARK: - Context-Free Factories (no ModelContext needed)

func makeBudget(
    periodType: String = "monthly",
    startDate: Date? = nil,
    endDate: Date? = nil,
    limitAmount: Double = 1000
) -> Budget {
    Budget(
        currencyCode: "USD",
        limitAmount: limitAmount,
        periodType: periodType,
        startDate: startDate,
        endDate: endDate
    )
}

// MARK: - InboxDraft Factory

@MainActor
func makeTestInboxDraft(
    context: ModelContext,
    amount: Double? = 50.0,
    date: Date? = nil,
    note: String = "Test draft"
) -> InboxDraft {
    let draft = InboxDraft(
        note: note,
        amount: amount,
        date: date ?? Date(),
        sourceType: .voice
    )
    context.insert(draft)
    return draft
}

// MARK: - ExchangeRate Factory

@MainActor
func makeTestExchangeRate(
    context: ModelContext,
    dateKey: String = "2026-01-15",
    rates: [String: Double] = ["PEN": 3.75, "EUR": 0.92, "USD": 1.0]
) throws -> ExchangeRate {
    let rate = try ExchangeRate(
        dateKey: dateKey,
        base: "USD",
        ratesDictionary: rates
    )
    context.insert(rate)
    return rate
}
