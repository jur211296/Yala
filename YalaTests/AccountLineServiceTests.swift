//
//  AccountLineServiceTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 1: lo que toca SwiftData. Vincular con movimientos no toca ninguna
//  transacción; dos líneas (tarjeta, divisa) de dos teléfonos acaban en una; una principal que cambia de
//  `shortcutID` (identidad colapsada, fusión de duplicados) se lleva sus líneas al valor nuevo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Tarjeta con varias divisas · SwiftData", .serialized)
@MainActor
struct AccountLineServiceTests {

    private func account(_ context: ModelContext, _ name: String, _ currency: String,
                         type: String = "creditCard", id: UUID? = nil) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: "#6366F1",
                              iconName: "creditcard", type: type)
        if let id { account.shortcutID = id }
        context.insert(account)
        return account
    }

    private func transaction(_ context: ModelContext, _ amount: Double, _ account: Account,
                             _ subcategory: Subcategory) -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_760_000_000), amount: amount,
                                 currencyCode: account.currencyCode, note: "x", category: subcategory.category,
                                 subcategory: subcategory, account: account)
        context.insert(tx)
        return tx
    }

    // MARK: - Vincular

    @Test func link_withMovements_writesOnlyTheLink_noTransactionChanges() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context)
        let subcategory = makeTestSubcategory(context: context, category: category)
        let pen = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        let penTx = transaction(context, -120, pen, subcategory)
        let usdTx = transaction(context, -35.5, usd, subcategory)
        try context.save()
        let before = [(penTx.amount, penTx.currencyCode, penTx.account?.shortcutID),
                      (usdTx.amount, usdTx.currencyCode, usdTx.account?.shortcutID)]

        try AccountLineService.link(usd, to: pen, in: context)

        #expect(usd.parentAccountID == pen.shortcutID)
        #expect(pen.parentAccountID == nil)
        let after = [(penTx.amount, penTx.currencyCode, penTx.account?.shortcutID),
                     (usdTx.amount, usdTx.currencyCode, usdTx.account?.shortcutID)]
        #expect(after.map(\.0) == before.map(\.0))
        #expect(after.map(\.1) == before.map(\.1))
        #expect(after.map(\.2) == before.map(\.2))
        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).count == 2)
        #expect(context.hasChanges == false, "lo guardó")
    }

    @Test func link_rejected_writesNothing() throws {
        let context = try makeTestContext()
        let pen = account(context, "Visa", "PEN")
        let otherPen = account(context, "Otra", "PEN")
        try context.save()
        #expect(throws: AccountLineService.LinkError.rejected(.sameCurrencyAsPrincipal)) {
            try AccountLineService.link(otherPen, to: pen, in: context)
        }
        #expect(otherPen.parentAccountID == nil)
        #expect(context.hasChanges == false)
    }

    @Test func link_anyAccountType() throws {
        let context = try makeTestContext()
        let cash = account(context, "Efectivo", "PEN", type: "cash")
        let cashUSD = account(context, "Efectivo USD", "USD", type: "cash")
        try context.save()
        try AccountLineService.link(cashUSD, to: cash, in: context)
        #expect(cashUSD.parentAccountID == cash.shortcutID)
    }

    // MARK: - Dos teléfonos, misma línea: la deduplicación es de lectura

    @Test func twoPhonesSameLine_readAsOne_andNothingIsWritten() throws {
        let context = try makeTestContext()
        let low = UUID(uuidString: "20000000-0000-4000-8000-00000000000A")!
        let high = UUID(uuidString: "90000000-0000-4000-8000-00000000000B")!
        let pen = account(context, "Visa", "PEN")
        let fromPhoneB = account(context, "Visa dólares", "USD", id: high)
        let fromPhoneA = account(context, "Visa USD", "USD", id: low)
        fromPhoneA.parentAccountID = pen.shortcutID
        fromPhoneB.parentAccountID = pen.shortcutID
        try context.save()

        CategoryDeduplicationService.runAllDeduplication(in: context)

        #expect(fromPhoneA.parentAccountID == pen.shortcutID)
        #expect(fromPhoneB.parentAccountID == pen.shortcutID, "nadie desvincula: no hay nada que se cruce entre teléfonos")
        let roles = AccountLineLogic.resolve(try context.fetch(FetchDescriptor<Account>()).map { AccountLineNode($0) })
        #expect(roles[pen.shortcutID] == .principal(lineIDs: [low]))
        #expect(roles[high] == .brokenLine(.duplicateCurrency(keptLineID: low)))
        #expect(try context.fetch(FetchDescriptor<Account>()).count == 3, "no se borra ninguna cuenta")
    }

    @Test func twoPhonesSameLine_archivingTheWinner_letsTheOtherTakeTheSlot() throws {
        let context = try makeTestContext()
        let low = UUID(uuidString: "20000000-0000-4000-8000-00000000000A")!
        let high = UUID(uuidString: "90000000-0000-4000-8000-00000000000B")!
        let pen = account(context, "Visa", "PEN")
        let a = account(context, "Visa USD", "USD", id: low)
        let b = account(context, "Visa dólares", "USD", id: high)
        a.parentAccountID = pen.shortcutID
        b.parentAccountID = pen.shortcutID
        a.isArchived = true   // el escenario de la review: en otro teléfono se archivó la ganadora
        try context.save()
        let roles = AccountLineLogic.resolve(try context.fetch(FetchDescriptor<Account>()).map { AccountLineNode($0) })
        #expect(roles[high] == .line(principalID: pen.shortcutID), "la tarjeta no se queda sin línea USD viva")
    }

    // MARK: - Identidad colapsada

    @Test func repairCollapsedIdentity_relinksTheLineToThePrincipalsNewID() throws {
        let context = try makeTestContext()
        let collapsed = UUID()
        let pen = account(context, "Visa", "PEN", id: collapsed)
        let otherUSD = account(context, "Ahorro USD", "USD", id: collapsed)  // misma divisa que la línea: no candidata
        let line = account(context, "Visa USD", "USD")
        line.parentAccountID = collapsed
        try context.save()

        CategoryDeduplicationService.repairCollapsedIdentityUUIDs(in: context)

        #expect(pen.shortcutID != collapsed)
        #expect(otherUSD.shortcutID != collapsed)
        #expect(line.parentAccountID == pen.shortcutID, "la línea sigue enlazada a su principal, con el valor nuevo")
        let roles = AccountLineLogic.resolve(try context.fetch(FetchDescriptor<Account>()).map { AccountLineNode($0) })
        #expect(roles[line.shortcutID] == .line(principalID: pen.shortcutID))
    }

    @Test func repairCollapsedIdentity_twoPossiblePrincipals_leavesTheLineOrphanAndVisible() throws {
        let context = try makeTestContext()
        let collapsed = UUID()
        _ = account(context, "Visa", "PEN", id: collapsed)
        _ = account(context, "Mastercard", "EUR", id: collapsed)
        let line = account(context, "Visa USD", "USD")
        line.parentAccountID = collapsed
        try context.save()

        CategoryDeduplicationService.repairCollapsedIdentityUUIDs(in: context)

        #expect(line.parentAccountID == collapsed, "no adivina: conserva el valor viejo")
        let roles = AccountLineLogic.resolve(try context.fetch(FetchDescriptor<Account>()).map { AccountLineNode($0) })
        #expect(roles[line.shortcutID] == .brokenLine(.orphan), "y se lee como cuenta suelta")
    }

    /// El mismo reenlace que hace el one-shot de `AppBootstrapper` (`migrateShortcutIDsAndRebuildCSVMirrors`), que
    /// regenera con `regenerateDuplicateUUIDs`: el helper recibe los pares viejo→nuevo y las líneas leídas antes.
    @Test func relinkAfterIdentityRegeneration_withTheOneShotsRegenerator() throws {
        let context = try makeTestContext()
        let collapsed = UUID()
        let pen = account(context, "Visa", "PEN", id: collapsed)
        _ = account(context, "Ahorro USD", "USD", id: collapsed)
        let line = account(context, "Visa USD", "USD")
        line.parentAccountID = collapsed
        try context.save()

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let oldIDs = accounts.map(\.shortcutID)
        let lines = accounts.filter { $0.parentAccountID == collapsed }
        regenerateDuplicateUUIDs(accounts, keyPath: \.shortcutID)
        let regenerated = zip(accounts, oldIDs).filter { $0.0.shortcutID != $0.1 }.map { (account: $0.0, oldID: $0.1) }

        #expect(AccountLineService.relinkAfterIdentityRegeneration(linesBefore: lines, regenerated: regenerated) == 1)
        #expect(line.parentAccountID == pen.shortcutID)
    }

    // MARK: - Fusión de cuentas duplicadas (reversa)

    @Test func mergeDuplicateAccounts_movesTheLosersLinesToTheWinner() throws {
        let context = try makeTestContext()
        // Sin movimientos gana el menor `shortcutID`: la línea apunta a la que PIERDE, o el test no prueba nada.
        let winner = account(context, "Visa", "PEN", id: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!)
        let loser = account(context, "Visa", "PEN", id: UUID(uuidString: "90000000-0000-4000-8000-000000000009")!)
        let line = account(context, "Visa USD", "USD")
        line.parentAccountID = loser.shortcutID
        try context.save()

        let removed = AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: nil)

        #expect(removed == 1)
        let survivors = try context.fetch(FetchDescriptor<Account>()).filter { $0.currencyCode == "PEN" }
        #expect(survivors.map(\.shortcutID) == [winner.shortcutID])
        #expect(line.parentAccountID == winner.shortcutID, "la línea no se queda huérfana")
    }

    /// Dos copias de la misma tarjeta, cada una con su copia de la misma línea: las líneas solo son duplicadas
    /// DESPUÉS de fundir las principales, así que hace falta una segunda pasada (review del 2026-10-18).
    @Test func mergeDuplicateAccounts_copiesOfACardAndItsLine_endUpAsOneCardWithOneLine() throws {
        let context = try makeTestContext()
        let p1 = account(context, "Visa", "PEN", id: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!)
        let p2 = account(context, "Visa", "PEN", id: UUID(uuidString: "90000000-0000-4000-8000-000000000009")!)
        let l1 = account(context, "Visa USD", "USD", id: UUID(uuidString: "20000000-0000-4000-8000-000000000002")!)
        let l2 = account(context, "Visa USD", "USD", id: UUID(uuidString: "80000000-0000-4000-8000-000000000008")!)
        l1.parentAccountID = p1.shortcutID
        l2.parentAccountID = p2.shortcutID
        try context.save()

        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: nil) == 2)
        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(Set(remaining.map(\.shortcutID)) == [p1.shortcutID, l1.shortcutID])
        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: nil) == 0, "idempotente")
    }

    @Test func mergeDuplicateAccounts_doesNotFuseALineWithALooseAccountOfTheSameName() throws {
        let context = try makeTestContext()
        let pen = account(context, "Visa", "PEN")
        let loose = account(context, "Visa USD", "USD")
        let line = account(context, "Visa USD", "USD")
        line.parentAccountID = pen.shortcutID
        try context.save()

        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: nil) == 0)
        #expect(try context.fetch(FetchDescriptor<Account>()).count == 3)
        _ = loose
    }
}
