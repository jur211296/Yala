//
//  CSVImportCategoryNatureTests.swift
//  YalaTests
//
//  Card d4od · ticket `csv-import-leaves-no-origin-mark-and-reuses-opposite-categories`, criterio 2: una fila cuyo
//  signo contradice la naturaleza de la categoría con ese nombre se resuelve al importar, sin romper las
//  transferencias de «Otros» ni los reembolsos.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - La decisión

@Suite("Importar CSV · qué categoría usa una fila según su signo")
struct CategoryImportNatureLogicTests {

    private typealias C = CategoryImportNatureLogic.Candidate

    @Test func noCategoryWithThatName_createsInCreateMode_andFailsInStrictMode() {
        #expect(CategoryImportNatureLogic.choose(candidates: [], isIncome: true, allowCreating: true)
                == .createWithRowNature)
        #expect(CategoryImportNatureLogic.choose(candidates: [], isIncome: true, allowCreating: false)
                == .unknownCategory)
    }

    /// «Otros» de gasto y de ingreso: un ingreso va a la de ingreso aunque la de gasto salga primero.
    @Test func twoWithTheSameName_theRowSignPicks() {
        let candidates = [C(index: 0, isIncome: false, hasSubcategory: false),
                          C(index: 1, isIncome: true, hasSubcategory: false)]
        #expect(CategoryImportNatureLogic.choose(candidates: candidates, isIncome: true, allowCreating: true)
                == .use(index: 1))
        #expect(CategoryImportNatureLogic.choose(candidates: candidates, isIncome: false, allowCreating: false)
                == .use(index: 0))
    }

    /// La de la naturaleza del signo que ya tiene la subcategoría gana a la que no la tiene.
    @Test func sameNatureWithTheSubcategory_winsOverSameNatureWithout() {
        let candidates = [C(index: 0, isIncome: true, hasSubcategory: false),
                          C(index: 1, isIncome: true, hasSubcategory: true)]
        #expect(CategoryImportNatureLogic.choose(candidates: candidates, isIncome: true, allowCreating: false)
                == .use(index: 1))
    }

    /// Un reembolso (+20 en «Comida › Restaurantes») o una transferencia (+ en «Otros › Transferencia entre cuentas»)
    /// se quedan en la categoría de gasto que ya tiene esa subcategoría: no se crea una «Comida» de ingreso.
    @Test func oppositeNatureWithTheSubcategory_isKept_asARefundOrATransfer() {
        let onlyExpense = [C(index: 0, isIncome: false, hasSubcategory: true)]
        #expect(CategoryImportNatureLogic.choose(candidates: onlyExpense, isIncome: true, allowCreating: true)
                == .use(index: 0))
        // Y gana a una de la naturaleza del signo que no tiene la subcategoría.
        let both = [C(index: 0, isIncome: true, hasSubcategory: false),
                    C(index: 1, isIncome: false, hasSubcategory: true)]
        #expect(CategoryImportNatureLogic.choose(candidates: both, isIncome: true, allowCreating: true)
                == .use(index: 1))
    }

    /// El caso del ticket: «Otros › Bonificación» +1.500 con solo la «Otros» de gasto, que no tiene «Bonificación».
    @Test func onlyOppositeWithoutTheSubcategory_createsTheRightNature_inCreateMode() {
        let onlyExpense = [C(index: 0, isIncome: false, hasSubcategory: false)]
        #expect(CategoryImportNatureLogic.choose(candidates: onlyExpense, isIncome: true, allowCreating: true)
                == .createWithRowNature)
        // En modo estricto no se crea nada: se usa la que hay y la fila sale con «subcategoría desconocida».
        #expect(CategoryImportNatureLogic.choose(candidates: onlyExpense, isIncome: true, allowCreating: false)
                == .use(index: 0))
    }
}

// MARK: - De punta a punta

@Suite("Importar CSV · las filas caen en la categoría de su naturaleza", .serialized)
@MainActor
struct CSVImportCategoryNatureTests {

    private struct Store {
        let context: ModelContext
        let account: Account
        let otherExpense: YalaCategory
        let food: YalaCategory
    }

