//
//  SubcategoryStableRoleTests.swift
//  YalaTests
//
//  Ticket `transfer-and-adjustment-subcategories-need-a-stable-role`. Decisión de Jürgen (2026-11-13): la subcategoría de
//  transferencia que Yala siembra es de sistema en todos los idiomas y Yala reconoce transferencias y ajustes por un
//  papel estable (`Subcategory.systemRole`), nunca por el nombre. Una creada a mano con el mismo nombre queda normal.
//
//  El store «de 2.2» se modela como lo deja la migración ligera: las mismas filas con `systemRoleRaw == nil`. Añadir un
//  atributo opcional es la migración automática de SwiftData, y el esquema de 2.2 no vive en el repo para abrirlo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Transferencias y ajustes se reconocen por su papel", .serialized)
struct SubcategoryStableRoleTests {

    // MARK: - Fixture: un store de 2.2 con la semilla en español y en inglés

    private struct Store22 {
        let otherES: YalaCategory
        let incomeES: YalaCategory
        let adjustmentES: Subcategory
        let transferOutES: Subcategory
        let transferInES: Subcategory
        let otherEN: YalaCategory
        let adjustmentEN: Subcategory
        /// «Account transfer» sembrada en «Other»: hasta 2.2 era normal y el usuario la elegía a mano.
        let accountTransferEN: Subcategory
        /// La que creó el formulario de Nuevo registro con el nombre del idioma (`isDefaultSeed` por defecto).
        let resolverTransferEN: Subcategory
        /// Creada a mano en Categorías con el nombre de transferencia, sin transferencias dentro.
        let handMadeHomonym: Subcategory
        /// La que creó el importador (con `isDefaultSeed: false`) y guarda transferencias de verdad.
        let importerTransferHolder: Subcategory
        let account: Account
    }

    private func subcategory(
        _ name: String, in category: YalaCategory, isDefaultSeed: Bool = true, sortOrder: Int = 0, context: ModelContext
    ) -> Subcategory {
        let sub = Subcategory(
            name: name, isDefaultSeed: isDefaultSeed, sortOrder: sortOrder,
            natureRawValue: "sin_clasificacion", iconName: "arrow.left.arrow.right", category: category)
        context.insert(sub)
        sub.systemRoleRaw = nil
        return sub
    }

    private func transaction(
        _ amount: Double, sub: Subcategory, type: String? = nil, account: Account, context: ModelContext
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(timeIntervalSince1970: 1_790_000_000), amount: amount, currencyCode: "PEN", note: nil,
            category: sub.category, subcategory: sub, account: account, exchangeRate: 1,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN")
        tx.balanceAdjustmentType = type
        context.insert(tx)
        return tx
    }

    private func makeStore22(context: ModelContext) throws -> Store22 {
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: "PEN")
        let otherES = YalaCategory(name: "Otros", colorHex: "#64748B", isIncome: false)
        let incomeES = YalaCategory(name: "Ingresos", colorHex: "#14B8A6", isIncome: true)
        let otherEN = YalaCategory(name: "Other", colorHex: "#64748C", isIncome: false)
        let food = YalaCategory(name: "Comida", colorHex: "#22C55E", isIncome: false)
        [otherES, incomeES, otherEN, food].forEach { context.insert($0) }

