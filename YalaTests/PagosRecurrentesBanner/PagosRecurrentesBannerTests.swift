//
//  PagosRecurrentesBannerTests.swift
//  YalaTests
//
//  «Pagos que se repiten» como banner + hoja grande + formulario completo (Jürgen, 17-nov). Fija:
//  - el prellenado del formulario de «Nuevo pago planificado» desde un caso detectado (frecuencia, día, suscripción,
//    monto variable, nombre, monto y divisa), que es lo que la hoja propia hacía antes por su cuenta;
//  - la fecha del primer aviso del mensaje de después;
//  - el plural del banner en los 16 idiomas y que los textos de la hoja vieja se fueron;
//  - el cableado: banner → hoja `.large` → formulario completo, descartar por deslizamiento y menú.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Pagos que se repiten · banner y hoja")
struct PagosRecurrentesBannerTests {

    nonisolated private static let lima: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }()

    nonisolated private static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        lima.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? .distantPast
    }

    private static func item(
        key: String = "brand:netflix|PEN",
        name: String = "Netflix",
        brandID: String? = "netflix",
        currency: String = "PEN",
        cadence: RecurringPaymentDetector.Cadence = .monthly(day: 14, isApproximate: false),
        amount: Double = 44.90,
        isVariable: Bool = false,
        nextDue: Date = date(2026, 12, 14)
    ) -> RecurringProposalsSource.Item {
        let proposal = RecurringPaymentDetector.Proposal(
            key: key, displayName: name, brandID: brandID, currencyCode: currency, cadence: cadence,
            chargeCount: 5, firstChargeDate: date(2026, 7, 14), lastChargeDate: date(2026, 11, 14), amount: amount,
            isVariableAmount: isVariable, nextDueDate: nextDue, lastChargeRef: 4, chargeRefs: [0, 1, 2, 3, 4]
        )
        return RecurringProposalsSource.Item(proposal: proposal, account: nil, subcategory: nil)
    }

    // MARK: - Prellenado

    @Test func suscripcionMensual_llegaComoSuscripcionCadaMesDesdeElProximoCobro() {
        let prefill = RecurringProposalPrefill.prefill(for: Self.item(), calendar: Self.lima)
        #expect(prefill.name == "Netflix")
        #expect(prefill.transactionType == "expense")
        #expect(AmountInputHelper.parseDecimal(prefill.amount) == 44.90)
        #expect(prefill.currencyCode == "PEN")
        #expect(prefill.note.isEmpty)
        #expect(prefill.recurrenceType == .monthly)
        #expect(prefill.dayOfMonth == 14)
        #expect(prefill.isSubscription)
        #expect(prefill.isVariableAmount == false)
        #expect(prefill.transactionDate == Self.lima.startOfDay(for: Self.date(2026, 12, 14)))
        #expect(prefill.tagIDs.isEmpty)
    }

    @Test func cobroSemanalSinMarca_llegaComoRecurrenteCadaSemana_yMontoVariable() {
        let prefill = RecurringProposalPrefill.prefill(
            for: Self.item(
                key: "name:panaderia|PEN", name: "Panadería", brandID: nil,
                cadence: .weekly(weekday: 2), amount: 12.5, isVariable: true, nextDue: Self.date(2026, 11, 23)
            ),
            calendar: Self.lima
        )
        #expect(prefill.recurrenceType == .weekly)
        #expect(prefill.isSubscription == false)
        #expect(prefill.isVariableAmount)
        #expect(prefill.name == "Panadería")
        // El día de la semana lo saca el formulario de la fecha: el lunes 23.
        #expect(Self.lima.component(.weekday, from: prefill.transactionDate) == 2)
    }

    /// Cobros el 31 y próximo el 30 de noviembre: se guarda el 31 (el calendario ya lo acorta en los meses cortos).
    @Test func cobrosElUltimoDia_guardanElDiaTipico_noElDelMesCorto() {
        let prefill = RecurringProposalPrefill.prefill(
            for: Self.item(cadence: .monthly(day: 31, isApproximate: false), nextDue: Self.date(2026, 11, 30)),
            calendar: Self.lima
        )
        #expect(prefill.dayOfMonth == 31)
        #expect(Self.lima.component(.day, from: prefill.transactionDate) == 30)
    }

    @Test func divisaDeLosCobros_viajaAunqueNoHayaCuenta() {
        let prefill = RecurringProposalPrefill.prefill(for: Self.item(currency: "USD"), calendar: Self.lima)
        #expect(prefill.currencyCode == "USD")
        #expect(prefill.account == nil)
    }

    // MARK: - Primer aviso

    @Test func primerAviso_losDiasDeAntes_oElMismoDiaSiYaPasaron_oNinguno() {
        let now = Self.date(2026, 11, 17)
        let lejos = Self.date(2026, 12, 14)
        #expect(RecurringProposalPrefill.firstReminderDate(
            dueDate: lejos, notifies: true, daysBefore: 3, now: now, calendar: Self.lima
        ) == Self.lima.startOfDay(for: Self.date(2026, 12, 11)))
        let cerca = Self.date(2026, 11, 18)
        #expect(RecurringProposalPrefill.firstReminderDate(
            dueDate: cerca, notifies: true, daysBefore: 3, now: now, calendar: Self.lima
        ) == Self.lima.startOfDay(for: cerca))
        #expect(RecurringProposalPrefill.firstReminderDate(
            dueDate: lejos, notifies: false, daysBefore: 3, now: now, calendar: Self.lima
        ) == nil)
    }

    // MARK: - Textos

    nonisolated private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static let locales = [
        "de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl", "pt", "pt-BR", "pt-PT",
        "zh-Hans",
    ]

    @Test func plural_delBanner_enLos16Idiomas() throws {
        for locale in Self.locales {
            let url = Self.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.stringsdict")
            let plist = try #require(NSDictionary(contentsOf: url) as? [String: Any], "\(locale)")
            let entry = try #require(plist["pagosRecurrentes.banner.found"] as? [String: Any], "\(locale)")
            let forms = try #require(entry["count"] as? [String: String], "\(locale)")
            let other = try #require(forms["other"], "\(locale)")
            #expect(other.contains("%d"), "\(locale)")
            if !["ja", "zh-Hans"].contains(locale) {
                let one = try #require(forms["one"], "\(locale)")
                #expect(one.contains("%d"), "\(locale)")
                #expect(one != other, "\(locale): el singular no puede ser el plural")
            }
            if locale == "pl" {
                #expect(forms["few"] != nil && forms["many"] != nil)
            }
        }
    }

    @Test func banner_enEspañolNeutro_diceUnoYVarios() throws {
        let path = try #require(Bundle.main.path(forResource: "es-419", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = NSLocalizedString("pagosRecurrentes.banner.found", bundle: bundle, value: "", comment: "")
        let one = String.localizedStringWithFormat(format, 1)
        let three = String.localizedStringWithFormat(format, 3)
        #expect(one == "Encontramos 1 pago que se repite. Puedes agregarlo a tus pagos planificados.")
        #expect(three == "Encontramos 3 pagos que se repiten. Puedes agregarlos a tus pagos planificados.")
    }

    @Test func textosDeLaHoja_estanEnLos16_yLosDeLaHojaViejaSeFueron() throws {
        let gone = [
            "sheet.chargesFound", "sheet.lastCharge", "sheet.amount", "sheet.frequency", "sheet.nextCharge",
            "sheet.account", "sheet.chooseAccount", "sheet.category", "sheet.notify", "sheet.variable", "notify.none",
            "notify.oneDay",
        ]
        for locale in Self.locales {
            let url = Self.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
            let strings = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            for key in ["list.footer", "card.title", "card.subtitle", "sheet.create", "sheet.notFixed", "sheet.notNow"] {
                #expect(!(strings["pagosRecurrentes.\(key)"] ?? "").isEmpty, "\(locale): falta \(key)")
            }
            for key in gone {
                #expect(strings["pagosRecurrentes.\(key)"] == nil, "\(locale): sobra \(key)")
            }
        }
    }

    // MARK: - Cableado

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func collapsed(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    @Test func planificacion_montaElBanner_yLaHojaViejaNoExiste() throws {
        let planning = try Self.source("Yala/App/Views/Planning/ScheduledPaymentsView.swift")
        #expect(planning.contains("RecurringProposalsBanner {"))
        #expect(!planning.contains("RecurringProposalsCard"))
        let old = Self.repoRoot.appendingPathComponent("Yala/App/Views/Planning/PagosRecurrentes/RecurringProposalSheet.swift")
        #expect(!FileManager.default.fileExists(atPath: old.path))
    }

    @Test func banner_abreLaHojaGrande_yLaHojaAbreElFormularioCompletoPrellenado() throws {
        let banner = Self.collapsed(try Self.source("Yala/App/Views/Planning/PagosRecurrentes/RecurringProposalsBanner.swift"))
        #expect(banner.contains(".sheet(isPresented: $showsList) { RecurringProposalsListSheet(model: model)"))
        #expect(banner.contains("PagosRecurrentesText.bannerFound(count)"))

        let sheet = Self.collapsed(
            try Self.source("Yala/App/Views/Planning/PagosRecurrentes/RecurringProposalsListSheet.swift")
        )
        #expect(sheet.contains(".presentationDetents([.large])"))
        #expect(sheet.contains(".navigationTitle(PagosRecurrentesText.cardTitle)"))
        #expect(sheet.contains(
            "ScheduledPaymentEditorView( payment: nil, prefill: RecurringProposalPrefill.prefill(for: item),"
        ))
        // El formulario cuelga del contenedor, fuera de la pila (`swiftui-ds.md`).
        let stackEnd = try #require(sheet.range(of: ".presentationDetents([.large])"))
        let editor = try #require(sheet.range(of: ".sheet(item: $editingItem"))
        #expect(stackEnd.lowerBound < editor.lowerBound)
        // Descartar: deslizar y menú, con las dos respuestas de siempre.
        #expect(sheet.contains(".swipeActions(edge: .trailing, allowsFullSwipe: false)"))
        #expect(sheet.contains(".contextMenu {"))
        #expect(sheet.contains("preferences.dismiss(item.proposal)"))
        #expect(sheet.contains("preferences.snooze(item.proposal)"))
        // Al guardar, el caso sale de la lista aunque el comercio tuviera algo contestado.
        #expect(sheet.contains("preferences.forget(item.proposal)"))
    }

    @Test func formulario_aplicaElPrellenadoNuevo_yEnseñaLaDivisaQueGuarda() throws {
        let editor = Self.collapsed(try Self.source("Yala/App/Views/Planning/ScheduledPaymentEditorView.swift"))
        #expect(editor.contains("if let recurrence = prefill.recurrenceType { recurrenceType = recurrence }"))
        #expect(editor.contains("if let day = prefill.dayOfMonth { dayOfMonth = day }"))
        #expect(editor.contains("if prefill.isSubscription { isSubscription = true paymentCategory = .subscription }"))
        #expect(editor.contains("isVariableAmount = prefill.isVariableAmount"))
        #expect(editor.contains("Text(prefillCurrency ?? account.currencyCode)"))
        #expect(editor.contains("(prefillCurrency ?? selectedAccount?.currencyCode"))
    }
}
