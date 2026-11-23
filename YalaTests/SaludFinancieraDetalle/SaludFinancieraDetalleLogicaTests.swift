//
//  SaludFinancieraDetalleLogicaTests.swift
//  YalaTests
//
//  La hoja de la nota de salud en tres secciones (opción A de Jürgen, 20-nov-2026): racha, presupuestos y su propuesta
//  de límite, la comparación de tu dinero con tus pagos, el estado y la cápsula de cada sección, el consejo bajo la nota
//  y la tarjeta de IA guardada. Y sus textos en los 16 idiomas.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Salud financiera · detalle · lógica")
struct SaludFinancieraDetalleLogicaTests {

    private typealias L = SaludFinancieraDetalleLogica

    /// Mediodía del 20-nov-2026 en Lima: fijo, nunca el reloj.
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return c
    }()
    private static let now: Date = {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12)) ?? .now
    }()
    private static let finDeMes: Date = {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 23, minute: 59, second: 59)) ?? .now
    }()

    private func dia(_ offset: Int, hora: Int = 9) -> Date {
        let base = Self.calendar.startOfDay(for: Self.now)
        let d = Self.calendar.date(byAdding: .day, value: offset, to: base) ?? base
        return Self.calendar.date(byAdding: .hour, value: hora, to: d) ?? d
    }

    private func presupuesto(_ nombre: String, gastado: Double, limite: Double = 100, moneda: String = "PEN")
        -> L.Presupuesto {
        L.Presupuesto(id: UUID(), nombre: nombre, icono: "cart", color: "6366F1", gastado: gastado, limite: limite,
                      moneda: moneda)
    }

    private func pago(_ nombre: String, dias: Int, monto: Double, aproximado: Bool = false) -> L.Pago {
        L.Pago(id: UUID(), nombre: nombre, fecha: dia(dias), dias: dias, monto: monto, moneda: "PEN",
               montoConvertido: monto, esAproximado: aproximado)
    }

    private func score(budget: Int? = 90, activity: Int? = 90, bills: Int? = 90) -> FinancialScore {
        FinancialScore(total: 90, budget: budget, activity: activity, bills: bills)
    }

    // MARK: Racha

    @Test func racha_cuentaDesdeHoy_cuandoHoyHayRegistro() {
        let r = L.racha(diasConMovimiento: [dia(0), dia(-1), dia(-2), dia(-4)], now: Self.now, calendar: Self.calendar)
        #expect(r.dias == 3)
        #expect(r.registroHoy)
        #expect(r.tira.count == L.diasEnTira)
        #expect(r.tira.last == true)
    }

    @Test func racha_sigueViva_siHoyAunNoHay_peroAyerSi() {
        let r = L.racha(diasConMovimiento: [dia(-1), dia(-2)], now: Self.now, calendar: Self.calendar)
        #expect(r.dias == 2)
        #expect(!r.registroHoy)
    }

    @Test func racha_seCorta_siAyerTampocoHay() {
        let r = L.racha(diasConMovimiento: [dia(-2), dia(-3)], now: Self.now, calendar: Self.calendar)
        #expect(r.dias == 0)
    }

    // MARK: Presupuestos

    @Test func presupuestos_vanPrimeroLosQueVanPeor() {
        let ordenados = L.ordenar([
            presupuesto("Bien", gastado: 10), presupuesto("Pasado", gastado: 130), presupuesto("Cerca", gastado: 90),
        ])
        #expect(ordenados.map(\.nombre) == ["Pasado", "Cerca", "Bien"])
    }

    @Test func propuesta_tresDeCuatroPasados_proponeElPromedioRedondeadoHaciaArriba() throws {
        let p = try #require(L.propuestaDeLimite(historial: [1210, 1185, 980, 1345], limite: 1000))
        #expect(p.vecesPasado == 3)
        #expect(p.periodos == 4)
        #expect(abs(p.promedio - 1180) < 0.001)
        #expect(p.limite == 1200)
    }

    @Test func propuesta_dosDeCuatro_noPropone() {
        #expect(L.propuestaDeLimite(historial: [1210, 900, 980, 1345], limite: 1000) == nil)
    }

    @Test func propuesta_sinCuatroPeriodosDeHistoria_noPropone() {
        #expect(L.propuestaDeLimite(historial: [1210, 1185, 1345], limite: 1000) == nil)
    }

    @Test func redondeo_esUnMontoRedondoHaciaArriba() {
        #expect(L.redondearHaciaArriba(123) == 130)
        #expect(L.redondearHaciaArriba(1180) == 1200)
        #expect(L.redondearHaciaArriba(6020) == 6100)
    }

    @Test func dondeMasPesa_lasTresConMasGasto_deMasAMenos() {
        let recortes = [("Cafés", 148.0), ("Delivery", 412.3), ("Bebidas", 20.0), ("Restaurantes", 386.1)]
            .map { L.Recorte(nombre: $0.0, monto: $0.1, filtro: .ninguno) }
        #expect(L.dondeMasPesa(recortes).map(\.nombre) == ["Delivery", "Restaurantes", "Cafés"])
    }

    @Test func estadoPresupuestos_pasadoEsParaRevisar_sinNingunoSinDatos() {
        #expect(L.estadoPresupuestos([]) == .sinDatos)
        #expect(L.estadoPresupuestos([presupuesto("A", gastado: 10)]) == .bien)
        #expect(L.estadoPresupuestos([presupuesto("A", gastado: 10), presupuesto("B", gastado: 120)]) == .paraRevisar)
    }

    @Test func quedaEntreTodos_soloConLaMismaMonedaYSinPasados() {
        let dos = [presupuesto("A", gastado: 60), presupuesto("B", gastado: 30)]
        #expect(L.quedaEntreTodos(dos)?.monto == 110)
        #expect(L.quedaEntreTodos([presupuesto("A", gastado: 60), presupuesto("B", gastado: 30, moneda: "USD")]) == nil)
        #expect(L.quedaEntreTodos([presupuesto("A", gastado: 160), presupuesto("B", gastado: 30)]) == nil)
    }

    // MARK: Compromisos

    @Test func comparacion_alcanza_yLasBarrasVanALaMismaEscala() {
        let c = L.comparacion(pagos: [pago("Alquiler", dias: 5, monto: 2230), pago("Luz", dias: 6, monto: 170)],
                              dineroHoy: 4800, moneda: "PEN")
        #expect(c.faltaPagar == 2400)
        #expect(c.alcanza)
        #expect(c.diferencia == 2400)
        #expect(c.barraDinero == 1)
        #expect(c.barraFalta == 0.5)
    }

    @Test func comparacion_noAlcanza_diceCuantoFaltaria() {
        let c = L.comparacion(pagos: [pago("Tarjeta", dias: 5, monto: 8699.5)], dineroHoy: 7850,
                              moneda: "PEN")
        #expect(!c.alcanza)
        #expect(abs(-c.diferencia - 849.5) < 0.001)
        #expect(c.barraFalta == 1)
    }

    @Test func comparacion_dineroNegativo_pintaLaBarraVacia() {
        let c = L.comparacion(pagos: [pago("Alquiler", dias: 5, monto: 100)], dineroHoy: -50,
                              moneda: "PEN")
        #expect(c.barraDinero == 0)
        #expect(c.barraFalta == 1)
    }

    /// La marca «≈» sigue el umbral de la app, no un «alguno es aproximado» (revisor con checklist, ronda 1).
    @Test func comparacion_laMarcaSigueElUmbral_sobreLoQueSePinta() {
        // Un Spotify de 19 con tasa dudosa entre 2.249: no llega al 5 %, no marca.
        let poco = L.comparacion(pagos: [pago("Alquiler", dias: 5, monto: 2230), pago("Spotify", dias: 6, monto: 19,
                                                                                       aproximado: true)],
                                 dineroHoy: 7850, moneda: "PEN")
        #expect(!poco.faltaEsAproximado)
        #expect(!poco.diferenciaEsAproximada)
        // 300 dudosos en un dinero de 10.000 no marcan el dinero (3 %), pero sí lo que sobra: 300 de 500.
        let resta = L.comparacion(pagos: [pago("Alquiler", dias: 5, monto: 9500)], dineroHoy: 10_000,
                                  dineroDudoso: 300, moneda: "PEN")
        #expect(!resta.dineroEsAproximado)
        #expect(resta.diferenciaEsAproximada)
        // Un solo pago, todo con tasa dudosa: marca lo que falta.
        let todo = L.comparacion(pagos: [pago("Netflix", dias: 2, monto: 40, aproximado: true)], dineroHoy: 100,
                                 moneda: "PEN")
        #expect(todo.faltaEsAproximado)
    }

    @Test func pagosPendientes_ordenadosPorFecha_conLosDiasDesdeHoy() {
        let pagos = L.pagosPendientes([
            (id: UUID(), nombre: "Alquiler", fecha: dia(8), monto: -2230, moneda: "PEN", convertido: -2230,
             aproximado: false),
            (id: UUID(), nombre: "Luz", fecha: dia(-1), monto: 142.6, moneda: "PEN", convertido: 142.6,
             aproximado: false),
        ], now: Self.now, calendar: Self.calendar)
        #expect(pagos.map(\.nombre) == ["Luz", "Alquiler"])
        #expect(pagos.map(\.dias) == [-1, 8])
        #expect(pagos.first?.vencido == true)
        #expect(pagos.last?.monto == 2230, "El monto se enseña sin signo.")
    }

    @Test func estadoCompromisos() {
        let alcanza = L.comparacion(pagos: [pago("A", dias: 3, monto: 10)], dineroHoy: 100, moneda: "PEN")
        let noAlcanza = L.comparacion(pagos: [pago("A", dias: 3, monto: 1000)], dineroHoy: 100,
                                      moneda: "PEN")
        #expect(L.estadoCompromisos(tienePagos: false, pagos: [], comparacion: nil) == .sinDatos)
        #expect(L.estadoCompromisos(tienePagos: true, pagos: [pago("A", dias: 3, monto: 10)],
                                    comparacion: alcanza) == .bien)
        #expect(L.estadoCompromisos(tienePagos: true, pagos: [pago("A", dias: 3, monto: 1000)],
                                    comparacion: noAlcanza) == .paraRevisar)
        #expect(L.estadoCompromisos(tienePagos: true, pagos: [pago("A", dias: -1, monto: 10)],
                                    comparacion: alcanza) == .paraRevisar)
    }

    // MARK: Nota

    @Test func capsula_sinPresupuestos_diceCreaUno() {
        #expect(L.motivoSinNota(.presupuestos, score: score(budget: nil), presupuestos: [], tienePagos: true) == .creaUno)
    }

    @Test func capsula_conPresupuestosYSinNota_noPrometeUnaFecha() {
        // Desde el 22-nov-2026 un presupuesto cuenta desde el período en que se creó: sin nota con presupuestos es que
        // ninguno cubre el período, y la cápsula no dice «Desde el…».
        let p = presupuesto("Comidas fuera", gastado: 40)
        #expect(L.motivoSinNota(.presupuestos, score: score(budget: nil), presupuestos: [p], tienePagos: true)
                == .sinDatos)
    }

    @Test func capsula_sinPagos_diceAgregaPagos_yConNotaNoDiceNada() {
        #expect(L.motivoSinNota(.compromisos, score: score(bills: nil), presupuestos: [], tienePagos: false)
                == .agregaPagos)
        #expect(L.motivoSinNota(.ritmo, score: score(activity: nil), presupuestos: [], tienePagos: true) == .registraHoy)
        #expect(L.motivoSinNota(.compromisos, score: score(), presupuestos: [], tienePagos: true) == nil)
    }

    @Test func consejo_loQueMasMueveLaNotaPrimero() {
        let noAlcanza = L.comparacion(pagos: [pago("A", dias: 3, monto: 1000)], dineroHoy: 100,
                                      moneda: "PEN")
        let alcanza = L.comparacion(pagos: [pago("A", dias: 3, monto: 10)], dineroHoy: 100, moneda: "PEN")
        let pasado = presupuesto("Comidas", gastado: 120)
        func consejo(_ presupuestos: [L.Presupuesto], _ c: L.Comparacion?, pagos: [L.Pago] = [],
                     tienePagos: Bool = true, soloGastos: Bool = false, s: FinancialScore? = nil) -> L.Consejo {
            L.consejo(score: s ?? score(), presupuestos: presupuestos, pagos: pagos, comparacion: c,
                      tienePagos: tienePagos, isExpensesOnlyMode: soloGastos, finDeMes: Self.finDeMes)
        }
        #expect(consejo([pasado], noAlcanza) == .noAlcanza(finDeMes: Self.finDeMes))
        #expect(consejo([pasado], noAlcanza, soloGastos: true) == .presupuestoPasado(nombre: "Comidas"),
                "En «Solo gastos» no hay saldos que comparar.")
        #expect(consejo([pasado, presupuesto("Taxi", gastado: 130)], alcanza) == .variosPasados(2))
        #expect(consejo([presupuesto("A", gastado: 10)], alcanza, pagos: [pago("Luz", dias: -1, monto: 10)])
                == .pagoVencido(nombre: "Luz"))
        #expect(consejo([], alcanza, s: score(budget: nil)) == .creaPresupuesto)
        #expect(consejo([presupuesto("A", gastado: 10)], nil, tienePagos: false) == .agregaPagos)
        #expect(consejo([presupuesto("A", gastado: 10)], alcanza, s: score(activity: 40)) == .registraMasSeguido)
        #expect(consejo([presupuesto("A", gastado: 10)], alcanza) == .todoBien)
    }

    // MARK: Tarjeta de IA

    private func respuesta(_ cards: [LLMInsightCard]) -> LLMInsightResponse {
        LLMInsightResponse(heroText: "Hero", cards: cards, funFact: nil)
    }

    @Test func tarjetaIA_soloLaQuePideAtencion_conConsejo() {
        let r = respuesta([
            LLMInsightCard(icon: "a", text: "Bien", sentiment: "positive", tip: "Sigue"),
            LLMInsightCard(icon: "b", text: "Sin consejo", sentiment: "attention", tip: nil),
            LLMInsightCard(icon: "c", text: "Delivery subió", sentiment: "attention", tip: "Pon un tope"),
        ])
        #expect(L.tarjetaIA(r) == L.TarjetaIA(texto: "Delivery subió", consejo: "Pon un tope"))
        #expect(L.tarjetaIA(nil) == nil)
        #expect(L.tarjetaIA(respuesta([LLMInsightCard(icon: "a", text: "x", sentiment: "neutral", tip: "y")])) == nil)
    }

    @Test func resumenDelMes_elUltimoGuardadoEsteMes_nuncaElDelMesPasado() {
        let pasado = respuesta([LLMInsightCard(icon: "a", text: "octubre", sentiment: "attention", tip: "t")])
        let viejo = respuesta([LLMInsightCard(icon: "a", text: "1 nov", sentiment: "attention", tip: "t")])
        let nuevo = respuesta([LLMInsightCard(icon: "a", text: "18 nov", sentiment: "attention", tip: "t")])
        let elegido = L.resumenDelMes([(dia(-25), pasado), (dia(-19), viejo), (dia(-2), nuevo)],
                                      now: Self.now, calendar: Self.calendar)
        #expect(elegido == nuevo)
        #expect(L.resumenDelMes([(dia(-25), pasado)], now: Self.now, calendar: Self.calendar) == nil)
        #expect(L.resumenDelMes([], now: Self.now, calendar: Self.calendar) == nil)
    }

    /// La tarjeta sale de lo guardado: leer los resúmenes no llama a nadie (no hay `InsightsLLMService` en el camino).
    @Test func tarjetaIA_seLeeDeLoGuardado_sinLlamarALaIA() throws {
        let defaults = makeIsolatedDefaults()
        let respuesta = respuesta([LLMInsightCard(icon: "a", text: "Delivery", sentiment: "attention", tip: "Tope")])
        let store = StatsAIAutoRefreshStore(defaults: defaults)
        store.save(respuesta, page: .summary, slot: "ranura", fingerprint: "f",
                   snapshot: StatsAIAutoRefreshLogic.Snapshot(transactionCount: 1, totals: [1, 2]), now: dia(-1))
        let tarjeta = SaludFinancieraDetalleCargador.tarjetaIAGuardada(defaults: defaults, now: Self.now,
                                                                       calendar: Self.calendar)
        #expect(tarjeta == L.TarjetaIA(texto: "Delivery", consejo: "Tope"))
        #expect(SaludFinancieraDetalleCargador.tarjetaIAGuardada(defaults: makeIsolatedDefaults(), now: Self.now,
                                                                 calendar: Self.calendar) == nil)

        let fuentes = try Self.fuente("Yala/App/Views/Panel/Sheets/SaludFinanciera/SaludFinancieraDetalleCargador.swift")
            + Self.fuente("Yala/App/Views/Panel/Sheets/SaludFinanciera/SaludFinancieraDetalleView.swift")
        #expect(!fuentes.contains("InsightsLLMService"), "La hoja no puede pedir un resumen nuevo.")
        #expect(!fuentes.contains("MonthEndBalanceLogic"), "La hoja no usa «Al 30 tendrías».")
    }

    static func fuente(_ ruta: String, file: StaticString = #filePath) throws -> String {
        let raiz = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: raiz.appending(path: ruta), encoding: .utf8)
            .split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
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
        #expect(try Self.table("es-AR")["saludDetalle.commit.lead"]?.contains("tenés") == true)
        #expect(try Self.table("pt-PT")["saludDetalle.commit.lead"] != Self.table("pt-BR")["saludDetalle.commit.lead"])
    }

    /// Ni rojo alarmista ni «No alcanza» en ningún idioma de la hoja nueva.
    @Test func elEspanol_aconsejaSinAlarma() throws {
        let es = try Self.table("es")
        #expect(!es.values.contains { $0.hasPrefix("No alcanza") })
        #expect(es["saludDetalle.section.howItWorks"] == "¿Cómo se calcula?")
        #expect(es["saludDetalle.commit.toPay"] == "Te falta pagar este mes")
        #expect(es["saludDetalle.commit.moneyToday"] == "Tu dinero hoy")
    }

    /// Cada clave que lee la app existe en español (una errata en el código devolvería la clave cruda).
    @Test func cadaClaveDelCodigo_existe() throws {
        typealias T = L10n.SaludFinancieraDetalle
        typealias L = SaludFinancieraDetalleLogica
        let fecha = Date(timeIntervalSince1970: 1_795_000_000)
        let pago = L.Pago(id: UUID(), nombre: "x", fecha: fecha, dias: -3, monto: 1, moneda: "PEN", montoConvertido: 1,
                          esAproximado: false)
        var leidas = [
            T.cargando, T.seccionComoSeCalcula, T.peso(40), T.capsulaPista, T.unoDentro("x"), T.todosDentro(3),
            T.todosDentroQueda(3, monto: "1"), T.soloPasado("x", monto: "1"), T.pasadoYOtros("x", monto: "1", otros: 1),
            T.pasadoYOtros("x", monto: "1", otros: 2), T.variosPasados(2),
            T.verTodosPresupuestos(5), T.teQuedan, T.tePasastePor, T.sinPresupuestos(peso: 40), T.porDondeEmpezar,
            T.sugerencia("x", monto: "1"), T.crearPresupuesto, T.paraMejorar, T.nadaQueAjustar, T.ajustarTitulo,
            T.ajustarDetalle("x", veces: 3, periodos: 4, promedio: "1", limite: "2"), T.ajustarBoton,
            T.recortarTitulo(solo: true), T.recortarTitulo(solo: false), T.recortarDetalle("x", lista: "y"),
            T.recortarBoton, T.iaEtiqueta, T.iaBoton, T.iaSinResumenTitulo, T.iaSinResumenDetalle, T.lineaPro,
            T.lineaProBoton, T.compromisosFrase(falta: "1", dinero: "2"), T.compromisosFraseSoloGastos(falta: "1"),
            T.alcanza(sobra: "1"), T.noAlcanza(mesSiguiente: "x"), T.teFaltaPagar, T.tuDineroHoy, T.faltarian("1"),
            T.ingreso("1", de: "x", fecha: fecha, mas: 0), T.ingreso("1", de: "x", fecha: fecha, mas: 1),
            T.ingreso("1", de: "x", fecha: fecha, mas: 2), T.vencido(pago), T.cuentaEnNegativo("x"),
            T.pendientes(1, hasta: fecha), T.pendientes(3, hasta: fecha), T.revisarOMover, T.verTusPagos,
            T.todoPagado(fecha), T.proximoPago("x", fecha: fecha), T.sinPagos(dinero: "1"), T.sinPagosSinDinero,
            T.cobrosTitulo, T.cobros(["a"]), T.cobros(["a", "b"]), T.cobrosBoton, T.agregarPago, T.cuando(dias: -1),
            T.cuando(dias: 0), T.cuando(dias: 1), T.cuando(dias: 4), T.rachaDias(1), T.rachaDias(5), T.rachaHoy,
            T.rachaMantener, T.rachaEmpezar, T.rachaBoton, T.rachaTira(14),
            T.vencido(L.Pago(id: UUID(), nombre: "x", fecha: fecha, dias: -1, monto: 1, moneda: "PEN",
                             montoConvertido: 1, esAproximado: false)),
        ]
        leidas += L.Seccion.allCases.map(T.seccion)
        leidas += [L.Estado.bien, .paraRevisar, .sinDatos].map(T.estado)
        leidas += [L.MotivoSinNota.creaUno, .agregaPagos, .registraHoy, .sinDatos].map(T.motivo)
        leidas += [L.Consejo.noAlcanza(finDeMes: fecha), .presupuestoPasado(nombre: "x"), .variosPasados(2),
                   .pagoVencido(nombre: "x"), .creaPresupuesto, .agregaPagos,
                   .registraMasSeguido, .todoBien].map(T.consejo)
        leidas += [T.apuntadoFuturo("x", resta: true), T.apuntadoFuturo("x", resta: false)]
        for texto in leidas {
            #expect(!texto.contains("saludDetalle."), "Clave sin texto: \(texto)")
        }
        #expect(try Self.table("es").count == 90)
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.SaludFinancieraDetalle.string("saludDetalle.section.commitments", resolution: resolution)
        #expect(texto == (try Self.table(locale)["saludDetalle.section.commitments"]))
    }
}
