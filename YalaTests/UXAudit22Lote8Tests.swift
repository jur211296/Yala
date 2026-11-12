//
//  UXAudit22Lote8Tests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 8 (Registros), lo decidido que se prueba sin pantalla:
//  - L8-3: la píldora de necesidad solo en los gastos y el importe en gris en transferencias y ajustes.
//  - L8-5: «Pagaste / Tu parte / Te deben» de un gasto de grupo, desde sus patas.
//  - L8-7: cómo se nombra el registro en la pregunta de borrado.
//  - L8-9: el aviso tras cambiar la subcategoría nombra la necesidad solo si cambió.
//

import Foundation
import Testing

@testable import Yala

struct RecordRowPresentationLogicTests {

    @Test func needPill_onlyOnPlainExpenses() {
        #expect(RecordRowPresentationLogic.showsNeedPill(isBalanceAdjustment: false, isIncome: false, subcategoryIsSystem: false))
        #expect(!RecordRowPresentationLogic.showsNeedPill(isBalanceAdjustment: false, isIncome: true, subcategoryIsSystem: false),
                "un ingreso no tiene necesidad: salía «Sin clasificación»")
        #expect(!RecordRowPresentationLogic.showsNeedPill(isBalanceAdjustment: true, isIncome: false, subcategoryIsSystem: false),
                "transferencias y ajustes de saldo, sin píldora")
        #expect(!RecordRowPresentationLogic.showsNeedPill(isBalanceAdjustment: false, isIncome: false, subcategoryIsSystem: true),
                "las patas de sistema del puente de grupos, sin píldora")
    }

    @Test func amountStyle_neutralForTransfersAndAdjustments_evenWhenTheyAdd() {
        #expect(RecordRowPresentationLogic.amountStyle(isBalanceAdjustment: true, isIncome: true) == .neutral,
                "«Saldo inicial $ 2,000» suma, pero no es un ingreso")
        #expect(RecordRowPresentationLogic.amountStyle(isBalanceAdjustment: true, isIncome: false) == .neutral)
        #expect(RecordRowPresentationLogic.amountStyle(isBalanceAdjustment: false, isIncome: true) == .income)
        #expect(RecordRowPresentationLogic.amountStyle(isBalanceAdjustment: false, isIncome: false) == .expense)
    }
}

struct GroupExpenseBreakdownLogicTests {

    /// El caso de la auditoría: S/ 80 pagados por mí en un grupo de dos.
    @Test func iPaid_showsPaidShareAndOwed() {
        let breakdown = GroupExpenseBreakdownLogic.breakdown(legs: [
            .init(amount: -80, isSystemAccount: false),
            .init(amount: 40, isSystemAccount: true),
        ])
        #expect(breakdown == .init(youPaid: 80, yourShare: 40, owedToYou: 40))
    }

    /// Mi parte es lo que suman Estadísticas para ese gasto: el real más las patas de préstamo.
    @Test func iPaid_manyLoanLegs_shareIsTheRest() {
        let breakdown = GroupExpenseBreakdownLogic.breakdown(legs: [
            .init(amount: -300, isSystemAccount: false),
            .init(amount: 100, isSystemAccount: true),
            .init(amount: 100, isSystemAccount: true),
        ])
        #expect(breakdown == .init(youPaid: 300, yourShare: 100, owedToYou: 200))
    }

    /// Pagué todo y todo era mío: nadie me debe nada y no se pinta «Te deben 0».
    @Test func iPaid_allMine_nothingOwed() {
        let breakdown = GroupExpenseBreakdownLogic.breakdown(legs: [.init(amount: -50, isSystemAccount: false)])
        #expect(breakdown == .init(youPaid: 50, yourShare: 50, owedToYou: nil))
    }

    /// Pagó otra persona: la pata de coste en Grupos ya vale mi parte, y no se dice «Pagaste».
    @Test func someoneElsePaid_onlyMyShare() {
        let breakdown = GroupExpenseBreakdownLogic.breakdown(legs: [.init(amount: -40, isSystemAccount: true)])
        #expect(breakdown == .init(youPaid: nil, yourShare: 40, owedToYou: nil))
    }

    /// Solo la pata de préstamo a la vista (la real aún no llegó): no se inventa lo que pagaste.
    @Test func onlyALoanLeg_explainsNothing() {
        #expect(GroupExpenseBreakdownLogic.breakdown(legs: [.init(amount: 40, isSystemAccount: true)]) == nil)
        #expect(GroupExpenseBreakdownLogic.breakdown(legs: []) == nil)
    }
}

struct RecordDeleteConfirmationLogicTests {

    @Test func displayName_noteFirst_thenSubcategory_thenCategory() {
        #expect(RecordDeleteConfirmationLogic.displayName(note: "Uber", subcategoryName: "Taxis", categoryName: "Transporte") == "Uber")
        #expect(RecordDeleteConfirmationLogic.displayName(note: "  ", subcategoryName: "Taxis", categoryName: "Transporte") == "Taxis",
                "una nota en blanco no cuenta")
        #expect(RecordDeleteConfirmationLogic.displayName(note: nil, subcategoryName: nil, categoryName: "Transporte") == "Transporte")
        #expect(RecordDeleteConfirmationLogic.displayName(note: nil, subcategoryName: nil, categoryName: nil) == nil)
    }

    @Test func summary_isNameAndAmount() {
        #expect(RecordDeleteConfirmationLogic.summary(name: "Uber", amount: "S/ 26.00") == "Uber · S/ 26.00")
    }
}

