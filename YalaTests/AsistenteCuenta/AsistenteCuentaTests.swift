//
//  AsistenteCuentaTests.swift
//  YalaTests
//
//  «Nueva cuenta» por pasos (encargo del 18-nov): qué preguntas tocan con lo respondido, cuándo se sigue, el nombre que
//  no repite otra cuenta, lo que se guarda y lo que pasa al formulario con «Usar formulario». Y sus textos, en los 16
//  idiomas.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Lógica

@Suite("Asistente de cuenta · las reglas")
struct AsistenteCuentaLogicaTests {
    typealias L = AsistenteCuentaLogica

    @Test func sinTarjeta_soloCuatroPreguntasYElResumen() {
        #expect(L.pasos(tipo: .checking, diaDePago: nil) == [.tipo, .moneda, .nombre, .saldo, .resumen])
        #expect(L.pasos(tipo: .cash, diaDePago: 10) == [.tipo, .moneda, .nombre, .saldo, .resumen],
                "Un día de pago que quedó de antes no saca las preguntas de tarjeta.")
    }

    @Test func tarjeta_preguntaCierreYPago_yElRecordatorioSoloConDiaDePago() {
        #expect(L.pasos(tipo: .creditCard, diaDePago: nil)
                == [.tipo, .moneda, .nombre, .saldo, .cierre, .pago, .resumen])
        #expect(L.pasos(tipo: .creditCard, diaDePago: 5)
                == [.tipo, .moneda, .nombre, .saldo, .cierre, .pago, .recordatorio, .resumen])
    }

    @Test func llegaConElTipoSugerido_yAvanzaSinTocarNada() {
        let r = L.Respuestas(nombre: "Cuenta corriente")
        #expect(r.tipo == L.tipoSugerido)
        for paso in [L.Paso.tipo, .moneda, .saldo, .cierre, .pago, .recordatorio] {
            #expect(L.puedeSeguir(en: paso, r, nombresExistentes: []), "«Siguiente» apagado en \(paso).")
        }
    }

    @Test func nombre_vacioORepetido_noDejaSeguir_sinMirarMayusculas() {
        let existentes = ["Cuenta Principal", "  Ahorros USD "]
        var r = L.Respuestas(nombre: "   ")
        #expect(!L.puedeSeguir(en: .nombre, r, nombresExistentes: existentes))
        r.nombre = "cuenta principal"
        #expect(!L.puedeSeguir(en: .nombre, r, nombresExistentes: existentes))
        r.nombre = "ahorros usd"
        #expect(!L.puedeSeguir(en: .nombre, r, nombresExistentes: existentes), "Los espacios del guardado no cuentan.")
        r.nombre = "BCP sueldo"
        #expect(L.puedeSeguir(en: .nombre, r, nombresExistentes: existentes))
    }

    @Test func nombreLibre_numeraSiYaExiste() {
        #expect(L.nombreLibre("Efectivo", existentes: []) == "Efectivo")
        #expect(L.nombreLibre("Efectivo", existentes: ["efectivo"]) == "Efectivo 2")
        #expect(L.nombreLibre("Efectivo", existentes: ["Efectivo", "Efectivo 2"]) == "Efectivo 3")
    }

    @Test func saldo_illegible_noDejaSeguirNiCrear() {
        let r = L.Respuestas(nombre: "Caja", saldo: nil)
        #expect(!L.puedeSeguir(en: .saldo, r, nombresExistentes: []))
        #expect(!L.puedeSeguir(en: .resumen, r, nombresExistentes: []))
    }

    @Test func resumen_exigeTodoLoObligatorio() {
        var r = L.Respuestas(nombre: "Caja", saldo: 0)
        #expect(L.puedeSeguir(en: .resumen, r, nombresExistentes: []))
        r.nombre = ""
        #expect(!L.puedeSeguir(en: .resumen, r, nombresExistentes: []), "Un nombre vaciado al volver atrás no crea.")
    }

    @Test func saldoGuardado_enTarjetaEsDeuda_enLasDemasLleVaElSigno() {
        #expect(L.saldoGuardado(.init(tipo: .creditCard, saldo: 300, saldoNegativo: false)) == -300)
        #expect(L.saldoGuardado(.init(tipo: .creditCard, saldo: 300, saldoNegativo: true)) == -300)
        #expect(L.saldoGuardado(.init(tipo: .checking, saldo: 300, saldoNegativo: false)) == 300)
        #expect(L.saldoGuardado(.init(tipo: .checking, saldo: 300, saldoNegativo: true)) == -300)
        #expect(L.saldoGuardado(.init(tipo: .cash, saldo: nil)) == 0)
    }

    @Test func recordatorio_sugeridoUnDiaAntes_oElMismoDiaSinCierre() {
        #expect(L.recordatorioSugerido(diaDeCierre: 20) == 1)
        #expect(L.recordatorioSugerido(diaDeCierre: nil) == 0)
        #expect(L.opcionesDeRecordatorio(diaDeCierre: nil) == [0])
    }

    @Test func opcionesDeMoneda_principalPrimero_sinRepetir_yLaElegidaAlFinal() {
        #expect(L.opcionesDeMoneda(principal: "PEN", secundarias: ["usd", "PEN"], elegida: "PEN") == ["PEN", "USD"])
        #expect(L.opcionesDeMoneda(principal: "PEN", secundarias: ["USD"], elegida: "eur") == ["PEN", "USD", "EUR"])
    }

    // MARK: Al formulario

    @Test func alFormulario_llevaTipoMonedaNombreYSaldoConSigno() {
        let r = L.Respuestas(tipo: .savings, moneda: "usd", nombre: "  Viaje  ", saldo: 1_500, saldoNegativo: false)
        let p = L.alFormulario(r, saldoRespondido: true)
        #expect(p.kind == .savings)
        #expect(p.currencyCode == "USD")
        #expect(p.name == "Viaje")
        #expect(p.balanceMagnitude == 1_500)
        #expect(!p.balanceIsNegative)
        #expect(p.statementDay == nil && p.paymentDay == nil && p.reminderDaysBefore == nil,
                "Los días de tarjeta no viajan en otra cuenta.")
    }

    @Test func alFormulario_tarjeta_laDeudaVaComoConsumido_yLosDias() {
        let r = L.Respuestas(tipo: .creditCard, nombre: "Visa", saldo: 420, diaDeCierre: 20, diaDePago: 5,
                             recordatorio: 3)
        let p = L.alFormulario(r, saldoRespondido: true)
        #expect(p.balanceIsNegative, "En el formulario la deuda de tarjeta es «Consumido».")
        #expect(p.statementDay == 20)
        #expect(p.paymentDay == 5)
        #expect(p.reminderDaysBefore == 3)
    }

    @Test func alFormulario_sinDiaDePago_noLlevaRecordatorio() {
        let r = L.Respuestas(tipo: .creditCard, nombre: "Visa", saldo: 0, diaDeCierre: 20, diaDePago: nil,
                             recordatorio: 1)
        #expect(L.alFormulario(r, saldoRespondido: true).reminderDaysBefore == nil)
    }

    @Test func alFormulario_saldoSinContestar_noSePasa() {
        let r = L.Respuestas(nombre: "Caja", saldo: 0)
        #expect(L.alFormulario(r, saldoRespondido: false).balanceMagnitude == nil,
                "El formulario tiene que seguir pidiendo el saldo si no se contestó.")
        #expect(L.alFormulario(r, saldoRespondido: true).balanceMagnitude == 0)
    }
}

