//
//  HojaCuentaTarjetaLogicaTests.swift
//  YalaTests
//
//  La hoja de una cuenta con la tarjeta personalizada arriba (pedido de Jürgen del 17-nov-2026): tamaño de la tarjeta,
//  la barra de lo que debes, qué bloque lleva la tarjeta de crédito y la entrada animada. Y sus textos en los 16 idiomas,
//  y el cableado de la hoja (que usa las piezas nuevas y no toca las de las tarjetas).
//

import CoreGraphics
import Foundation
import Testing
@testable import Yala

@Suite("Hoja de cuenta · tarjeta · lógica")
struct HojaCuentaTarjetaLogicaTests {

    typealias L = HojaCuentaTarjetaLogica

    // MARK: Tamaño

    @Test func ancho_ocupaElHueco_hastaElTope() {
        #expect(L.anchoTarjeta(disponible: 250) == 250)
        #expect(L.anchoTarjeta(disponible: 900) == L.anchoMaximoTarjeta)
        #expect(L.anchoTarjeta(disponible: L.anchoMaximoTarjeta) == L.anchoMaximoTarjeta)
    }

    @Test func ancho_sinHueco_esCero() {
        #expect(L.anchoTarjeta(disponible: 0) == 0)
        #expect(L.anchoTarjeta(disponible: -20) == 0)
        #expect(L.anchoTarjeta(disponible: .infinity) == 0)
    }

    @Test func alto_esElDeUnaTarjetaBancaria() {
        // 340 / (85,6 / 53,98) ≈ 214,4
        #expect(abs(L.altoTarjeta(ancho: 340) - 214.4) < 0.1)
        #expect(L.altoTarjeta(ancho: 0) == 0)
        #expect(L.altoTarjeta(ancho: 300) < 300)
    }

    // MARK: Barra

    @Test func reparto_unaDivisa_repartePorLoQueDebes() throws {
        let reparto = try #require(L.reparto(lineas: [(facturado: 300, porFacturar: 100)]))
        #expect(reparto.facturado == 300)
        #expect(reparto.porFacturar == 100)
        #expect(reparto.fraccionFacturada == 0.75)
    }

    @Test func reparto_todoPorFacturar_esCero_yTodoFacturado_esUno() throws {
        #expect(try #require(L.reparto(lineas: [(0, 50)])).fraccionFacturada == 0)
        #expect(try #require(L.reparto(lineas: [(80, 0)])).fraccionFacturada == 1)
    }

    @Test func reparto_variasDivisas_noLlevaBarra() {
        // Entre divisas no se suma: con dos líneas la barra mentiría.
        #expect(L.reparto(lineas: [(100, 10), (20, 5)]) == nil)
    }

    @Test func reparto_sinDeuda_noLlevaBarra() {
        #expect(L.reparto(lineas: [(0, 0)]) == nil)
        #expect(L.reparto(lineas: []) == nil)
    }

    @Test func reparto_unPagoDeMas_cuentaComoCero() throws {
        // Facturado negativo (pagaste de más): no puede dar una fracción fuera de 0…1.
        #expect(L.reparto(lineas: [(-40, 0)]) == nil)
        let reparto = try #require(L.reparto(lineas: [(-40, 60)]))
        #expect(reparto.fraccionFacturada == 0)
        #expect(reparto.facturado == 0)
    }

    // MARK: Uso de línea (opción A del 22-nov: sale solo con límite)

    @Test func usoDeLinea_sinLimite_noHayLinea() {
        // Hoy la cuenta no guarda el límite: ni texto vacío ni «0 %».
        #expect(L.usoDeLinea(lineas: [(facturado: 300, porFacturar: 100)], limite: nil) == nil)
        #expect(L.usoDeLinea(lineas: [(300, 100)], limite: 0) == nil)
        #expect(L.usoDeLinea(lineas: [(300, 100)], limite: -500) == nil)
        #expect(L.usoDeLinea(lineas: [(300, 100)], limite: .infinity) == nil)
        #expect(L.usoDeLinea(lineas: [(300, 100)], limite: .nan) == nil)
    }

    @Test func usoDeLinea_conLimite_comoLaReferencia() throws {
        // «16 % usado · 6.752,50 disponible de 8.000,00».
        let uso = try #require(L.usoDeLinea(lineas: [(facturado: 1_000, porFacturar: 247.50)], limite: 8_000))
        #expect(uso.usado == 1_247.50)
        #expect(uso.disponible == 6_752.50)
        #expect(abs(uso.fraccionUsada - 0.1559) < 0.0001)
    }

    @Test func usoDeLinea_pasadoDelLimite_disponibleCero() throws {
        let uso = try #require(L.usoDeLinea(lineas: [(900, 300)], limite: 1_000))
        #expect(uso.disponible == 0)
        #expect(uso.fraccionUsada == 1.2)
    }

    @Test func usoDeLinea_variasDivisas_noHayLinea() {
        #expect(L.usoDeLinea(lineas: [(100, 10), (20, 5)], limite: 1_000) == nil)
        #expect(L.usoDeLinea(lineas: [], limite: 1_000) == nil)
    }

    @Test func usoDeLinea_unPagoDeMas_cuentaComoCero() throws {
        let uso = try #require(L.usoDeLinea(lineas: [(-40, 60)], limite: 1_000))
        #expect(uso.usado == 60)
    }

