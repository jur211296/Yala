//
//  PagosChipsVistaTests.swift
//  YalaTests
//
//  Pagos planificados (encargo del 24-nov-2026): la vista elegida recordada, el ícono de la subcategoría cuando no hay
//  logo (lista, línea de tiempo y calendario) y el enlace del pie pegado al final. Los chips con texto se revirtieron.
//

import Foundation
import Testing

@testable import Yala

@Suite("Pagos planificados · selector de vista: orden, nombre y vista recordada", .serialized)
@MainActor
struct PagosChipsVistaTests {

    private static func makeSuite() -> UserDefaults {
        testDefaults(suiteName: "PagosChipsVistaTests.\(UUID().uuidString)")!
    }

    @Test("Tres vistas, en este orden: Lista, Línea de tiempo, Calendario")
    func ordenDeLasVistas() {
        #expect(PaymentsViewMode.allCases == [.list, .timeline, .calendar])
    }

    @Test("Cada chip se llama como su vista y tiene su ícono; los nombres no se repiten ni salen vacíos")
    func nombreDeCadaVista() {
        let nombres = PaymentsViewMode.allCases.map(\.accessibilityLabel)
        #expect(nombres == [L10n.UXL10.viewList, L10n.UXL10.viewTimeline, L10n.UXL10.viewCalendar])
        #expect(Set(nombres).count == 3)
        for (modo, nombre) in zip(PaymentsViewMode.allCases, nombres) {
            #expect(!nombre.isEmpty && !nombre.hasPrefix("scheduled."), "\(modo) sin traducir")
            #expect(!modo.iconName.isEmpty)
        }
    }

    @Test("Sin nada guardado, la lista")
    func porDefectoLaLista() {
        let prefs = AppPreferences(defaults: Self.makeSuite())
        #expect(prefs.scheduledPaymentsViewMode == .list)
    }

    @Test("La vista elegida se guarda y la recuerda una instancia nueva sobre el mismo almacén")
    func laVistaSeRecuerda() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.scheduledPaymentsViewMode = .timeline
        #expect(defaults.string(forKey: AppPreferences.Keys.scheduledPaymentsViewMode) == "timeline")
        #expect(AppPreferences(defaults: defaults).scheduledPaymentsViewMode == .timeline)

        prefs.scheduledPaymentsViewMode = .calendar
        #expect(AppPreferences(defaults: defaults).scheduledPaymentsViewMode == .calendar)
    }

    @Test("Borrada la clave con la app abierta («Vaciar datos», -uitest-reset), vuelve a la lista")
    func borrarLaClaveVuelveALaLista() async {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.scheduledPaymentsViewMode = .timeline
        defaults.removeObject(forKey: AppPreferences.Keys.scheduledPaymentsViewMode)
        // La relectura llega por el aviso de `UserDefaults`, en una vuelta del main actor.
        for _ in 0..<50 where prefs.scheduledPaymentsViewMode != .list {
            await Task.yield()
        }
        #expect(prefs.scheduledPaymentsViewMode == .list)
    }

    @Test("Un valor guardado que no es una vista se lee como la lista")
    func valorDesconocido() {
        let defaults = Self.makeSuite()
        defaults.set("mosaico", forKey: AppPreferences.Keys.scheduledPaymentsViewMode)
        #expect(AppPreferences(defaults: defaults).scheduledPaymentsViewMode == .list)
    }
}

@Suite("Pagos planificados · ícono cuando no hay logo: logo, subcategoría, categoría, tipo")
@MainActor
struct PagosIconoSinLogoTests {

    private static let fecha = Date(timeIntervalSince1970: 1_790_000_000)

    private static func pago(_ nombre: String, subcategoria: Subcategory?, tipo: String = "recurring") -> ScheduledPayment {
        ScheduledPayment(
            name: nombre, amount: 10, currencyCode: "PEN", subcategory: subcategoria, nextDueDate: fecha,
            paymentCategory: tipo
        )
    }

    private static func categoria() -> Yala.Category {
        Yala.Category(name: "Vivienda", colorHex: "#22AA88", isIncome: false, iconName: "house.fill")
    }

