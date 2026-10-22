//
//  GroupShareableSummaryLogicTests.swift
//  YalaTests
//
//  Cubre `GroupShareableSummaryLogic` — el resumen compartible del «cierre del viaje».
//  Lógica pura sobre `@Model` directos: sin `ModelContext`, sin `makeTestContext`, sin `.serialized`
//  (molde de `SettlementReminderLogicTests`).
//
//  Cada test está escrito para MORIR si se revierte la decisión que prueba, no solo para recorrer el
//  camino feliz. Los cuatro que más importan en ese sentido: la unión de monedas (`debtWithoutExpense…`),
//  la simplificación incondicional (`paymentsAreAlwaysSimplified…`), la frontera del saldo inicial
//  (`openingBalanceIsDebtButNotSpending`) y el dedup de CloudKit (`duplicateExpensesDoNotInflate…`).
//

import Testing
import Foundation
@testable import Yala

// MARK: - Helpers (molde de GroupBalanceServiceTests — no hay factory compartida de Split*)

@MainActor
private func makeGroup(
    name: String = "Viaje a Cusco",
    currencyCode: String = "PEN",
    simplifyDebts: Bool = false,
    showDebtsInSingleCurrency: Bool = false
) -> SplitGroup {
    SplitGroup(
        name: name,
        iconName: "airplane",
        colorHex: "#8B5CF6",
        currencyCode: currencyCode,
        simplifyDebts: simplifyDebts,
        showDebtsInSingleCurrency: showDebtsInSingleCurrency
    )
}

@MainActor
private func makeExpense(
    id: UUID = UUID(),
    amount: Double,
    currencyCode: String = "PEN",
    paidByMemberID: String,
    isSettled: Bool = false,
    isOpeningBalance: Bool = false
) -> SplitExpense {
    let e = SplitExpense(
        groupZoneID: "test-zone",
        amount: amount,
        currencyCode: currencyCode,
        expenseDescription: "Test",
        paidByMemberID: paidByMemberID
    )
    e.id = id
    e.isSettled = isSettled
    e.isOpeningBalance = isOpeningBalance
    return e
}

@MainActor
private func makeShare(expenseID: UUID, memberID: String, amount: Double) -> SplitShare {
    SplitShare(expenseID: expenseID, memberID: memberID, amount: amount)
}

@MainActor
private func makeMember(id: UUID, displayName: String) -> SplitMember {
    let m = SplitMember(displayName: displayName)
    m.id = id
    return m
}

@MainActor
private func makeSettlement(
    fromMemberID: String,
    toMemberID: String,
    amount: Double,
    currencyCode: String = "PEN",
    isConfirmed: Bool = true
) -> SplitSettlement {
    let s = SplitSettlement(
        groupZoneID: "test-zone",
        fromMemberID: fromMemberID,
        toMemberID: toMemberID,
        amount: amount,
        currencyCode: currencyCode
    )
    s.isConfirmed = isConfirmed
    return s
}

// IDs fijos: los tests comparan arrays ordenados y un UUID aleatorio haría inestable el desempate.
private let anaUUID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
private let betoUUID = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
private let carlaUUID = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000003")!
private let ana = anaUUID.uuidString
private let beto = betoUUID.uuidString
private let carla = carlaUUID.uuidString

private let sinNombre = "Sin nombre"

@MainActor
private func threeMembers() -> [SplitMember] {
    [
        makeMember(id: anaUUID, displayName: "Ana"),
        makeMember(id: betoUUID, displayName: "Beto"),
        makeMember(id: carlaUUID, displayName: "Carla")
    ]
}

// MARK: - Suite

@Suite("Resumen compartible de grupo · construcción")
@MainActor
struct GroupShareableSummaryLogicTests {