struct SubcategoryChangeNoticeLogicTests {

    @Test func mentionsNeed_onlyWhenItChanged() {
        #expect(SubcategoryChangeNoticeLogic.mentionsNeed(old: .essential, new: .optional),
                "Supermercado (Esencial) → Restaurantes (Opcional): la necesidad cambió y se dice")
        #expect(!SubcategoryChangeNoticeLogic.mentionsNeed(old: .optional, new: .optional))
        #expect(!SubcategoryChangeNoticeLogic.mentionsNeed(old: .essential, new: nil), "un ingreso no tiene necesidad")
        #expect(SubcategoryChangeNoticeLogic.mentionsNeed(old: nil, new: .essential))
    }
}

/// L8-6: lo que no se puede hacer en un registro de grupo no se ofrece. Sin store ni pantalla: se mira el cableado del
/// editor, como `RecordsAuditLote8WiringTests`.
struct UXAudit22Lote8WiringTests {

    private static func code(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let src = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        return src.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    @Test func groupRecord_editorHidesDuplicateDeleteAndRecurring() throws {
        let code = try Self.code("Yala/App/Views/Transactions/NewTransactionView.swift")
        let bar = try #require(code.components(separatedBy: "private var quickActionsBar: some View {").dropFirst().first)
        let body = bar.components(separatedBy: "private func quickActionButton(").first ?? ""
        #expect(body.components(separatedBy: "if isEditingSavedRecord && !isBridgedReadOnly {").count == 3,
                "Duplicar y Eliminar tienen que esconderse en lo que viene de un grupo")
        #expect(body.contains("if !viewModel.isTransfer && !isBridgedReadOnly {"),
                "Recurrente tiene que esconderse en lo que viene de un grupo")
        #expect(!body.contains(".disabled(isBridgedCasoA)"), "vuelven los botones grises que no responden")
    }

    @Test func groupRecord_bannerSaysWhereToDelete() throws {
        let code = try Self.code("Yala/App/Views/Transactions/NewTransactionView.swift")
        let banner = try #require(code.components(separatedBy: "private var bridgedTxReadOnlyBanner: some View {").dropFirst().first)
        let body = banner.components(separatedBy: "private func handleBridgedCTA(").first ?? ""
        #expect(body.contains("L10n.UXL8.deleteFromGroupHint"))
    }

    @Test func lote8Accessors_resolve() {
        #expect(!L10n.UXL8.deleteNamedTitle("Uber · S/ 26").contains("records.l8"))
        #expect(!L10n.UXL8.deleteFromGroupHint.contains("records.l8"))
        #expect(!L10n.UXL8.changedToWithNeed("A", "B", "C").contains("records.l8"))
        #expect(!L10n.UXL8.selectHint.contains("records.l8"))
        #expect(!L10n.UXL8.duplicateReady.contains("records.l8"))
    }
}

/// Revisión adversarial del lote 8: «Quitar repetidos» borra, así que dos registros de cuentas distintas no son copias.
struct RecordsDuplicateAccountSignatureTests {

    private func candidate(_ id: Int, account: String?) -> RecordsDuplicateLogic.Candidate<Int> {
        RecordsDuplicateLogic.Candidate(
            id: id, amount: -20, currencyCode: "PEN", note: "Almuerzo", subcategoryID: "rest",
            date: Date(timeIntervalSince1970: 1_760_000_000), accountID: account)
    }

    private let all = RecordsDuplicateLogic.Criteria(amount: true, note: true, subcategory: true, date: true)

    @Test func sameLunchInTwoAccounts_isNotADuplicate() {
        let groups = RecordsDuplicateLogic.duplicateGroups(
            in: [candidate(1, account: "efectivo"), candidate(2, account: "tarjeta")], criteria: all)
        #expect(groups.isEmpty, "borrar uno cambiaría el saldo de la otra cuenta")
    }

    @Test func sameLunchTwiceInTheSameAccount_isADuplicate() {
        let groups = RecordsDuplicateLogic.duplicateGroups(
            in: [candidate(1, account: "efectivo"), candidate(2, account: "efectivo")], criteria: all)
        #expect(groups.count == 1)
        #expect(RecordsDuplicateLogic.removalPlan(groups).toDelete.count == 1, "se queda uno")
    }

    @Test func looseCriteria_stillSplitByAccount() {
        let onlyAmount = RecordsDuplicateLogic.Criteria(amount: true, note: false, subcategory: false, date: false)
        let groups = RecordsDuplicateLogic.duplicateGroups(
            in: [candidate(1, account: "a"), candidate(2, account: "b"), candidate(3, account: "a")], criteria: onlyAmount)
        #expect(groups.count == 1)
        #expect(Set(groups[0].map(\.id)) == [1, 3])
    }
}

/// El calendario no pinta «S/ 0» por un residuo de coma flotante (dos gastos y un reembolso que se anulan).
struct RecordsCalendarResidueTests {

    @Test func floatingResidue_isBelowTheThreshold() {
        let residue = (0.1 + 0.2) - 0.3
        #expect(residue > 0, "el residuo existe: por eso hace falta el umbral")
        #expect(residue < RecordsCalendarDaySummaryLogic.minimumAmount)
        #expect(0.01 >= RecordsCalendarDaySummaryLogic.minimumAmount, "un céntimo de verdad sí se pinta")
    }
}
