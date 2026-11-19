//
//  AsistenteFavoritoTests.swift
//  YalaTests
//
//  «Nuevo favorito» por pasos (encargo del 17-nov): qué preguntas tocan con el tipo, cuándo se sigue, lo sugerido, el
//  navegador compartido con estas preguntas (Atrás, cambiar de tipo y volver al resumen), lo que pasa al formulario
//  con «Usar formulario», el estado que vive en quien presenta la hoja, y sus textos en los 16 idiomas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Reglas

@MainActor
@Suite("Asistente de favorito · las reglas")
struct AsistenteFavoritoLogicaTests {
    typealias Logica = AsistenteFavoritoLogica
    typealias R = Logica.Respuestas<Int>

    private func respuestas(_ cambios: (inout R) -> Void = { _ in }) -> R {
        var r = R(tipo: .expense, nombre: "Café", montoTexto: "", origen: 1, destino: nil)
        cambios(&r)
        return r
    }

    @Test func gastoEIngreso_preguntanCategoria_sinDestino() {
        #expect(Logica.pasos(tipo: .expense, tiposDisponibles: 3) == [.tipo, .categoria, .nombre, .monto, .cuenta, .resumen])
        #expect(Logica.pasos(tipo: .income, tiposDisponibles: 3) == [.tipo, .categoria, .nombre, .monto, .cuenta, .resumen])
    }

    @Test func transferencia_preguntaOrigenYDestino_sinCategoria() {
        #expect(Logica.pasos(tipo: .transfer, tiposDisponibles: 3) == [.tipo, .nombre, .monto, .cuenta, .destino, .resumen])
    }

    @Test func soloGastos_noPreguntaElTipo() {
        #expect(Logica.pasos(tipo: .expense, tiposDisponibles: 1) == [.categoria, .nombre, .monto, .cuenta, .resumen])
    }

    @Test func tipoCategoriaYCuenta_siempreDejanSeguir() {
        let vacio = respuestas { $0.nombre = ""; $0.origen = nil }
        #expect(Logica.puedeSeguir(en: .tipo, vacio))
        #expect(Logica.puedeSeguir(en: .categoria, vacio))
        #expect(Logica.puedeSeguir(en: .cuenta, vacio))
    }

    @Test func nombre_noAdmiteSoloEspacios() {
        #expect(!Logica.puedeSeguir(en: .nombre, respuestas { $0.nombre = "   " }))
        #expect(Logica.puedeSeguir(en: .nombre, respuestas { $0.nombre = " Café " }))
    }

    /// Vacío vale (el favorito pide el monto al usarlo); escrito, mayor que cero.
    @Test func monto_vacioVale_ceroNo() {
        #expect(Logica.puedeSeguir(en: .monto, respuestas { $0.montoTexto = "" }))
        #expect(!Logica.puedeSeguir(en: .monto, respuestas { $0.montoTexto = "0" }))
        #expect(Logica.puedeSeguir(en: .monto, respuestas { $0.montoTexto = "8.50" }))
        #expect(Logica.monto("") == nil)
        #expect(Logica.monto("1,250.50") == 1250.5)
    }

    @Test func destino_noPuedeSerElOrigen() {
        #expect(!Logica.puedeSeguir(en: .destino, respuestas { $0.tipo = .transfer; $0.destino = 1 }))
        #expect(Logica.puedeSeguir(en: .destino, respuestas { $0.tipo = .transfer; $0.destino = 2 }))
        #expect(Logica.puedeSeguir(en: .destino, respuestas { $0.tipo = .transfer; $0.destino = nil }))
    }

    @Test func resumen_vuelveAMirarLoObligatorio() {
        #expect(Logica.puedeSeguir(en: .resumen, respuestas()))
        #expect(!Logica.puedeSeguir(en: .resumen, respuestas { $0.nombre = "" }))
        #expect(!Logica.puedeSeguir(en: .resumen, respuestas { $0.montoTexto = "0" }))
        #expect(!Logica.puedeSeguir(en: .resumen, respuestas { $0.tipo = .transfer; $0.destino = 1 }))
    }

