//
//  KeyboardCommandLogicTests.swift
//  YalaTests
//
//  iPad con teclado, puntero y arrastrar (fase 3 del carril adaptativo): qué hacen los atajos, qué ofrece el menú
//  contextual de un registro y qué pasa al soltar un recibo.
//

import Testing

@testable import Yala

struct KeyboardCommandLogicTests {
    private typealias Logic = KeyboardCommandLogic

    // MARK: - ⌘1…⌘6

    /// El número de cada atajo es la posición en la barra lateral: el orden del usuario, luego el resto.
    @Test func sectionShortcuts_followTheSidebarOrder() {
        let ordered = RootTabLayoutLogic.orderedTabs(activeTabs: [.groups, .panel])
        #expect(Logic.sectionTabs(orderedTabs: ordered) == [.groups, .panel, .statistics, .planning, .records, .reports])
    }

    /// Nunca más de seis: ⌘7 no existe.
    @Test func sectionShortcuts_stopAtSix() {
        let tabs = ConfigurableTab.allCases + ConfigurableTab.allCases
        #expect(Logic.sectionTabs(orderedTabs: tabs).count == 6)
    }

    /// Shell de solo grupos: un único atajo, ⌘1 → Grupos.
    @Test func sectionShortcuts_inGroupsOnlyShell_onlyGroups() {
        #expect(Logic.sectionTabs(orderedTabs: [.groups]) == [.groups])
    }

    // MARK: - Cuándo actúa un atajo

    @Test func globalCommands_actOnlyWithNothingPresented() {
        #expect(Logic.globalCommandsAllowed(shellBlocker: nil, anythingPresented: false))
        #expect(!Logic.globalCommandsAllowed(shellBlocker: nil, anythingPresented: true))
        #expect(!Logic.globalCommandsAllowed(shellBlocker: "splash", anythingPresented: false))
    }

    // MARK: - ↑↓

    @Test func arrows_moveToTheNeighbor() {
        let ids = [1, 2, 3]
        #expect(Logic.neighbor(of: 2, in: ids, direction: .next) == 3)
        #expect(Logic.neighbor(of: 2, in: ids, direction: .previous) == 1)
    }

    /// En los extremos no se da la vuelta: la flecha no hace nada.
    @Test func arrows_stopAtTheEnds() {
        let ids = [1, 2, 3]
        #expect(Logic.neighbor(of: 3, in: ids, direction: .next) == nil)
        #expect(Logic.neighbor(of: 1, in: ids, direction: .previous) == nil)
    }

    /// Sin nada abierto, o con lo abierto fuera de la lista filtrada, las dos flechas abren el primero.
    @Test func arrows_withNothingOpen_openTheFirst() {
        let ids = [1, 2, 3]
        #expect(Logic.neighbor(of: nil, in: ids, direction: .next) == 1)
        #expect(Logic.neighbor(of: nil, in: ids, direction: .previous) == 1)
        #expect(Logic.neighbor(of: 9, in: ids, direction: .previous) == 1)
    }

    @Test func arrows_onAnEmptyList_doNothing() {
        #expect(Logic.neighbor(of: nil, in: [Int](), direction: .next) == nil)
    }
}

// MARK: - Menú contextual de un registro

struct RecordContextActionLogicTests {
    private func shape(
        adjustment: Bool = false,
        splitExpense: Bool = false,
        splitSettlement: Bool = false,
        accountIsNil: Bool = false,
        accountIsSystem: Bool = false,
        subcategoryIsSystem: Bool = false
    ) -> RecordContextActionLogic.Shape {
        RecordContextActionLogic.Shape(
            hasBalanceAdjustmentType: adjustment,
            hasSplitExpenseID: splitExpense,
            hasSplitSettlementID: splitSettlement,
            accountIsNil: accountIsNil,
            accountIsSystem: accountIsSystem,
            subcategoryIsSystem: subcategoryIsSystem)
    }

    @Test func plainRecord_offersEverything() {
        let actions = RecordContextActionLogic.actions(shape())
        #expect(actions == .init(canEdit: true, canDuplicate: true, canChangeCategory: true, canDelete: true))
    }

    /// Un gasto de grupo en una cuenta real (caso A): el editor deshabilita Duplicar y Borrar, y el menú no los ofrece.
    /// La categoría sí es personal.
    @Test func groupExpenseOnARealAccount_hidesDuplicateAndDelete() {
        let actions = RecordContextActionLogic.actions(shape(splitExpense: true))
        #expect(!actions.canDuplicate)
        #expect(!actions.canDelete)
        #expect(actions.canChangeCategory)
    }

    /// Más estricto que el editor: el menú no sabe si el gasto de grupo sigue vivo, así que ningún registro con
    /// puntero de grupo ofrece Borrar, tampoco los de la cuenta virtual.
    @Test func anyGroupPointer_hidesDelete() {
        #expect(!RecordContextActionLogic.actions(shape(splitExpense: true, accountIsSystem: true)).canDelete)
        #expect(!RecordContextActionLogic.actions(shape(splitExpense: true, accountIsNil: true)).canDelete)
        #expect(!RecordContextActionLogic.actions(shape(splitSettlement: true)).canDelete)
    }

    /// Liquidaciones y registros derivados del grupo: la categoría la manda el grupo.
    @Test func settlementAndDerived_hideChangeCategory() {
        #expect(!RecordContextActionLogic.actions(shape(splitSettlement: true)).canChangeCategory)
        #expect(!RecordContextActionLogic.actions(shape(splitExpense: true, accountIsNil: true)).canChangeCategory)
    }

    /// Transferencias y ajustes de saldo llevan subcategoría de sistema: no se les cambia.
    @Test func transfersAndAdjustments_hideChangeCategory_butCanBeDeleted() {
        let transfer = RecordContextActionLogic.actions(shape(adjustment: true, subcategoryIsSystem: true))
        #expect(!transfer.canChangeCategory)
        #expect(transfer.canDelete)
        #expect(transfer.canEdit)
    }
}

// MARK: - Soltar un recibo

struct ReceiptDropLogicTests {
    /// Sin la entrada por imagen (Pro), el aviso de Pro y nada guardado: si no, la recuperación del arranque
    /// re-emitiría el fichero en cada vuelta a primer plano.
    @Test func withoutImageInput_asksForUpgrade() {
        #expect(ReceiptDropLogic.decide(canAccessImageInput: false) == .upgrade)
    }

    @Test func withImageInput_presents() {
        #expect(ReceiptDropLogic.decide(canAccessImageInput: true) == .present)
    }
}

// MARK: - Menú contextual de un grupo y soltar en la shell de solo grupos

struct GroupContextActionLogicTests {
    /// «Abrir grupo» va donde va el toque: no abre una solicitud en revisión ni una rechazada.
    @Test func open_onlyWhereTheTapOpensTheDetail() {
        #expect(GroupContextActionLogic.offersOpen(.active))
        #expect(GroupContextActionLogic.offersOpen(.migratedFrozen))
        #expect(GroupContextActionLogic.offersOpen(.migratedNeedsUpdate))
        #expect(GroupContextActionLogic.offersOpen(.migratedPaused))
        #expect(!GroupContextActionLogic.offersOpen(.pendingApproval))
        #expect(!GroupContextActionLogic.offersOpen(.rejected))
    }

    /// En la shell de solo grupos no hay Panel que presente la imagen: no se acepta lo soltado.
    @Test func receiptDrop_isRefusedInTheGroupsOnlyShell() {
        #expect(!ReceiptDropLogic.accepts(isGroupsOnly: true))
        #expect(ReceiptDropLogic.accepts(isGroupsOnly: false))
    }
}
