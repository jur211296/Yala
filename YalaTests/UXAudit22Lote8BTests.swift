//
//  UXAudit22Lote8BTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 8 (Registros), cards L8-10, L8-11 y L8-13: la lógica pura detrás del resumen del día del
//  calendario, de los grupos de duplicados («Quitar repetidos») y de «Editar varios» (elegir primero, aplicar
//  después). Sin ModelContext: los `@Model` se crean sueltos, como en `DailySpendingCalculatorTests`.
//

import Foundation
import Testing

@testable import Yala

// MARK: - L8-10 · Calendario: lo que sumó cada día

@MainActor
struct UXAudit22Lote8BCalendarTests {

    private let calendar = Calendar.current

    private func startOfDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
        let date = calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
        return calendar.startOfDay(for: date)
    }

    private func makeAccount(excludeFromStatistics: Bool = false) -> Account {
        Account(
            name: "Main", currencyCode: "USD", colorHex: "#6366F1",
            iconName: "creditcard", type: "bank",
            excludeFromStatistics: excludeFromStatistics
        )
    }

    private func makeTx(
        _ preferred: Double, account: Account?, isIncome: Bool, balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(),
            amount: preferred,
            currencyCode: "USD",
            note: "",
            category: YalaCategory(name: isIncome ? "Sueldo" : "Comida", colorHex: "#FF0000", isIncome: isIncome),
            account: account,
            tags: [],
            amountInPreferredCurrency: preferred,
            preferredCurrencyCode: "USD"
        )
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    @Test func dayTotals_countsSpendingAndIncome_withTheSummaryRules() {
        let account = makeAccount()
        let records = [
            makeTx(-2300, account: account, isIncome: false),
            makeTx(354, account: account, isIncome: true),
            // Un reembolso de gasto RESTA del gasto (acumulación signed, como el hero).
            makeTx(100, account: account, isIncome: false),
            // Transferencias y ajustes no cuentan.
            makeTx(-500, account: account, isIncome: false, balanceAdjustmentType: TransactionItem.adjustmentTypeTransfer),
            // Una cuenta fuera de estadísticas tampoco.
            makeTx(-999, account: makeAccount(excludeFromStatistics: true), isIncome: false),
        ]
        let totals = DailySpendingCalculator.dayTotals(records: records, currencyCode: "USD")
        #expect(totals.expense == 2200)
        #expect(totals.income == 354)
    }

    @Test func compute_marksIncomeOnlyDays_andKnowsWhichDaysHaveRecords() {
        let account = makeAccount()
        let payday = startOfDay(2026, 10, 15)
        let transferDay = startOfDay(2026, 10, 16)
        let result = DailySpendingCalculator.compute(
            groups: [
                (date: payday, records: [makeTx(354, account: account, isIncome: true)]),
                (date: transferDay, records: [
                    makeTx(-50, account: account, isIncome: false, balanceAdjustmentType: TransactionItem.adjustmentTypeTransfer),
                ]),
            ],
            currencyCode: "USD"
        )
        // El día de cobro ya no sale en blanco: lleva ingreso (el punto) y no gasto (sin barra).
        #expect(result.incomeByDay[payday] == 354)
        #expect(result.spendingByDay[payday] == nil)
        // El día con solo una transferencia tiene registros: VoiceOver no dice «Sin registros».
        #expect(result.daysWithRecords == [payday, transferDay])
        #expect(result.incomeByDay[transferDay] == nil)
    }

    @Test func daySummary_namesOnlyTheSidesThatAreNotZero() {
        typealias Logic = RecordsCalendarDaySummaryLogic
        #expect(Logic.parts(.init(expense: 2300, income: 354)) == [.spent(2300), .income(354)])
        #expect(Logic.parts(.init(expense: 2300, income: 0)) == [.spent(2300)])
        #expect(Logic.parts(.init(expense: 0, income: 354)) == [.income(354)])
        #expect(Logic.parts(.init(expense: 0, income: 0)).isEmpty)
        // Solo un reembolso: el gasto neto es negativo y no se nombra.
        #expect(Logic.parts(.init(expense: -40, income: 0)).isEmpty)
        // El residuo de coma flotante no se pinta como «Gastaste S/ 0.00».
        #expect(Logic.parts(.init(expense: 1e-12, income: 0)).isEmpty)
    }
}

