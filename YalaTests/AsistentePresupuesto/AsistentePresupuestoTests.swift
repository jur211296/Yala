//
//  AsistentePresupuestoTests.swift
//  YalaTests
//
//  «Nuevo presupuesto» por pasos (encargo del 17-nov): el navegador compartido de los asistentes (Atrás, progreso, volver
//  al resumen), las reglas del asistente de presupuesto (qué preguntas tocan, cuándo se sigue, topes sugeridos, nombre) y
//  lo que pasa al formulario con «Usar formulario». Y sus textos, en los 16 idiomas.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Navegador compartido

@Suite("Asistente de creación · el navegador")
struct AsistenteCreacionNavegadorTests {
    typealias Paso = AsistentePresupuestoLogica.Paso
    typealias Navegador = AsistenteCreacionNavegador<Paso>

    private let todos = AsistentePresupuestoLogica.pasos(alcance: .all, periodo: .monthly)
    private let conCategorias = AsistentePresupuestoLogica.pasos(alcance: .categories, periodo: .monthly)

    @Test func arranca_sinRespuestas_niAtras() {
        let nav = Navegador(inicio: .alcance)
        #expect(nav.actual == .alcance)
        #expect(!nav.tieneRespuestas)
        #expect(!nav.puedeRetroceder)
        #expect(nav.indice(en: todos) == 0)
    }

    @Test func siguiente_avanza_yApuntaLoRespondido() {
        var nav = Navegador(inicio: .alcance)
        let paso1 = nav.avanzar(en: todos)
        #expect(paso1)
        #expect(nav.actual == .periodo)
        #expect(nav.tieneRespuestas)
        #expect(nav.puedeRetroceder)
        #expect(nav.indice(en: todos) == 1)
    }

    @Test func enLaUltima_siguienteNoAvanza() {
        var nav = Navegador(inicio: .alcance)
        while nav.avanzar(en: todos) {}
        #expect(nav.actual == .resumen)
        let paso2 = nav.avanzar(en: todos)
        #expect(!paso2)
        #expect(nav.actual == .resumen)
    }

    @Test func atras_vuelveALaAnterior() {
        var nav = Navegador(inicio: .alcance)
        nav.avanzar(en: todos)
        nav.avanzar(en: todos)
        #expect(nav.actual == .tope)
        let paso3 = nav.retroceder(en: todos)
        #expect(paso3)
        #expect(nav.actual == .periodo)
        let paso4 = nav.retroceder(en: todos)
        #expect(paso4)
        #expect(nav.actual == .alcance)
        let paso5 = nav.retroceder(en: todos)
        #expect(!paso5)
    }

    /// «¿Cuáles?» ya no toca si se cambió a «Todos mis gastos»: Atrás la salta.
    @Test func atras_saltaLoQueYaNoToca() {
        var nav = Navegador(inicio: .alcance)
        nav.avanzar(en: conCategorias)                 // → ¿Cuáles?
        nav.avanzar(en: conCategorias)                 // → ¿Cada cuánto?
        #expect(nav.actual == .periodo)
        let paso6 = nav.retroceder(en: todos)
        #expect(paso6)             // ¿Cuáles? ya no está
        #expect(nav.actual == .alcance)
    }

    @Test func desdeElResumen_siguienteVuelveAlResumen() {
        var nav = Navegador(inicio: .alcance)
        while nav.avanzar(en: todos) {}
        nav.cambiar(.periodo, desde: .resumen)
        #expect(nav.actual == .periodo)
        let paso7 = nav.avanzar(en: todos)
        #expect(paso7)
        #expect(nav.actual == .resumen, "Cambiar una respuesta obligaba a pasar otra vez por todas las demás.")
        // Y la vuelta se olvida: con Atrás desde el resumen se vuelve a la que se cambió, y desde ahí «Siguiente» sigue
        // el orden de siempre.
        let paso8 = nav.retroceder(en: todos)
        #expect(paso8)
        #expect(nav.actual == .periodo)
        nav.avanzar(en: todos)
        #expect(nav.actual == .tope)
    }

