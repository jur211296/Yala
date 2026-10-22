//
//  AccountRemovalLogicTests.swift
//  YalaTests
//
//  Qué se puede hacer con lo que cuelga de una cuenta antes de eliminarla (decisión A, 2026-10-15).
//  Card `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`. Lógica pura, sin SwiftData.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Eliminar cuenta · decisiones")
struct AccountRemovalLogicTests {

    private typealias Logic = AccountRemovalLogic
    private typealias Row = AccountRemovalLogic.Row<String>

    private func row(
        _ currency: String = "PEN",
        block: AccountCurrencyChangeLogic.BlockReason? = nil,
        group: Bool = false,
        partner: String? = nil
    ) -> Row {
        Row(currencyCode: currency, conversionBlock: block, isGroupRecord: group, transferPartnerAccount: partner)
    }

    private func inventory(
        _ rows: [Row] = [],
        source: String = "PEN",
        scheduled: [AccountRemovalLogic.ScheduledShape] = [],
        favorites: Int = 0,
        favoriteCurrencies: [String] = [],
        drafts: Int = 0,
        draftsNotConvertible: Int = 0,
        draftsToConvert: Int = 0,
        budgets: Int = 0,
        budgetsOnly: Int = 0
    ) -> AccountRemovalLogic.Inventory<String> {
        .init(
            sourceCurrencyCode: source, rows: rows, scheduled: scheduled,
            favoriteCount: favorites, favoriteAmountCurrencies: favoriteCurrencies,
            pendingDraftCount: drafts, pendingDraftsNotConvertible: draftsNotConvertible,
            pendingDraftsToConvert: draftsToConvert, budgetCount: budgets, budgetsOnlyThisAccount: budgetsOnly)
    }

    // MARK: - ¿Pregunta?

    @Test func vacia_seEliminaComoSiempre() {
        #expect(inventory().needsQuestion == false)
    }

    @Test func conMovimientos_pregunta() {
        #expect(inventory([row()]).needsQuestion)
    }

    /// Un alquiler programado sin movimientos también quedaba sin cuenta en silencio (D1).
    @Test func soloConProgramadosFavoritosOBorradores_tambienPregunta() {
        #expect(inventory(scheduled: [.init(currencyCode: "PEN", isGroupPayment: false)]).needsQuestion)
        #expect(inventory(favorites: 1).needsQuestion)
        #expect(inventory(drafts: 1).needsQuestion)
    }

    /// Un presupuesto que solo miraba esta cuenta pasaría a mirar todas sin decirlo; uno que mira más, no.
    @Test func presupuestoQueSoloMirabaEstaCuenta_pregunta() {
        #expect(inventory(budgets: 1, budgetsOnly: 1).needsQuestion)
        #expect(inventory(budgets: 1, budgetsOnly: 0).needsQuestion == false)
    }

    // MARK: - Borrar

    @Test func borrar_permitido_cuentaLasParejasQueSeQuedanFuera() {
        let verdict = Logic.deleteVerdict(inventory([row(), row(block: .transfer, partner: "B")]))
        #expect(verdict == .allowed(rowCount: 2, partnersKept: 1))
    }

    /// Borrar un movimiento de grupo lo resucita el siguiente sync como borrador (D5).
    @Test func borrar_conMovimientosDeGrupo_seBloquea() {
        let verdict = Logic.deleteVerdict(inventory([row(), row(block: .groupExpense, group: true)]))
        #expect(verdict == .blockedByGroupRecords(count: 1))
    }

    // MARK: - Mover

