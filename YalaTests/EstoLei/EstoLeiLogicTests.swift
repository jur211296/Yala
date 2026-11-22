//
//  EstoLeiLogicTests.swift
//  YalaTests
//
//  «Esto leí» con la tarjeta B1 (opción A, Jürgen 2026-11-22): qué falta y en qué orden, qué fila de varios se abre
//  sola, cómo «Otra foto» suma sin repetir, el aviso al cerrar sin guardar y la fila de botones con texto grande.
//

import Foundation
import Testing
@testable import Yala

@Suite("«Esto leí» · tarjeta B1")
struct EstoLeiLogicTests {

    private typealias Item = MultiDraftReviewLogic.Item<Int>

    private let fixedDate = Date(timeIntervalSince1970: 1_795_000_000)

    private func item(_ id: Int, complete: Bool, pending: Bool = true, saved: Bool = false) -> Item {
        Item(id: id, amount: -10, currencyCode: "PEN", date: fixedDate, categoryKey: complete ? "c" : nil,
             categoryName: "C", colorHex: nil, isPending: pending, isSaved: saved, isComplete: complete)
    }

    private func selection(_ ids: [Int]) -> MultiDraftReviewLogic.Selection<Int> {
        var selection = MultiDraftReviewLogic.Selection<Int>()
        selection.sync(with: ids)
        return selection
    }

    private func readiness(amount: Bool = true, account: Bool = true, archived: Bool = false,
                           subcategory: Bool = true) -> VoiceDraftReadiness {
        VoiceDraftReadiness(hasAmount: amount, hasAccount: account, accountIsArchived: archived,
                            hasSubcategory: subcategory, isFutureDate: false)
    }

    // MARK: - Qué falta

    @Test func completo_noLeFaltaNada() {
        #expect(EstoLeiLogic.missing(readiness()).isEmpty)
    }

    @Test func faltaTodo_enElOrdenDeLaTarjeta() {
        #expect(EstoLeiLogic.missing(readiness(amount: false, account: false, subcategory: false))
                == [.amount, .subcategory, .account])
    }

    @Test func cuentaArchivada_cuentaComoQueFalta() {
        #expect(EstoLeiLogic.missing(readiness(archived: true)) == [.account])
    }

    // MARK: - La fila que se abre sola

    @Test func seAbreLaPrimeraIncompletaEnElOrdenEnQueSePinta() {
        let items = [item(1, complete: true), item(2, complete: false), item(3, complete: false)]
        // Se pinta 3 antes que 2 (otro día): manda el orden de la hoja, no el de la lista.
        #expect(EstoLeiLogic.autoExpanded(items, selection([1, 2, 3]), order: [1, 3, 2]) == 3)
    }

    @Test func unaIncompletaDesmarcada_noSeAbre() {
        let items = [item(1, complete: false), item(2, complete: false)]
        var marked = selection([1, 2])
        marked.toggle(1)
        #expect(EstoLeiLogic.autoExpanded(items, marked, order: [1, 2]) == 2)
    }

    @Test func todasCompletas_ningunaSeAbre() {
        let items = [item(1, complete: true), item(2, complete: true)]
        #expect(EstoLeiLogic.autoExpanded(items, selection([1, 2]), order: [1, 2]) == nil)
    }

    @Test func laGuardada_noSeAbre() {
        let items = [item(1, complete: false, pending: false, saved: true), item(2, complete: true)]
        #expect(EstoLeiLogic.autoExpanded(items, selection([1, 2]), order: [1, 2]) == nil)
    }

    @Test func laAbiertaSeQuedaAbiertaAunqueYaEsteCompleta() {
        let items = [item(1, complete: true), item(2, complete: false)]
        #expect(EstoLeiLogic.expandedAfterChange(current: 1, items, selection([1, 2]), order: [1, 2]) == 1)
    }

    @Test func siLaAbiertaSeGuardoOSeFue_seAbreLaSiguiente() {
        let saved = [item(1, complete: true, pending: false, saved: true), item(2, complete: false)]
        #expect(EstoLeiLogic.expandedAfterChange(current: 1, saved, selection([1, 2]), order: [1, 2]) == 2)
        let gone = [item(2, complete: false)]
        #expect(EstoLeiLogic.expandedAfterChange(current: 1, gone, selection([2]), order: [2]) == 2)
    }

    // MARK: - «Otra foto» suma

    @Test func otraFoto_sumaDetrasDeLoQueYaEstaba() {
        #expect(EstoLeiLogic.appended([1, 2], [3, 4], id: { $0 }) == [1, 2, 3, 4])
    }

    @Test func otraFoto_noRepiteLoQueYaSeEnsena() {
        // La deduplicación devolvió el borrador que ya estaba (el mismo recibo leído dos veces).
        #expect(EstoLeiLogic.appended([1, 2], [2, 3, 3], id: { $0 }) == [1, 2, 3])
    }

    @Test func loQueDijiste_juntaLasDosGrabaciones() {
        #expect(EstoLeiLogic.joinedTranscription("Almuerzo 25", " Taxi 12 ") == "Almuerzo 25\n\nTaxi 12")
        #expect(EstoLeiLogic.joinedTranscription("", "Taxi 12") == "Taxi 12")
        #expect(EstoLeiLogic.joinedTranscription("Almuerzo 25", "  ") == "Almuerzo 25")
    }

    // MARK: - Cerrar sin guardar

    @Test func cerrarConPendientes_avisaQueQuedoEnLaBandeja() {
        #expect(EstoLeiLogic.showsInboxNoticeOnClose(pendingCount: 2, isSetupTrial: false))
    }

    @Test func cerrarSinPendientes_oEnLaPractica_noAvisa() {
        #expect(!EstoLeiLogic.showsInboxNoticeOnClose(pendingCount: 0, isSetupTrial: false))
        #expect(!EstoLeiLogic.showsInboxNoticeOnClose(pendingCount: 1, isSetupTrial: true))
    }

    // MARK: - Línea ✦

    @Test func lineaDeLaCuenta_primeraOracion() {
        #expect(EstoLeiLogic.firstSentence("Elegí BCP porque la imagen lo dice. Toca la cuenta para cambiarla.")
                == "Elegí BCP porque la imagen lo dice.")
        #expect(EstoLeiLogic.firstSentence("Elegí Zip por tu regla «zip».") == "Elegí Zip por tu regla «zip».")
    }

    // MARK: - Botones

    @Test func conTextoGrande_elSecundarioSeQuedaEnSuIcono() {
        #expect(EstoLeiLogic.secondaryShowsTitle(isAccessibilitySize: false))
        #expect(!EstoLeiLogic.secondaryShowsTitle(isAccessibilitySize: true))
    }
}