    /// Cambiar a «Solo algunas categorías» desde el resumen hace aparecer «¿Cuáles?», que nunca se contestó: se pregunta.
    @Test func desdeElResumen_unaPreguntaNuevaSePregunta() {
        var nav = Navegador(inicio: .alcance)
        while nav.avanzar(en: todos) {}
        nav.cambiar(.alcance, desde: .resumen)
        let paso9 = nav.avanzar(en: conCategorias)
        #expect(paso9)
        #expect(nav.actual == .categorias)
        let paso10 = nav.avanzar(en: conCategorias)
        #expect(paso10)
        #expect(nav.actual == .resumen)
    }
}

// MARK: - Reglas del asistente de presupuesto

@Suite("Asistente de presupuesto · las reglas")
struct AsistentePresupuestoLogicaTests {
    typealias L = AsistentePresupuestoLogica

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }()

    private static func dia(_ d: Int, _ m: Int = 11, hora: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: hora)) ?? .distantPast
    }

    @Test func lasPreguntas_dependenDeLoRespondido() {
        #expect(L.pasos(alcance: .all, periodo: .monthly)
                == [.alcance, .periodo, .tope, .nombre, .aviso, .resumen])
        #expect(L.pasos(alcance: .categories, periodo: .monthly)
                == [.alcance, .categorias, .periodo, .tope, .nombre, .aviso, .resumen])
        #expect(L.pasos(alcance: .categories, periodo: .unique)
                == [.alcance, .categorias, .periodo, .fechas, .tope, .nombre, .aviso, .resumen])
    }

    @Test func lasDeOpcion_siempreDejanSeguir_conLoSugerido() {
        let r = L.Respuestas()
        #expect(L.puedeSeguir(en: .alcance, r))
        #expect(L.puedeSeguir(en: .periodo, r))
        #expect(L.puedeSeguir(en: .aviso, r))
    }

    @Test func cuales_pideAlMenosUna() {
        var r = L.Respuestas(alcance: .categories)
        #expect(!L.puedeSeguir(en: .categorias, r))
        r.categoriasElegidas = 1
        #expect(L.puedeSeguir(en: .categorias, r))
    }

    @Test func tope_pideUnNumeroMayorQueCero() {
        var r = L.Respuestas()
        #expect(!L.puedeSeguir(en: .tope, r))
        r.tope = 0
        #expect(!L.puedeSeguir(en: .tope, r))
        r.tope = 450
        #expect(L.puedeSeguir(en: .tope, r))
    }

    @Test func nombre_noAdmiteSoloEspacios() {
        var r = L.Respuestas(nombre: "   ")
        #expect(!L.puedeSeguir(en: .nombre, r))
        r.nombre = " Comida "
        #expect(L.puedeSeguir(en: .nombre, r))
    }

    /// Un presupuesto de un solo día vale (se comparan días, no instantes), como en el formulario.
    @Test func fechas_unSoloDiaVale_alReves_no() {
        let c = Self.calendar
        var r = L.Respuestas(periodo: .unique, inicio: Self.dia(20, hora: 18), fin: Self.dia(20, hora: 9))
        #expect(L.puedeSeguir(en: .fechas, r, calendar: c))
        r.fin = Self.dia(19)
        #expect(!L.puedeSeguir(en: .fechas, r, calendar: c))
    }

    /// El resumen vuelve a mirarlo todo: si al volver atrás se vació el tope, no crea.
    @Test func resumen_exigeTodoLoObligatorio() {
        var r = L.Respuestas(tope: 300, nombre: "Mis gastos del mes")
        #expect(L.puedeSeguir(en: .resumen, r))
        r.tope = nil
        #expect(!L.puedeSeguir(en: .resumen, r))
        r = L.Respuestas(alcance: .categories, categoriasElegidas: 0, tope: 300, nombre: "Comida")
        #expect(!L.puedeSeguir(en: .resumen, r))
    }

    @Test(arguments: [(43.0, 50.0), (100.0, 100.0), (101.0, 150.0), (480.0, 500.0), (1_234.0, 1_300.0),
                      (12_340.0, 13_000.0), (0.0, 0.0), (-5.0, 0.0)])
    func redondeo_aUnNumeroFacil(_ entrada: Double, _ esperado: Double) {
        #expect(L.redondeado(entrada) == esperado)
    }

    @Test func sugerencias_loMismo_10y20MenosRedondeados() {
        let s = L.sugerencias(gastadoAnterior: 1_000)
        #expect(s.map(\.0) == [.igual, .menos10, .menos20])
        #expect(s.map(\.1) == [1_000, 900, 800])
    }

    @Test func sugerencias_sinRepetidos_ySinGasto_ninguna() {
        // 12 → 20, 10.8 → 20, 9.6 → 10: el segundo repite el primero y se cae.
        #expect(L.sugerencias(gastadoAnterior: 12).map(\.1) == [20, 10])
        #expect(L.sugerencias(gastadoAnterior: 0).isEmpty)
    }

    @Test func periodoAnterior_unoAtrasDelMismoTipo() {
        let c = Self.calendar
        let hoy = Self.dia(18)
        #expect(L.fechaDelPeriodoAnterior(.monthly, ahora: hoy, calendar: c) == Self.dia(18, 10))
        #expect(L.fechaDelPeriodoAnterior(.weekly, ahora: hoy, calendar: c) == Self.dia(11))
        #expect(L.fechaDelPeriodoAnterior(.yearly, ahora: hoy, calendar: c)
                == c.date(from: DateComponents(year: 2025, month: 11, day: 18, hour: 12)))
        #expect(L.fechaDelPeriodoAnterior(.unique, ahora: hoy, calendar: c) == nil)
    }

    @Test func nombre_todosSigueAlPeriodo_categoriasComoPrimerosPasos() {
        let unidas: (String, String) -> String = { "\($0) y \($1)" }
        #expect(L.nombreSugerido(alcance: .all, periodo: .weekly, categorias: ["X"], todos: "Mis gastos de la semana",
                                 unidas: unidas, porDefecto: "Mi presupuesto") == "Mis gastos de la semana")
        #expect(L.nombreSugerido(alcance: .categories, periodo: .monthly, categorias: ["Comida"], todos: "T",
                                 unidas: unidas, porDefecto: "Mi presupuesto") == "Comida")
        #expect(L.nombreSugerido(alcance: .categories, periodo: .monthly, categorias: ["Comida", "Ocio", "Casa"],
                                 todos: "T", unidas: unidas, porDefecto: "Mi presupuesto") == "Comida y Ocio")
        #expect(L.nombreSugerido(alcance: .categories, periodo: .monthly, categorias: [], todos: "T",
                                 unidas: unidas, porDefecto: "Mi presupuesto") == "Mi presupuesto")
    }

    // MARK: Al formulario

    @Test func alFormulario_pasaTodoLoRespondido() {
        let c = Self.calendar
        let subs = [UUID(), UUID()]
        let r = L.Respuestas(alcance: .categories, categoriasElegidas: 1, periodo: .unique,
                             inicio: Self.dia(20, hora: 15), fin: Self.dia(30, hora: 8), tope: 800,
                             nombre: "  Viaje  ")
        let p = L.alFormulario(r, subcategorias: subs, aviso: .at75And100, calendar: c)
        #expect(p.name == "Viaje")
        #expect(p.limit == 800)
        #expect(p.periodType == .unique)
        #expect(p.startDate == c.startOfDay(for: Self.dia(20)))
        #expect(p.endDate == c.startOfDay(for: Self.dia(30)))
        #expect(p.subcategoryIDs == subs)
        #expect(p.alertThresholds == [75, 100])
    }

    /// Con «Todos mis gastos» no viaja ninguna subcategoría (aunque se hubieran tocado antes), y sin aviso no hay umbrales.
    @Test func alFormulario_todosMisGastos_sinSubcategorias_sinAviso() {
        let r = L.Respuestas(alcance: .all, categoriasElegidas: 2, tope: nil)
        let p = L.alFormulario(r, subcategorias: [UUID()], aviso: .none, calendar: Self.calendar)
        #expect(p.subcategoryIDs.isEmpty)
        #expect(p.alertThresholds.isEmpty)
        #expect(p.limit == nil, "Un tope sin contestar no pasa como 0.")
    }
}

