//
//  DeadPointerSeedTests.swift
//  YalaTests
//
//  AC (c) de `qa_groups-tx-fantasma-al-borrar-gasto-de-grupo`: una TX cuyo puntero
//  de grupo está muerto sigue siendo editable y borrable. El seed `-uitest-seed
//  dead-pointer` planta exactamente ese estado, y Borrar/Duplicar del editor ganan
//  ids estables para que Mini pueda afirmarlos.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

#if DEBUG

/// El seed produce una TX que la policy trata como puntero muerto, y Borrar/Duplicar
/// quedan habilitados (`.disabled(isBridgedCasoA)` es false).
@Suite("Seed dead-pointer · AC-c fantasma", .serialized)
@MainActor
struct DeadPointerSeedBehaviorTests {

    /// Replica el predicado de `NewTransactionView.isBridgedCasoA`: es lo que
    /// apaga Borrar y Duplicar. Extraído aquí para no arrastrar SwiftUI al test.
    private func deleteAndDuplicateDisabled(
        tx: TransactionItem, pointerResolves: Bool
    ) -> Bool {
        guard pointerResolves,
              tx.splitExpenseID != nil,
              let account = tx.account,
              !account.isSystemAccount
        else { return false }
        return true
    }

    /// Misma fórmula que `resolveBridgedPointer`: fetch vacío solo cuenta si la zona es fresca.
    private func editorTreatsPointerAsResolved(
        tx: TransactionItem, context: ModelContext
    ) throws -> Bool {
        let raw = try #require(tx.splitExpenseID)
        let found: Bool
        if let id = UUID(uuidString: raw) {
            found = try !context.fetch(
                FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id })
            ).isEmpty
        } else {
            found = false
        }
        return found || !GroupChannelFreshness.isFresh(zone: tx.splitGroupZoneID, context: context)
    }

    private func plantedTx(in context: ModelContext) throws -> TransactionItem {
        let account = makeTestAccount(context: context, currencyCode: "PEN")
        DevSeedTransactions.createDeadPointerFixture(
            account: account, currencyCode: "PEN", in: context)
        let txs = try context.fetch(FetchDescriptor<TransactionItem>())
        return try #require(
            txs.first { $0.note == DevSeedTransactions.DeadPointerUITestSeed.note },
            "El fixture no insertó la TX con la nota estable.")
    }

    /// El corazón del AC (c): el seed deja una TX que el editor trata como puntero muerto,
    /// la policy la clasifica como personal, y Borrar/Duplicar quedan habilitados.
    @Test func seed_producesDeadPointerTx_thatStaysEditableAndDeletable() throws {
        let context = try makeTestContext()
        let tx = try plantedTx(in: context)

        #expect(tx.splitExpenseID == DevSeedTransactions.DeadPointerUITestSeed.unresolvedExpenseIDString)
        #expect(tx.account?.isSystemAccount == false)
        #expect(tx.splitGroupZoneID != nil && tx.splitGroupZoneID?.isEmpty == false)

        let expenseID = try #require(UUID(uuidString: DevSeedTransactions.DeadPointerUITestSeed.unresolvedExpenseIDString))
        let matchingExpenses = try context.fetch(
            FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == expenseID }))
        #expect(matchingExpenses.isEmpty, "El puntero sembrado resolvió a un SplitExpense — ya no está muerto.")

        #expect(GroupChannelFreshness.isFresh(zone: tx.splitGroupZoneID, context: context),
                """
                La zona del fixture no es fresca. El editor haría \
                `bridgedPointerResolves = false || !isFresh` = true y Borrar/Duplicar \
                se apagarían — el seed no sirve para el AC (c).
                """)

        let pointerResolves = try editorTreatsPointerAsResolved(tx: tx, context: context)
        #expect(pointerResolves == false, "El editor trataría este puntero como vivo.")

        let shape = BridgedEditPolicy.TxShape(
            hasSplitExpenseID: tx.splitExpenseID != nil,
            hasSplitSettlementID: tx.splitSettlementID != nil,
            accountIsNil: tx.account == nil,
            accountIsSystem: tx.account?.isSystemAccount == true,
            subcategoryIsSystem: tx.subcategory?.isAnySystem == true,
            hasPendingPointerDraft: false,
            pointerResolves: pointerResolves)
        let classification = BridgedEditPolicy.classify(shape)
        #expect(classification == .notBridged)
        #expect(BridgedEditPolicy.canSave(classification))
        #expect(BridgedEditPolicy.canEditAccount(classification))
        #expect(BridgedEditPolicy.canEditSubcategoryAndTags(classification))
        #expect(BridgedEditPolicy.banner(shape) == .none)

        #expect(deleteAndDuplicateDisabled(tx: tx, pointerResolves: pointerResolves) == false)
        // Control: la misma TX con el puntero VIVO sí apagaría Borrar/Duplicar.
        // Sin él, «habilitado» no discrimina de «el seed no plantó los punteros».
        #expect(deleteAndDuplicateDisabled(tx: tx, pointerResolves: true),
                "El control positivo se rompió: isBridgedCasoA ya no apaga Borrar en Caso A.")
    }

    /// El grupo plantado es legacy a propósito. Si alguien le copia el `isBackendGroup = true`
    /// de `.grupos` (C3), la zona deja de ser fresca en uitest y el AC (c) queda ciego.
    @Test func seed_groupIsSettledAndNotBackend() throws {
        let context = try makeTestContext()
        _ = try plantedTx(in: context)
        let groups = try context.fetch(FetchDescriptor<SplitGroup>())
        let group = try #require(groups.first, "El fixture no insertó el SplitGroup de la zona.")
        #expect(group.isBackendGroup == false)
        #expect(group.movedToBackendAt == nil)
        #expect(group.initialMemberImportStartedAt == nil)
        #expect(group.cloudKitZoneID.isEmpty == false)
    }
}

