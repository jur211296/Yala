//
//  CerrarSesionCuentaVaciaTests.swift
//  YalaTests / CerrarSesionCuentaVacia
//
//  Card «Cerrar sesión en una cuenta vacía dice “Cambios por subir: 893”» (Jürgen, 2026-11-19, build 2.3 (5)). Lo que
//  la app escribe sola —tipos de cambio, categorías y avisos de serie, el papel de sistema de sus subcategorías— no es un
//  cambio de la persona: no infla el contador del cierre privado ni lo hace esperar. Lo de la persona sí.
//
//  Historial REAL, con el andamio de `PersonalExportPendingCounterTests` (tres stores on-disk y un contexto que los
//  abarca: el historial es por container). El ancla es anterior a todo, como en un iPhone que ya usó iCloud: el ancla
//  sobrevive al borrado del cierre y cada alta nueva queda después de ella.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Cerrar sesión en una cuenta vacía: lo que la app crea sola no cuenta", .serialized)
@MainActor
struct CerrarSesionCuentaVaciaTests {

    // MARK: - Andamio

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CuentaVacia-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CV-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CV-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CV-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func count(_ context: ModelContext, since anchor: Date?) -> Int? {
        PersonalExportPendingCounter.pendingChangeCount(context: context, confirmedExportStart: anchor)
    }

    /// Un ancla anterior a todo: la de un iPhone que ya subió algo a iCloud antes de crear esta cuenta.
    private let anchorBeforeEverything = Date.distantPast

    private struct EmptyAccount {
        let seedCategory: Yala.Category
        let seedSubcategory: Subcategory
        let systemRoleSubcategory: Subcategory
        let defaultNotification: NotificationItem
        let rate: ExchangeRate
    }

    /// Lo que deja una cuenta nueva sin que la persona toque nada, con la misma anatomía que en producción (medido en el
    /// simulador el 2026-11-19: 11 categorías, 62 subcategorías y 7 avisos; en un iPhone, además, un año de tipos de
    /// cambio). Aquí una muestra de cada clase, y una fila de tipos de cambio por día de un año.
    private func seedEmptyAccount(_ context: ModelContext) throws -> EmptyAccount {
        let food = Yala.Category(name: "Alimentación", colorHex: "#22C55E", isIncome: false, isDefaultSeed: true,
                                 isVisible: true, sortOrder: 0, iconName: "cart.fill")
        context.insert(food)
        let restaurants = Subcategory(name: "Restaurantes", colorHex: nil, isDefaultSeed: true, isVisible: true,
                                      sortOrder: 0, natureRawValue: "opcional", iconName: "fork.knife", category: food)
        context.insert(restaurants)
        let transfers = Subcategory(name: "Transferencia entre cuentas", colorHex: nil, isDefaultSeed: true,
                                    isVisible: true, sortOrder: 1, natureRawValue: nil, iconName: "arrow.left.arrow.right",
                                    category: food)
        context.insert(transfers)
        // Categoría de sistema de Grupos (`seedSystemGroupCategoriesIfNeeded`), sin marca de serie.
        let groups = Yala.Category(name: "Grupos", colorHex: "#6366F1", isIncome: false, isDefaultSeed: false,
                                   isVisible: true, sortOrder: 99, iconName: "person.2.fill")
        groups.isSystem = true
        context.insert(groups)
        let notifications = NotificationItem.createDefaults()
        for item in notifications { context.insert(item) }
        try context.save()

        var firstRate: ExchangeRate?
        let day: TimeInterval = 86_400
        for index in 0..<366 {
            let date = Date(timeIntervalSince1970: 1_731_000_000 + Double(index) * day)
            let key = ISO8601DateFormatter().string(from: date).prefix(10)
            let rate = try ExchangeRate(dateKey: String(key), base: "USD", ratesDictionary: ["PEN": 3.75])
            context.insert(rate)
            if firstRate == nil { firstRate = rate }
        }
        try context.save()

        // El arranque siguiente escribe el papel de sistema de las subcategorías de serie (`SubcategorySystemRoleBackfill`).
        transfers.systemRole = .transfer
        try context.save()

        return EmptyAccount(seedCategory: food, seedSubcategory: restaurants, systemRoleSubcategory: transfers,
                            defaultNotification: try #require(notifications.first), rate: try #require(firstRate))
    }

    // MARK: - El caso de Jürgen

    @Test("una cuenta nueva sin tocar no tiene cambios por subir")
    func emptyAccount_hasNothingToUpload() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        _ = try seedEmptyAccount(context)

        #expect(count(context, since: anchorBeforeEverything) == 0, "contó \(String(describing: count(context, since: anchorBeforeEverything)))")
        // Sin ancla (nunca se vio un export) tampoco hay nada de la persona: cero honesto, no «no se puede contar».
        #expect(count(context, since: nil) == 0, "contó \(String(describing: count(context, since: nil)))")
    }

