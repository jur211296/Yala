//
//  BankNoticeParserTests.swift
//  YalaTests
//
//  Atajo del banco (2.3, B1): la lectura por reglas. Cada formato de aviso tiene su caso con el texto tal cual; un aviso
//  real nuevo suma aquí su caso y su fila en `BankNoticeRules.all`.
//
//  El texto llega como «título␤cuerpo»: medido en el iPhone 14 con iOS 27.2.1 en la prueba B0
//  (`docs/ux/atajo-banco-y-suscripciones/prueba-b0/`).
//

import Foundation
import Testing

@testable import Yala

@Suite("Atajo del banco · reglas")
struct BankNoticeParserTests {

    private func movement(_ reading: BankNoticeReading?) -> (BankNoticeMovement, String?)? {
        guard case .movement(let movement, let ruleID)? = reading else { return nil }
        return (movement, ruleID)
    }

    private func dec(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    // MARK: - BCP

    @Test("BCP: el aviso de la prueba B0, tal como lo entrega la automatización")
    func bcp_consumo_asDeliveredByTheAutomation() throws {
        let text = "Consumo con tu tarjeta\nRealizaste un consumo de S/ 12.50 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES."
        let (m, rule) = try #require(movement(BankNoticeParser.read(text, bankHint: .bcp)))
        #expect(m.amount == dec("12.50"))
        #expect(m.currencyCode == "PEN")
        #expect(m.isExpense)
        #expect(m.counterparty == "TAMBO+ MIRAFLORES")
        #expect(m.cardLast4 == "4821")
        #expect(rule == "bcp.consumo")
    }

    @Test("BCP: el ejemplo de la definición, sin pista de banco, sale por la regla del BCP porque el texto lo nombra")
    func bcp_detectedFromText() throws {
        let text = "Realizaste un consumo de S/ 45.90 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES."
        let (m, rule) = try #require(movement(BankNoticeParser.read(text)))
        #expect(m.amount == dec("45.90"))
        #expect(rule == "bcp.consumo")
    }

    @Test("«Operación por USD 12.00 en AMZN Mktp» no lo lee ninguna regla: es el ejemplo de «No entendimos» de la definición")
    func operacionPor_isNotReadByRules() {
        #expect(BankNoticeParser.read("Operación por USD 12.00 en AMZN Mktp US*2K4", bankHint: .bcp) == nil)
    }

    // MARK: - Yape

    @Test("Yape: pago recibido (formato del proyecto público app-yape-monitoreo)")
    func yape_recibido() throws {
        let (m, rule) = try #require(movement(BankNoticeParser.read("Yape! Juan Pérez te envió un pago por S/ 10.00", bankHint: .yape)))
        #expect(m.amount == 10)
        #expect(!m.isExpense)
        #expect(m.counterparty == "Juan Pérez")
        #expect(rule == "yape.recibido")
    }

    @Test("Yape: el código de seguridad del pago recibido no lo convierte en «no era una compra»")
    func yape_recibido_withSecurityCode_isStillAMovement() throws {
        let text = "Confirmación de Pago\nYape! María L. te envió un pago por S/ 25.50. El código de seguridad es: 482"
        let (m, _) = try #require(movement(BankNoticeParser.read(text)))
        #expect(m.amount == dec("25.50"))
        #expect(!m.isExpense)
    }

    @Test("Yape: «te yapeó» y «yapeaste»")
    func yape_otherForms() throws {
        let (income, r1) = try #require(movement(BankNoticeParser.read("Carlos te yapeó S/ 8.00")))
        #expect(!income.isExpense && income.amount == 8 && r1 == "yape.teYapeo")
        let (expense, r2) = try #require(movement(BankNoticeParser.read("Yapeaste S/ 15.00 a Bodega Don Pepe.")))
        #expect(expense.isExpense && expense.amount == 15 && r2 == "yape.yapeaste")
        #expect(expense.counterparty == "Bodega Don Pepe")
    }

    // MARK: - Plin, Interbank, BBVA, Scotiabank (sin texto público: reglas propias y genéricas)

    @Test("Plin: pago recibido y pago hecho")
    func plin() throws {
        let (income, r1) = try #require(movement(BankNoticeParser.read("Ana Torres te plineó S/ 30.00", bankHint: .plin)))
        #expect(!income.isExpense && income.amount == 30 && r1 == "plin.recibido")
        #expect(income.counterparty == "Ana Torres")
        let (expense, r2) = try #require(movement(BankNoticeParser.read("Plineaste S/ 12.00 a Luis Rojas", bankHint: .plin)))
        #expect(expense.isExpense && r2 == "plin.plineaste")
    }

    @Test("Interbank, BBVA y Scotiabank: una compra con tarjeta la lee la regla genérica, con comercio y cuatro dígitos")
    func genericPurchase_forBanksWithoutOwnRules() throws {
        let cases: [(String, BankNoticeBank, String, String)] = [
            ("Interbank: Consumo de S/ 89.90 en WONG BENAVIDES con tu tarjeta ****1234.", .interbank, "89.90", "WONG BENAVIDES"),
            ("BBVA: Compra por S/ 150.00 en SAGA FALABELLA con tu tarjeta terminada en 5678", .bbva, "150.00", "SAGA FALABELLA"),
            ("Scotiabank: Compra aprobada por US$ 20.00 en NETFLIX.COM", .scotiabank, "20.00", "NETFLIX.COM"),
        ]
        for (text, bank, amount, merchant) in cases {
            let (m, _) = try #require(movement(BankNoticeParser.read(text, bankHint: bank)), "\(text)")
            #expect(m.amount == dec(amount), "\(text)")
            #expect(m.isExpense, "\(text)")
            #expect(m.counterparty == merchant, "\(text)")
        }
    }

    @Test("«en tu tarjeta …» no es el comercio: se toma el siguiente «en»")
    func merchant_skipsEnTuTarjeta() throws {
        let (m, _) = try #require(movement(BankNoticeParser.read("Compra por S/ 30.00 en tu tarjeta ****1234 en PLAZA VEA")))
        #expect(m.counterparty == "PLAZA VEA")
        #expect(m.cardLast4 == "1234")
    }

    @Test("Dinero que entra por transferencia")
    func generic_income() throws {
        let (m, rule) = try #require(movement(BankNoticeParser.read("Recibiste S/ 500.00 de EMPRESA SAC.")))
        #expect(!m.isExpense && m.amount == 500 && rule == "generic.recibiste")
        #expect(m.counterparty == "EMPRESA SAC")
    }

    // MARK: - No eran compras

    @Test("Una compra rechazada no es un movimiento, aunque traiga importe y comercio")
    func declined_isNotAMovement() {
        #expect(BankNoticeParser.read("Tu compra por S/ 50.00 en RIPLEY fue rechazada.") == .notAMovement)
        #expect(BankNoticeParser.read("Consumo de S/ 20.00 no aprobado en TOTTUS") == .notAMovement)
    }

    @Test("Publicidad, claves y saldos no son movimientos")
    func promotionsAndSecurity_areNotMovements() {
        #expect(BankNoticeParser.read("Compra de S/ 100 o más y gana un viaje. ¡Participa!") == .notAMovement)
        #expect(BankNoticeParser.read("Tu clave dinámica es 123456. No la compartas.") == .notAMovement)
        #expect(BankNoticeParser.read("Tu saldo disponible es S/ 1,200.00") == .notAMovement)
        #expect(BankNoticeParser.read("Iniciaste sesión en un nuevo dispositivo") == .notAMovement)
    }

    @Test("Una anulación o devolución no la decide una regla: se completa a mano")
    func reversal_isNotUnderstood() {
        #expect(BankNoticeParser.read("Se realizó el extorno de S/ 45.90 en TAMBO+") == .notUnderstood)
        #expect(BankNoticeParser.read("Devolución de S/ 20.00 de RIPLEY") == .notUnderstood)
    }

    @Test("Texto vacío o sin nada reconocible: ninguna regla")
    func empty_andUnknown() {
        #expect(BankNoticeParser.read("   \n ") == nil)
        #expect(BankNoticeParser.read("Hola, ¿cómo estás?") == nil)
    }

    // MARK: - Orden

    @Test("Las reglas del banco del aviso van primero; las genéricas al final")
    func ordering() {
        let ordered = BankNoticeParser.ordered(BankNoticeRules.all, for: .yape)
        #expect(ordered.first?.bank == .yape)
        #expect(ordered.last?.bank == nil)
        #expect(ordered.count == BankNoticeRules.all.count)
    }

    @Test("Toda regla compila y trae los grupos del importe")
    func everyRuleCompiles() throws {
        for rule in BankNoticeRules.all {
            let regex = try NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive])
            #expect(regex.numberOfCaptureGroups >= 2, "\(rule.id)")
            #expect(rule.pattern.contains("(?<amt>"), "\(rule.id)")
        }
        #expect(Set(BankNoticeRules.all.map(\.id)).count == BankNoticeRules.all.count, "ids repetidos")
    }

    @Test("El banco se deduce del texto si el atajo no lo dice; Yape gana a BCP cuando los nombra a los dos")
    func bankDetection() {
        #expect(BankNoticeParser.bank(text: "Yape! … BCP", hint: nil) == .yape)
        #expect(BankNoticeParser.bank(text: "Tarjeta de Débito BCP", hint: nil) == .bcp)
        #expect(BankNoticeParser.bank(text: "cualquier cosa", hint: .interbank) == .interbank)
        #expect(BankNoticeParser.bank(text: "cualquier cosa", hint: nil) == nil)
    }
}

