//
//  PanelScheduledPaymentsPeriodLabelTests.swift
//  YalaTests
//
//  El mes del widget de pagos del Panel: «Octubre de 2026», no «Octubre De 2026» ni «October 2026» con la app en
//  español. Ticket `month-year-titles-capitalize-every-word` (card «El widget de pagos del Panel pone mayúscula en
//  cada palabra del mes»).
//
//  Control rojo: con el cuerpo de antes (`dateFormat = "MMMM yyyy"` sin `locale` + `.capitalized`) el caso español
//  sale en el idioma del simulador, y con la plantilla del idioma + `.capitalized`, «Octubre De 2026».
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Panel · mes del widget de pagos")
struct PanelScheduledPaymentsPeriodLabelTests {

    /// 15 de octubre de 2026 a mediodía en Lima: lejos de los bordes del mes en cualquier zona.
    private var october2026: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 15
        components.hour = 12
        components.timeZone = TimeZone(identifier: "America/Lima")
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }

    @Test("En español: «Octubre de 2026», con «de» en minúscula")
    func spanish() {
        let label = PanelViewModel.scheduledPaymentsPeriodLabel(for: october2026, locale: Locale(identifier: "es_PE"))
        #expect(label == "Octubre de 2026", "salió «\(label)»; «Octubre De 2026» es el `.capitalized` del bug")
    }

    @Test("En portugués: «Outubro de 2026»")
    func portuguese() {
        let label = PanelViewModel.scheduledPaymentsPeriodLabel(for: october2026, locale: Locale(identifier: "pt_BR"))
        #expect(label == "Outubro de 2026", "salió «\(label)»")
    }

    @Test("Sigue el idioma que se le pasa, no el del sistema")
    func followsTheGivenLanguage() {
        let label = PanelViewModel.scheduledPaymentsPeriodLabel(for: october2026, locale: Locale(identifier: "en_US"))
        #expect(label == "October 2026", "salió «\(label)»")
    }

    @Test("El Panel pinta la etiqueta con esta función (source-scan del cableado)")
    func panelUsesIt() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/ViewModels/PanelViewModel.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("periodLabel: Self.scheduledPaymentsPeriodLabel(for: displayMonth, locale: AppLocale.current)"))
        #expect(!source.contains("monthYearFormatter"), "volvió el formatter de antes, sin idioma")
    }
}