// MARK: - Lo que se guarda

@Suite("Asistente de cuenta · el borrador que guarda Primeros pasos")
@MainActor
struct AsistenteCuentaBorradorTests {
    typealias L = AsistenteCuentaLogica

    @Test func unaSolaMoneda_ySinSaldoNoHayFilaDeSaldo() {
        let d = L.borrador(.init(tipo: .cash, moneda: "pen", nombre: " Caja ", saldo: 0))
        #expect(d.kind == .cash)
        #expect(d.currencies == ["PEN"])
        #expect(d.name == "Caja")
        #expect(d.balances.isEmpty)
        #expect(d.statementDay == nil && d.paymentDay == nil && d.reminderLead == nil)
    }

    @Test func tarjeta_diasQueNoSeSabenVanComoNoLoSe_yElRecordatorioSoloConPago() {
        let sinPago = L.borrador(.init(tipo: .creditCard, moneda: "USD", nombre: "Visa", saldo: 100,
                                       diaDeCierre: nil, diaDePago: nil, recordatorio: 1))
        #expect(sinPago.balances == ["USD": -100])
        #expect(sinPago.statementDay == .unknown)
        #expect(sinPago.paymentDay == .unknown)
        #expect(sinPago.reminderLead == nil)

        let conPago = L.borrador(.init(tipo: .creditCard, moneda: "USD", nombre: "Visa", saldo: 0,
                                       diaDeCierre: 20, diaDePago: 5, recordatorio: 3))
        #expect(conPago.statementDay == .day(20))
        #expect(conPago.paymentDay == .day(5))
        #expect(conPago.reminderLead == 3)
        #expect(FirstAccountFlowLogic.storedReminder(
            lead: conPago.reminderLead, paymentDay: conPago.paymentDay, statementDay: conPago.statementDay) == 3)
    }
}

