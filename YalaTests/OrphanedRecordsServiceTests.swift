//
//  OrphanedRecordsServiceTests.swift
//  YalaTests
//
//  Movimientos que se quedaron sin cuenta: el aviso los encuentra (también los que llegan tarde) y moverlos los
//  devuelve al saldo. Cards `tablero-los-movimientos-que-quedaron-sin-cuenta-sovw` y
//  `tablero-eliminar-una-cuenta-todavia-puede-dejar-mjzx`.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID` y vacía el store en cada llamada, así que
//  `.serialized`. Las tasas se siembran (día de las filas y hoy): `prepareRates` no pide nada a la red si ya están.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Movimientos sin cuenta · encontrar y mover", .serialized)
struct OrphanedRecordsServiceTests {

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

    /// «Efectivo» (PEN, la que se elimina a pelo, como antes de la 2.1), «Banco» (PEN) y «Dólares» (USD).
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

    /// Lo que hacía «Eliminar cuenta» antes de la 2.1: borrar la cuenta sin mirar. `.nullify` deja sus movimientos
    /// sin cuenta.
    private func deleteBluntly(_ account: Account, _ f: Fixture) throws {
        f.context.delete(account)
        try f.context.save()
    }

    private func ids(_ f: Fixture) throws -> Set<PersistentIdentifier> {
        Set(try OrphanedRecordsService.inventory(context: f.context).transactions.map(\.persistentModelID))
    }

    /// El saldo que el Panel suma: solo movimientos con cuenta.
    private func countedBalance(_ f: Fixture) throws -> Double {
        try f.context.fetch(FetchDescriptor<TransactionItem>())
            .filter { $0.account != nil }
            .map(\.amount)
            .reduce(0, +)
    }

    // MARK: - Encontrar

    /// El caso del QA: Taxi 25 y Teléfono 33 de «Efectivo» se quedan sin cuenta y el saldo pierde los 58.
    @Test func borradoAntiguo_dejaDosHuerfanos_yElSaldoLosPierde() throws {
        let f = try makeFixture()
        tx(f, -25, in: f.source, note: "Taxi")
        tx(f, -33, in: f.source, note: "Teléfono")
        tx(f, 1000, in: f.bank, note: "Sueldo")
        try f.context.save()
        try deleteBluntly(f.source, f)

        let orphans = try OrphanedRecordsService.inventory(context: f.context).transactions
        #expect(Set(orphans.compactMap(\.note)) == ["Taxi", "Teléfono"])
        #expect(try countedBalance(f) == 1000)
    }

    /// (b) Un movimiento que llega DESPUÉS de eliminar su cuenta (otro dispositivo, una restauración a medias) también
    /// sale: el recuento no es un barrido único.
    @Test func movimientoQueLlegaTarde_trasEliminarLaCuenta_tambienSale() throws {
        let f = try makeFixture()
        try deleteBluntly(f.source, f)
        #expect(try ids(f).isEmpty)

        // Llega por sync apuntando a una cuenta que aquí ya no existe: la referencia no resuelve y queda sin cuenta.
        let late = TransactionItem(
            date: date(Self.rowKey), amount: -40, currencyCode: "PEN", note: "Gasto de otro dispositivo",
            category: f.category, subcategory: f.sub, account: nil)
        f.context.insert(late)
        try f.context.save()

        #expect(try ids(f) == [late.persistentModelID])
    }

    /// (b) La otra mitad del hueco: el movimiento llegó ANTES que el borrado de su cuenta (la restauración trajo la
    /// cuenta vacía y luego sus movimientos, o el borrado de otro dispositivo llega después). Al borrar, sale.
    @Test func cuentaEliminadaDespuesDeQueLlegaraSuMovimiento_elMovimientoSale() throws {
        let f = try makeFixture()
        let arrived = tx(f, -12, in: f.source, note: "Café")
        try f.context.save()
        #expect(try ids(f).isEmpty)

        try deleteBluntly(f.source, f)

        #expect(try ids(f) == [arrived.persistentModelID])
    }

    /// Una fila de grupo sin cuenta es ambigua (pata virtual con su cuenta de sistema sin hidratar): no sale.
    @Test func filaDeGrupoSinCuenta_noSale() throws {
        let f = try makeFixture()
        let groupLeg = tx(f, -20, in: f.source, note: "Cena del grupo")
        groupLeg.splitExpenseID = UUID().uuidString
        let settlement = tx(f, 15, in: f.source, note: "Liquidación")
        settlement.splitSettlementID = UUID().uuidString
        try f.context.save()
        try deleteBluntly(f.source, f)

        #expect(try ids(f).isEmpty)
    }