    /// «Otros» de gasto con su transferencia de sistema y «Comida › Restaurantes», como los siembra Yala.
    private func store() throws -> Store {
        let context = try makeTestContext()
        let other = YalaCategory(name: "Otros", colorHex: "#999999", isIncome: false)
        context.insert(other)
        context.insert(Subcategory(name: "Transferencia entre cuentas", category: other))
        let food = YalaCategory(name: "Comida", colorHex: "#22C55E", isIncome: false)
        context.insert(food)
        context.insert(Subcategory(name: "Restaurantes", category: food))
        let account = Account(
            name: "Cuenta", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "general")
        context.insert(account)
        try context.save()
        return Store(context: context, account: account, otherExpense: other, food: food)
    }

    private func importRows(_ rows: [String], into store: Store, allowCreating: Bool) async throws
        -> [ParsedTransactionDraft] {
        let csv = (["date,amount,currency,category,subcategory,tags,note"] + rows).joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nature-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer {
            do { try FileManager.default.removeItem(at: url) } catch { Issue.record("No se borró el CSV: \(error)") }
        }
        let result = try await TransactionCSVImportService.importCSV(
            from: url, into: store.account, in: store.context, allowCreatingNewCategories: allowCreating)
        return result.drafts
    }

    /// El ingreso del ticket ya no se cuelga de la «Otros» de gasto: va a una «Otros» de ingreso.
    @Test func incomeInAnExpenseNamedCategory_goesToACategoryOfItsNature() async throws {
        let store = try store()
        let drafts = try await importRows(
            ["2026-05-10,1500.00,PEN,Otros,Bonificación,,"], into: store, allowCreating: true)

        let draft = try #require(drafts.first)
        #expect(draft.category.isIncome)
        #expect(draft.category.name == "Otros")
        #expect(draft.category !== store.otherExpense)
        #expect(draft.subcategory.name == "Bonificación")
        #expect(draft.subcategory.category === draft.category)
    }

    /// Las transferencias de «Otros» llevan los dos signos y se quedan donde están; un reembolso, también.
    @Test func transfersAndRefunds_stayInTheirExpenseCategory() async throws {
        let store = try store()
        let drafts = try await importRows([
            "2026-05-10,200.00,PEN,Otros,Transferencia entre cuentas,,",
            "2026-05-11,-200.00,PEN,Otros,Transferencia entre cuentas,,",
            "2026-05-12,20.00,PEN,Comida,Restaurantes,,devolución",
            "2026-05-13,-35.00,PEN,Comida,Restaurantes,,",
        ], into: store, allowCreating: true)

        #expect(drafts.count == 4)
        #expect(drafts[0].category === store.otherExpense)
        #expect(drafts[1].category === store.otherExpense)
        #expect(drafts[2].category === store.food)
        #expect(drafts[3].category === store.food)
        // Ninguna categoría nueva: la «Otros» y la «Comida» de gasto bastan.
        let categories = try store.context.fetch(FetchDescriptor<YalaCategory>())
        #expect(categories.count == 2)
    }

    /// Con las dos «Otros» ya creadas, cada fila va a la de su signo, también en modo estricto.
    @Test func withBothNatures_strictModePicksByTheRowSign() async throws {
        let store = try store()
        let otherIncome = YalaCategory(name: "Otros", colorHex: "#999999", isIncome: true, sortOrder: 99)
        store.context.insert(otherIncome)
        store.context.insert(Subcategory(name: "Bonificación", category: otherIncome))
        try store.context.save()

        let drafts = try await importRows(
            ["2026-05-10,1500.00,PEN,Otros,Bonificación,,"], into: store, allowCreating: false)

        #expect(drafts.first?.category === otherIncome)
    }

    /// Control del modo estricto: sin la categoría de la naturaleza correcta no se crea nada y la fila falla como antes.
    @Test func strictMode_withoutTheRightNature_stillRejectsTheRow() async throws {
        let store = try store()
        await #expect(throws: ImportError.self) {
            _ = try await importRows(
                ["2026-05-10,1500.00,PEN,Otros,Bonificación,,"], into: store, allowCreating: false)
        }
        let categories = try store.context.fetch(FetchDescriptor<YalaCategory>())
        #expect(categories.count == 2)
    }
}