    /// AC del ticket: nombre del grupo, total gastado, desglose por miembro y lista mínima de pagos.
    @Test("AC · total, quién pagó qué y los pagos mínimos para saldar")
    func buildsTheWholeSummary() throws {
        let group = makeGroup()
        let e1 = makeExpense(amount: 900, paidByMemberID: ana)
        let shares = [
            makeShare(expenseID: e1.id, memberID: ana, amount: 300),
            makeShare(expenseID: e1.id, memberID: beto, amount: 300),
            makeShare(expenseID: e1.id, memberID: carla, amount: 300)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        #expect(snapshot.groupName == "Viaje a Cusco")
        #expect(snapshot.blocks.count == 1)

        let block = try #require(snapshot.blocks.first)
        #expect(block.currencyCode == "PEN")
        #expect(block.totalSpent == 900)

        // Desglose: Ana puso los 900 y le tocaban 300; los otros dos no pusieron nada.
        #expect(block.members.count == 3)
        #expect(block.members[0].displayName == "Ana")
        #expect(block.members[0].paid == 900)
        #expect(block.members[0].owed == 300)
        #expect(block.members.allSatisfy { $0.owed == 300 })

        // Dos pagos, ambos hacia Ana.
        #expect(block.payments.count == 2)
        #expect(block.payments.allSatisfy { $0.toName == "Ana" && $0.amount == 300 })
        #expect(Set(block.payments.map(\.fromName)) == ["Beto", "Carla"])
        #expect(snapshot.isFullySettled == false)
    }

    /// AC del ticket: multi-moneda por separado, jamás sumadas en un mismo número.
    @Test("AC · dos monedas dan dos bloques y ningún total las mezcla")
    func multiCurrencyNeverMixes() throws {
        let group = makeGroup(currencyCode: "PEN")
        let pen = makeExpense(amount: 200, currencyCode: "PEN", paidByMemberID: ana)
        let usd = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: beto)
        let shares = [
            makeShare(expenseID: pen.id, memberID: ana, amount: 100),
            makeShare(expenseID: pen.id, memberID: beto, amount: 100),
            makeShare(expenseID: usd.id, memberID: ana, amount: 25),
            makeShare(expenseID: usd.id, memberID: beto, amount: 25)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [pen, usd], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        #expect(snapshot.blocks.count == 2)
        // La principal del grupo va primero (molde de GroupStatsViewModel.orderedCurrencies).
        #expect(snapshot.blocks.map(\.currencyCode) == ["PEN", "USD"])
        #expect(snapshot.blocks[0].totalSpent == 200)
        #expect(snapshot.blocks[1].totalSpent == 50)
        // Ningún bloque cargó el importe del otro (250 sería la suma cruda; 190 la convertida).
        #expect(snapshot.blocks.allSatisfy { $0.totalSpent != 250 })

        // Y las deudas también quedan en su moneda.
        #expect(snapshot.blocks[0].payments.map(\.amount) == [100])
        #expect(snapshot.blocks[1].payments.map(\.amount) == [25])
    }

    /// El saldo inicial es deuda arrastrada, no gasto del viaje. Frontera deliberada: fuera del
    /// total (igual que Estadísticas), dentro de los pagos (igual que Balances).
    @Test("El saldo inicial no suma al total gastado, pero sí genera pago")
    func openingBalanceIsDebtButNotSpending() throws {
        let group = makeGroup()
        let opening = makeExpense(amount: 500, paidByMemberID: ana, isOpeningBalance: true)
        let real = makeExpense(amount: 100, paidByMemberID: ana)
        let shares = [
            makeShare(expenseID: opening.id, memberID: beto, amount: 500),
            makeShare(expenseID: real.id, memberID: ana, amount: 50),
            makeShare(expenseID: real.id, memberID: beto, amount: 50)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [opening, real], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        // 100, no 600: el saldo inicial no es gasto.
        #expect(block.totalSpent == 100)
        // Y tampoco entra en el desglose de quién pagó qué.
        let anaLine = try #require(block.members.first { $0.displayName == "Ana" })
        #expect(anaLine.paid == 100)
        // Pero sí en lo que hay que transferir: 500 del saldo inicial + 50 del gasto real.
        #expect(block.payments.count == 1)
        #expect(block.payments[0].amount == 550)
    }

    /// El caso que se pierde si se recorren solo las monedas CON gasto: una divisa cuya única huella
    /// es un saldo inicial tiene deuda viva y ni un gasto real detrás.
    @Test("Una moneda con deuda y sin gasto real igual aparece en el resumen")
    func debtWithoutExpenseStillGetsItsBlock() throws {
        let group = makeGroup(currencyCode: "PEN")
        let pen = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: ana)
        let usdOpening = makeExpense(
            amount: 80, currencyCode: "USD", paidByMemberID: ana, isOpeningBalance: true
        )
        let shares = [
            makeShare(expenseID: pen.id, memberID: ana, amount: 50),
            makeShare(expenseID: pen.id, memberID: beto, amount: 50),
            makeShare(expenseID: usdOpening.id, memberID: beto, amount: 80)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [pen, usdOpening], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        #expect(snapshot.blocks.count == 2)
        let usdBlock = try #require(snapshot.blocks.first { $0.currencyCode == "USD" })
        #expect(usdBlock.totalSpent == 0)
        #expect(usdBlock.members.isEmpty)
        #expect(usdBlock.payments.count == 1)
        #expect(usdBlock.payments[0].amount == 80)
        #expect(usdBlock.payments[0].fromName == "Beto")
    }

    /// El resumen responde «cómo saldamos esto en los menos pagos posibles», así que simplifica
    /// SIEMPRE — aunque el grupo tenga la preferencia apagada y su pestaña Balances muestre otra cosa.
    @Test("Los pagos se simplifican aunque el grupo tenga simplifyDebts apagado")
    func paymentsAreAlwaysSimplified() throws {
        let group = makeGroup(simplifyDebts: false)
        // Cadena A→B→C: sin simplificar son dos transferencias; simplificada, una sola.
        let e1 = makeExpense(amount: 100, paidByMemberID: beto)
        let e2 = makeExpense(amount: 100, paidByMemberID: carla)
        let shares = [
            makeShare(expenseID: e1.id, memberID: ana, amount: 100),
            makeShare(expenseID: e2.id, memberID: beto, amount: 100)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1, e2], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        // Con `simplifyDebts: false` el servicio devolvería DOS deudas (Ana→Beto y Beto→Carla).
        #expect(block.payments.count == 1)
        #expect(block.payments[0].fromName == "Ana")
        #expect(block.payments[0].toName == "Carla")
        #expect(block.payments[0].amount == 100)
    }

    /// Un duplicado de CloudKit inflaría un número que se congela en una imagen y se reparte por el
    /// chat del grupo.
    @Test("Un gasto duplicado por CloudKit no infla el total")
    func duplicateExpensesDoNotInflateTheTotal() throws {
        let group = makeGroup()
        let sharedID = UUID()
        let original = makeExpense(id: sharedID, amount: 300, paidByMemberID: ana)
        let duplicate = makeExpense(id: sharedID, amount: 300, paidByMemberID: ana)
        let shares = [
            makeShare(expenseID: sharedID, memberID: ana, amount: 150),
            makeShare(expenseID: sharedID, memberID: beto, amount: 150)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [original, duplicate], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        #expect(block.totalSpent == 300)
        let anaLine = try #require(block.members.first { $0.displayName == "Ana" })
        #expect(anaLine.paid == 300)
    }

    /// Invariante REAL: lo pagado recorre los mismos gastos que el total, así que suma exacto.
    ///
    /// Lo que NO se aserta aquí, a propósito, es `sumOwed == totalSpent`: la implementación dice
    /// expresamente que la columna «le tocaba» puede descuadrar (reparto exacto con tolerancia,
    /// importes que bajan del wire sin pasar por el calculador). Un test que lo afirmara pasaría con
    /// la lógica actual y con una que reconciliara el residuo por su cuenta — no distinguiría las
    /// dos, que es la definición de falso verde. El caso que sí las distingue está justo debajo.
    @Test("La suma de lo pagado por cada miembro es el total del bloque")
    func paidSumsToTotal() throws {
        let group = makeGroup()
        let e1 = makeExpense(amount: 120.5, paidByMemberID: ana)
        let e2 = makeExpense(amount: 79.5, paidByMemberID: beto)
        let shares = [
            makeShare(expenseID: e1.id, memberID: ana, amount: 60.25),
            makeShare(expenseID: e1.id, memberID: beto, amount: 60.25),
            makeShare(expenseID: e2.id, memberID: ana, amount: 39.75),
            makeShare(expenseID: e2.id, memberID: beto, amount: 39.75)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1, e2], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        let sumPaid = block.members.reduce(0) { $0 + $1.paid }
        #expect(sumPaid == block.totalSpent)
    }

    /// Y el reverso: cuando los repartos guardados NO suman su gasto, el resumen los enseña tal
    /// cual en vez de cuadrarlos. Fija la decisión de ser fiel al dato: si alguien reconciliara el
    /// residuo, la imagen mostraría una parte distinta de la que el grupo tiene guardada.
    @Test("Si los repartos guardados no suman el gasto, el resumen no los cuadra")
    func owedIsShownAsStoredEvenWhenItDoesNotAddUp() throws {
        let group = makeGroup()
        // 50 repartidos en tres partes redondeadas hacia arriba: 16,67 × 3 = 50,01.
        let e1 = makeExpense(amount: 50, paidByMemberID: ana)
        let shares = [ana, beto, carla].map { makeShare(expenseID: e1.id, memberID: $0, amount: 16.67) }

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        #expect(block.totalSpent == 50)
        #expect(block.members.allSatisfy { $0.owed == 16.67 })
        let sumOwed = block.members.reduce(0) { $0 + $1.owed }
        #expect(sumOwed != block.totalSpent)
        #expect(abs(sumOwed - 50.01) < 0.001)
    }

    /// Deduplicar solo los gastos blindaba el total y la columna «pagó» y dejaba «le tocaba» al
    /// doble: la misma imagen contradiciéndose a sí misma.
    @Test("Los repartos duplicados tampoco inflan la columna «le tocaba»")
    func duplicateSharesDoNotInflateTheOwedColumn() throws {
        let group = makeGroup()
        let expenseID = UUID()
        let expense = makeExpense(id: expenseID, amount: 300, paidByMemberID: ana)
        let shareID = UUID()
        let original = makeShare(expenseID: expenseID, memberID: beto, amount: 300)
        original.id = shareID
        let duplicate = makeShare(expenseID: expenseID, memberID: beto, amount: 300)
        duplicate.id = shareID

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [expense], shares: [original, duplicate],
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        #expect(block.totalSpent == 300)
        let betoLine = try #require(block.members.first { $0.displayName == "Beto" })
        #expect(betoLine.owed == 300)
        #expect(block.payments.count == 1)
        #expect(block.payments[0].amount == 300)
    }

    /// El defecto más caro que encontró la review: con «ver deudas en una sola moneda», el grupo
    /// ESCRIBE sus liquidaciones en la moneda del grupo, no en la del gasto. Sin consolidar, la
    /// deuda original seguía viva en su divisa y el pago aparecía como deuda inversa en la otra: dos
    /// transferencias fantasma en direcciones opuestas por dinero que ya no se debe.
    @Test("Con «una sola moneda», una deuda liquidada en la moneda del grupo queda saldada")
    func singleCurrencyGroupNetsSettlementsAcrossCurrencies() throws {
        let group = makeGroup(currencyCode: "PEN", showDebtsInSingleCurrency: true)
        let usd = makeExpense(amount: 100, currencyCode: "USD", paidByMemberID: ana)
        let shares = [
            makeShare(expenseID: usd.id, memberID: ana, amount: 50),
            makeShare(expenseID: usd.id, memberID: beto, amount: 50)
        ]
        // Beto liquida desde la pestaña Balances, que le ofrece la deuda ya consolidada a PEN.
        let converted = CurrencyConverter.shared.convertWithLatestRate(Decimal(50), from: "USD", to: "PEN")
        let settled = makeSettlement(
            fromMemberID: beto, toMemberID: ana,
            amount: NSDecimalNumber(decimal: converted).doubleValue,
            currencyCode: "PEN"
        )

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [usd], shares: shares,
            settlements: [settled], unknownMemberName: sinNombre
        )

        // Ni un pago vivo en ninguna divisa: es la misma conclusión que da la pestaña Balances.
        #expect(snapshot.blocks.allSatisfy { $0.payments.isEmpty })
        #expect(snapshot.isFullySettled)
        // Y tiene que haber DÓNDE decirlo: sin un bloque que cuente pagos, la imagen se queda sin
        // sitio para el «todo saldado» y sale muda, que es media razón de mandarla. (El gasto es en
        // USD, así que ese bloque solo existe si se fuerza el de la moneda del grupo.)
        let settledBlock = try #require(snapshot.blocks.first { $0.showsPayments })
        #expect(settledBlock.currencyCode == "PEN")
        #expect(settledBlock.isSettled)
        #expect(settledBlock.hasSpending == false)
        // Y el bloque de la divisa del gasto no puede decir «todo saldado» por su cuenta: sus deudas
        // se cuentan en el de la moneda del grupo.
        let usdBlock = try #require(snapshot.blocks.first { $0.currencyCode == "USD" })
        #expect(usdBlock.showsPayments == false)
        #expect(usdBlock.isSettled == false)
        // El total del gasto sigue en SU moneda: los totales no se convierten nunca.
        #expect(usdBlock.totalSpent == 100)
    }

    /// Y el complemento: con el ajuste ENCENDIDO y deuda viva, los pagos aparecen una sola vez, en
    /// la moneda del grupo, marcados como convertidos.
    @Test("Con «una sola moneda», los pagos van solo en la moneda del grupo y marcados como aproximados")
    func singleCurrencyGroupPlacesPaymentsOnlyInTheGroupCurrency() throws {
        let group = makeGroup(currencyCode: "PEN", showDebtsInSingleCurrency: true)
        let usd = makeExpense(amount: 100, currencyCode: "USD", paidByMemberID: ana)
        let shares = [
            makeShare(expenseID: usd.id, memberID: ana, amount: 50),
            makeShare(expenseID: usd.id, memberID: beto, amount: 50)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [usd], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let penBlock = try #require(snapshot.blocks.first { $0.currencyCode == "PEN" })
        #expect(penBlock.showsPayments)
        #expect(penBlock.paymentsAreConverted)
        #expect(penBlock.payments.count == 1)
        #expect(penBlock.payments[0].fromName == "Beto")
        // El gasto es en USD, así que este bloque no tiene total propio ni desglose.
        #expect(penBlock.totalSpent == 0)

        let usdBlock = try #require(snapshot.blocks.first { $0.currencyCode == "USD" })
        #expect(usdBlock.payments.isEmpty)
        #expect(usdBlock.showsPayments == false)
    }

    /// Una liquidación ya confirmada deja de aparecer como pago pendiente.
    @Test("Una liquidación confirmada cierra el pago y el resumen lo dice")
    func confirmedSettlementClearsThePayment() throws {
        let group = makeGroup()
        let e1 = makeExpense(amount: 100, paidByMemberID: ana)
        let shares = [
            makeShare(expenseID: e1.id, memberID: ana, amount: 50),
            makeShare(expenseID: e1.id, memberID: beto, amount: 50)
        ]
        let settled = makeSettlement(fromMemberID: beto, toMemberID: ana, amount: 50)

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1], shares: shares,
            settlements: [settled], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        // El gasto sigue contando en el total del viaje…
        #expect(block.totalSpent == 100)
        // …pero ya no hay nada que transferir.
        #expect(block.payments.isEmpty)
        #expect(block.isSettled)
        #expect(snapshot.isFullySettled)
    }

    /// Frontera de `isSettled`: sigue siendo gasto del viaje, ya no es deuda.
    @Test("Un gasto marcado como saldado cuenta en el total pero no genera pago")
    func settledExpenseCountsAsSpendingButNotAsDebt() throws {
        let group = makeGroup()
        let e1 = makeExpense(amount: 240, paidByMemberID: ana, isSettled: true)
        let shares = [
            makeShare(expenseID: e1.id, memberID: ana, amount: 120),
            makeShare(expenseID: e1.id, memberID: beto, amount: 120)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        #expect(block.totalSpent == 240)
        #expect(block.payments.isEmpty)
    }

    /// La moneda principal del grupo abre el resumen, aunque alfabéticamente fuera la última.
    ///
    /// El fixture es deliberadamente PEN/USD-al-revés: con la moneda principal `USD` y una segunda
    /// `EUR`, ordenar alfabéticamente daría `["EUR", "USD"]` y «principal primero» da `["USD", "EUR"]`.
    /// Escrito así porque el test de multi-moneda de arriba usa PEN/USD, donde las dos reglas
    /// coinciden — medido con un mutante: cambiar el orden a `codes.sorted()` lo dejaba en VERDE.
    @Test("La moneda principal del grupo abre el resumen aunque no sea la primera alfabéticamente")
    func mainCurrencyGoesFirstEvenWhenAlphabeticallyLast() throws {
        let group = makeGroup(currencyCode: "USD")
        let usd = makeExpense(amount: 100, currencyCode: "USD", paidByMemberID: ana)
        let eur = makeExpense(amount: 40, currencyCode: "EUR", paidByMemberID: beto)
        let shares = [
            makeShare(expenseID: usd.id, memberID: ana, amount: 100),
            makeShare(expenseID: eur.id, memberID: beto, amount: 40)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [eur, usd], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        #expect(snapshot.blocks.map(\.currencyCode) == ["USD", "EUR"])
    }

    /// Orden determinista: dos generaciones del mismo grupo tienen que dar la misma imagen.
    @Test("Los miembros van por lo que pusieron, de más a menos")
    func membersAreOrderedByAmountPaid() throws {
        let group = makeGroup()
        let e1 = makeExpense(amount: 10, paidByMemberID: carla)
        let e2 = makeExpense(amount: 300, paidByMemberID: ana)
        let e3 = makeExpense(amount: 90, paidByMemberID: beto)
        let shares = [e1, e2, e3].flatMap { expense in
            [ana, beto, carla].map { makeShare(expenseID: expense.id, memberID: $0, amount: expense.amount / 3) }
        }

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1, e2, e3], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        #expect(block.members.map(\.displayName) == ["Ana", "Beto", "Carla"])
        #expect(block.members.map(\.paid) == [300, 90, 10])
    }

    /// Un `memberID` sin miembro que lo respalde no puede acabar como UUID crudo en una imagen que
    /// se manda al grupo.
    @Test("Un miembro que ya no está sale con el nombre de reemplazo, no con su UUID")
    func missingMemberFallsBackToTheInjectedName() throws {
        let group = makeGroup()
        let fantasma = UUID().uuidString
        let e1 = makeExpense(amount: 60, paidByMemberID: fantasma)
        let shares = [
            makeShare(expenseID: e1.id, memberID: ana, amount: 30),
            makeShare(expenseID: e1.id, memberID: fantasma, amount: 30)
        ]

        let snapshot = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1], shares: shares,
            settlements: [], unknownMemberName: sinNombre
        )

        let block = try #require(snapshot.blocks.first)
        let ghostLine = try #require(block.members.first { $0.memberID == fantasma })
        #expect(ghostLine.displayName == sinNombre)
        #expect(!block.members.contains { $0.displayName.contains("-") })
    }

    /// Sin nada que resumir, el punto de entrada no se ofrece (`isEmpty` es lo que lo decide).
    @Test("Un grupo sin gastos ni deudas da un resumen vacío")
    func emptyGroupYieldsEmptySnapshot() throws {
        let snapshot = GroupShareableSummaryLogic.build(
            group: makeGroup(), members: threeMembers(), expenses: [], shares: [],
            settlements: [], unknownMemberName: sinNombre
        )

        #expect(snapshot.isEmpty)
        #expect(snapshot.blocks.isEmpty)
        #expect(snapshot.isFullySettled)
    }

    /// Solo-lectura: el AC lo pide explícitamente. Se comprueba por el lado observable — construir
    /// el resumen no cambia ni un campo de los objetos que recibe.
    @Test("AC · construir el resumen no toca ningún dato del grupo")
    func buildingIsReadOnly() throws {
        let group = makeGroup()
        let e1 = makeExpense(amount: 100, paidByMemberID: ana)
        let share = makeShare(expenseID: e1.id, memberID: beto, amount: 100)
        let settlement = makeSettlement(fromMemberID: beto, toMemberID: ana, amount: 20)

        let before = (
            groupName: group.name,
            simplify: group.simplifyDebts,
            amount: e1.amount,
            settled: e1.isSettled,
            shareAmount: share.amount,
            settlementConfirmed: settlement.isConfirmed
        )

        _ = GroupShareableSummaryLogic.build(
            group: group, members: threeMembers(), expenses: [e1], shares: [share],
            settlements: [settlement], unknownMemberName: sinNombre
        )

        #expect(group.name == before.groupName)
        #expect(group.simplifyDebts == before.simplify)
        #expect(e1.amount == before.amount)
        #expect(e1.isSettled == before.settled)
        #expect(share.amount == before.shareAmount)
        #expect(settlement.isConfirmed == before.settlementConfirmed)
    }
}