    // MARK: Bloque de la tarjeta de crédito

    @Test func bloque_tarjetaConCorte_enseñaElEstadoDeCuenta() {
        #expect(L.bloque(esTarjetaDeCredito: true, tieneEstadoDeCuenta: true, esCuentaDeSistema: false,
                         soloGastos: false, puedeEditar: true) == .estadoDeCuenta)
    }

    @Test func bloque_tarjetaSinFechas_lasPide() {
        #expect(L.bloque(esTarjetaDeCredito: true, tieneEstadoDeCuenta: false, esCuentaDeSistema: false,
                         soloGastos: false, puedeEditar: true) == .pedirFechas)
        // Sin poder editar no se ofrece un botón que no lleva a ningún sitio.
        #expect(L.bloque(esTarjetaDeCredito: true, tieneEstadoDeCuenta: false, esCuentaDeSistema: false,
                         soloGastos: false, puedeEditar: false) == .ninguno)
    }

    @Test func bloque_debito_soloGastos_oGrupos_noLleva() {
        #expect(L.bloque(esTarjetaDeCredito: false, tieneEstadoDeCuenta: false, esCuentaDeSistema: false,
                         soloGastos: false, puedeEditar: true) == .ninguno)
        #expect(L.bloque(esTarjetaDeCredito: true, tieneEstadoDeCuenta: true, esCuentaDeSistema: false,
                         soloGastos: true, puedeEditar: true) == .ninguno)
        #expect(L.bloque(esTarjetaDeCredito: true, tieneEstadoDeCuenta: true, esCuentaDeSistema: true,
                         soloGastos: false, puedeEditar: false) == .ninguno)
    }

    // MARK: Entrada

    @Test func entrada_subeYCrece_hastaSuSitio() {
        let inicio = L.entradaInicial(reducirMovimiento: false)
        #expect(inicio.desplazamiento > 0)
        #expect(inicio.escala < 1)
        #expect(inicio.opacidad == 0)
        #expect(L.entradaFinal == L.Entrada(desplazamiento: 0, escala: 1, opacidad: 1))
    }

    @Test func entrada_conReducirMovimiento_yaEstaEnSuSitio() {
        #expect(L.entradaInicial(reducirMovimiento: true) == L.entradaFinal)
    }
}

@MainActor
@Suite("Hoja de cuenta · tarjeta · textos en los 16 idiomas")
struct HojaCuentaTarjetaTextosTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    nonisolated static func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = repoRoot().appending(path: "Yala/Resources/\(locale).lproj/HojaCuentaTarjeta.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func placeholders(_ text: String) -> [String] {
        text.matches(of: /%(\d+\$)?[@d]/).map { String($0.output.0) }.sorted()
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

    @Test func cadaClaveDelCodigo_existe() throws {
        typealias T = L10n.HojaCuentaTarjeta
        for texto in [T.proximoCorte("15 dic"), T.sinFechasTitulo, T.sinFechasDetalle, T.anadirFechas,
                      T.usoDeLinea(porcentaje: "16 %", disponible: "6.752,50", limite: "8.000,00")] {
            #expect(!texto.hasPrefix("hojaCuenta."), "Clave sin texto: \(texto)")
        }
        #expect(try Self.table("es").count == 5)
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.HojaCuentaTarjeta.string("hojaCuenta.noDates.action", resolution: resolution)
        #expect(texto == (try Self.table(locale)["hojaCuenta.noDates.action"]))
    }
}

@Suite("Hoja de cuenta · tarjeta · cableado")
struct HojaCuentaTarjetaCableadoTests {

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: HojaCuentaTarjetaTextosTests.repoRoot().appending(path: path), encoding: .utf8)
    }

    /// La hoja pinta la tarjeta personalizada arriba y el bloque nuevo de la tarjeta de crédito.
    @Test func laHoja_usaLaTarjetaYElBloqueNuevos() throws {
        let hoja = try Self.source("Yala/App/Views/Panel/Sheets/AccountDetailSheet.swift")
        #expect(hoja.contains("HojaCuentaTarjetaCara(account: account"))
        #expect(hoja.contains("HojaCuentaTarjetaEstado(card: statement)"))
        #expect(hoja.contains("HojaCuentaTarjetaSinFechas"))
        // Opción A del 22-nov: hasta que la cuenta guarde el límite, la hoja no lo pasa y la línea no sale.
        #expect(!hoja.contains("limite:"), "El límite llega con el campo nuevo, en otro encargo.")
        #expect(!hoja.contains("CreditCardStatementBlock(card:"), "El bloque viejo ya no se pinta en la hoja.")
    }

    /// La cara sale del MISMO diseño que la tarjeta del carrusel: lo que la persona personalizó.
    @Test func laCara_usaElDisenoDeLaPersona() throws {
        let cara = try Self.source("Yala/App/Views/Panel/Sheets/HojaCuentaTarjeta/HojaCuentaTarjetaCara.swift")
        #expect(cara.contains("AccountCardView.look(for: account, storedDesigns: appPreferences.accountCardDesigns)"))
        #expect(cara.contains("CardBackgroundView(look: look)"))
        #expect(cara.contains("dsWithAnimation(reduceMotion"), "La entrada respeta Reducir movimiento.")
    }
}
