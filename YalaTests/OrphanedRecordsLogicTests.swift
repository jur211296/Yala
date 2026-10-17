//
//  OrphanedRecordsLogicTests.swift
//  YalaTests
//
//  Las decisiones puras del aviso «Movimientos sin cuenta». Card `tablero-los-movimientos-que-quedaron-sin-cuenta-sovw`.
//

import Testing

@testable import Yala

@Suite("Movimientos sin cuenta · lógica")
struct OrphanedRecordsLogicTests {

    private typealias Row = AccountRemovalLogic.Row<String>

    private func row(_ currency: String, transfer: Bool = false, partner: String? = nil) -> Row {
        Row(
            currencyCode: currency,
            conversionBlock: transfer ? AccountCurrencyChangeLogic.blockReason(for: .init(
                isTransferType: true, hasTransferPairID: true, hasSplitExpenseID: false, hasSplitSettlementID: false))
                : nil,
            isGroupRecord: false,
            transferPartnerAccount: partner)
    }

    @Test(arguments: [
        (true, false, false),
        (true, true, false),
        (false, false, true),
        (false, true, false),
    ])
    func isOrphan(hasAccount: Bool, hasGroupPointer: Bool, expected: Bool) {
        #expect(OrphanedRecordsLogic.isOrphan(.init(hasAccount: hasAccount, hasGroupPointer: hasGroupPointer)) == expected)
    }

    @Test func showsNotice_soloConAlgoYElImportQuieto() {
        #expect(OrphanedRecordsLogic.showsNotice(orphanCount: 2, importIsQuiescent: true))
        #expect(!OrphanedRecordsLogic.showsNotice(orphanCount: 2, importIsQuiescent: false))
        #expect(!OrphanedRecordsLogic.showsNotice(orphanCount: 0, importIsQuiescent: true))
    }

    private func outcome(_ rows: [Row], paired: [Bool] = [], to currency: String = "PEN")
        -> OrphanedRecordsLogic.MoveOutcome {
        OrphanedRecordsLogic.moveOutcome(rows: rows, pairedWithinOrphans: paired, to: "banco", currencyCode: currency)
    }

    /// Misma moneda: se mueven todos y no se convierte nada.
    @Test func mover_mismaMoneda() {
        #expect(outcome([row("PEN"), row("PEN")]) == .init(moved: 2, converted: 0, keptInTheirCurrency: 0, removed: 0))
    }

    /// Monedas mezcladas: cada fila se convierte desde la suya.
    @Test func mover_monedasMezcladas_cuentaLasQueSeConvierten() {
        #expect(outcome([row("PEN"), row("USD"), row("EUR")])
                == .init(moved: 3, converted: 2, keptInTheirCurrency: 0, removed: 0))
    }

    /// Una transferencia en otra moneda NO bloquea (la hoja de eliminar cuenta sí): pasa tal cual, y el resto se
    /// mueve. Bloquear dejaba el aviso sin salida (review adversarial del 2026-10-15).
    @Test func mover_transferenciaEnOtraMoneda_pasaTalCual() {
        #expect(outcome([row("PEN"), row("USD", transfer: true)])
                == .init(moved: 2, converted: 0, keptInTheirCurrency: 1, removed: 0))
    }

    /// Una pata cuya pareja vive en el destino se quita.
    @Test func mover_parejaEnElDestino_seQuita() {
        #expect(outcome([row("PEN", transfer: true, partner: "banco"), row("PEN")])
                == .init(moved: 1, converted: 0, keptInTheirCurrency: 0, removed: 1))
    }

    /// Las dos patas sin cuenta acabarían dentro del destino: se quitan las dos, también en monedas distintas.
    @Test func mover_lasDosPatasSinCuenta_seQuitan() {
        #expect(outcome([row("USD", transfer: true), row("PEN", transfer: true), row("PEN")], paired: [true, true, false])
                == .init(moved: 1, converted: 0, keptInTheirCurrency: 0, removed: 2))
    }
}
