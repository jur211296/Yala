//
//  CuentaSolaAlLeerReglasTests.swift
//  YalaTests
//
//  Reglas de captura (parte 2 de la cuenta sola al leer, 2026-11-21), la parte pura: cómo se guardan, cuál gana, el
//  choque, «Recordar», lo que viaja a la IA y cuándo se vuelve a pedir el permiso de voz y foto. Sin `@Model`.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct CuentaSolaAlLeerReglasTests {

    private typealias Logic = CuentaSolaAlLeer
    private typealias Reglas = CuentaSolaAlLeerReglas

    private let zip = UUID()
    private let zipVisa = UUID()
    private let bcp = UUID()

    private func cuentas(zipRules: [AccountCaptureRule] = [], zipVisaRules: [AccountCaptureRule] = [],
                         bcpRules: [AccountCaptureRule] = []) -> [Logic.Cuenta] {
        [
            Logic.Cuenta(id: zip, name: "Zip", kind: .creditCard, currencyCode: "PEN", accountNumber: nil, rules: zipRules),
            Logic.Cuenta(id: zipVisa, name: "Zip Visa", kind: .creditCard, currencyCode: "PEN", accountNumber: "4557 1234",
                         rules: zipVisaRules),
            Logic.Cuenta(id: bcp, name: "BCP Soles", kind: .bank, currencyCode: "PEN", accountNumber: nil, rules: bcpRules),
        ]
    }

    private func texto(_ value: String, _ mode: AccountCaptureRule.Mode = .allWords) -> AccountCaptureRule {
        AccountCaptureRule(kind: .text, value: value, mode: mode, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - Cómo se guardan

    @Test("Ida y vuelta por el JSON, nil sin reglas y tolerante con lo que no entiende")
    func codec() throws {
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)
        let rules = [texto("zip"), AccountCaptureRule(kind: .merchant, value: "Uber", createdAt: fecha),
                     AccountCaptureRule(kind: .applePayCard, value: "Interbank Visa", createdAt: fecha)]
        let raw = try #require(AccountCaptureRule.encode(rules))
        #expect(AccountCaptureRule.decode(raw) == rules)
        #expect(AccountCaptureRule.encode([]) == nil, "sin reglas el campo queda nil y no viaja un cambio vacío")
        #expect(AccountCaptureRule.decode(nil).isEmpty)
        #expect(AccountCaptureRule.decode("no es json").isEmpty)
        // Una entrada de una versión futura (otro `kind`) no tumba las demás.
        let mixed = raw.replacingOccurrences(of: "\"merchant\"", with: "\"futuro\"")
        #expect(AccountCaptureRule.decode(mixed).map(\.kind) == [.text, .applePayCard])
        #expect(!raw.contains("balance") && !raw.contains("4557"), "una regla no guarda números de la cuenta")

        // Editar en un teléfono viejo no borra la regla de una versión futura: se conserva al guardar.
        let rewritten = try #require(AccountCaptureRule.encode([texto("visa")], preservingUnknownFrom: mixed))
        #expect(rewritten.contains("\"futuro\""), "la regla que esta versión no entiende sigue ahí")
        #expect(AccountCaptureRule.decode(rewritten).map(\.value) == ["visa"])
        #expect(AccountCaptureRule.unknownEntries(raw).isEmpty)
    }

    // MARK: - Cuál gana

    @Test("Criterio del ticket: «El texto dice “zip”» manda «Zip» a Zip Visa aunque exista la cuenta «Zip»")
    func reglaGanaAlNombre() {
        let sinRegla = Logic.leerConRegla(mention: "Zip", last4: nil, among: cuentas())
        #expect(sinRegla.lectura == .elegida(zip, .nombre))
        #expect(sinRegla.regla == nil)

        let conRegla = Logic.leerConRegla(mention: "Zip", last4: nil, among: cuentas(zipVisaRules: [texto("zip")]))
        #expect(conRegla.lectura == .elegida(zipVisa, .regla))
        #expect(conRegla.regla?.value == "zip")
    }

    @Test("La regla gana también a los últimos 4 y a la IA")
    func reglaGanaALosUltimos4YALaIA() {
        let lista = cuentas(zipRules: [texto("visa")])
        let leida = Logic.leerConRegla(mention: "Visa ••1234", last4: nil, among: lista)
        #expect(leida.lectura == .elegida(zip, .regla), "sin la regla, ••1234 elegiría Zip Visa")
        #expect(Logic.combinar(leida.lectura, iaAccountID: zipVisa) == .sola(zip, .regla))
    }

    @Test("La más concreta gana: tarjeta de Apple Pay › comercio › juntas › varias palabras › una palabra")
    func concrecion() {
        let applePay = AccountCaptureRule(kind: .applePayCard, value: "Interbank Visa")
        let merchant = AccountCaptureRule(kind: .merchant, value: "Uber")
        let juntas = texto("pago movil", .together)
        let varias = texto("pago movil")
        let una = texto("uber")
        let orden = [applePay, merchant, juntas, varias, una].map(Reglas.concrecion)
        #expect(orden == orden.sorted(by: >) && Set(orden).count == 5)
        #expect(Reglas.concrecion(texto("uber", .together)) == Reglas.concrecion(una), "juntas con una palabra es una palabra")

        let lectura = Reglas.Lectura(mention: "Interbank Visa", merchant: "Uber Eats", applePayCard: "Interbank Visa")
        let lista = cuentas(zipRules: [una], zipVisaRules: [merchant], bcpRules: [applePay])
        #expect(Reglas.decidir(lectura, among: lista) == .elegida(bcp, applePay))
        let sinApplePay = Reglas.Lectura(mention: nil, merchant: "Uber Eats")
        #expect(Reglas.decidir(sinApplePay, among: lista) == .elegida(zipVisa, merchant))
    }

    @Test("«Paga con Apple Pay» solo se cumple desde Apple Pay, no por el texto de una foto")
    func applePaySoloDesdeApplePay() {
        let rule = AccountCaptureRule(kind: .applePayCard, value: "Interbank Visa")
        #expect(Reglas.cumple(rule, .init(applePayCard: "Interbank Visa")))
        #expect(!Reglas.cumple(rule, .init(mention: "Interbank Visa")))
    }

    @Test("Todas en cualquier orden frente a juntas tal cual, sin tildes ni mayúsculas")
    func modosDePalabras() {
        let lectura = Reglas.Lectura(mention: "Pago con TARJETA Café", merchant: nil)
        #expect(Reglas.cumple(texto("cafe tarjeta"), lectura))
        #expect(!Reglas.cumple(texto("cafe tarjeta", .together), lectura))
        #expect(Reglas.cumple(texto("tarjeta cafe", .together), lectura))
        #expect(!Reglas.cumple(texto("tarjetas"), lectura), "palabra entera, no un trozo")
        #expect(Reglas.cumple(texto("Uber"), .init(merchant: "uber")), "«uber» es relleno en alemán, pero escrito solo cuenta")
    }

    @Test("Criterio del ticket: dos reglas igual de concretas hacia cuentas distintas no eligen")
    func choque() {
        let lista = cuentas(zipRules: [texto("zip")], zipVisaRules: [texto("zip")])
        let leida = Logic.leerConRegla(mention: "Zip", last4: nil, among: lista)
        guard case .choqueReglas(let cumplidas) = leida.lectura else {
            Issue.record("esperaba choque de reglas, salió \(leida.lectura)")
            return
        }
        #expect(cumplidas.map(\.accountID) == [zip, zipVisa])
        let resultado = Logic.combinar(leida.lectura, iaAccountID: zip)
        #expect(resultado == .choqueReglas(cumplidas), "la IA no deshace un choque de reglas")
        #expect(resultado.cuentaPuesta == nil)
        #expect(Logic.chip(for: resultado, currentAccountID: nil) == .elige(coinciden: 2))
        // Más concreta en una sola cuenta: decide aunque la otra también se cumpla.
        let desempate = cuentas(zipRules: [texto("zip")], zipVisaRules: [AccountCaptureRule(kind: .merchant, value: "Tambo")])
        #expect(Logic.leerConRegla(mention: "Zip", last4: nil, merchant: "Tambo", among: desempate).lectura
                == .elegida(zipVisa, .regla))
    }

    @Test("El selector enseña las dos cuentas del choque, cada una con su regla")
    func pistaDelChoque() throws {
        let cumplidas = [Reglas.Cumplida(accountID: zip, rule: texto("zip")),
                         Reglas.Cumplida(accountID: zipVisa, rule: texto("zip"))]
        let eleccion = Logic.Eleccion(resultado: .choqueReglas(cumplidas), mention: "Zip", last4: nil)
        let pista = try #require(CuentaSolaAlLeerSelectorPista.pista(for: eleccion))
        #expect(pista.titulo == L10n.CuentaSolaAlLeer.Rule.conflict)
        #expect(pista.filas.map(\.accountID) == [zip, zipVisa])
        #expect(pista.filas.allSatisfy { $0.motivo == L10n.CuentaSolaAlLeer.Rule.reason("zip") })
    }

    @Test("La línea de «por qué» de una regla dice cuál")
    func porqueDeLaRegla() {
        let eleccion = Logic.Eleccion(resultado: .sola(zipVisa, .regla), mention: "Zip", last4: nil, regla: texto("zip"))
        let chip = CuentaSolaAlLeerChipPresentacion.make(
            eleccion: eleccion, currentAccountID: zipVisa, accountName: "Zip Visa", muestraPorque: true,
            selectAccount: "Selecciona cuenta")
        #expect(chip.porque == L10n.CuentaSolaAlLeer.Rule.why("Zip Visa", "zip"))
        #expect(chip.accessibilityLabel == L10n.CuentaSolaAlLeer.Rule.accessibility("Zip Visa", "zip"))
    }

    // MARK: - Recordar

    @Test("«Recordar» sale solo si la persona cambió la cuenta con la que nació el borrador")
    func ofertaRecordar() throws {
        let eleccion = Logic.Eleccion(resultado: .sola(zip, .nombre), mention: "Zip", last4: nil)
        #expect(eleccion.cuentaInicial == zip)
        #expect(Reglas.ofertaRecordar(eleccion, currentAccountID: zip) == nil, "sin cambiarla, nada")
        let oferta = try #require(Reglas.ofertaRecordar(eleccion, currentAccountID: zipVisa))
        #expect(oferta.kind == .text && oferta.value == "Zip" && oferta.mode == .allWords)

        // Nació con la única cuenta en la moneda (sin estrella): dejarla no ofrece nada; cambiarla, sí.
        let porMoneda = Logic.Eleccion(resultado: .ninguna, mention: "Zip", last4: nil, cuentaInicial: bcp)
        #expect(Reglas.ofertaRecordar(porMoneda, currentAccountID: bcp) == nil)
        #expect(Reglas.ofertaRecordar(porMoneda, currentAccountID: zipVisa) != nil)

        // Lo leído sin palabras (solo los últimos 4): no hay regla que ofrecer.
        let soloDigitos = Logic.Eleccion(resultado: .ninguna, mention: "••4417", last4: nil)
        #expect(Reglas.ofertaRecordar(soloDigitos, currentAccountID: zip) == nil)
        #expect(Reglas.ofertaRecordar(nil, currentAccountID: zip) == nil)

        // Varias palabras: juntas, tal cual.
        let varias = Logic.Eleccion(resultado: .ninguna, mention: "Zip Platinum ••4417", last4: nil)
        let juntas = try #require(Reglas.ofertaRecordar(varias, currentAccountID: zip))
        #expect(juntas.value == "Zip Platinum" && juntas.mode == .together)
    }

    @Test("Criterio del ticket: tras «Recordar», la siguiente captura con esa palabra va sola")
    func recordarYLaSiguienteVaSola() throws {
        let eleccion = Logic.Eleccion(resultado: .sola(zip, .nombre), mention: "Zip", last4: nil)
        let rule = try #require(Reglas.ofertaRecordar(eleccion, currentAccountID: zipVisa))
        let lista = cuentas(zipVisaRules: Reglas.anadir(rule, a: []))
        #expect(Logic.leerConRegla(mention: "ZIP", last4: nil, among: lista).lectura == .elegida(zipVisa, .regla))
    }

    @Test("Una regla igual en otra cuenta se detecta, y añadirla no la repite")
    func repetidaYAnadir() {
        let rule = texto("zip")
        let en = [(id: zip, rules: [texto("ZIP")]), (id: zipVisa, rules: [AccountCaptureRule]())]
        #expect(Reglas.repetida(rule, destino: zipVisa, en: en)?.accountID == zip)
        #expect(Reglas.repetida(rule, destino: zip, en: en) == nil, "en la propia cuenta no es repetida")
        #expect(!texto("zip").isSameCondition(as: texto("zip", .together)), "el modo cuenta en las de texto")
        let una = Reglas.anadir(rule, a: [])
        #expect(Reglas.anadir(texto("Zip"), a: una).count == 1)
    }

    // MARK: - Lo que viaja a la IA

    @Test("Con nombres y reglas, la petición lleva las reglas como texto; nunca saldos ni números")
    func peticionConReglas() throws {
        let lista = cuentas(zipVisaRules: [texto("zip"), AccountCaptureRule(kind: .merchant, value: "Uber")])
        let conReglas = CuentaSolaAlLeerPeticion.cuentas(from: lista, envio: .nombresYReglas)
        let bloque = try #require(CuentaSolaAlLeerPeticion.texto(conReglas))
        #expect(bloque.contains("Zip Visa | credit card | PEN | rules: text contains \"zip\"; merchant is \"Uber\""))
        #expect(!bloque.contains("4557") && !bloque.contains("1234"))

        let soloNombres = CuentaSolaAlLeerPeticion.cuentas(from: lista, envio: .nombres)
        #expect(soloNombres.allSatisfy { $0.rules.isEmpty })
        #expect(CuentaSolaAlLeerPeticion.texto(soloNombres)?.contains("rules") == false)
        #expect(CuentaSolaAlLeerPeticion.cuentas(from: lista, envio: .nada).isEmpty)
    }

    @Test("Qué viaja: foto en la nube o con el permiso vigente; chat con nombres siempre y reglas en la nube")
    func envio() {
        #expect(CuentaSolaAlLeerPeticion.Envio.foto(isCloud: true, hasCurrentProcessingConsent: false) == .nombresYReglas)
        #expect(CuentaSolaAlLeerPeticion.Envio.foto(isCloud: false, hasCurrentProcessingConsent: true) == .nombresYReglas)
        #expect(CuentaSolaAlLeerPeticion.Envio.foto(isCloud: false, hasCurrentProcessingConsent: false) == .nada)
        #expect(CuentaSolaAlLeerPeticion.Envio.chat(isCloud: true) == .nombresYReglas)
        #expect(CuentaSolaAlLeerPeticion.Envio.chat(isCloud: false) == .nombres)
    }

    @Test("El permiso de voz y foto se vuelve a pedir una vez a quien aceptó el texto anterior, fuera de la nube")
    func permisoOtraVez() {
        let v = AIConsentRevision.processing
        #expect(CuentaSolaReglasConsentLogic.asksAgain(accepted: true, version: 0, askedVersion: 0, isCloud: false, isSetupTrial: false))
        #expect(!CuentaSolaReglasConsentLogic.asksAgain(accepted: true, version: v, askedVersion: 0, isCloud: false, isSetupTrial: false))
        #expect(!CuentaSolaReglasConsentLogic.asksAgain(accepted: true, version: 0, askedVersion: v, isCloud: false, isSetupTrial: false),
                "«Ahora no» cuenta: no se vuelve a pedir")
        #expect(!CuentaSolaReglasConsentLogic.asksAgain(accepted: false, version: 0, askedVersion: 0, isCloud: false, isSetupTrial: false),
                "sin aceptar, sale el permiso de siempre con el texto nuevo")
        #expect(!CuentaSolaReglasConsentLogic.asksAgain(accepted: true, version: 0, askedVersion: 0, isCloud: true, isSetupTrial: false))
        #expect(!CuentaSolaReglasConsentLogic.asksAgain(accepted: true, version: 0, askedVersion: 0, isCloud: false, isSetupTrial: true))
    }

    @Test("El permiso de voz y foto lo dice en los 16 idiomas: nombres de cuentas y reglas, nunca saldos")
    func permisoLoDice() throws {
        let words = [
            "es": "reglas de captura", "es-419": "reglas de captura", "es-AR": "reglas de captura",
            "es-ES": "reglas de captura", "en": "capture rules", "en-GB": "capture rules", "de": "Erfassungsregeln",
            "fr": "règles de saisie", "it": "regole di acquisizione", "ja": "取り込みルール", "nl": "vastlegregels",
            "pl": "reguły przechwytywania", "pt-BR": "regras de captura", "pt": "regras de captura",
            "pt-PT": "regras de captura", "zh-Hans": "记账规则",
        ]
        #expect(words.count == 16)
        for (lang, word) in words {
            let path = try #require(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil,
                                                     forLocalization: lang), "falta \(lang)")
            let strings = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
            let message = try #require(strings["aiConsent.processingMessage"])
            #expect(message.contains(word), "\(lang): el permiso no dice que viajan las reglas")
        }
    }

    // MARK: - La respuesta del chat

    @Test("El chat lee `account` de la respuesta; sin el campo o con otro tipo, nil")
    func chatLeeLaCuenta() throws {
        let parser = TranscriptionParserService.shared
        let con = #"{"transactions":[{"amount":25,"date":"2026-11-21","note":"almuerzo","isExpense":true,"subcategoryHint":null,"tagHints":[],"currencyHint":null,"paymentHint":"zip","account":"Zip Visa","confidence":{"amount":1,"date":1,"merchant":0.5,"subcategory":0.5,"tags":0}}]}"#
        let sin = con.replacingOccurrences(of: #","account":"Zip Visa""#, with: "")
        let raro = con.replacingOccurrences(of: #""account":"Zip Visa""#, with: #""account":7"#)
        #expect(try parser.parseMultipleResponse(con).first?.accountHint == "Zip Visa")
        #expect(try parser.parseMultipleResponse(sin).first?.accountHint == nil)
        #expect(try parser.parseMultipleResponse(raro).first?.accountHint == nil)
        #expect(try parser.parseMultipleResponse(raro).first?.paymentHint == "zip", "un `account` raro no tumba la lectura")
        #expect(TextParseResponseSchema.transactionFields.contains("account"))
    }
}
