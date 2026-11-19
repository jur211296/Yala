//
//  SaludFinancieraDetalleLogicaTests.swift
//  YalaTests
//
//  La hoja de la nota de salud, visual y accionable (18-nov-2026): racha, próximos pagos, orden de presupuestos,
//  alertas y qué hacer para subir la nota. Y sus textos en los 16 idiomas.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Salud financiera · detalle · lógica")
struct SaludFinancieraDetalleLogicaTests {

    private typealias L = SaludFinancieraDetalleLogica

    /// Mediodía del 18-nov-2026 en Lima: fijo, nunca el reloj.
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return c
    }()
    private static let now: Date = {
        let comps = DateComponents(year: 2026, month: 11, day: 18, hour: 12)
        return calendar.date(from: comps) ?? .now
    }()

    private func dia(_ offset: Int, hora: Int = 9) -> Date {
        let base = Self.calendar.startOfDay(for: Self.now)
        let d = Self.calendar.date(byAdding: .day, value: offset, to: base) ?? base
        return Self.calendar.date(byAdding: .hour, value: hora, to: d) ?? d
    }

    private func presupuesto(_ nombre: String, gastado: Double, limite: Double = 100) -> L.Presupuesto {
        L.Presupuesto(id: UUID(), nombre: nombre, icono: "cart", color: "6366F1", gastado: gastado, limite: limite,
                      moneda: "PEN")
    }

    // MARK: Racha

    @Test func racha_cuentaDesdeHoy_cuandoHoyHayRegistro() {
        let r = L.racha(diasConMovimiento: [dia(0), dia(-1), dia(-2), dia(-4)], now: Self.now, calendar: Self.calendar)
        #expect(r.dias == 3)
        #expect(r.registroHoy)
        #expect(r.tira.count == L.diasEnTira)
        #expect(r.tira.last == true)
        #expect(r.tira[L.diasEnTira - 4] == false, "El día −3 no tiene registro.")
    }

    @Test func racha_sigueViva_siHoyAunNoHay_peroAyerSi() {
        let r = L.racha(diasConMovimiento: [dia(-1), dia(-2)], now: Self.now, calendar: Self.calendar)
        #expect(r.dias == 2)
        #expect(!r.registroHoy)
    }

    @Test func racha_seCorta_siAyerTampocoHay() {
        let r = L.racha(diasConMovimiento: [dia(-2), dia(-3)], now: Self.now, calendar: Self.calendar)
        #expect(r.dias == 0)
        #expect(r.tira.filter { $0 }.count == 2)
    }

    @Test func racha_juntaVariosMovimientosDelMismoDia() {
        let r = L.racha(diasConMovimiento: [dia(0, hora: 1), dia(0, hora: 23)], now: Self.now, calendar: Self.calendar)
        #expect(r.dias == 1)
    }

    // MARK: Pagos

    private func pago(_ nombre: String, en offset: Int, esGasto: Bool = true, activo: Bool = true, saltado: Bool = false)
        -> (id: UUID, nombre: String, fecha: Date, monto: Double, moneda: String, esGasto: Bool, activo: Bool,
            saltado: Bool) {
        (id: UUID(), nombre: nombre, fecha: dia(offset), monto: 50, moneda: "PEN", esGasto: esGasto, activo: activo,
         saltado: saltado)
    }

    @Test func pagos_soloGastosActivosNoSaltados_dentroDelHorizonte_yEnOrden() {
        let lista = L.proximosPagos([
            pago("Lejano", en: L.horizontePagos + 1),
            pago("Luz", en: 5),
            pago("Renta", en: 0),
            pago("Sueldo", en: 2, esGasto: false),
            pago("Pausado", en: 1, activo: false),
            pago("Saltado", en: 1, saltado: true),
            pago("Vencido", en: -3),
            pago("Borde", en: L.horizontePagos),
        ], now: Self.now, calendar: Self.calendar)
        #expect(lista.map(\.nombre) == ["Vencido", "Renta", "Luz", "Borde"])
        #expect(lista.map(\.dias) == [-3, 0, 5, L.horizontePagos])
    }

    // MARK: Presupuestos

    @Test func presupuestos_vanPrimeroLosQueVanPeor() {
        let ordenados = L.ordenar([
            presupuesto("Tranquilo", gastado: 20),
            presupuesto("Al 90", gastado: 90),
            presupuesto("Justo", gastado: 100),
            presupuesto("Pasado", gastado: 130),
            presupuesto("Al 50", gastado: 50),
        ])
        #expect(ordenados.map(\.nombre) == ["Pasado", "Justo", "Al 90", "Al 50", "Tranquilo"])
    }

    @Test func presupuesto_restante_esLaReglaDeTeQuedan() {
        #expect(presupuesto("A", gastado: 30).restante == 70)
        #expect(presupuesto("B", gastado: 130).restante == -30)
        #expect(presupuesto("B", gastado: 130).estado == .overLimit)
    }

    // MARK: Alertas

    private func cobertura(alCierre: Double, faltaSalir: Double = 500) -> L.Cobertura {
        L.Cobertura(alCierre: alCierre, faltaSalir: faltaSalir, fechaCierre: dia(12), moneda: "PEN", esAproximada: false)
    }

    @Test func alertas_loGravePrimero_yLosDelLimiteAlFinal() {
        let vencido = L.Pago(id: UUID(), nombre: "Luz", fecha: dia(-2), dias: -2, monto: 80, moneda: "PEN")
        let alertas = L.alertas(
            presupuestos: [presupuesto("Al 90", gastado: 90), presupuesto("Pasado", gastado: 130)],
            pagos: [vencido, L.Pago(id: UUID(), nombre: "Renta", fecha: dia(3), dias: 3, monto: 900, moneda: "PEN")],
            cobertura: cobertura(alCierre: -200),
            cuentasEnRojo: [(nombre: "Efectivo", id: nil)],
            isExpensesOnlyMode: false
        )
        let tipos = alertas.map { alerta -> String in
            switch alerta {
            case .presupuestoPasado: "pasado"
            case .pagosSinCubrir: "cobertura"
            case .pagoVencido: "vencido"
            case .cuentaEnRojo: "cuenta"
            case .presupuestoAlLimite: "limite"
            case .presupuestosAlLimite: "limites"
            }
        }
        #expect(tipos == ["pasado", "cobertura", "vencido", "cuenta", "limite"])
        #expect(alertas.filter(\.esGrave).count == 4)
    }

    @Test func alertas_variosAlLimite_vanEnUnaSolaFila() {
        let alertas = L.alertas(
            presupuestos: [presupuesto("A", gastado: 85), presupuesto("B", gastado: 100), presupuesto("C", gastado: 95)],
            pagos: [], cobertura: nil, cuentasEnRojo: [], isExpensesOnlyMode: false
        )
        #expect(alertas.count == 1)
        guard case .presupuestosAlLimite(let lista) = alertas.first else {
            Issue.record("Esperaba una sola fila con los tres al límite: \(alertas)")
            return
        }
        #expect(lista.map(\.nombre) == ["B", "C", "A"])
    }

    @Test func alertas_soloGastos_sinCuentasNiCobertura() {
        let alertas = L.alertas(
            presupuestos: [], pagos: [], cobertura: cobertura(alCierre: -200),
            cuentasEnRojo: [(nombre: "Efectivo", id: nil)], isExpensesOnlyMode: true
        )
        #expect(alertas.isEmpty)
    }

    @Test func cobertura_sinPagosQueFaltan_noEsAlerta_aunqueElCierreSeaNegativo() {
        let alertas = L.alertas(presupuestos: [], pagos: [], cobertura: cobertura(alCierre: -200, faltaSalir: 0),
                                cuentasEnRojo: [], isExpensesOnlyMode: false)
        #expect(alertas.isEmpty, "Sin pagos por delante no hay pagos que cubrir.")
    }

    @Test func cobertura_queSeVeComoCero_cubre() {
        #expect(cobertura(alCierre: -0.001).cubre)
        #expect(!cobertura(alCierre: -1).cubre)
    }

    // MARK: Para subir la nota

    private func racha(hoy: Bool) -> L.Racha { L.Racha(dias: hoy ? 3 : 0, tira: [], registroHoy: hoy) }

    @Test func pasos_sinPresupuestosNiPagos_invitaACrearlos() {
        let score = FinancialScore(total: nil, budget: nil, activity: 100, bills: nil)
        let pasos = L.pasos(score: score, tienePresupuestos: false, tienePagos: false, racha: racha(hoy: true))
        #expect(pasos == [.crearPresupuesto, .agregarPagos])
    }

    @Test func pasos_conPresupuestosQueAunNoCuentan_noPideCrearOtro() {
        let score = FinancialScore(total: 100, budget: nil, activity: 100, bills: 100)
        let pasos = L.pasos(score: score, tienePresupuestos: true, tienePagos: true, racha: racha(hoy: true))
        #expect(pasos.isEmpty)
    }

    @Test func pasos_sinRegistroHoy_loPide_yLaParteMasFlojaDespues() {
        let score = FinancialScore(total: 70, budget: 60, activity: 92, bills: 95)
        let pasos = L.pasos(score: score, tienePresupuestos: true, tienePagos: true, racha: racha(hoy: false))
        #expect(pasos == [.registrarHoy, .revisarPresupuestos])
    }

    @Test func pasos_nuncaMasDeDos() {
        let score = FinancialScore(total: nil, budget: nil, activity: 40, bills: nil)
        let pasos = L.pasos(score: score, tienePresupuestos: false, tienePagos: false, racha: racha(hoy: false))
        #expect(pasos.count == L.maximoPasos)
        #expect(pasos == [.crearPresupuesto, .registrarHoy])
    }

    @Test func pasos_cadaUnoMueveSuParte() {
        #expect(L.Paso.crearPresupuesto.parte == .budget)
        #expect(L.Paso.registrarHoy.parte == .activity)
        #expect(L.Paso.revisarPagos.parte == .bills)
    }
}

