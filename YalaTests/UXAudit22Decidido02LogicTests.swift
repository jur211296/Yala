//
//  UXAudit22Decidido02LogicTests.swift
//  YalaTests
//
//  Lógica pura del lote decidido 2.2 · 02, sesión A (formulario de registro): la cuenta precargada (L2-1 y la card
//  uipg), qué se ve al guardar (L2-5), las tres frecuencias de «Hacer recurrente» (L2-15) y los atajos de fecha (L2-7).
//

import Foundation
import Testing

@testable import Yala

// MARK: - L2-1 · La cuenta precargada

@Suite("L2-1 · Cuenta precargada")
struct TransactionAccountPrefillLogicTests {
    typealias Logic = TransactionAccountPrefillLogic
    typealias Candidate = Logic.Candidate<String>

    private func account(_ id: String, active: Bool = true, line: Bool = false) -> Candidate {
        Candidate(id: id, shortcutID: "S-\(id)", isActive: active, isLine: line)
    }

    private func filter(_ ids: Set<String>, shown: Set<String>? = nil, exclude: Bool = false) -> Logic.Filter<String> {
        Logic.Filter(accountIDs: ids, shownAccountIDs: shown ?? ids, isExcludeMode: exclude)
    }

    private let three = [
        Candidate(id: "A", shortcutID: "S-A", isActive: true, isLine: false),
        Candidate(id: "B", shortcutID: "S-B", isActive: true, isLine: false),
        Candidate(id: "C", shortcutID: "S-C", isActive: true, isLine: false),
    ]

    @Test func unaCuentaFiltrada_esa_aunqueLaUltimaUsadaSeaOtra() {
        #expect(Logic.account(candidates: three, filter: filter(["B"]), lastUsedShortcutID: "S-C") == "B")
    }

    @Test func variasFiltradas_laUltimaUsadaSiEstaEntreEllas() {
        #expect(Logic.account(candidates: three, filter: filter(["A", "B"]), lastUsedShortcutID: "S-B") == "B")
    }

    @Test func variasFiltradas_laUltimaUsadaFuera_vacia_nuncaUnaAlAzar() {
        #expect(Logic.account(candidates: three, filter: filter(["A", "B"]), lastUsedShortcutID: "S-C") == nil)
        #expect(Logic.account(candidates: three, filter: filter(["A", "B"]), lastUsedShortcutID: nil) == nil)
    }

    @Test func modoExcluir_nuncaLaExcluida() {
        #expect(Logic.account(candidates: three, filter: filter(["B"], exclude: true), lastUsedShortcutID: "S-B") == nil)
        #expect(Logic.account(candidates: three, filter: filter(["B"], exclude: true), lastUsedShortcutID: "S-C") == "C")
    }

    @Test func modoExcluirDeUna_noEsElFiltroDeUna() {
        // Excluir B no es «el Panel filtrado por B».
        #expect(Logic.account(candidates: three, filter: filter(["B"], exclude: true), lastUsedShortcutID: nil) == nil)
    }

    @Test func sinFiltro_laUltimaUsada() {
        #expect(Logic.account(candidates: three, filter: .none, lastUsedShortcutID: "S-A") == "A")
    }

    @Test func sinFiltroNiUltima_conVarias_vacia() {
        #expect(Logic.account(candidates: three, filter: .none, lastUsedShortcutID: nil) == nil)
    }

    @Test func unaSolaCuenta_esa() {
        #expect(Logic.account(candidates: [account("A")], filter: .none, lastUsedShortcutID: nil) == "A")
    }

    @Test func unaSolaCuentaExcluida_vacia() {
        #expect(Logic.account(candidates: [account("A")], filter: filter(["A"], exclude: true), lastUsedShortcutID: nil) == nil)
    }

    @Test func laUltimaUsadaArchivada_noSePrecarga() {
        let accounts = [account("A", active: false), account("B")]
        // Con la archivada fuera queda una sola cuenta elegible: esa.
        #expect(Logic.account(candidates: accounts, filter: .none, lastUsedShortcutID: "S-A") == "B")
        let more = [account("A", active: false), account("B"), account("C")]
        #expect(Logic.account(candidates: more, filter: .none, lastUsedShortcutID: "S-A") == nil)
    }

    @Test func unaCuentaFiltradaArchivada_noSePrecarga() {
        let accounts = [account("A", active: false), account("B"), account("C")]
        #expect(Logic.account(candidates: accounts, filter: filter(["A"]), lastUsedShortcutID: nil) == nil)
    }

    @Test func lasLineasDeUnaTarjeta_noCuentanComoOtraCuenta() {
        // Una tarjeta en soles con su línea en dólares es UNA cuenta para la persona.
        let card = [account("A"), account("A-USD", line: true)]
        #expect(Logic.account(candidates: card, filter: .none, lastUsedShortcutID: nil) == "A")
    }