// MARK: - L8-11 · Duplicados: grupos y cuál se queda

@MainActor
struct UXAudit22Lote8BDuplicatesTests {

    private typealias Logic = RecordsDuplicateLogic

    private func date(_ day: Int, hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 10; comps.day = day; comps.hour = hour
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps) ?? .distantPast
    }

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    private let all = Logic.Criteria(amount: true, note: true, subcategory: true, date: true)

    private func cand(
        _ id: Int, amount: Double = -50, note: String? = "Cena", day: Int = 10,
        createdAt: Int = 0, deletable: Bool = true, tiebreak: String = ""
    ) -> Logic.Candidate<Int> {
        .init(
            id: id, amount: amount, currencyCode: "PEN", note: note, subcategoryID: "sub", date: date(day),
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            isDeletable: deletable, tiebreak: tiebreak
        )
    }

    @Test func groups_keepEachSetTogether_andDropSingles() {
        let groups = Logic.duplicateGroups(
            in: [cand(1), cand(2, amount: -80), cand(3), cand(4, amount: -80), cand(5, amount: -99)],
            criteria: all, calendar: utc)
        #expect(groups.count == 2)
        #expect(Set(groups.map { Set($0.map(\.id)) }) == [[1, 3], [2, 4]])
    }

    @Test func groups_putTheFirstCreatedFirst_thatIsTheOneThatStays() {
        let groups = Logic.duplicateGroups(
            in: [cand(1, createdAt: 300), cand(2, createdAt: 100), cand(3, createdAt: 200)],
            criteria: all, calendar: utc)
        #expect(groups.first?.map(\.id) == [2, 3, 1])
    }

    @Test func groups_keepTheGroupRecord_becauseItCannotBeDeletedHere() {
        // El registro de Grupos es el más nuevo, pero no se puede borrar desde Registros: quedarse con otro
        // dejaría dos.
        let groups = Logic.duplicateGroups(
            in: [cand(1, createdAt: 100), cand(2, createdAt: 900, deletable: false)],
            criteria: all, calendar: utc)
        #expect(groups.first?.first?.id == 2)
        let plan = Logic.removalPlan(groups)
        #expect(plan.toDelete == [1])
        #expect(plan.keptGroupRecords == 0)
    }

    @Test func groups_tieOnCreation_fallsBackToDateThenTiebreak() {
        let byDate = Logic.duplicateGroups(
            in: [
                .init(id: 1, amount: -5, currencyCode: "PEN", note: nil, subcategoryID: "s", date: date(10, hour: 18)),
                .init(id: 2, amount: -5, currencyCode: "PEN", note: nil, subcategoryID: "s", date: date(10, hour: 8)),
            ],
            criteria: all, calendar: utc)
        #expect(byDate.first?.map(\.id) == [2, 1])

        let byTiebreak = Logic.duplicateGroups(
            in: [cand(1, tiebreak: "b"), cand(2, tiebreak: "a")], criteria: all, calendar: utc)
        #expect(byTiebreak.first?.map(\.id) == [2, 1])
    }

    @Test func groups_areOrderedFromTheMostRecent() {
        let groups = Logic.duplicateGroups(
            in: [cand(1, day: 3), cand(2, day: 3), cand(3, amount: -9, day: 20), cand(4, amount: -9, day: 20)],
            criteria: all, calendar: utc)
        #expect(groups.map { $0.map(\.id).sorted() } == [[3, 4], [1, 2]])
    }

    @Test func removalPlan_leavesOnePerGroup_andCountsTheGroupRecordsThatStay() {
        let groups = Logic.duplicateGroups(
            in: [
                cand(1, createdAt: 1), cand(2, createdAt: 2), cand(3, createdAt: 3),
                cand(4, amount: -7, createdAt: 1, deletable: false), cand(5, amount: -7, createdAt: 2, deletable: false),
            ],
            criteria: all, calendar: utc)
        let plan = Logic.removalPlan(groups)
        #expect(Set(plan.toDelete) == [2, 3])
        // Dos de Grupos en el mismo grupo: uno se queda como «el de cada grupo» y el otro se queda porque no se
        // puede borrar aquí.
        #expect(plan.keptGroupRecords == 1)

        let tally = Logic.tally(groups)
        #expect(tally == Logic.Tally(duplicates: 5, groups: 2))
    }

    @Test func noCriteria_meansNoGroups() {
        let none = Logic.Criteria(amount: false, note: false, subcategory: false, date: false)
        #expect(Logic.duplicateGroups(in: [cand(1), cand(2)], criteria: none, calendar: utc).isEmpty)
        #expect(none.activeFields.isEmpty)
    }

    @Test func activeFields_followTheMenuOrder() {
        let some = Logic.Criteria(amount: true, note: false, subcategory: true, date: true)
        #expect(some.activeFields == [.amount, .subcategory, .date])
    }
}