    // MARK: - Lo de la persona sigue contando

    @Test("un registro de la persona cuenta, también en una cuenta recién creada")
    func userRecord_counts() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        _ = try seedEmptyAccount(context)
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_760_000_000), amount: -12, currencyCode: "PEN"))
        try context.save()

        #expect(count(context, since: anchorBeforeEverything) == 1, "contó \(String(describing: count(context, since: anchorBeforeEverything)))")
        // Sin ancla, con algo de la persona, no hay número honesto: sigue siendo «no se puede contar».
        #expect(count(context, since: nil) == nil, "contó \(String(describing: count(context, since: nil)))")
    }

    @Test("editar una categoría de serie la vuelve de la persona")
    func editedSeedCategory_counts() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let account = try seedEmptyAccount(context)
        account.seedCategory.name = "Comida"
        try context.save()

        #expect(count(context, since: anchorBeforeEverything) == 1, "contó \(String(describing: count(context, since: anchorBeforeEverything)))")
    }

    @Test("editar una subcategoría de serie además del papel de sistema cuenta")
    func systemRolePlusAPersonEdit_counts() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let account = try seedEmptyAccount(context)
        account.systemRoleSubcategory.iconName = "banknote"
        try context.save()

        #expect(count(context, since: anchorBeforeEverything) == 1, "contó \(String(describing: count(context, since: anchorBeforeEverything)))")
    }

    /// Borrar una subcategoría de serie cuenta, y su categoría también: el historial anota el cambio de la relación en la
    /// categoría madre (medido, 2026-11-19). Es lo que el contador hacía antes de este arreglo; aquí solo se fija que lo
    /// de la persona no desaparece por venir de algo que creó la app.
    @Test("borrar una subcategoría de serie cuenta: el borrado tiene que viajar")
    func deletedSeed_counts() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let account = try seedEmptyAccount(context)
        context.delete(account.seedSubcategory)
        try context.save()

        #expect(count(context, since: anchorBeforeEverything) == 2, "contó \(String(describing: count(context, since: anchorBeforeEverything)))")
    }

    @Test("un aviso de serie que la persona activa cuenta")
    func activatedDefaultNotification_counts() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let account = try seedEmptyAccount(context)
        account.defaultNotification.isActive.toggle()
        try context.save()

        #expect(count(context, since: anchorBeforeEverything) == 1, "contó \(String(describing: count(context, since: anchorBeforeEverything)))")
    }

    @Test("una categoría que crea la persona cuenta")
    func userCategory_counts() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        _ = try seedEmptyAccount(context)
        context.insert(Yala.Category(name: "Mascotas", colorHex: "#F59E0B", isIncome: false, isDefaultSeed: false,
                                     isVisible: true, sortOrder: 20, iconName: "pawprint.fill"))
        try context.save()

        #expect(count(context, since: anchorBeforeEverything) == 1, "contó \(String(describing: count(context, since: anchorBeforeEverything)))")
    }

    /// Si no se puede leer qué creó la app, no se descuenta nada: cuenta todo, como antes del arreglo. Leído como «nada
    /// de la app», una tabla ilegible restaba también las altas de la persona y el cierre borraba sin subir.
    @Test("si no se puede leer lo creado por la app, cuenta todo")
    func unreadableDefaults_countEverything() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        _ = try seedEmptyAccount(context)
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_760_000_000), amount: -12, currencyCode: "PEN"))
        try context.save()
        // Control: legible, solo el registro.
        #expect(count(context, since: anchorBeforeEverything) == 1)

        PersonalExportPendingCounter._testThrowOnDefaultsFetch = true
        defer { PersonalExportPendingCounter._testThrowOnDefaultsFetch = false }
        let unreadable = count(context, since: anchorBeforeEverything) ?? 0
        // Las dos categorías, las dos subcategorías, los avisos de serie y el registro: nada se descuenta.
        let notifications = NotificationItem.createDefaults().count
        #expect(unreadable == 4 + notifications + 1, "contó \(unreadable)")
    }

    // MARK: - Los tipos de cambio nunca

    @Test("los tipos de cambio no cuentan, ni al bajarlos, ni al fusionarlos, ni al borrarlos")
    func exchangeRates_neverCount() throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let account = try seedEmptyAccount(context)
        account.rate.rates = try JSONEncoder().encode(["PEN": 3.8, "EUR": 0.9])
        try context.save()
        context.delete(account.rate)
        try context.save()

        #expect(count(context, since: anchorBeforeEverything) == 0, "contó \(String(describing: count(context, since: anchorBeforeEverything)))")
    }
}