// MARK: - Lo respondido, en quien presenta

@Suite("Asistente de cuenta · el estado y «Usar formulario»")
@MainActor
struct AsistenteCuentaEstadoTests {

    @Test func empezar_dejaTodoComoNuevo_conLaMonedaPrincipal() {
        let estado = AsistenteCuentaEstado()
        estado.tipo = .creditCard
        estado.saldoTexto = "500"
        estado.diaDePago = 5
        estado.navegador.avanzar(en: estado.pasos)
        estado.usarFormulario()
        estado.empezar(monedaPrincipal: "pen", nombresExistentes: ["Caja"])
        #expect(estado.modo == .asistente)
        #expect(estado.empezado)
        #expect(estado.tipo == AsistenteCuentaLogica.tipoSugerido)
        #expect(estado.moneda == "PEN")
        #expect(estado.saldoTexto.isEmpty)
        #expect(estado.diaDePago == nil)
        #expect(!estado.navegador.tieneRespuestas)
        #expect(estado.nombresExistentes == ["Caja"])
    }

    @Test func terminar_tiraLoRespondido_yLaProximaVezEmpiezaDeNuevo() {
        let estado = AsistenteCuentaEstado()
        estado.empezar(monedaPrincipal: "USD", nombresExistentes: [])
        estado.nombre = "Algo"
        estado.navegador.avanzar(en: estado.pasos)
        estado.terminar()
        #expect(!estado.empezado)
        #expect(estado.nombre.isEmpty)
        #expect(!estado.navegador.tieneRespuestas)
    }

    @Test func saldo_vacioEsCero_yLoQueNoEsNumeroNoSeLee() {
        let estado = AsistenteCuentaEstado()
        #expect(estado.saldo == 0)
        estado.saldoTexto = "1,250.50"
        #expect((estado.saldo ?? 0) > 1_000)
        estado.saldoTexto = "."
        #expect(estado.saldo == nil)
    }

    @Test func usarFormulario_sinRespuestas_abreElFormularioVacio() {
        let estado = AsistenteCuentaEstado()
        estado.empezar(monedaPrincipal: "PEN", nombresExistentes: [])
        estado.tipo = .cash
        estado.usarFormulario()
        #expect(estado.modo == .formulario(nil))
    }

    @Test func usarFormulario_conRespuestas_llevaLoRespondido_inclusoLoDeLaPreguntaActual() {
        let estado = AsistenteCuentaEstado()
        estado.empezar(monedaPrincipal: "PEN", nombresExistentes: [])
        estado.tipo = .savings
        estado.navegador.avanzar(en: estado.pasos)          // → ¿En qué moneda?
        estado.moneda = "USD"
        estado.navegador.avanzar(en: estado.pasos)          // → ¿Cómo la llamamos?
        estado.nombre = "Viaje"
        estado.navegador.avanzar(en: estado.pasos)          // → ¿Cuánto tienes hoy?
        estado.saldoTexto = "800"                           // escrito, sin tocar «Siguiente»
        estado.usarFormulario()
        guard case .formulario(let prefill?) = estado.modo else {
            Issue.record("«Usar formulario» no llevó lo respondido: \(estado.modo)")
            return
        }
        #expect(prefill.kind == .savings)
        #expect(prefill.currencyCode == "USD")
        #expect(prefill.name == "Viaje")
        #expect(prefill.balanceMagnitude == 800)
    }