    @Test("Con logo gana el logo, aunque tenga subcategoría con ícono")
    func primeroElLogo() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let sub = Subcategory(name: "Streaming", iconName: "tv.fill", category: Self.categoria())
        let pago = Self.pago("Netflix", subcategoria: sub)
        #expect(PagoLogoComercio.logo(for: pago) != nil)
    }

    @Test("Sin logo, el ícono de la subcategoría sobre el color de su categoría (como en Registros)")
    func despuesLaSubcategoria() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let sub = Subcategory(name: "Renta", iconName: "key.fill", category: Self.categoria())
        let pago = Self.pago("Renta depa", subcategoria: sub)
        #expect(PagoLogoComercio.logo(for: pago) == nil)
        let propiedades = ScheduledPaymentsViewModel.paymentDisplayProperties(for: pago)
        #expect(propiedades.icon == "key.fill")
        #expect(propiedades.color == "#22AA88")
    }

    @Test("Subcategoría sin ícono: el de la categoría")
    func luegoLaCategoria() {
        let sub = Subcategory(name: "Otros", iconName: nil, category: Self.categoria())
        let propiedades = ScheduledPaymentsViewModel.paymentDisplayProperties(for: Self.pago("Préstamo SIP", subcategoria: sub))
        #expect(propiedades.icon == "house.fill")
    }

    @Test("Sin subcategoría: el ícono de su tipo, nunca vacío")
    func sinSubcategoria() {
        let recurrente = ScheduledPaymentsViewModel.paymentDisplayProperties(for: Self.pago("Sueldo Zeal", subcategoria: nil))
        let suscripcion = ScheduledPaymentsViewModel.paymentDisplayProperties(
            for: Self.pago("Hevy Pro", subcategoria: nil, tipo: "subscription")
        )
        #expect(!recurrente.icon.isEmpty && !suscripcion.icon.isEmpty)
        #expect(recurrente.icon != suscripcion.icon)
    }

    @Test("El calendario pone dos marcas por celda: todas son de logo o ícono, del mismo tamaño")
    func limiteDelCalendario() {
        #expect(ScheduledPaymentsListView.calendarMarkLimit == 2)
    }
}

@Suite("Pagos planificados · chips, ícono y pie: cableado (source-scan)")
struct PagosChipsVistaCableadoTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios, para que documentar el invariante no lo cumpla.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }

    private static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private static let lista = "Yala/App/Views/Planning/ScheduledPaymentsListView.swift"
    private static let contenedor = "Yala/App/Views/Planning/ScheduledPaymentsView.swift"
    private static let pie = "Yala/App/Views/Planning/PagosRecurrentes/RecurringProposalsSettingsView.swift"

    @Test("El selector de vista sigue con iconos a la derecha y lee la vista guardada")
    func selectorConIconosQueRecuerda() throws {
        let code = Self.codeOnly(try Self.source(Self.lista))
        // Jürgen, 24-nov-2026: los chips con texto se probaron y se revirtieron; quedan los botones redondos a la derecha.
        #expect(code.contains("Spacer()\n                viewModeSelector"))
        #expect(code.contains("Image(systemName: mode.iconName)"))
        #expect(!code.contains("Text(mode.accessibilityLabel)"))
        #expect(code.contains("appPreferences.scheduledPaymentsViewMode = mode"))
        #expect(code.contains("switch appPreferences.scheduledPaymentsViewMode"))
        #expect(code.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
        #expect(code.contains("\"scheduled_view_mode_\\(mode.rawValue)\""))
    }

    @Test("Línea de tiempo y calendario pintan el ícono de la subcategoría cuando no hay logo")
    func iconoSinLogoEnLasTresVistas() throws {
        let code = Self.codeOnly(try Self.source(Self.lista))
        #expect(code.contains("PagoIconoRespaldo(icon: summary.icon, colorHex: summary.color, diameter: DS.Icon.badgeSmall)"))
        #expect(code.contains("PaymentIconCalendarMark(icon: summary.icon, colorHex: summary.color, stateColor: stateColor)"))
        // El punto suelto de antes ya no se pinta.
        #expect(!code.contains(".frame(width: 6, height: 6)"))
        let fila = Self.codeOnly(try Self.source("Yala/App/Views/Planning/ScheduledPaymentRowView.swift"))
        #expect(fila.contains("Image(systemName: summary.icon)"))
    }

    @Test("Sin hueco entre la lista y el enlace: el sitio del «+» va debajo de todo, el de un botón")
    func sinHuecoBajoLaLista() throws {
        let lista = Self.codeOnly(try Self.source(Self.lista))
        #expect(!lista.contains("DS.Spacing.safeBottom"))
        let contenedor = Self.codeOnly(try Self.source(Self.contenedor))
        let enlace = try #require(contenedor.range(of: "RecurringProposalsFooterLink()"))
        let reserva = try #require(contenedor.range(of: ".padding(.bottom, DS.Button.fabStackClearance(buttons: 1))"))
        #expect(enlace.upperBound < reserva.lowerBound, "el sitio del «+» va DEBAJO del enlace, no entre la lista y él")
        let pie = Self.codeOnly(try Self.source(Self.pie))
        #expect(pie.contains(".padding(.top, DS.Spacing.lg)"))
    }

    @Test("El enlace dice «Ver más pagos que se repiten»; el título de la hoja sigue igual")
    func textoDelEnlace() throws {
        let es = try Self.source("Yala/Resources/es.lproj/Localizable.strings")
        #expect(es.contains("\"pagosRecurrentes.footer.link\" = \"Ver más pagos que se repiten\";"))
        #expect(es.contains("\"pagosRecurrentes.settings.title\" = \"Pagos que se repiten\";"))
        let latam = try Self.source("Yala/Resources/es-419.lproj/Localizable.strings")
        #expect(latam.contains("\"pagosRecurrentes.footer.link\" = \"Ver más pagos que se repiten\";"))
    }
}