    @Test func nombrePropuesto_sigueALaCategoria() {
        #expect(Logica.nombrePropuesto(tipo: .expense, categoria: "Restaurantes", transferencia: "Transferencia")
                == "Restaurantes")
        #expect(Logica.nombrePropuesto(tipo: .expense, categoria: nil, transferencia: "Transferencia").isEmpty)
        #expect(Logica.nombrePropuesto(tipo: .transfer, categoria: "Restaurantes", transferencia: "Transferencia")
                == "Transferencia")
    }

    @Test func destinoSugerido_esLaPrimeraDistintaDelOrigen_yRespetaUnaElegida() {
        #expect(Logica.destinoSugerido(actual: nil, origen: 1, cuentas: [1, 2, 3]) == 2)
        #expect(Logica.destinoSugerido(actual: 3, origen: 1, cuentas: [1, 2, 3]) == 3)
        // Se cambió el origen a la que era el destino: el destino se mueve.
        #expect(Logica.destinoSugerido(actual: 2, origen: 2, cuentas: [1, 2, 3]) == 1)
        #expect(Logica.destinoSugerido(actual: nil, origen: 1, cuentas: [1]) == nil)
    }

    // MARK: Navegador con estas preguntas

    @Test func atras_yVolverAlResumen() {
        let pasos = Logica.pasos(tipo: .expense, tiposDisponibles: 3)
        var nav = AsistenteCreacionNavegador<Logica.Paso>(inicio: .tipo)
        for _ in 0..<5 { nav.avanzar(en: pasos) }
        #expect(nav.actual == .resumen)
        nav.cambiar(.nombre, desde: .resumen)
        #expect(nav.actual == .nombre)
        nav.avanzar(en: pasos)
        #expect(nav.actual == .resumen, "Cambiar una respuesta ya contestada vuelve al resumen.")
        nav.retroceder(en: pasos)
        #expect(nav.actual == .nombre)
    }

    /// Pasar a transferencia desde el resumen: el navegador compartido vuelve al resumen en cuanto la siguiente
    /// («¿Cómo lo llamamos?») ya está contestada, así que «¿A qué cuenta va?» no se pregunta. Por eso la vista pone el
    /// destino sugerido al entrar al resumen si nunca se respondió (`AsistenteFavoritoView.alEntrar`), y el resumen
    /// tiene su fila para cambiarlo.
    @Test func cambiarATransferencia_desdeElResumen_vuelveAlResumenSinElDestino() {
        let gasto = Logica.pasos(tipo: .expense, tiposDisponibles: 3)
        var nav = AsistenteCreacionNavegador<Logica.Paso>(inicio: .tipo)
        for _ in 0..<5 { nav.avanzar(en: gasto) }
        nav.cambiar(.tipo, desde: .resumen)
        let transferencia = Logica.pasos(tipo: .transfer, tiposDisponibles: 3)
        nav.avanzar(en: transferencia)
        #expect(nav.actual == .resumen)
        #expect(!nav.respondidos.contains(.destino))
    }

    /// Y al revés: de transferencia a gasto, la categoría va justo después del tipo y sí se pregunta.
    @Test func cambiarAGasto_desdeElResumen_preguntaLaCategoria() {
        let transferencia = Logica.pasos(tipo: .transfer, tiposDisponibles: 3)
        var nav = AsistenteCreacionNavegador<Logica.Paso>(inicio: .tipo)
        for _ in 0..<5 { nav.avanzar(en: transferencia) }
        #expect(nav.actual == .resumen)
        nav.cambiar(.tipo, desde: .resumen)
        nav.avanzar(en: Logica.pasos(tipo: .expense, tiposDisponibles: 3))
        #expect(nav.actual == .categoria)
    }

    // MARK: Al formulario

    @Test func alFormulario_pasaLoRespondido_yLimpiaLoQueNoCabeEnElTipo() {
        let gasto = Logica.alFormulario(tipo: .expense, nombre: " Café ", montoTexto: "8.50", subcategoria: nil,
                                        origen: nil, destino: nil)
        #expect(gasto == FavoriteWizardPrefill(type: .expense, name: "Café", amount: 8.5, subcategoryID: nil,
                                               accountID: nil, destinationAccountID: nil))
        let sinMonto = Logica.alFormulario(tipo: .income, nombre: "Sueldo", montoTexto: "", subcategoria: nil,
                                           origen: nil, destino: nil)
        #expect(sinMonto.amount == nil)
        #expect(sinMonto.type == .income)
    }
}