// MARK: - L8-13 · Editar varios: lo de hoy y lo pendiente

@MainActor
struct UXAudit22Lote8BBulkEditTests {

    @Test func current_saysTheSharedValue_orHowManyDiffer() {
        #expect(BulkEditLogic.current(["Ahorros", "Ahorros"]) == .same("Ahorros"))
        #expect(BulkEditLogic.current(["Ahorros", "Sueldo", "Ahorros"]) == .distinct(2))
        // Nota vacía y sin nota son lo mismo: «Sin nota».
        #expect(BulkEditLogic.current([nil, "", "  "]) == .same(nil))
        #expect(BulkEditLogic.current([nil, "Taxi"]) == .distinct(2))
    }

    @Test func amountCurrency_isTheNewAccountsOrTheSharedOne_elseNotOffered() {
        #expect(BulkEditLogic.amountCurrency(selectedCurrencies: ["PEN", "pen"], pendingAccountCurrency: nil) == "PEN")
        #expect(BulkEditLogic.amountCurrency(selectedCurrencies: ["PEN", "USD"], pendingAccountCurrency: nil) == nil)
        // Con una cuenta nueva, todos quedan en su moneda: el monto vuelve a tener sentido.
        #expect(BulkEditLogic.amountCurrency(selectedCurrencies: ["PEN", "USD"], pendingAccountCurrency: "USD") == "USD")
    }

    @Test func currencyWarning_onlyWhenTheNewAccountChangesSomeCurrency() {
        #expect(BulkEditLogic.changesCurrency(selectedCurrencies: ["PEN", "PEN"], destination: "PEN") == false)
        #expect(BulkEditLogic.changesCurrency(selectedCurrencies: ["PEN", "USD"], destination: "PEN") == true)
    }

    @Test func summaryLines_listWhatWillChange_inTheOptionsOrder() {
        let lines = BulkEditLogic.summaryLines(
            account: "Ahorros", subcategory: "Restaurantes",
            tagsAdded: ["Viaje"], tagsRemoved: ["Trabajo"],
            note: "  ", amount: "S/ 20.00", noNote: "Sin nota")
        #expect(lines.map(\.option) == [.account, .subcategory, .tag, .note, .amount])
        #expect(lines.map(\.value) == ["Ahorros", "Restaurantes", "+Viaje, −Trabajo", "Sin nota", "S/ 20.00"])
    }

    @Test func summaryLines_areEmptyWithoutPendingChanges() {
        let lines = BulkEditLogic.summaryLines(
            account: nil, subcategory: nil, tagsAdded: [], tagsRemoved: [], note: nil, amount: nil, noNote: "Sin nota")
        #expect(lines.isEmpty)
    }

    @Test func changes_knowWhatIsPending() {
        var changes = BulkEditChanges()
        #expect(changes.isEmpty)
        #expect(changes.changedOptions.isEmpty)
        changes.amount = 20
        changes.note = ""
        #expect(!changes.isEmpty)
        #expect(changes.changedOptions == [.amount, .note])
        let before = changes.signature
        changes.amount = 25
        #expect(changes.signature != before)
    }
}
