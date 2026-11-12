//
//  AccountRemovalServiceTests.swift
//  YalaTests
//
//  Mover o borrar lo que cuelga de una cuenta y eliminarla (decisión A, 2026-10-15).
//  Card `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID` y vacía el store en cada llamada, así
//  que `.serialized`. Las tasas se siembran (hoy y el día de cada fila): `prepareRates` no pide nada a la red
//  si ya están, que es lo que hace este camino determinista en el simulador.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Eliminar cuenta · mover o borrar", .serialized)
struct AccountRemovalServiceTests {

    /// 100 PEN de este día valen 25,00 USD.
    private static let rowKey = "2026-06-15"
    private static let rowPEN = 4.0

    private func date(_ key: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: key + " 12:00") ?? Date()
    }

    private static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: .now)
    }

    private struct Fixture {
        let context: ModelContext
        let source: Account
        let bank: Account
        let usd: Account
        let category: YalaCategory
        let sub: Subcategory
    }

    /// «Efectivo» (PEN, la que se elimina), «Banco» (PEN) y «Dólares» (USD), con las tasas del día de las filas
    /// y de hoy (4 PEN = 1 USD las dos).
    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        for key in [Self.rowKey, Self.todayKey] {
            _ = try makeTestExchangeRate(context: context, dateKey: key, rates: ["USD": 1.0, "PEN": Self.rowPEN])
        }
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let fixture = Fixture(
            context: context,
            source: makeTestAccount(context: context, name: "Efectivo", currencyCode: "PEN"),
            bank: makeTestAccount(context: context, name: "Banco", currencyCode: "PEN"),
            usd: makeTestAccount(context: context, name: "Dólares", currencyCode: "USD"),
            category: category, sub: sub)
        try context.save()
        return fixture
    }

    @discardableResult
    private func tx(_ f: Fixture, _ amount: Double, in account: Account, note: String) -> TransactionItem {
        let item = makeTestTransaction(
            context: f.context, amount: amount, date: date(Self.rowKey),
            account: account, category: f.category, subcategory: f.sub, currencyCode: account.currencyCode)
        item.note = note
        return item
    }

    /// Una transferencia entre dos cuentas: dos patas con el mismo `transferPairID`.
    private func transfer(_ f: Fixture, _ amount: Double, from: Account, to: Account) -> (TransactionItem, TransactionItem) {
        let pairID = UUID().uuidString
        let out = tx(f, -amount, in: from, note: "Transferencia")
        let inflow = tx(f, amount, in: to, note: "Transferencia")
        for leg in [out, inflow] {
            leg.transferPairID = pairID
            leg.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        }
        return (out, inflow)
    }

    private func deleteAccount(_ context: ModelContext) -> (Account) throws -> Void {
        { account in
            context.delete(account)
            try context.save()
        }
    }

    /// Los movimientos que la hoja habría enseñado al abrir.
    private func confirmed(_ f: Fixture) throws -> Set<PersistentIdentifier> {
        Set(try AccountRemovalService.inventory(of: f.source, context: f.context).transactions.map(\.persistentModelID))
    }

    private func transactions(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>())
    }

    private func accountNames(_ context: ModelContext) throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<Account>()).map(\.name))
    }

    // MARK: - Mover

    /// El caso del QA: Taxi 25 y Teléfono 33 pasan a «Banco», la cuenta desaparece y no queda ningún
    /// movimiento sin cuenta.
    @Test func mover_mismaDivisa_dejaLosMovimientosEnElDestino() async throws {
        let f = try makeFixture()
        tx(f, -25, in: f.source, note: "Taxi")
        tx(f, -33, in: f.source, note: "Teléfono")
        tx(f, 1000, in: f.bank, note: "Sueldo")
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.bank, context: f.context, deleteAccount: deleteAccount(f.context))

        let all = try transactions(f.context)
        #expect(all.count == 3)
        #expect(all.allSatisfy { $0.account?.name == "Banco" })
        #expect(all.map(\.amount).reduce(0, +) == 942)
        #expect(try accountNames(f.context) == ["Banco", "Dólares"])
    }

    /// Con otra divisa, cada fila se reexpresa con la tasa de SU fecha y sus derivadas se recalculan.
    @Test func mover_otraDivisa_convierteConLaTasaDeSuFecha() async throws {
        let f = try makeFixture()
        tx(f, -100, in: f.source, note: "Mercado")
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.usd, context: f.context, deleteAccount: deleteAccount(f.context))

        let moved = try #require(try transactions(f.context).first)
        #expect(moved.account?.name == "Dólares")
        #expect(moved.currencyCode == "USD")
        #expect(abs(moved.amount - -25) < 0.0001)
    }

    /// UX 2.2 · L2-14: el favorito de transferencia que llevaba dinero A la cuenta que se va pasa a llevarlo a la que
    /// la recibe; y el que iba de ella a la que la recibe se queda sin destino (origen y destino serían la misma).
    @Test func mover_llevaElDestinoDeLosFavoritosDeTransferencia() async throws {
        let f = try makeFixture()
        let toSource = FavoritePayment(
            name: "Ahorro", transactionType: "transfer", amount: 50, account: f.bank, destinationAccount: f.source)
        let sourceToBank = FavoritePayment(
            name: "Pago", transactionType: "transfer", amount: 20, account: f.source, destinationAccount: f.bank)
        f.context.insert(toSource)
        f.context.insert(sourceToBank)
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.bank, context: f.context, deleteAccount: deleteAccount(f.context))

        #expect(sourceToBank.account?.name == "Banco")
        #expect(sourceToBank.destinationAccount == nil)
        // «Banco → Banco» tampoco: el de «Banco → la que se va» se queda sin destino.
        #expect(toSource.account?.name == "Banco")
        #expect(toSource.destinationAccount == nil)
    }

    @Test func mover_aOtraCuenta_elDestinoPasaALaQueLaRecibe() async throws {
        let f = try makeFixture()
        let toSource = FavoritePayment(
            name: "Ahorro", transactionType: "transfer", amount: 50, account: f.bank, destinationAccount: f.source)
        f.context.insert(toSource)
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.usd, context: f.context, deleteAccount: deleteAccount(f.context))

        #expect(toSource.account?.name == "Banco")
        #expect(toSource.destinationAccount?.name == "Dólares")
    }

    /// Programados, favoritos y borradores pendientes se mueven con la cuenta, y con otra divisa se convierten.
    @Test func mover_otraDivisa_llevaProgramadosFavoritosYBorradores() async throws {
        let f = try makeFixture()
        let rent = ScheduledPayment(name: "Alquiler", amount: 400, currencyCode: "PEN", account: f.source, nextDueDate: .now)
        let favorite = FavoritePayment(name: "Mercado", amount: 40, account: f.source, currencyCode: "PEN")
        let draft = InboxDraft(amount: 80, date: date(Self.rowKey), account: f.source, subcategory: f.sub)
        f.context.insert(rent)
        f.context.insert(favorite)
        f.context.insert(draft)
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.usd, context: f.context, deleteAccount: deleteAccount(f.context))

        #expect(rent.account?.name == "Dólares")
        #expect(rent.currencyCode == "USD")
        #expect(abs(rent.amount - 100) < 0.0001)
        #expect(favorite.account?.name == "Dólares")
        #expect(abs((favorite.amount ?? 0) - 10) < 0.0001)
        #expect(draft.account?.name == "Dólares")
        #expect(abs((draft.amount ?? 0) - 20) < 0.0001)
    }

    /// Una transferencia «Efectivo → Banco» movida a «Banco» se quita entera; una con una tercera cuenta se
    /// queda emparejada y sale ahora de la cuenta destino.
    @Test func mover_transferencias_conLaParejaEnElDestinoSeQuitan() async throws {
        let f = try makeFixture()
        let card = makeTestAccount(context: f.context, name: "Tarjeta", currencyCode: "PEN")
        _ = transfer(f, 50, from: f.source, to: f.bank)
        let (out, inflow) = transfer(f, 30, from: f.source, to: card)
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.bank, context: f.context, deleteAccount: deleteAccount(f.context))

        let all = try transactions(f.context)
        #expect(all.count == 2)
        #expect(out.account?.name == "Banco")
        #expect(out.transferPairID != nil && out.transferPairID == inflow.transferPairID)
        #expect(inflow.account?.name == "Tarjeta")
    }

    /// A otra divisa, una transferencia que habría que convertir lo impide, y no se toca nada.
    @Test func mover_otraDivisa_conTransferencia_noHaceNada() async throws {
        let f = try makeFixture()
        let (out, _) = transfer(f, 50, from: f.source, to: f.bank)
        try f.context.save()

        await #expect(throws: AccountRemovalService.Failure.noLongerAllowed) {
            try await AccountRemovalService.move(
                f.source, to: f.usd, context: f.context, deleteAccount: self.deleteAccount(f.context))
        }
        #expect(out.account?.name == "Efectivo")
        #expect(out.amount == -50)
        #expect(try accountNames(f.context).contains("Efectivo"))
    }

    /// Sin la tasa del día de la fila no se convierte con la tabla estática: no se mueve nada.
    @Test func mover_otraDivisa_sinTasas_noHaceNada() async throws {
        let f = try makeFixture()
        let row = makeTestTransaction(
            context: f.context, amount: -100, date: date("2020-02-02"),
            account: f.source, category: f.category, subcategory: f.sub, currencyCode: "PEN")
        try f.context.save()
        AccountRemovalService.prepareRatesOverride = { _, _, _ in false }
        defer { AccountRemovalService.prepareRatesOverride = nil }

        await #expect(throws: AccountRemovalService.Failure.ratesUnavailable) {
            try await AccountRemovalService.move(
                f.source, to: f.usd, context: f.context, deleteAccount: self.deleteAccount(f.context))
        }
        #expect(row.amount == -100)
        #expect(row.account?.name == "Efectivo")
    }

    // MARK: - Borrar

    @Test func borrar_quitaLosMovimientosYLaCuenta() throws {
        let f = try makeFixture()
        tx(f, -25, in: f.source, note: "Taxi")
        tx(f, -33, in: f.source, note: "Teléfono")
        tx(f, 1000, in: f.bank, note: "Sueldo")
        try f.context.save()

        try AccountRemovalService.deleteRecords(
            of: f.source, confirmedTransactionIDs: try confirmed(f), context: f.context,
            deleteAccount: deleteAccount(f.context))

        let all = try transactions(f.context)
        #expect(all.map(\.note) == ["Sueldo"])
        #expect(all.allSatisfy { $0.account != nil })
        #expect(try accountNames(f.context) == ["Banco", "Dólares"])
    }

    /// La otra pata, en otra cuenta, se queda como movimiento normal: su saldo no cambia (D6).
    @Test func borrar_laOtraPataDeUnaTransferenciaSeQuedaComoMovimientoNormal() throws {
        let f = try makeFixture()
        let (_, inflow) = transfer(f, 50, from: f.source, to: f.bank)
        try f.context.save()

        try AccountRemovalService.deleteRecords(
            of: f.source, confirmedTransactionIDs: try confirmed(f), context: f.context,
            deleteAccount: deleteAccount(f.context))

        let all = try transactions(f.context)
        #expect(all.count == 1)
        #expect(inflow.account?.name == "Banco")
        #expect(inflow.amount == 50)
        #expect(inflow.transferPairID == nil)
        #expect(inflow.balanceAdjustmentType == nil)
    }

    /// Programados, favoritos y borradores pendientes se quedan, sin cuenta (D8).
    @Test func borrar_programadosFavoritosYBorradoresSeQuedanSinCuenta() throws {
        let f = try makeFixture()
        let rent = ScheduledPayment(name: "Alquiler", amount: 400, currencyCode: "PEN", account: f.source, nextDueDate: .now)
        let favorite = FavoritePayment(name: "Mercado", amount: 40, account: f.source, currencyCode: "PEN")
        let draft = InboxDraft(amount: 80, date: date(Self.rowKey), account: f.source, subcategory: f.sub)
        f.context.insert(rent)
        f.context.insert(favorite)
        f.context.insert(draft)
        try f.context.save()

        try AccountRemovalService.deleteRecords(
            of: f.source, confirmedTransactionIDs: try confirmed(f), context: f.context,
            deleteAccount: deleteAccount(f.context))

        #expect(try f.context.fetch(FetchDescriptor<ScheduledPayment>()).count == 1)
        #expect(rent.account == nil)
        #expect(favorite.account == nil)
        #expect(draft.account == nil)
        #expect(draft.status == .pending)
    }

    /// Con un movimiento de grupo no se borra nada: el siguiente sync lo resucitaría (D5).
    @Test func borrar_conMovimientoDeGrupo_noHaceNada() throws {
        let f = try makeFixture()
        let group = tx(f, -40, in: f.source, note: "Cena")
        group.splitExpenseID = UUID().uuidString
        try f.context.save()

        #expect(throws: AccountRemovalService.Failure.noLongerAllowed) {
            try AccountRemovalService.deleteRecords(
                of: f.source, confirmedTransactionIDs: try self.confirmed(f), context: f.context,
                deleteAccount: self.deleteAccount(f.context))
        }
        #expect(try transactions(f.context).count == 1)
        #expect(try accountNames(f.context).contains("Efectivo"))
    }

    /// Si llegan movimientos nuevos de la cuenta después de confirmar la cifra, no se borra nada.
    @Test func borrar_conUnMovimientoQueLlegoDespuesDeConfirmar_noHaceNada() throws {
        let f = try makeFixture()
        tx(f, -25, in: f.source, note: "Taxi")
        try f.context.save()
        let seen = try confirmed(f)
        tx(f, -99, in: f.source, note: "Llegó del iPad")
        try f.context.save()

        #expect(throws: AccountRemovalService.Failure.noLongerAllowed) {
            try AccountRemovalService.deleteRecords(
                of: f.source, confirmedTransactionIDs: seen, context: f.context,
                deleteAccount: self.deleteAccount(f.context))
        }
        #expect(try transactions(f.context).count == 2)
    }

    /// Si el guardado falla, no queda nada aplicado a medias en el contexto (`rollback`).
    @Test func borrar_siFallaElGuardado_noQuedaNadaAplicado() throws {
        let f = try makeFixture()
        let taxi = tx(f, -25, in: f.source, note: "Taxi")
        try f.context.save()
        struct Boom: Error {}

        #expect(throws: AccountRemovalService.Failure.saveFailed) {
            try AccountRemovalService.deleteRecords(
                of: f.source, confirmedTransactionIDs: try self.confirmed(f), context: f.context,
                deleteAccount: { _ in throw Boom() })
        }
        #expect(f.context.hasChanges == false)
        #expect(try transactions(f.context).count == 1)
        #expect(taxi.modelContext != nil)
    }

    /// El saldo inicial de la cuenta que se va entra en el destino como ajuste: el destino conserva uno solo.
    @Test func mover_elSaldoInicialEntraComoAjuste() async throws {
        let f = try makeFixture()
        let opening = tx(f, 200, in: f.source, note: "Saldo inicial")
        opening.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        let bankOpening = tx(f, 500, in: f.bank, note: "Saldo inicial")
        bankOpening.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.bank, context: f.context, deleteAccount: deleteAccount(f.context))

        #expect(opening.account?.name == "Banco")
        #expect(opening.balanceAdjustmentType == InitialBalanceService.typeAdjustment)
        #expect(bankOpening.balanceAdjustmentType == InitialBalanceService.typeInitialBalance)
    }

    /// Un presupuesto que miraba la cuenta pasa a mirar el destino (las dos mitades del filtro).
    @Test func mover_elPresupuestoPasaAMirarElDestino() async throws {
        let f = try makeFixture()
        let budget = Budget(currencyCode: "PEN", limitAmount: 300, name: "Comida", accounts: [f.source])
        f.context.insert(budget)
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.bank, context: f.context, deleteAccount: deleteAccount(f.context))

        #expect(budget.accountIDsSet == [f.bank.shortcutID])
        #expect(budget.accounts?.map(\.name) == ["Banco"])
    }

    /// Al borrar, un presupuesto que solo miraba esta cuenta queda sin filtro de cuentas, y la hoja lo avisa.
    @Test func borrar_presupuestoQueSoloMirabaLaCuenta_quedaSinFiltroYSeAvisa() throws {
        let f = try makeFixture()
        let budget = Budget(currencyCode: "PEN", limitAmount: 300, name: "Comida", accounts: [f.source])
        f.context.insert(budget)
        try f.context.save()
        #expect(try AccountRemovalService.inventory(of: f.source, context: f.context).shape.budgetsOnlyThisAccount == 1)

        try AccountRemovalService.deleteRecords(
            of: f.source, confirmedTransactionIDs: try confirmed(f), context: f.context,
            deleteAccount: deleteAccount(f.context))

        #expect(budget.accountIDsSet == nil)
    }

    /// Las dos patas se reconocen aunque el `transferPairID` venga en otro formato (mayúsculas, espacios).
    @Test func mover_laParejaSeReconoceConElIdEnOtroFormato() async throws {
        let f = try makeFixture()
        let (out, inflow) = transfer(f, 50, from: f.source, to: f.bank)
        let pairID = try #require(out.transferPairID)
        out.transferPairID = pairID.lowercased()
        inflow.transferPairID = " " + pairID.uppercased()
        try f.context.save()

        try await AccountRemovalService.move(
            f.source, to: f.bank, context: f.context, deleteAccount: deleteAccount(f.context))

        #expect(try transactions(f.context).isEmpty)
    }

    // MARK: - Destinos e inventario

    /// Sin otra cuenta elegible a mano (archivada o de sistema), no hay a dónde mover.
    @Test func destinos_excluyenArchivadasYDeSistema() throws {
        let f = try makeFixture()
        f.bank.isArchived = true
        f.usd.isSystemAccount = true
        try f.context.save()

        #expect(try AccountRemovalService.destinations(excluding: f.source, context: f.context).isEmpty)
        f.bank.isArchived = false
        #expect(try AccountRemovalService.destinations(excluding: f.source, context: f.context).map(\.name) == ["Banco"])
    }

    /// El inventario cuenta solo lo de ESTA cuenta, y los borradores aprobados no cuentan.
    @Test func inventario_cuentaSoloLoDeLaCuentaYLosPendientes() throws {
        let f = try makeFixture()
        tx(f, -25, in: f.source, note: "Taxi")
        tx(f, 1000, in: f.bank, note: "Sueldo")
        f.context.insert(InboxDraft(amount: 1, account: f.source, status: .approved))
        f.context.insert(InboxDraft(amount: 2, account: f.source))
        try f.context.save()

        let shape = try AccountRemovalService.inventory(of: f.source, context: f.context).shape
        #expect(shape.rows.count == 1)
        #expect(shape.pendingDraftCount == 1)
        #expect(shape.needsQuestion)
        let empty = try AccountRemovalService.inventory(of: f.usd, context: f.context).shape
        #expect(empty.needsQuestion == false)
    }

    // MARK: - Saldo que enseña la hoja (propuesta A, card rd7z)

    private func balance(of account: Account, _ context: ModelContext) throws -> Decimal {
        AccountBalanceCalculator.currentBalance(for: account, allTransactions: try transactions(context))
    }

    /// Lo que la hoja promete es lo que la mudanza deja: con una transferencia con la pareja en el destino (se quita
    /// entera) y otra con una tercera cuenta (entra).
    @Test func previsionDelSaldo_mismaDivisa_coincideConLoQueDejaMover() async throws {
        let f = try makeFixture()
        let card = makeTestAccount(context: f.context, name: "Tarjeta", currencyCode: "PEN")
        tx(f, -25, in: f.source, note: "Taxi")
        tx(f, -33, in: f.source, note: "Teléfono")
        tx(f, 1000, in: f.bank, note: "Sueldo")
        _ = transfer(f, 50, from: f.source, to: f.bank)
        _ = transfer(f, 30, from: f.source, to: card)
        try f.context.save()

        let inventory = try AccountRemovalService.inventory(of: f.source, context: f.context)
        let previews = try AccountRemovalService.balancePreviews(
            of: inventory, destinations: [f.bank, f.usd, card], context: f.context)
        #expect(previews.source == -138)
        let preview = try #require(previews.byDestination[f.bank.persistentModelID])
        #expect(preview.before == 1050)
        #expect(preview.after == 912)
        #expect(preview.isApproximate == false)

        try await AccountRemovalService.move(
            f.source, to: f.bank, context: f.context, deleteAccount: deleteAccount(f.context))
        #expect(try balance(of: f.bank, f.context) == preview.after)
    }

    /// A otra divisa, con la tasa de la fecha de cada fila (4 PEN = 1 USD): −100 PEN entran como −25 USD.
    @Test func previsionDelSaldo_otraDivisa_convierteComoMover() async throws {
        let f = try makeFixture()
        tx(f, -100, in: f.source, note: "Mercado")
        try f.context.save()

        let inventory = try AccountRemovalService.inventory(of: f.source, context: f.context)
        let previews = try AccountRemovalService.balancePreviews(
            of: inventory, destinations: [f.bank, f.usd], context: f.context)
        let preview = try #require(previews.byDestination[f.usd.persistentModelID])
        #expect(preview.before == 0)
        #expect(abs(NSDecimalNumber(decimal: preview.after).doubleValue - -25) < 0.0001)
        #expect(preview.isApproximate == false)

        try await AccountRemovalService.move(
            f.source, to: f.usd, context: f.context, deleteAccount: deleteAccount(f.context))
        let after = NSDecimalNumber(decimal: try balance(of: f.usd, f.context)).doubleValue
        #expect(abs(after - NSDecimalNumber(decimal: preview.after).doubleValue) < 0.0001)
    }

    /// Un destino al que no se puede mover no tiene previsión, y lo fechado en el futuro no cuenta (como el saldo).
    @Test func previsionDelSaldo_soloDestinosPermitidosYHastaHoy() throws {
        let f = try makeFixture()
        _ = transfer(f, 50, from: f.source, to: f.bank)
        let future = makeTestTransaction(
            context: f.context, amount: -7, date: Date.now.addingTimeInterval(86_400 * 30),
            account: f.source, category: f.category, subcategory: f.sub, currencyCode: "PEN")
        future.note = "Futuro"
        try f.context.save()

        let inventory = try AccountRemovalService.inventory(of: f.source, context: f.context)
        let previews = try AccountRemovalService.balancePreviews(
            of: inventory, destinations: [f.bank, f.usd], context: f.context)
        #expect(previews.byDestination[f.usd.persistentModelID] == nil)
        #expect(previews.source == -50)
        #expect(previews.byDestination[f.bank.persistentModelID]?.after == 0)
    }
}
