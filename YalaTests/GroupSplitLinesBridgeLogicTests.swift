//
//  GroupSplitLinesBridgeLogicTests.swift
//  YalaTests
//
//  Grupos B · card 2: cuándo aplica el puente la receta de líneas y qué línea es la ancla
//  (`GroupSplitLinesBridgeLogic`), y la partición de patas que aparta las derivadas (`BridgeBranchLogic`).
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos B · lógica del puente con líneas")
@MainActor
struct GroupSplitLinesBridgeLogicTests {

    private let sip = UUID()
    private let comisiones = UUID()
    private let supermercado = UUID()
    private let hogar = UUID()

    private var pen: [UUID: GroupSplitLinesBridgeLogic.DestinationInfo] {
        [sip: .init(currencyCode: "PEN", isSystemAccount: false)]
    }

    private func pia() -> [GroupSplitLinesRecipe.Line] {
        [.transfer(amount: 500, destinationAccountID: sip), .expense(amount: 10, subcategoryID: comisiones)]
    }

    private func decide(
        _ lines: [GroupSplitLinesRecipe.Line]?, gateOpen: Bool = true, isCaseA: Bool = false, share: Double = 510,
        destinations: [UUID: GroupSplitLinesBridgeLogic.DestinationInfo]? = nil
    ) -> GroupSplitLinesBridgeLogic.Decision {
        GroupSplitLinesBridgeLogic.decide(
            stored: lines.map { .recipe($0) } ?? .none, gateOpen: gateOpen, isCaseA: isCaseA, share: share,
            currencyCode: "PEN", destinations: destinations ?? pen)
    }

    // MARK: - Ancla

    @Test func anchor_isTheFirstExpenseLine_evenAfterATransfer() {
        #expect(GroupSplitLinesBridgeLogic.anchorIndex(in: pia(), isCaseA: false) == 1)
        #expect(GroupSplitLinesBridgeLogic.anchorIndex(in: pia(), isCaseA: true) == 1)
    }