// MARK: - Textos

@MainActor
@Suite("Salud financiera · detalle · los textos en los 16 idiomas")
struct SaludFinancieraDetalleTextosTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/SaludFinancieraDetalle.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func placeholders(_ text: String) -> [String] {
        let regex = /%(\d+\$)?[@d]/
        return text.matches(of: regex).map { String($0.output.0) }.sorted()
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneCadaClave_conTexto_yLosMismosHuecos(_ locale: String) throws {
        let referencia = try Self.table("es")
        let textos = try Self.table(locale)
        #expect(Set(textos.keys) == Set(referencia.keys), "\(locale): claves distintas de es.")
        for (clave, valor) in textos {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
            #expect(Self.placeholders(valor) == Self.placeholders(referencia[clave] ?? ""),
                    "\(locale): \(clave) no tiene los mismos huecos que en español.")
        }
    }

    @Test func alias_copianSuReferencia() throws {
        #expect(try Self.table("es-419") == Self.table("es"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test func variantes_hablanASuManera() throws {
        #expect(try Self.table("es-AR")["saludDetalle.alert.overBudget.detail"]?.hasPrefix("Tocá") == true)
        #expect(try Self.table("es-ES")["saludDetalle.payments.empty.detail"]?.hasPrefix("Alquiler") == true)
        #expect(try Self.table("pt-PT")["saludDetalle.streak.keep"]?.hasPrefix("Registe") == true)
    }

    /// Cada clave que lee la app existe en español (una errata en el código devolvería la clave cruda).
    @Test func cadaClaveDelCodigo_existe() throws {
        typealias T = L10n.SaludFinancieraDetalle
        let leidas = [
            T.seccionAlertas, T.seccionPresupuestos, T.seccionPagos, T.seccionRacha, T.seccionSubir,
            T.seccionComoSeCalcula, T.cargando, T.sinAlertasTitulo, T.sinAlertasDetalle, T.pasadoTitulo("x"),
            T.pasadoDetalle, T.alLimiteTitulo("x"), T.alLimiteDetalle(porcentaje: 90), T.llegoAlLimiteTitulo("x"),
            T.variosAlLimiteTitulo(3), T.cuentaEnRojoTitulo("x"), T.cuentaEnRojoDetalle, T.vencidoTitulo("x"),
            T.vencidoDetalle, T.sinCubrirTitulo, T.sinCubrirDetalle, T.presupuestosVacioTitulo,
            T.presupuestosVacioDetalle, T.presupuestosVacioBoton, T.verTodosPresupuestos(5), T.teQuedan,
            T.tePasastePor, T.cuando(dias: -1), T.cuando(dias: 0), T.cuando(dias: 1), T.cuando(dias: 4),
            T.sinPagosCerca, T.pagosVacioTitulo, T.pagosVacioDetalle, T.pagosVacioBoton, T.verTodosPagos, T.cubre,
            T.noCubre, T.rachaDias(1), T.rachaDias(5), T.rachaHoy, T.rachaMantener, T.rachaEmpezar, T.rachaBoton,
            T.rachaTira(14), T.diaConRegistro, T.diaSinRegistro, T.pesoDeLaParte("x", porcentaje: 40),
        ] + [L.crearPresupuesto, .registrarHoy, .agregarPagos, .revisarPresupuestos, .revisarRitmo, .revisarPagos]
            .map(T.paso)
        for texto in leidas {
            #expect(!texto.hasPrefix("saludDetalle."), "Clave sin texto: \(texto)")
        }
        #expect(try Self.table("es").count == 54)
    }

    private typealias L = SaludFinancieraDetalleLogica.Paso

    @Test func elEspanol_diceLoQueSePidio() throws {
        let es = try Self.table("es")
        #expect(es["saludDetalle.section.howItWorks"] == "¿Cómo se calcula?")
        #expect(es["saludDetalle.budgets.empty.cta"] == "Crear presupuesto")
        #expect(es["saludDetalle.streak.days.one"] == "%d día seguido")
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.SaludFinancieraDetalle.string("saludDetalle.section.alerts", resolution: resolution)
        #expect(texto == (try Self.table(locale)["saludDetalle.section.alerts"]))
    }
}