    @Test func diaDeCierreQuitado_elRecordatorioPasaAlMismoDia() {
        let estado = AsistenteCuentaEstado()
        estado.empezar(monedaPrincipal: "PEN", nombresExistentes: [])
        estado.recordatorio = 3
        estado.diaDeCierre = nil
        estado.ajustarRecordatorio()
        #expect(estado.recordatorio == 0, "Sin cierre solo queda «el mismo día».")
    }
}

// MARK: - Textos

@Suite("Asistente de cuenta · los textos en los 16 idiomas")
struct AsistenteCuentaStringsTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/AsistenteCuenta.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneLasMismasClavesQueEs419_yNingunaVacia(locale: String) throws {
        let referencia = try Self.table("es-419")
        let tabla = try Self.table(locale)
        #expect(Set(tabla.keys) == Set(referencia.keys), "\(locale) no tiene las mismas claves que es-419.")
        for (clave, valor) in tabla {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
        }
    }

    @Test func esYPt_sonCopiaDeSuReferencia() throws {
        #expect(try Self.table("es") == Self.table("es-419"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test(arguments: locales)
    func elDiaLlevaSuNumero(locale: String) throws {
        let dia = try #require(try Self.table(locale)["asistenteCuenta.summary.day"])
        #expect(dia.contains("%d"), "\(locale): «Día %d» sin el número.")
    }

    /// Los textos del asistente van en su tabla, nunca en `Localizable.strings` (encargo).
    @Test func ningunTextoDelAsistente_enLocalizable() throws {
        let repoRoot = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/es-419.lproj/Localizable.strings")
        let texto = try String(contentsOf: url, encoding: .utf8)
        #expect(!texto.contains("\"asistenteCuenta."))
    }
}

// MARK: - El recordatorio sugerido y el nombre de la moneda

@Suite("Asistente de cuenta · recordatorio y moneda")
@MainActor
struct AsistenteCuentaRecordatorioTests {

    /// La primera vez que se llega al recordatorio, el sugerido sale del día de cierre que se acaba de contestar: con
    /// cierre, un día antes (al empezar, sin cierre, el sugerido era «el mismo día»).
    @Test func primeraVez_unDiaAntesConCierre() {
        let estado = AsistenteCuentaEstado()
        estado.empezar(monedaPrincipal: "PEN", nombresExistentes: [])
        estado.diaDeCierre = 20
        estado.prepararRecordatorio()
        #expect(estado.recordatorio == 1)
    }

    @Test func yaContestado_respetaLoElegido() {
        let estado = AsistenteCuentaEstado()
        estado.empezar(monedaPrincipal: "PEN", nombresExistentes: [])
        estado.tipo = .creditCard
        estado.diaDeCierre = 20
        estado.diaDePago = 5
        while estado.navegador.actual != .recordatorio { estado.navegador.avanzar(en: estado.pasos) }
        estado.recordatorio = nil                       // «No me lo recuerdes»
        estado.navegador.avanzar(en: estado.pasos)      // → resumen
        estado.navegador.cambiar(.recordatorio, desde: .resumen)
        estado.prepararRecordatorio()
        #expect(estado.recordatorio == nil, "Volver a la pregunta no puede cambiar lo que se eligió.")
    }

    @Test func nombreMoneda_conMayusculaInicial() {
        let nombre = AsistenteCuentaView.nombreMoneda("PEN")
        #expect(nombre.first?.isUppercase == true, "«\(nombre)»")
        #expect(AsistenteCuentaView.nombreMoneda("ZZZ") == "ZZZ")
    }
}