@Suite("Atajo del banco · importes")
struct BankNoticeAmountTests {

    private func dec(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    @Test("Separadores: el último seguido de 1-2 dígitos es el decimal; los demás separan miles")
    func separators() {
        #expect(BankNoticeAmount.decimal(from: "12.50") == dec("12.50"))
        #expect(BankNoticeAmount.decimal(from: "45,90") == dec("45.90"))
        #expect(BankNoticeAmount.decimal(from: "1,234.50") == dec("1234.50"))
        #expect(BankNoticeAmount.decimal(from: "1.234,50") == dec("1234.50"))
        #expect(BankNoticeAmount.decimal(from: "1,234") == 1234)
        #expect(BankNoticeAmount.decimal(from: "12") == 12)
        #expect(BankNoticeAmount.decimal(from: "0.00") == nil)
        #expect(BankNoticeAmount.decimal(from: "abc") == nil)
    }

    @Test("Monedas: soles y dólares con símbolo o código; «$» se queda ambiguo")
    func currencies() {
        #expect(BankNoticeAmount.currency(of: "S/").code == "PEN")
        #expect(BankNoticeAmount.currency(of: "S/.").code == "PEN")
        #expect(BankNoticeAmount.currency(of: "US$").code == "USD")
        #expect(BankNoticeAmount.currency(of: "usd").code == "USD")
        #expect(BankNoticeAmount.currency(of: "$").code == nil)
        #expect(BankNoticeAmount.currency(of: "$").ambiguous == "$")
    }

    @Test("Los importes escritos en un aviso, para validar al modelo")
    func amountsWritten() {
        let found = BankNoticeAmount.amountsWritten(in: "Consumo de S/ 1,234.50 con tu tarjeta ****4821")
        #expect(found.contains(dec("1234.50")))
        #expect(found.contains(4821))
        #expect(!found.contains(1234))
    }

    @Test("«S/.12» sin espacio y «$ 9.99» se leen por la regla genérica")
    func compactForms() throws {
        guard case .movement(let soles, _)? = BankNoticeParser.read("Compra por S/.12 en KFC") else {
            Issue.record("sin movimiento"); return
        }
        #expect(soles.amount == 12 && soles.currencyCode == "PEN")
        guard case .movement(let dollars, _)? = BankNoticeParser.read("Pagaste $ 9.99 en APPLE.COM/BILL") else {
            Issue.record("sin movimiento"); return
        }
        #expect(dollars.amount == dec("9.99") && dollars.currencyCode == nil && dollars.ambiguousSymbol == "$")
    }
}