// MARK: - Lo respondido, en quien presenta

@Suite("Asistente de presupuesto · el estado y «Usar formulario»")
@MainActor
struct AsistentePresupuestoEstadoTests {

    @Test func empezar_dejaTodoComoNuevo_conElTipoDeLaPestana() {
        let estado = AsistentePresupuestoEstado()
        estado.alcance = .categories
        estado.topeTexto = "500"
        estado.navegador.avanzar(en: estado.pasos)
        estado.usarFormulario(subcategorias: [])
        estado.empezar(periodo: .yearly)
        #expect(estado.modo == .asistente)
        #expect(estado.alcance == .all)
        #expect(estado.periodo == .yearly)
        #expect(estado.topeTexto.isEmpty)
        #expect(!estado.navegador.tieneRespuestas)
        #expect(estado.aviso == FirstBudgetFlowLogic.proposedAlert)
        #expect(estado.fin > estado.inicio)
    }

    @Test func usarFormulario_sinRespuestas_abreElFormularioVacio() {
        let estado = AsistentePresupuestoEstado()
        estado.empezar(periodo: .monthly)
        estado.usarFormulario(subcategorias: [])
        #expect(estado.modo == .formulario(nil))
    }

    @Test func usarFormulario_conRespuestas_llevaLoRespondido_inclusoLoDeLaPreguntaActual() {
        let estado = AsistentePresupuestoEstado()
        estado.empezar(periodo: .monthly)
        estado.navegador.avanzar(en: estado.pasos)          // ¿Qué gastos cuenta? → ¿Cada cuánto?
        estado.periodo = .weekly
        estado.navegador.avanzar(en: estado.pasos)          // → ¿Cuánto como máximo?
        estado.topeTexto = "300"                            // escrito, sin tocar «Siguiente»
        estado.usarFormulario(subcategorias: [])
        guard case .formulario(let prefill?) = estado.modo else {
            Issue.record("«Usar formulario» no llevó lo respondido: \(estado.modo)")
            return
        }
        #expect(prefill.periodType == .weekly)
        #expect(prefill.limit == 300)
        #expect(prefill.alertThresholds == [75, 100], "El aviso sugerido viaja también.")
    }
}

// MARK: - Textos

@Suite("Asistente de presupuesto · los textos en los 16 idiomas")
struct AsistentePresupuestoStringsTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/AsistentePresupuesto.strings")
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
        #expect(try Self.table("es-AR")["asistente.changeHint"]?.contains("Tocá") == true)
        #expect(try Self.table("pt-PT")["asistente.changeHint"]?.contains("Toca para alterar") == true)
    }

    /// El botón de arriba es corto y dice la acción; el de abajo nunca es solo «Crear».
    @Test func elEspanol_diceLoQueSePidio() throws {
        let es = try Self.table("es")
        #expect(es["asistente.useForm"] == "Usar formulario")
        #expect(es["asistentePresupuesto.create"] == "Crear presupuesto")
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = AsistenteCreacionTexto.string("asistente.useForm", resolution: resolution)
        #expect(texto == (try Self.table(locale)["asistente.useForm"]))
    }

    @Test func unaClaveQueFalta_vuelveCruda() {
        #expect(AsistenteCreacionTexto.string("asistente.no.existe") == "asistente.no.existe")
    }
}
