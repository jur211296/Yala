//
//  AsistentePagoPlanificadoTests.swift
//  YalaTests
//
//  «Nuevo pago planificado» por pasos (encargo del 17-nov): las preguntas y cuándo se sigue, lo sugerido, el navegador
//  compartido con estas preguntas (Atrás y volver al resumen), lo que pasa al formulario con «Usar formulario», el
//  estado que vive en quien presenta la hoja, y sus textos en los 16 idiomas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Reglas

@MainActor
@Suite("Asistente de pago planificado · las reglas")
struct AsistentePagoPlanificadoLogicaTests {
    typealias Logica = AsistentePagoPlanificadoLogica

    /// Un miércoles a media mañana, el 18 de noviembre de 2026.
    private static let hoy: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 18; c.hour = 10
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantPast
    }()
    private let calendar = Calendar(identifier: .gregorian)

    private func respuestas(_ cambios: (inout Logica.Respuestas) -> Void = { _ in }) -> Logica.Respuestas {
        var r = Logica.Respuestas(tieneTipo: true, nombre: "Luz", monto: 80, frecuencia: .monthly, diaDelMes: 18,
                                  fecha: Self.hoy)
        cambios(&r)
        return r
    }

    private func puede(_ paso: Logica.Paso, _ r: Logica.Respuestas) -> Bool {
        Logica.puedeSeguir(en: paso, r, hoy: Self.hoy, calendar: calendar)
    }

    /// Sin grupos: ocho preguntas, con «¿Algo más?» antes del resumen (21-nov). Las de lo compartido, en
    /// `AsistentePagoCompartidoTests`.
    @Test func ochoPreguntasSinGrupos_enOrden_terminandoEnElResumen() {
        #expect(Logica.pasos == [.tipo, .nombre, .monto, .frecuencia, .dia, .aviso, .algoMas, .resumen])
    }

    @Test func tipo_pideElegirUno_noLlegaElegido() {
        #expect(!puede(.tipo, respuestas { $0.tieneTipo = false }))
        #expect(puede(.tipo, respuestas()))
    }

    @Test func nombre_noAdmiteSoloEspacios() {
        #expect(!puede(.nombre, respuestas { $0.nombre = "   " }))
        #expect(puede(.nombre, respuestas { $0.nombre = " Luz " }))
    }

    @Test func monto_pideUnNumeroMayorQueCero() {
        #expect(!puede(.monto, respuestas { $0.monto = nil }))
        #expect(!puede(.monto, respuestas { $0.monto = 0 }))
        #expect(puede(.monto, respuestas { $0.monto = 0.5 }))
    }

    @Test func lasDeOpcion_siempreDejanSeguir() {
        #expect(puede(.frecuencia, respuestas()))
        #expect(puede(.aviso, respuestas()))
    }

    @Test func dia_unaVez_deHoyEnAdelante_elAnio_cualquiera() throws {
        let ayer = try #require(calendar.date(byAdding: .day, value: -1, to: Self.hoy))
        #expect(!puede(.dia, respuestas { $0.frecuencia = .once; $0.fecha = ayer }))
        #expect(puede(.dia, respuestas { $0.frecuencia = .once; $0.fecha = calendar.startOfDay(for: Self.hoy) }))
        #expect(puede(.dia, respuestas { $0.frecuencia = .yearly; $0.fecha = ayer }))
        #expect(puede(.dia, respuestas { $0.frecuencia = .weekly }))
        #expect(!puede(.dia, respuestas { $0.diaDelMes = 32 }))
    }

    @Test func resumen_exigeTodoLoObligatorio() {
        #expect(puede(.resumen, respuestas()))
        #expect(!puede(.resumen, respuestas { $0.tieneTipo = false }))
        #expect(!puede(.resumen, respuestas { $0.nombre = "" }))
        #expect(!puede(.resumen, respuestas { $0.monto = nil }))
    }

    @Test func diasDelMes_losAtajos_masElDeHoy_sinRepetir() throws {
        #expect(Logica.diasDelMes(hoy: Self.hoy, calendar: calendar) == [1, 5, 10, 15, 18, 20, 30])
        let quince = try #require(calendar.date(byAdding: .day, value: -3, to: Self.hoy))
        #expect(Logica.diasDelMes(hoy: quince, calendar: calendar) == [1, 5, 10, 15, 20, 30])
    }

    @Test func loSugerido_hoyMensual_avisoTresDiasAntes_sinTipoNiMonto() {
        let draft = Logica.borradorInicial(esSuscripcion: false, hoy: Self.hoy, calendar: calendar)
        #expect(draft.frequency == .monthly)
        #expect(draft.dayOfMonth == 18)
        #expect(draft.weekday == 4)
        #expect(draft.date == calendar.startOfDay(for: Self.hoy))
        #expect(draft.reminder == .threeDaysBefore)
        #expect(draft.kind == nil)
        #expect(draft.subcategoryID == nil)
        #expect(draft.amount == nil)
        #expect(!draft.isSubscription)
        #expect(Logica.borradorInicial(esSuscripcion: true, hoy: Self.hoy, calendar: calendar).isSubscription)
    }
}