    @Test func anchor_withoutExpenseLines_isTheFirstLineInCaseB_andNoneInCaseA() {
        let onlyTransfer: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 500, destinationAccountID: sip)]
        #expect(GroupSplitLinesBridgeLogic.anchorIndex(in: onlyTransfer, isCaseA: false) == 0)
        #expect(GroupSplitLinesBridgeLogic.anchorIndex(in: onlyTransfer, isCaseA: true) == nil)
    }

    // MARK: - Decisión

    @Test func pia_appliesWithTheExpenseAsAnchor_andTheRechargeDerived() throws {
        guard case let .apply(plan) = decide(pia()) else { Issue.record("no aplica"); return }
        #expect(plan.anchor?.kind == .expense)
        #expect(plan.anchor?.amount == 10)
        #expect(plan.derived.map(\.amount) == [500])
        #expect(plan.extraLoan == 500)
    }

    @Test func caseA_withoutExpenseLines_derivesEverything_andTheLoanGrowsByAll() throws {
        let lines: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 500, destinationAccountID: sip)]
        guard case let .apply(plan) = decide(lines, isCaseA: true, share: 500) else { Issue.record("no aplica"); return }
        #expect(plan.anchor == nil)
        #expect(plan.extraLoan == 500)
    }

    @Test func closedGate_orNoRecipe_isASingleLine() {
        #expect(decide(pia(), gateOpen: false) == .singleLine)
        #expect(decide(nil) == .singleLine)
        #expect(GroupSplitLinesBridgeLogic.decide(
            stored: .newerVersion, gateOpen: true, isCaseA: false, share: 510, currencyCode: "PEN",
            destinations: pen) == .singleLine)
        #expect(GroupSplitLinesBridgeLogic.decide(
            stored: .unreadable, gateOpen: true, isCaseA: false, share: 510, currencyCode: "PEN",
            destinations: pen) == .singleLine)
    }

    @Test func linesThatNoLongerAddUp_areAMismatch_notASilentSplit() {
        #expect(decide(pia(), share: 520) == .mismatch(.missing(10)))
        #expect(decide(pia(), share: 505) == .mismatch(.over(5)))
    }

    @Test func aShareWithBinaryTail_stillBalances() {
        // 1530 / 3 en `Double` no es exacto; la regla compara con los decimales de la divisa.
        let lines: [GroupSplitLinesRecipe.Line] = [.expense(amount: 500, subcategoryID: supermercado),
                                                  .expense(amount: 10, subcategoryID: hogar)]
        guard case .apply = decide(lines, share: 1530.0 / 3.0) else { Issue.record("no cuadra"); return }
    }

    @Test func aDestinationThatIsMissing_system_orInAnotherCurrency_isUnavailable() {
        #expect(decide(pia(), destinations: [:]) == .destinationUnavailable)
        #expect(decide(pia(), destinations: [sip: .init(currencyCode: "PEN", isSystemAccount: true)])
                == .destinationUnavailable)
        #expect(decide(pia(), destinations: [sip: .init(currencyCode: "USD", isSystemAccount: false)])
                == .destinationUnavailable)
    }

    @Test func linesWithProblems_areASingleLine() {
        let noCategory: [GroupSplitLinesRecipe.Line] = [.expense(amount: 510, subcategoryID: nil),
                                                        .expense(amount: 0, subcategoryID: hogar)]
        #expect(decide(noCategory) == .singleLine)
    }

    // MARK: - Marcas

    @Test func markers_areRecognized_andARecipeIsNeverDerived() throws {
        let lineID = UUID()
        let marker = GroupSplitLinesRecipe.encodeDerivedMarker(lineID: lineID)
        #expect(GroupSplitLinesBridgeLogic.isDerivedMarker(marker))
        #expect(GroupSplitLinesBridgeLogic.derivedLineID(marker) == lineID)
        #expect(!GroupSplitLinesBridgeLogic.mayCarryRecipe(marker))
        let recipe = try #require(GroupSplitLinesRecipe.encode(pia()))
        #expect(GroupSplitLinesBridgeLogic.mayCarryRecipe(recipe))
        #expect(!GroupSplitLinesBridgeLogic.isDerivedMarker(recipe))
        #expect(!GroupSplitLinesBridgeLogic.isDerivedMarker(nil))
        #expect(!GroupSplitLinesBridgeLogic.mayCarryRecipe(nil))
    }

    @Test func aMarkerFromANewerVersion_isDerived_andNeverARecipe() {
        let newerMarker = #"{"of":"7D3C2E8A-0000-4000-8000-000000000001","v":2}"#
        #expect(GroupSplitLinesBridgeLogic.isDerivedMarker(newerMarker))
        #expect(!GroupSplitLinesBridgeLogic.mayCarryRecipe(newerMarker))
        #expect(GroupSplitLinesBridgeLogic.derivedLineID(newerMarker) == nil)
        let newerRecipe = #"{"l":[],"v":2}"#
        #expect(!GroupSplitLinesBridgeLogic.isDerivedMarker(newerRecipe))
        #expect(GroupSplitLinesBridgeLogic.mayCarryRecipe(newerRecipe))
    }

    // MARK: - Partición

    private func shape(
        nilSub: Bool = false, systemSub: Bool = false, metadata: Bool = false, age: TimeInterval = 0,
        derived: Bool = false, recipe: Bool = false
    ) -> BridgeBranchLogic.VirtualTxShape {
        let date = Date(timeIntervalSince1970: 1_000_000 + age)
        return .init(subcategoryIsNil: nilSub, subcategoryIsSystem: systemSub, hasUserMetadata: metadata,
                     date: date, createdAt: date, isDerivedLine: derived, carriesRecipe: recipe)
    }

    @Test func partition_setsDerivedLegsAside_insteadOfDeletingThem() {
        // Una derivada lleva subcategoría de usuario: antes contaba como clasificable y se borraba en la pasada siguiente.
        let partition = BridgeBranchLogic.partitionVirtualTxs([
            shape(recipe: true),
            shape(metadata: true, derived: true),
            shape(derived: true),
            shape(systemSub: true),
        ])
        #expect(partition.preservedIndex == 0)
        #expect(partition.derivedLineIndices == [1, 2])
        #expect(partition.deletedIndices == [3])
    }

    @Test func partition_theRecipeHolderWins_overTagsAndAge() {
        let partition = BridgeBranchLogic.partitionVirtualTxs([
            shape(metadata: true, age: 0),
            shape(age: 100, recipe: true),
        ])
        #expect(partition.preservedIndex == 1)
        #expect(partition.deletedIndices == [0])
    }

    @Test func partition_aRecipeHolderWithASystemSubcategory_isStillKept() {
        let partition = BridgeBranchLogic.partitionVirtualTxs([shape(systemSub: true, recipe: true)])
        #expect(partition.preservedIndex == 0)
        #expect(partition.deletedIndices.isEmpty)
    }
}