// MARK: - Con modelos (ids reales de SwiftData)

@MainActor
@Suite("Asistente de favorito · ids de categoría y cuentas al formulario", .serialized)
struct AsistenteFavoritoIdsTests {

    @Test func transferencia_noLlevaCategoria_yGastoNoLlevaDestino() throws {
        let context = try makeTestContext()
        let origen = Account(name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        let destino = Account(name: "Ahorros", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(origen)
        context.insert(destino)
        try context.save()
        let a = origen.persistentModelID
        let b = destino.persistentModelID

        let transferencia = AsistenteFavoritoLogica.alFormulario(
            tipo: .transfer, nombre: "Ahorro", montoTexto: "100", subcategoria: a, origen: a, destino: b)
        #expect(transferencia.subcategoryID == nil)
        #expect(transferencia.accountID == a)
        #expect(transferencia.destinationAccountID == b)

        let gasto = AsistenteFavoritoLogica.alFormulario(
            tipo: .expense, nombre: "Café", montoTexto: "", subcategoria: nil, origen: a, destino: b)
        #expect(gasto.destinationAccountID == nil)
        #expect(gasto.accountID == a)
    }
}

// MARK: - Estado

@MainActor
@Suite("Asistente de favorito · el estado y «Usar formulario»")
struct AsistenteFavoritoEstadoTests {
    private let todos: [TransactionType] = [.expense, .income, .transfer]

    @Test func empieza_enGasto_conElTipoComoPrimeraPregunta() {
        let estado = AsistenteFavoritoEstado()
        estado.empezar(tiposDisponibles: todos, cuentaSugerida: nil)
        #expect(estado.tipo == .expense)
        #expect(estado.navegador.actual == .tipo)
    }

    @Test func soloGastos_empiezaEnLaCategoria() {
        let estado = AsistenteFavoritoEstado()
        estado.empezar(tiposDisponibles: [.expense], cuentaSugerida: nil)
        #expect(estado.navegador.actual == .categoria)
        #expect(!estado.pasos.contains(.tipo))
    }

    @Test func usarFormulario_sinRespuestas_abreElFormularioVacio() {
        let estado = AsistenteFavoritoEstado()
        estado.empezar(tiposDisponibles: todos, cuentaSugerida: nil)
        estado.usarFormulario()
        #expect(estado.modo == .formulario(nil))
    }

    @Test func usarFormulario_conRespuestas_llevaLoRespondido() {
        let estado = AsistenteFavoritoEstado()
        estado.empezar(tiposDisponibles: todos, cuentaSugerida: nil)
        estado.elegirTipo(.income)
        estado.navegador.avanzar(en: estado.pasos)   // → categoría
        estado.navegador.avanzar(en: estado.pasos)   // → nombre
        estado.nombre = "Sueldo"
        estado.navegador.avanzar(en: estado.pasos)   // → monto
        estado.montoTexto = "3,000"
        estado.usarFormulario()
        guard case .formulario(let prefill?) = estado.modo else {
            Issue.record("«Usar formulario» con respuestas no pasó nada: \(estado.modo)")
            return
        }
        #expect(prefill.type == .income)
        #expect(prefill.name == "Sueldo")
        #expect(prefill.amount == 3000)
    }

    @Test func cambiarDeTipo_quitaLaCategoria_yElNombrePropuesto() {
        let estado = AsistenteFavoritoEstado()
        estado.empezar(tiposDisponibles: todos, cuentaSugerida: nil)
        estado.nombre = "Restaurantes"
        estado.elegirTipo(.transfer)
        #expect(estado.subcategoriaID == nil)
        #expect(estado.nombre.isEmpty, "El nombre propuesto no se escribió a mano: se va con el tipo.")
        estado.nombre = "Mío"
        estado.nombreEditado = true
        estado.elegirTipo(.expense)
        #expect(estado.nombre == "Mío", "Lo que escribió la persona se queda.")
    }

    /// El contenido de la hoja puede rehacerse sin cerrarla: prepararse otra vez no tira lo respondido. Al cerrarla, sí.
    @Test func prepararDosVeces_conservaLoRespondido_olvidarLoTira() {
        let estado = AsistenteFavoritoEstado()
        estado.prepararSiHaceFalta(tiposDisponibles: todos, cuentaSugerida: { nil })
        estado.nombre = "Café"
        estado.navegador.avanzar(en: estado.pasos)
        estado.prepararSiHaceFalta(tiposDisponibles: todos, cuentaSugerida: { nil })
        #expect(estado.nombre == "Café")
        #expect(estado.navegador.actual == .categoria)
        estado.olvidar()
        #expect(estado.nombre.isEmpty)
        #expect(estado.navegador.actual == .tipo)
        #expect(estado.modo == .asistente)
    }
}

// MARK: - Textos

@MainActor
@Suite("Asistente de favorito · los textos en los 16 idiomas")
struct AsistenteFavoritoStringsTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/AsistenteFavorito.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneCadaClave_conTexto(_ locale: String) throws {
        let referencia = try Self.table("es")
        let textos = try Self.table(locale)
        #expect(Set(textos.keys) == Set(referencia.keys), "\(locale): claves distintas de es.")
        for (clave, valor) in textos {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
            #expect(!valor.contains("%"), "\(locale): \(clave) no lleva huecos.")
        }
    }

    @Test func alias_copianSuReferencia() throws {
        #expect(try Self.table("es") == Self.table("es-419"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test func variantes_hablanASuManera() throws {
        #expect(try Self.table("es-AR")["asistenteFavorito.summary.detail"]?.contains("Tocá") == true)
        #expect(try Self.table("es-ES")["asistenteFavorito.summary.amount"] == "Importe")
        #expect(try Self.table("en-GB")["asistenteFavorito.create"] == "Create favourite")
        #expect(try Self.table("pt-PT")["asistenteFavorito.summary.detail"]?.contains("Toca numa") == true)
    }

    /// Cada clave que lee la app existe en español (una errata en el código devolvería la clave cruda).
    @Test func cadaClaveDelCodigo_existe() throws {
        typealias A = L10n.AsistenteFavorito
        let tipos: [TransactionType] = [.expense, .income, .transfer]
        let leidas = [
            A.descartarTitulo, A.crear, A.crearCorto, A.tipoPregunta, A.tipoDetalle, A.categoriaPregunta,
            A.categoriaDetalle, A.sinCategoria, A.sinCategoriaPista, A.otraCategoria, A.nombrePregunta, A.nombreDetalle,
            A.montoDetalle, A.cuentaDetalle, A.sinCuenta, A.sinCuentaPista, A.destinoPregunta, A.destinoDetalle,
            A.resumenPregunta, A.resumenDetalle, A.resumenTipo, A.resumenCategoria, A.resumenNombre, A.resumenMonto,
            A.resumenMontoVacio, A.resumenCuenta, A.resumenOrigen, A.resumenDestino,
        ] + tipos.flatMap { [A.tipoPista($0), A.montoPregunta($0), A.cuentaPregunta($0)] }
        for texto in leidas {
            #expect(!texto.hasPrefix("asistenteFavorito."), "Clave sin texto: \(texto)")
        }
        #expect(try Self.table("es").count == leidas.count)
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.AsistenteFavorito.string("asistenteFavorito.create", resolution: resolution)
        #expect(texto == (try Self.table(locale)["asistenteFavorito.create"]))
    }
}