    /// El Panel recuenta en cada recarga: el aviso ve los huérfanos, y tras moverlos deja de verlos sin que cambie el
    /// array de movimientos (mover cambia la cuenta en sitio).
    @Test func panel_recuentaEnCadaRecarga() async throws {
        let f = try makeFixture()
        tx(f, -25, in: f.source, note: "Taxi")
        try f.context.save()
        let panel = PanelViewModel()
        panel.setContext(f.context, defaultCurrencyCode: "PEN", sessionState: SessionState.shared)

        panel.loadData()
        #expect(panel.orphanedRecordCount == 0)

        try deleteBluntly(f.source, f)
        panel.loadData()
        #expect(panel.orphanedRecordCount == 1)

        try await OrphanedRecordsService.move(try ids(f), to: f.bank, context: f.context)
        panel.loadData()
        #expect(panel.orphanedRecordCount == 0)
    }

    // MARK: - Mover

    /// Taxi y Teléfono pasan a «Banco»: el saldo vuelve a 942 y no queda ningún huérfano.
    @Test func mover_mismaMoneda_losDevuelveAlSaldo() async throws {
        let f = try makeFixture()
        tx(f, -25, in: f.source, note: "Taxi")
        tx(f, -33, in: f.source, note: "Teléfono")
        tx(f, 1000, in: f.bank, note: "Sueldo")
        try f.context.save()
        try deleteBluntly(f.source, f)

        let moved = try await OrphanedRecordsService.move(try ids(f), to: f.bank, context: f.context)

        #expect(moved == 2)
        #expect(try ids(f).isEmpty)
        #expect(try countedBalance(f) == 942)
        let all = try f.context.fetch(FetchDescriptor<TransactionItem>())
        #expect(all.allSatisfy { $0.account?.name == "Banco" })
    }

    /// A otra moneda, cada fila se reexpresa con la tasa de SU fecha.
    @Test func mover_otraMoneda_convierteConLaTasaDeSuFecha() async throws {
        let f = try makeFixture()
        let row = tx(f, -100, in: f.source, note: "Mercado")
        try f.context.save()
        try deleteBluntly(f.source, f)

        try await OrphanedRecordsService.move(try ids(f), to: f.usd, context: f.context)

        #expect(row.account?.name == "Dólares")
        #expect(row.currencyCode == "USD")
        #expect(abs(row.amount - -25) < 0.0001)
    }

    /// Solo se mueven los que la persona vio: uno que llega con la hoja abierta espera al siguiente aviso, y uno que
    /// recuperó su cuenta mientras tanto no se toca.
    @Test func mover_soloLosQueSeVieron_yQueSiguenSinCuenta() async throws {
        let f = try makeFixture()
        let seen = tx(f, -25, in: f.source, note: "Taxi")
        let recovered = tx(f, -33, in: f.source, note: "Teléfono")
        try f.context.save()
        try deleteBluntly(f.source, f)
        let confirmed = try ids(f)

        let card = makeTestAccount(context: f.context, name: "Tarjeta", currencyCode: "PEN")
        recovered.account = card
        let late = TransactionItem(
            date: date(Self.rowKey), amount: -7, currencyCode: "PEN", note: "Llegó después",
            category: f.category, subcategory: f.sub, account: nil)
        f.context.insert(late)
        try f.context.save()

        try await OrphanedRecordsService.move(confirmed, to: f.bank, context: f.context)

        #expect(seen.account?.name == "Banco")
        #expect(recovered.account?.name == "Tarjeta")
        #expect(late.account == nil)
        #expect(try ids(f) == [late.persistentModelID])
    }

    /// Una transferencia «Efectivo → Banco» movida a «Banco» se quita entera; con otra cuenta, la pata se mueve y
    /// sigue emparejada.
    @Test func mover_transferencia_conLaParejaEnElDestino_seQuita() async throws {
        let f = try makeFixture()
        let card = makeTestAccount(context: f.context, name: "Tarjeta", currencyCode: "PEN")
        func transfer(_ amount: Double, to other: Account) -> (TransactionItem, TransactionItem) {
            let pair = UUID().uuidString
            let out = tx(f, -amount, in: f.source, note: "Transferencia")
            let inflow = tx(f, amount, in: other, note: "Transferencia")
            for leg in [out, inflow] {
                leg.transferPairID = pair
                leg.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            }
            return (out, inflow)
        }
        _ = transfer(50, to: f.bank)
        let (out, inflow) = transfer(30, to: card)
        try f.context.save()
        try deleteBluntly(f.source, f)

        let moved = try await OrphanedRecordsService.move(try ids(f), to: f.bank, context: f.context)

        #expect(moved == 1)
        let all = try f.context.fetch(FetchDescriptor<TransactionItem>())
        #expect(all.count == 2)
        #expect(out.account?.name == "Banco")
        #expect(out.transferPairID != nil && out.transferPairID == inflow.transferPairID)
    }