    @Test func tarjetaFiltrada_seCuentaPorLoQueSePinta() {
        // El conjunto lleva la tarjeta y su línea; lo que se pinta, la tarjeta.
        let card = [account("A"), account("A-USD", line: true), account("B")]
        let result = Logic.account(
            candidates: card, filter: filter(["A", "A-USD"], shown: ["A"]), lastUsedShortcutID: nil)
        #expect(result == "A")
    }

    // MARK: Transferencia

    @Test func destino_conExactamenteDos_laOtra() {
        let two = [account("A"), account("B")]
        #expect(Logic.transferDestination(candidates: two, filter: .none, source: "A") == "B")
    }

    @Test func destino_conTres_vacio() {
        #expect(Logic.transferDestination(candidates: three, filter: .none, source: "A") == nil)
    }

    @Test func destino_conUna_vacio() {
        #expect(Logic.transferDestination(candidates: [account("A")], filter: .none, source: "A") == nil)
    }

    @Test func destino_conElPanelFiltradoPorElOrigen_laOtraIgual() {
        let two = [account("A"), account("B")]
        #expect(Logic.transferDestination(candidates: two, filter: filter(["A"]), source: "A") == "B")
    }

    @Test func destino_nuncaUnaExcluida() {
        let two = [account("A"), account("B")]
        #expect(Logic.transferDestination(candidates: two, filter: filter(["B"], exclude: true), source: "A") == nil)
    }

    @Test func destino_sinOrigen_vacio() {
        let two = [account("A"), account("B")]
        #expect(Logic.transferDestination(candidates: two, filter: .none, source: nil) == nil)
    }
}

// MARK: - L2-5 · Qué se ve al guardar

@Suite("L2-5 · Pantalla completa o aviso")
struct TransactionSaveFeedbackLogicTests {
    @Test func lasTresPrimeras_pantallaCompleta() {
        for count in 1...3 {
            #expect(TransactionSaveFeedbackLogic.feedback(isEdit: false, savedCountAfterSave: count) == .fullScreen)
        }
    }

    @Test func desdeLaCuarta_aviso() {
        #expect(TransactionSaveFeedbackLogic.feedback(isEdit: false, savedCountAfterSave: 4) == .savedNotice)
        #expect(TransactionSaveFeedbackLogic.feedback(isEdit: false, savedCountAfterSave: 40) == .savedNotice)
    }

    @Test func unaEdicion_nuncaPantallaCompleta() {
        #expect(TransactionSaveFeedbackLogic.feedback(isEdit: true, savedCountAfterSave: 1) == .editedNotice)
        #expect(TransactionSaveFeedbackLogic.feedback(isEdit: true, savedCountAfterSave: 40) == .editedNotice)
    }
}

// MARK: - L2-15 · Hacer recurrente

@MainActor
@Suite("L2-15 · Las tres frecuencias")
struct RecurringQuickChoiceLogicTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }

    /// Martes 13 de octubre de 2026.
    private var tuesday13October: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 9)) ?? .now
    }

    @Test func elAncla_saleDeLaFechaDelRegistro_noDelLunes() {
        let anchor = RecurringQuickChoiceLogic.anchor(for: tuesday13October, calendar: calendar)
        #expect(anchor.weekday == 3) // martes; antes se quedaba en lunes (2)
        #expect(anchor.dayOfMonth == 13)
        #expect(anchor.month == 10)
    }

    @Test func lasTresFilas_enOrden_conElDiaYElMes() {
        let choices = RecurringQuickChoiceLogic.choices(
            for: tuesday13October, locale: Locale(identifier: "es_PE"), calendar: calendar)
        #expect(choices.map(\.recurrence) == [.weekly, .monthly, .yearly])
        #expect(choices[0].title.contains("martes"))
        #expect(choices[1].title.contains("13"))
        #expect(choices[2].title.contains("13") && choices[2].title.contains("octubre"))
    }
}

// MARK: - L2-7 · Atajos de fecha

@MainActor
@Suite("L2-7 · Hoy, Ayer, Anteayer")
struct DatePickerQuickPickLogicTests {
    @Test func losAtajos_sonHoyAyerYAnteayer() {
        let calendar = Calendar.current
        let now = Date.now
        let days = DatePickerQuickPickLogic.Shortcut.allCases.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: DatePickerQuickPickLogic.date(for: $0, now: now)),
                                    to: calendar.startOfDay(for: now)).day
        }
        #expect(days == [0, 1, 2])
    }

    @Test func laNota_llevaElEnlaceAPagosPlanificados() throws {
        let url = try #require(DatePickerQuickPickLogic.scheduledPaymentsURL)
        let note = DatePickerQuickPickLogic.noteText(L10n.UXL2.futureDaysNote)
        let links = note.runs.compactMap(\.link)
        #expect(links == [url])
    }
}