    @Test func mover_mismaDivisa_sinConvertir() {
        let inv = inventory([row(), row(block: .groupExpense, group: true), row(block: .transfer, partner: "C")])
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "PEN"))
            == .allowed(movedRows: 3, convertedRows: 0, collapsedTransfers: 0, convertsPlans: false))
    }

    @Test func mover_otraDivisa_convierteLasLibres() {
        #expect(Logic.moveVerdict(inventory([row(), row()]), to: .init(id: "B", currencyCode: "USD"))
            == .allowed(movedRows: 2, convertedRows: 2, collapsedTransfers: 0, convertsPlans: false))
    }

    /// Una transferencia, un gasto o una liquidación de grupo no admiten conversión (`AccountCurrencyChangeLogic`).
    @Test(arguments: AccountCurrencyChangeLogic.BlockReason.allCases)
    func mover_otraDivisa_conFilaQueNoSeConvierte_seBloquea(_ reason: AccountCurrencyChangeLogic.BlockReason) {
        let inv = inventory([row(), row(block: reason, group: reason != .transfer, partner: reason == .transfer ? "C" : nil)])
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "USD")) == .blockedByCurrency)
    }

    /// La fila bloqueada que YA está en la divisa del destino no se convierte, así que no bloquea.
    @Test func mover_filaBloqueadaYaEnLaDivisaDestino_noBloquea() {
        let inv = inventory([row("USD", block: .transfer, partner: "C"), row()])
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "USD"))
            == .allowed(movedRows: 2, convertedRows: 1, collapsedTransfers: 0, convertsPlans: false))
    }

    /// Una transferencia que YA venía en otra divisa que su cuenta se mueve tal cual, sin convertir y sin
    /// bloquear: queda igual de desemparejada que estaba, no peor.
    @Test func mover_filaBloqueadaYaDesemparejada_seMueveSinConvertir() {
        let inv = inventory([row("USD", block: .transfer, partner: "C")])
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "PEN"))
            == .allowed(movedRows: 1, convertedRows: 0, collapsedTransfers: 0, convertsPlans: false))
    }

    /// Un favorito en otra divisa se convierte aunque la cuenta y el destino compartan divisa: la hoja lo dice.
    @Test func mover_favoritoEnOtraDivisa_seAnunciaAunqueLaCuentaNoCambie() {
        let inv = inventory(favorites: 1, favoriteCurrencies: ["USD"])
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "PEN"))
            == .allowed(movedRows: 0, convertedRows: 0, collapsedTransfers: 0, convertsPlans: true))
    }

    /// Un borrador sin importe no tiene nada que convertir: ni bloquea ni se anuncia.
    @Test func mover_borradorSinImporte_niBloqueaNiSeAnuncia() {
        let inv = inventory(drafts: 1)
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "USD"))
            == .allowed(movedRows: 0, convertedRows: 0, collapsedTransfers: 0, convertsPlans: false))
    }

    /// Con la otra pata en el destino, la transferencia se quita: no se convierte y no bloquea (D7).
    @Test func mover_transferenciaConLaParejaEnElDestino_seQuitaYNoBloquea() {
        let inv = inventory([row(block: .transfer, partner: "B"), row()])
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "USD"))
            == .allowed(movedRows: 1, convertedRows: 1, collapsedTransfers: 1, convertsPlans: false))
    }

    @Test func mover_programadoDeGrupoEnOtraDivisa_seBloquea() {
        let inv = inventory(scheduled: [.init(currencyCode: "PEN", isGroupPayment: true)])
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "USD")) == .blockedByCurrency)
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "PEN"))
            == .allowed(movedRows: 0, convertedRows: 0, collapsedTransfers: 0, convertsPlans: false))
    }

    @Test func mover_borradorDeGrupo_soloBloqueaSiCambiaLaDivisa() {
        let inv = inventory(drafts: 1, draftsNotConvertible: 1)
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "USD")) == .blockedByCurrency)
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "PEN"))
            == .allowed(movedRows: 0, convertedRows: 0, collapsedTransfers: 0, convertsPlans: false))
    }

    @Test func mover_programadosYFavoritosEnOtraDivisa_seConvierten() {
        let inv = inventory(scheduled: [.init(currencyCode: "PEN", isGroupPayment: false)], favorites: 1)
        #expect(Logic.moveVerdict(inv, to: .init(id: "B", currencyCode: "USD"))
            == .allowed(movedRows: 0, convertedRows: 0, collapsedTransfers: 0, convertsPlans: true))
    }
}