#endif

// MARK: - Cableado (source-scan)

@Suite("Seed dead-pointer · cableado de ids y perfil")
struct DeadPointerSeedWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func codeLines(_ src: String) -> String {
        src.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Mini necesita ids estables, no el texto localizado de Borrar/Duplicar.
    @Test func editorExposesDeleteAndDuplicateIdentifiers() throws {
        let src = try Self.source("Yala/App/Views/Transactions/NewTransactionView.swift")
        let code = Self.codeLines(src)
        #expect(code.contains(".accessibilityIdentifier(\"new_transaction_duplicate_action\")"),
                "Duplicar del quick-actions bar perdió su accessibilityIdentifier.")
        #expect(code.contains(".accessibilityIdentifier(\"new_transaction_delete_action\")"),
                "Borrar del quick-actions bar perdió su accessibilityIdentifier.")
    }

    /// Los ids van en LOS botones de Duplicar/Borrar, no en un vecino. Ancla junto a
    /// `L10n.Action.duplicate` / `delete` — un id suelto en el fichero pasaría en verde
    /// con los botones mudos (familia `AppAttestClient.ensureRegistered`).
    @Test func identifiersSitOnTheDuplicateAndDeleteButtons() throws {
        let src = try Self.source("Yala/App/Views/Transactions/NewTransactionView.swift")
        let bar = try #require(
            src.components(separatedBy: "private var quickActionsBar: some View {").dropFirst().first,
            "`quickActionsBar` cambió de nombre; este scan dejó de medir nada.")
        let body = bar.components(separatedBy: "\n    private func quickActionButton(").first ?? ""
        #expect(body.contains("L10n.Action.duplicate"),
                "El ancla de Duplicar desapareció del quick-actions bar.")
        #expect(body.contains("L10n.Action.delete"),
                "El ancla de Borrar desapareció del quick-actions bar.")

        let dup = try #require(body.range(of: "L10n.Action.duplicate"))
        let dupID = try #require(body.range(of: "new_transaction_duplicate_action"))
        #expect(dupID.lowerBound > dup.lowerBound,
                "new_transaction_duplicate_action ya no está en el botón Duplicar.")

        let del = try #require(body.range(of: "L10n.Action.delete"))
        let delID = try #require(body.range(of: "new_transaction_delete_action"))
        #expect(delID.lowerBound > del.lowerBound,
                "new_transaction_delete_action ya no está en el botón Borrar.")
    }

    /// El perfil entra por `-uitest-seed`, no por un flag de producto.
    @Test func seedProfile_isWiredThroughExistingSeedMachinery() throws {
        let profile = try Self.source("Yala/Seed/DevSeedService.swift")
        #expect(profile.contains("case deadPointer = \"dead-pointer\""),
                "DevSeedProfile perdió el caso `dead-pointer`. Mini no tiene cómo lanzar el seed.")

        let seedFn = try #require(
            profile.components(separatedBy: "func seed(in context: ModelContext").dropFirst().first,
            "`DevSeedService.seed` cambió de forma; este scan dejó de medir nada.")
        let seedBody = seedFn.components(separatedBy: "\n    /// Seed AISLADO").first ?? seedFn
        #expect(seedBody.contains("seedDeadPointerFixtures(in: context)"),
                """
                `seed(profile: .deadPointer)` dejó de llamar al fixture. El perfil existiría \
                y Mini lanzaría `-uitest-seed dead-pointer` contra el generador aleatorio.
                """)

        let fixture = try Self.source("Yala/Seed/DevSeedTransactions.swift")
        let fn = try #require(
            fixture.components(separatedBy: "static func createDeadPointerFixture(").dropFirst().first,
            "El helper que planta el puntero muerto desapareció.")
        let body = Self.codeLines(fn.components(separatedBy: "\n    /// ").first ?? fn)
        #expect(body.contains("isBackendGroup = true") == false,
                """
                createDeadPointerFixture empezó a marcar el grupo como backend. En uitest \
                la zona deja de ser fresca y el editor trata el puntero como vivo.
                """)
    }
}