    /// A otra moneda, una transferencia pasa tal cual (sin convertir) en vez de bloquear: el gasto de al lado sí se
    /// convierte, y ninguno se queda fuera del saldo.
    @Test func mover_otraMoneda_conTransferencia_laPasaTalCual() async throws {
        let f = try makeFixture()
        let out = tx(f, -50, in: f.source, note: "Transferencia")
        let inflow = tx(f, 50, in: f.bank, note: "Transferencia")
        let pair = UUID().uuidString
        for leg in [out, inflow] {
            leg.transferPairID = pair
            leg.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        }
        let expense = tx(f, -100, in: f.source, note: "Mercado")
        try f.context.save()
        try deleteBluntly(f.source, f)

        try await OrphanedRecordsService.move(try ids(f), to: f.usd, context: f.context)

        #expect(out.account?.name == "Dólares")
        #expect(out.currencyCode == "PEN" && out.amount == -50)
        #expect(out.transferPairID == inflow.transferPairID)
        #expect(expense.account?.name == "Dólares")
        #expect(expense.currencyCode == "USD" && abs(expense.amount - -25) < 0.0001)
        #expect(try ids(f).isEmpty)
    }

    /// Una transferencia entre dos cuentas borradas deja sus dos patas sin cuenta: se quitan las dos en vez de acabar
    /// «de Banco a Banco».
    @Test func mover_transferenciaConLasDosPatasSinCuenta_seQuita() async throws {
        let f = try makeFixture()
        let other = makeTestAccount(context: f.context, name: "Ahorros", currencyCode: "PEN")
        let out = tx(f, -40, in: f.source, note: "Transferencia")
        let inflow = tx(f, 40, in: other, note: "Transferencia")
        let pair = UUID().uuidString
        for leg in [out, inflow] {
            leg.transferPairID = pair
            leg.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        }
        let expense = tx(f, -9, in: f.source, note: "Pan")
        try f.context.save()
        try deleteBluntly(f.source, f)
        try deleteBluntly(other, f)
        #expect(try ids(f).count == 3)

        let moved = try await OrphanedRecordsService.move(try ids(f), to: f.bank, context: f.context)

        #expect(moved == 1)
        #expect(expense.account?.name == "Banco")
        let remaining = try f.context.fetch(FetchDescriptor<TransactionItem>())
        #expect(remaining.count == 1)
        #expect(try ids(f).isEmpty)
    }

    /// Con el import en marcha no se mueve nada: un movimiento puede verse sin cuenta solo porque su cuenta no ha
    /// llegado. La hoja puede quedarse abierta, así que mover vuelve a preguntarlo.
    @Test func mover_conElImportEnMarcha_noMueveNada() async throws {
        let f = try makeFixture()
        let row = tx(f, -10, in: f.source, note: "Pan")
        try f.context.save()
        try deleteBluntly(f.source, f)
        OrphanedRecordsService.importIsQuiescentOverride = { false }
        defer { OrphanedRecordsService.importIsQuiescentOverride = nil }

        await #expect(throws: AccountRemovalService.Failure.noLongerAllowed) {
            try await OrphanedRecordsService.move(try self.ids(f), to: f.bank, context: f.context)
        }
        #expect(row.account == nil)
    }

    /// El saldo inicial de la cuenta borrada entra como ajuste: la cuenta destino ya tiene el suyo.
    @Test func mover_saldoInicial_pasaAAjuste() async throws {
        let f = try makeFixture()
        let opening = tx(f, 200, in: f.source, note: "Saldo inicial")
        opening.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        try f.context.save()
        try deleteBluntly(f.source, f)

        try await OrphanedRecordsService.move(try ids(f), to: f.bank, context: f.context)

        #expect(opening.account?.name == "Banco")
        #expect(opening.balanceAdjustmentType == InitialBalanceService.typeAdjustment)
    }

    /// Sin las tasas a mano no se convierte con lo que haya: no se mueve nada.
    @Test func mover_sinTasas_noMueveNada() async throws {
        let f = try makeFixture()
        let row = tx(f, -100, in: f.source, note: "Mercado")
        row.date = date("2020-01-05")
        try f.context.save()
        try deleteBluntly(f.source, f)
        OrphanedRecordsService.prepareRatesOverride = { _, _ in false }
        defer { OrphanedRecordsService.prepareRatesOverride = nil }

        await #expect(throws: AccountRemovalService.Failure.ratesUnavailable) {
            try await OrphanedRecordsService.move(try self.ids(f), to: f.usd, context: f.context)
        }
        #expect(row.account == nil)
        #expect(row.amount == -100)
    }

    /// Una cuenta archivada no es destino.
    @Test func mover_aUnaCuentaArchivada_noSePuede() async throws {
        let f = try makeFixture()
        let row = tx(f, -10, in: f.source, note: "Pan")
        try f.context.save()
        try deleteBluntly(f.source, f)
        f.bank.isArchived = true
        try f.context.save()

        #expect(try !OrphanedRecordsService.destinations(context: f.context).contains { $0.name == "Banco" })
        await #expect(throws: AccountRemovalService.Failure.noLongerAllowed) {
            try await OrphanedRecordsService.move(try self.ids(f), to: f.bank, context: f.context)
        }
        #expect(row.account == nil)
    }
}
