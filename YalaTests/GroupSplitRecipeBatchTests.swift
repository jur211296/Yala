//
//  GroupSplitRecipeBatchTests.swift
//  YalaTests
//
//  Grupos B · card 6u5f: «Editar varios» no cambia la categoría de la pata que lleva tu parte partida en líneas (la
//  pisaría el puente) y dice dónde cambiarla. Archivo propio: `makeTestContext()` se cachea por archivo, y la otra suite
//  de `GroupsBCabosSueltosTests.swift` que lo pide compartiría el store (`.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos B · 6u5f: el lote con la pata que lleva la receta", .serialized)
@MainActor
struct GroupSplitRecipeBatchTests {

    @Test func theBatch_saysWhereToChangeIt() throws {
        let context = try makeTestContext()
        let account = Account(name: "BCP", currencyCode: "PEN", colorHex: "#111111", iconName: "creditcard", type: "bank")
        context.insert(account)
        let cat = makeTestCategory(context: context, name: "Gastos")
        let hogar = makeTestSubcategory(context: context, name: "Hogar", category: cat)
        let leg = TransactionItem(date: .now, amount: -200, currencyCode: "PEN", account: account)
        leg.splitExpenseID = UUID().uuidString
        leg.splitLinesRaw = GroupSplitLinesRecipe.encode([
            .expense(amount: 80, subcategoryID: hogar.shortcutID), .expense(amount: 20, subcategoryID: hogar.shortcutID),
        ])
        context.insert(leg)
        try context.save()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [leg.persistentModelID]
        #expect(vm.bulkEditBlocker(BulkEditChanges(subcategory: hogar), context: context)
                == L10n.BulkEdit.cannotEditSplitRecipeCategory)
        #expect(vm.bulkEditBlocker(BulkEditChanges(account: account), context: context) == nil,
                "La cuenta de la pata real se sigue pudiendo cambiar en lote.")
    }
}