        let store = Store22(
            otherES: otherES,
            incomeES: incomeES,
            adjustmentES: subcategory("Ajustes de saldo", in: otherES, context: context),
            transferOutES: subcategory("Transferencia entre cuentas", in: otherES, sortOrder: 1, context: context),
            transferInES: subcategory("Transferencia entre cuentas", in: incomeES, context: context),
            otherEN: otherEN,
            adjustmentEN: subcategory("Balance adjustment", in: otherEN, context: context),
            accountTransferEN: subcategory("Account transfer", in: otherEN, sortOrder: 4, context: context),
            resolverTransferEN: subcategory("Transfer between accounts", in: otherEN, sortOrder: 9, context: context),
            handMadeHomonym: subcategory(
                "Transfer between accounts", in: food, isDefaultSeed: false, context: context),
            importerTransferHolder: subcategory(
                "Transferencia entre cuentas", in: food, isDefaultSeed: false, sortOrder: 3, context: context),
            account: account
        )
        _ = transaction(-50, sub: store.resolverTransferEN, type: TransactionItem.adjustmentTypeTransfer,
                        account: account, context: context)
        _ = transaction(-70, sub: store.importerTransferHolder, type: TransactionItem.adjustmentTypeTransfer,
                        account: account, context: context)
        try context.save()
        return store
    }

    // MARK: - Lectores

    @Test func handMadeSubcategoryWithTheTransferName_isNormal() throws {
        let context = try makeTestContext()
        let store = try makeStore22(context: context)
        #expect(!store.handMadeHomonym.isAnySystem)
        #expect(ManualSubcategoryPickerLogic.isPickable(
            .init(isVisible: true, isAnySystem: store.handMadeHomonym.isAnySystem, categoryIsVisible: true,
                  categoryIsSystem: false, categoryIsIncome: false),
            for: .expense))
    }

    @Test func seededTransferInEnglish_isSystemBeforeAndAfterTheBackfill() throws {
        let context = try makeTestContext()
        let store = try makeStore22(context: context)
        #expect(store.accountTransferEN.isAnySystem, "deducido mientras el campo está vacío")
        SubcategorySystemRoleBackfill.run(context: context)
        #expect(store.accountTransferEN.systemRoleRaw == SubcategorySystemRole.transfer.rawValue)
    }

    // MARK: - La migración

    @Test func backfill_writesTheRoleOnEveryYalaSubcategory_andLeavesTheUserOnesAlone() throws {
        let context = try makeTestContext()
        let store = try makeStore22(context: context)

        let report = SubcategorySystemRoleBackfill.run(context: context)

        #expect(store.adjustmentES.systemRoleRaw == "balanceAdjustment")
        #expect(store.adjustmentEN.systemRoleRaw == "balanceAdjustment")
        #expect(store.transferOutES.systemRoleRaw == "transfer")
        #expect(store.transferInES.systemRoleRaw == "transfer")
        #expect(store.accountTransferEN.systemRoleRaw == "transfer")
        #expect(store.resolverTransferEN.systemRoleRaw == "transfer")
        #expect(store.importerTransferHolder.systemRoleRaw == "transfer", "ya guardaba transferencias")
        #expect(store.handMadeHomonym.systemRoleRaw == nil)
        #expect(!store.handMadeHomonym.isAnySystem)
        // La medida que pide el encargo: siete subcategorías con papel, ninguna copia (nadie usó la sembrada a mano).
        #expect(report == .init(rolesWritten: 7, userCopiesCreated: 0, transactionsMoved: 0, otherRecordsMoved: 0))
        #expect(!context.hasChanges)
    }

    @Test func backfill_isRepeatable_andDoesNotDuplicate() throws {
        let context = try makeTestContext()
        _ = try makeStore22(context: context)
        let before = try context.fetchCount(FetchDescriptor<Subcategory>())

        _ = SubcategorySystemRoleBackfill.run(context: context)
        let second = SubcategorySystemRoleBackfill.run(context: context)

        #expect(second == .init())
        #expect(try context.fetchCount(FetchDescriptor<Subcategory>()) == before)
    }

    /// Lo que S27l protegía: lo que el usuario apuntó a mano en «Account transfer» no se pierde al volverse de sistema.
    @Test func seededTransferUsedByHand_movesTheUsersRecordsToTheirOwnCopy() throws {
        let context = try makeTestContext()
        let store = try makeStore22(context: context)
        let seeded = store.accountTransferEN
        let manual = transaction(-30, sub: seeded, account: store.account, context: context)
        let groupLeg = transaction(-12, sub: seeded, account: store.account, context: context)
        groupLeg.splitExpenseID = UUID().uuidString
        let realTransfer = transaction(
            -80, sub: seeded, type: TransactionItem.adjustmentTypeTransfer, account: store.account, context: context)
        let favorite = FavoritePayment(name: "Mamá", subcategory: seeded)
        let transferFavorite = FavoritePayment(
            name: "A ahorros", transactionType: "transfer", account: store.account,
            destinationAccount: store.account, subcategory: seeded)
        let budget = Budget(currencyCode: "PEN", limitAmount: 100, name: "Familia", subcategories: [seeded])
        [favorite, transferFavorite].forEach { context.insert($0) }
        context.insert(budget)
        budget.setSubcategoryIDs(from: [seeded])
        try context.save()

        let report = SubcategorySystemRoleBackfill.run(context: context)

        let copy = try #require(manual.subcategory)
        #expect(copy.persistentModelID != seeded.persistentModelID)
        #expect(copy.name == "Account transfer")
        #expect(copy.category?.persistentModelID == store.otherEN.persistentModelID)
        #expect(copy.sortOrder == seeded.sortOrder)
        #expect(!copy.isAnySystem, "la copia es del usuario")
        #expect(seeded.isAnySystem)
        #expect(groupLeg.subcategory?.persistentModelID == copy.persistentModelID, "la clasificación del puente")
        #expect(realTransfer.subcategory?.persistentModelID == seeded.persistentModelID)
        #expect(favorite.subcategory?.persistentModelID == copy.persistentModelID)
        #expect(transferFavorite.subcategory?.persistentModelID == seeded.persistentModelID)
        #expect(budget.subcategories?.map(\.persistentModelID) == [copy.persistentModelID])
        #expect(budget.subcategoryIDsSet == [copy.shortcutID], "el espejo CSV también")
        #expect(report == .init(rolesWritten: 7, userCopiesCreated: 1, transactionsMoved: 2, otherRecordsMoved: 2))
        // El puente de Grupos encuentra por nombre la del usuario, no la de sistema.
        let matched = GroupTransactionBridge.matchSubcategory(name: "Account transfer", context: context)
        #expect(matched?.persistentModelID == copy.persistentModelID)
    }

    /// En español la sembrada ya era de sistema: no hay nada del usuario dentro que separar.
    @Test func seededTransferThatWasAlreadySystem_isNotSplit() throws {
        let context = try makeTestContext()
        let store = try makeStore22(context: context)
        _ = transaction(-30, sub: store.transferOutES, account: store.account, context: context)
        try context.save()

        let report = SubcategorySystemRoleBackfill.run(context: context)

        #expect(report.userCopiesCreated == 0)
    }

    // MARK: - El resolver y el importador

    @Test func resolver_neverSendsTransfersToAHandMadeHomonym() throws {
        let context = try makeTestContext()
        let food = YalaCategory(name: "Comida", colorHex: "#22C55E", isIncome: false)
        context.insert(food)
        let homonym = subcategory(L10n.Transfer.categoryName, in: food, isDefaultSeed: false, context: context)
        try context.save()

        let outflow = try TransferCategoryResolver.outflow(context: context)

        #expect(outflow.persistentModelID != homonym.persistentModelID)
        #expect(outflow.systemRoleRaw == SubcategorySystemRole.transfer.rawValue)
    }

    @Test func resolver_usesTheSeededTransferOfAnyLanguage() throws {
        let context = try makeTestContext()
        let store = try makeStore22(context: context)
        _ = SubcategorySystemRoleBackfill.run(context: context)

        let outflow = try TransferCategoryResolver.outflow(context: context)
        let inflow = try TransferCategoryResolver.inflow(context: context)

        #expect(outflow.systemRole == .transfer)
        #expect(outflow.category?.isIncome == false)
        #expect(outflow.persistentModelID != store.handMadeHomonym.persistentModelID)
        #expect(inflow.persistentModelID == store.transferInES.persistentModelID)
    }

    @Test func initialBalance_findsTheAdjustmentByItsRole() throws {
        let context = try makeTestContext()
        let other = YalaCategory(name: "Otros", colorHex: "#64748B", isIncome: false)
        context.insert(other)
        let homonym = subcategory(L10n.Subcategory.balanceAdjustment, in: other, isDefaultSeed: false, context: context)
        try context.save()

        let found = try #require(InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context))

        #expect(found.persistentModelID != homonym.persistentModelID)
        #expect(found.systemRoleRaw == SubcategorySystemRole.balanceAdjustment.rawValue)
    }

    /// Un CSV con transferencias en un teléfono con una homónima del usuario: la fila va a la de sistema y la homónima
    /// sigue normal. Con la regla vieja la fila caía en la homónima, que era «de sistema» por su nombre.
    @Test func importedTransferRows_goToTheRoleSubcategory_notToAHomonym() async throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: "PEN")
        let other = YalaCategory(name: "Otros", colorHex: "#64748B", isIncome: false)
        context.insert(other)
        let homonym = subcategory("Transfer between accounts", in: other, isDefaultSeed: false, context: context)
        try context.save()

        let csv = [
            "date,amount,currency,category,subcategory,tags,note",
            "2026-10-14,-100.00,PEN,Otros,Transfer between accounts,,",
            "2026-10-14,100.00,PEN,Income,Account transfer,,",
        ].joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("papel-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer {
            do { try FileManager.default.removeItem(at: url) } catch { Issue.record("Error: \(error)") }
        }

        _ = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importCSV(
                from: url, into: account, in: context, allowCreatingNewCategories: true)
        }

        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(transactions.count == 2)
        for tx in transactions {
            #expect(tx.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer)
            #expect(tx.subcategory?.systemRole == .transfer)
            #expect(tx.subcategory?.persistentModelID != homonym.persistentModelID)
        }
        #expect(!homonym.isAnySystem)
        #expect((homonym.transactions ?? []).isEmpty)
    }
}