// MARK: - Navegador con estas preguntas

@MainActor
@Suite("Asistente de pago planificado · Atrás y volver al resumen")
struct AsistentePagoPlanificadoNavegadorTests {
    typealias Navegador = AsistenteCreacionNavegador<AsistentePagoPlanificadoLogica.Paso>
    private let pasos = AsistentePagoPlanificadoLogica.pasos

    @Test func recorrido_progresoYAtras() {
        var nav = Navegador(inicio: .tipo)
        #expect(nav.indice(en: pasos) == 0)
        while nav.avanzar(en: pasos) {}
        #expect(nav.actual == .resumen)
        #expect(nav.indice(en: pasos) == 7)
        nav.retroceder(en: pasos)
        #expect(nav.actual == .algoMas)
    }

    @Test func cambiarElMontoDesdeElResumen_siguienteVuelveAlResumen() {
        var nav = Navegador(inicio: .tipo)
        while nav.avanzar(en: pasos) {}
        nav.cambiar(.monto, desde: .resumen)
        #expect(nav.actual == .monto)
        nav.avanzar(en: pasos)
        #expect(nav.actual == .resumen)
    }
}

// MARK: - Al formulario

@MainActor
@Suite("Asistente de pago planificado · lo que pasa al formulario")
struct AsistentePagoPlanificadoFormularioTests {
    typealias Logica = AsistentePagoPlanificadoLogica

    private static let hoy: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 18; c.hour = 10
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantPast
    }()

    @Test func pasaTodoLoRespondido() {
        var draft = Logica.borradorInicial(esSuscripcion: false, hoy: Self.hoy)
        draft.name = "  Luz del Sur "
        draft.isVariableAmount = true
        draft.isSubscription = true
        draft.frequency = .weekly
        draft.weekday = 6
        draft.reminder = .oneDayBefore
        let prefill = Logica.alFormulario(draft, monto: 85.5, respondidos: Set(Logica.pasos))
        #expect(prefill.name == "Luz del Sur")
        #expect(prefill.amount == 85.5)
        #expect(prefill.isVariableAmount)
        #expect(prefill.isSubscription)
        #expect(prefill.isRecurring)
        #expect(prefill.recurrenceType == .weekly)
        #expect(prefill.weekday == 6)
        #expect(prefill.notifyOnDueDate == false)
        #expect(prefill.notifyDaysBefore == 1)
    }

    @Test func unaVez_noSeRepite_yLlevaSuFecha() {
        var draft = Logica.borradorInicial(esSuscripcion: false, hoy: Self.hoy)
        draft.frequency = .once
        let prefill = Logica.alFormulario(draft, monto: 10, respondidos: [.tipo, .frecuencia])
        #expect(!prefill.isRecurring)
        #expect(prefill.date == Calendar.current.startOfDay(for: draft.date))
    }

    /// El aviso del formulario se queda con el suyo si no se llegó a contestar en el asistente; un monto vacío o en cero
    /// no se pasa.
    @Test func loNoContestado_noSePasa() {
        let draft = Logica.borradorInicial(esSuscripcion: false, hoy: Self.hoy)
        let prefill = Logica.alFormulario(draft, monto: nil, respondidos: [.tipo])
        #expect(prefill.amount == nil)
        #expect(prefill.notifyOnDueDate == nil)
        #expect(prefill.notifyDaysBefore == nil)
        #expect(Logica.alFormulario(draft, monto: 0, respondidos: [.tipo]).amount == nil)
    }

    @Test func sinAvisoContestado_seApagaEnElFormulario() {
        var draft = Logica.borradorInicial(esSuscripcion: false, hoy: Self.hoy)
        draft.reminder = FirstScheduledPaymentFlowLogic.Reminder.none
        let prefill = Logica.alFormulario(draft, monto: 10, respondidos: [.aviso])
        #expect(prefill.notifyOnDueDate == false)
        #expect(prefill.notifyDaysBefore == 0)
    }
}

// MARK: - Estado

@MainActor
@Suite("Asistente de pago planificado · el estado y «Usar formulario»")
struct AsistentePagoPlanificadoEstadoTests {

    @Test func usarFormulario_sinRespuestas_abreElFormularioVacio() {
        let estado = AsistentePagoPlanificadoEstado()
        estado.empezar(esSuscripcion: false)
        estado.usarFormulario()
        #expect(estado.modo == .formulario(nil))
    }

    @Test func usarFormulario_conRespuestas_llevaLoDeLaPreguntaActual() {
        let estado = AsistentePagoPlanificadoEstado()
        estado.empezar(esSuscripcion: false)
        estado.draft.name = "Gimnasio"
        estado.navegador.avanzar(en: AsistentePagoPlanificadoLogica.pasos)   // → nombre
        estado.navegador.avanzar(en: AsistentePagoPlanificadoLogica.pasos)   // → monto
        estado.montoTexto = "1,250.50"
        estado.usarFormulario()
        guard case .formulario(let prefill?) = estado.modo else {
            Issue.record("«Usar formulario» con respuestas no pasó nada: \(estado.modo)")
            return
        }
        #expect(prefill.name == "Gimnasio")
        #expect(prefill.amount == 1250.5)
        #expect(prefill.notifyDaysBefore == nil, "El aviso aún no se preguntó.")
    }

    @Test func monto_seLeeConSeparadores_yCeroNoVale() {
        let estado = AsistentePagoPlanificadoEstado()
        estado.montoTexto = "0"
        #expect(estado.monto == nil)
        estado.montoTexto = "45.90"
        #expect(estado.monto == 45.9)
    }

    /// El contenido de la hoja puede rehacerse sin cerrarla: prepararse otra vez no tira lo respondido. Al cerrarla, sí.
    @Test func prepararDosVeces_conservaLoRespondido_olvidarLoTira() {
        let estado = AsistentePagoPlanificadoEstado()
        estado.prepararSiHaceFalta(esSuscripcion: true)
        #expect(estado.draft.isSubscription)
        estado.draft.name = "Netflix"
        estado.navegador.avanzar(en: AsistentePagoPlanificadoLogica.pasos)
        estado.prepararSiHaceFalta(esSuscripcion: false)
        #expect(estado.draft.name == "Netflix")
        #expect(estado.navegador.actual == .nombre)
        estado.olvidar()
        #expect(estado.draft.name.isEmpty)
        #expect(estado.navegador.actual == .tipo)
        #expect(estado.modo == .asistente)
        estado.prepararSiHaceFalta(esSuscripcion: true)
        #expect(estado.draft.isSubscription)
    }
}

// MARK: - Textos

@MainActor
@Suite("Asistente de pago planificado · los textos en los 16 idiomas")
struct AsistentePagoPlanificadoStringsTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/AsistentePagoPlanificado.strings")
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
        #expect(try Self.table("es-AR")["asistentePago.summary.detail"]?.contains("Tocá") == true)
        #expect(try Self.table("es-ES")["asistentePago.summary.amount"] == "Importe")
        #expect(try Self.table("pt-PT")["asistentePago.summary.detail"]?.contains("Toca numa") == true)
    }

    /// Cada clave que lee la app existe en español (una errata en el código devolvería la clave cruda).
    @Test func cadaClaveDelCodigo_existe() throws {
        let es = try Self.table("es")
        let leidas = [
            L10n.AsistentePagoPlanificado.descartarTitulo, L10n.AsistentePagoPlanificado.crear,
            L10n.AsistentePagoPlanificado.crearCorto, L10n.AsistentePagoPlanificado.nombrePregunta,
            L10n.AsistentePagoPlanificado.nombreDetalle, L10n.AsistentePagoPlanificado.montoPregunta,
            L10n.AsistentePagoPlanificado.montoDetalle, L10n.AsistentePagoPlanificado.frecuenciaPregunta,
            L10n.AsistentePagoPlanificado.frecuenciaDetalle, L10n.AsistentePagoPlanificado.diaDetalle,
            L10n.AsistentePagoPlanificado.otroDia, L10n.AsistentePagoPlanificado.resumenPregunta,
            L10n.AsistentePagoPlanificado.resumenDetalle, L10n.AsistentePagoPlanificado.resumenTipo,
            L10n.AsistentePagoPlanificado.resumenNombre, L10n.AsistentePagoPlanificado.resumenMonto,
            L10n.AsistentePagoPlanificado.resumenFrecuencia, L10n.AsistentePagoPlanificado.resumenCuando,
            L10n.AsistentePagoPlanificado.resumenAviso, L10n.AsistentePagoPlanificado.sinAviso,
        ] + FirstScheduledPaymentFlowLogic.Frequency.allCases.flatMap {
            [L10n.AsistentePagoPlanificado.frecuenciaPista($0), L10n.AsistentePagoPlanificado.diaPregunta($0)]
        }
        for texto in leidas {
            #expect(!texto.hasPrefix("asistentePago."), "Clave sin texto: \(texto)")
        }
        #expect(es.count == 56, "29 del 17-nov y 27 de lo compartido y «¿Algo más?» del 21-nov.")
    }

    @Test func elEspanol_diceLoQueSePidio() throws {
        let es = try Self.table("es")
        #expect(es["asistentePago.create"] == "Crear pago")
        #expect(es["asistentePago.discard.title"] == "¿Descartar este pago?")
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.AsistentePagoPlanificado.string("asistentePago.create", resolution: resolution)
        #expect(texto == (try Self.table(locale)["asistentePago.create"]))
    }
}
