//
//  GroupSplitLinesRecipeTests.swift
//  YalaTests
//
//  Las reglas de «tu parte en líneas» (Grupos, opción B, 2026-11-01). Tres mitades:
//    1. SI CUADRA — la cuenta que enciende «Guardar»/«Aprobar», con los decimales de cada divisa y los casos de la
//       página de diseño (Pía 500 + 10 = 510; súper 80 + 20 = 100).
//    2. QUÉ LÍNEA ESTÁ MAL — cada problema por separado, con su control positivo.
//    3. GUARDAR Y LEER — ida y vuelta exacta (el importe no pasa por `Double`), la marca de pata derivada, y lo que NO
//       se debe tocar: una receta de una versión posterior no es ilegible.
//

import Foundation
import Testing

@testable import Yala

private let comisiones = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
private let supermercado = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
private let hogar = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
private let sip = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
private let lineA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
private let lineB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

private typealias R = GroupSplitLinesRecipe

/// La recarga de Pía: 500 a Sip y 10 de comisión.
private let piaLines: [R.Line] = [
    .transfer(id: lineA, amount: 500, destinationAccountID: sip),
    .expense(id: lineB, amount: 10, subcategoryID: comisiones),
]

// MARK: - 1 · Si cuadra

@Suite("Tu parte en líneas · si cuadra")
@MainActor
struct GroupSplitLinesBalanceTests {

    @Test("La recarga de Pía cuadra: 500 + 10 = 510")
    func pia_balanced() {
        #expect(R.balance(of: piaLines, share: 510, currencyCode: "PEN") == .balanced)
        #expect(R.canSave(piaLines, share: 510, currencyCode: "PEN"))
    }

    @Test("Si falta, dice cuánto: «Faltan S/ 10.00» al subir Pía el monto a 520")
    func missing_saysHowMuch() {
        #expect(R.balance(of: piaLines, share: 520, currencyCode: "PEN") == .missing(10))
        #expect(!R.canSave(piaLines, share: 520, currencyCode: "PEN"))
    }

    @Test("Si sobra, también lo dice, y no deja guardar")
    func over_saysHowMuch() {
        #expect(R.balance(of: piaLines, share: 505, currencyCode: "PEN") == .over(5))
        #expect(!R.canSave(piaLines, share: 505, currencyCode: "PEN"))
    }

    @Test("Decimales tecleados suman exacto: 0.1 + 0.2 = 0.3 (con Double, no)")
    func decimals_sumExactly() {
        let lines: [R.Line] = [
            .expense(amount: Decimal(string: "0.1")!, subcategoryID: supermercado),
            .expense(amount: Decimal(string: "0.2")!, subcategoryID: hogar),
        ]
        #expect(R.balance(of: lines, share: Decimal(string: "0.3")!, currencyCode: "USD") == .balanced)
        // Control: el mismo cálculo en Double no cuadra, que es por lo que el dinero va en Decimal.
        #expect(0.1 + 0.2 != 0.3)
    }

    @Test("Tu parte con más decimales que la divisa se compara redondeada: 511 / 3 = 170.333… → 170.33")
    func share_isRoundedToTheCurrency() {
        let share = Decimal(511) / Decimal(3)
        let lines: [R.Line] = [
            .expense(amount: Decimal(string: "160.33")!, subcategoryID: supermercado),
            .expense(amount: 10, subcategoryID: comisiones),
        ]
        #expect(R.balance(of: lines, share: share, currencyCode: "PEN") == .balanced)
        // Control: un céntimo menos ya no cuadra.
        let short: [R.Line] = [
            .expense(amount: Decimal(string: "160.32")!, subcategoryID: supermercado),
            .expense(amount: 10, subcategoryID: comisiones),
        ]
        #expect(R.balance(of: short, share: share, currencyCode: "PEN") == .missing(Decimal(string: "0.01")!))
    }

    @Test("En yenes no hay céntimos: 1000 / 3 se compara con 333")
    func yen_hasNoDecimals() {
        let share = Decimal(1000) / Decimal(3)
        let lines: [R.Line] = [
            .expense(amount: 300, subcategoryID: supermercado),
            .expense(amount: 33, subcategoryID: hogar),
        ]
        #expect(R.balance(of: lines, share: share, currencyCode: "JPY") == .balanced)
    }
}

// MARK: - 2 · Qué línea está mal

@Suite("Tu parte en líneas · qué línea está mal")
@MainActor
struct GroupSplitLinesProblemsTests {

    @Test("Control positivo: el caso de Pía y el del súper no tienen problemas")
    func validCases_haveNoProblems() {
        #expect(R.problems(in: piaLines, currencyCode: "PEN").isEmpty)
        let super_: [R.Line] = [
            .expense(amount: 80, subcategoryID: supermercado),
            .expense(amount: 20, subcategoryID: hogar),
        ]
        #expect(R.problems(in: super_, currencyCode: "PEN").isEmpty)
    }

    @Test("Sin líneas no se guarda")
    func noLines() {
        #expect(R.problems(in: [], currencyCode: "PEN") == [.noLines])
        #expect(!R.canSave([], share: 0, currencyCode: "PEN"))
    }

    @Test("Importe cero o negativo", arguments: [Decimal(0), Decimal(-5)])
    func nonPositiveAmount(amount: Decimal) {
        let lines: [R.Line] = [.expense(id: lineA, amount: amount, subcategoryID: comisiones)]
        #expect(R.problems(in: lines, currencyCode: "PEN") == [.nonPositiveAmount(lineID: lineA)])
    }

    @Test("Importe que no es un número")
    func nanAmount() {
        let lines: [R.Line] = [.expense(id: lineA, amount: .nan, subcategoryID: comisiones)]
        #expect(R.problems(in: lines, currencyCode: "PEN") == [.nonPositiveAmount(lineID: lineA)])
    }

    @Test("Más decimales que la divisa: 10.005 soles, 10.5 yenes")
    func tooManyDecimals() {
        let soles: [R.Line] = [.expense(id: lineA, amount: Decimal(string: "10.005")!, subcategoryID: comisiones)]
        #expect(R.problems(in: soles, currencyCode: "PEN") == [.tooManyDecimals(lineID: lineA)])
        let yen: [R.Line] = [.expense(id: lineA, amount: Decimal(string: "10.5")!, subcategoryID: comisiones)]
        #expect(R.problems(in: yen, currencyCode: "JPY") == [.tooManyDecimals(lineID: lineA)])
        // Control: con los decimales de la divisa no hay problema.
        let ok: [R.Line] = [.expense(id: lineA, amount: Decimal(string: "10.05")!, subcategoryID: comisiones)]
        #expect(R.problems(in: ok, currencyCode: "PEN").isEmpty)
    }

    @Test("Un gasto sin categoría")
    func expenseWithoutSubcategory() {
        let lines: [R.Line] = [.expense(id: lineA, amount: 10, subcategoryID: nil)]
        #expect(R.problems(in: lines, currencyCode: "PEN") == [.expenseWithoutSubcategory(lineID: lineA)])
    }

    @Test("Una recarga sin cuenta destino")
    func transferWithoutDestination() {
        let lines: [R.Line] = [.transfer(id: lineA, amount: 500, destinationAccountID: nil)]
        #expect(R.problems(in: lines, currencyCode: "PEN") == [.transferWithoutDestination(lineID: lineA)])
    }

    @Test("Dos líneas con el mismo id")
    func duplicateID() {
        let lines: [R.Line] = [
            .expense(id: lineA, amount: 5, subcategoryID: comisiones),
            .expense(id: lineA, amount: 5, subcategoryID: hogar),
        ]
        #expect(R.problems(in: lines, currencyCode: "PEN") == [.duplicateID(lineID: lineA)])
    }

    @Test("Cuadrar no basta: una línea mal apaga «Guardar» aunque la suma dé")
    func balancedButInvalid_cannotSave() {
        let lines: [R.Line] = [
            .transfer(id: lineA, amount: 500, destinationAccountID: nil),
            .expense(id: lineB, amount: 10, subcategoryID: comisiones),
        ]
        #expect(R.balance(of: lines, share: 510, currencyCode: "PEN") == .balanced)
        #expect(!R.canSave(lines, share: 510, currencyCode: "PEN"))
    }
}

// MARK: - 3 · Guardar y leer

@Suite("Tu parte en líneas · guardar y leer")
@MainActor
struct GroupSplitLinesStorageTests {

    @Test("Ida y vuelta: la receta de Pía se lee igual que se escribió")
    func roundTrip_pia() throws {
        let raw = try #require(R.encode(piaLines))
        #expect(R.parse(raw) == .recipe(piaLines))
    }

    @Test("El importe viaja como texto y vuelve exacto (0.1 no se vuelve 0.1000000000000000055…)")
    func roundTrip_amountIsExact() throws {
        let lines: [R.Line] = [
            .expense(id: lineA, amount: Decimal(string: "0.1")!, subcategoryID: supermercado),
            .expense(id: lineB, amount: Decimal(string: "1234567.89")!, subcategoryID: hogar),
        ]
        let raw = try #require(R.encode(lines))
        #expect(raw.contains("\"a\":\"0.1\""))
        #expect(raw.contains("\"a\":\"1234567.89\""))
        #expect(R.parse(raw) == .recipe(lines))
    }

    @Test("Una sola línea de gasto es lo de siempre: no se guarda receta")
    func singleExpense_storesNothing() {
        #expect(R.encode([.expense(amount: 510, subcategoryID: comisiones)]) == nil)
        #expect(R.encode([]) == nil)
    }

    @Test("Una sola recarga SÍ es receta: Pía recarga 500 a Sip sin comisión")
    func singleTransfer_isARecipe() throws {
        let lines: [R.Line] = [.transfer(id: lineA, amount: 500, destinationAccountID: sip)]
        let raw = try #require(R.encode(lines))
        #expect(R.parse(raw) == .recipe(lines))
    }

    @Test("La marca de pata derivada se lee como tal, no como receta")
    func derivedMarker_roundTrip() {
        let raw = R.encodeDerivedMarker(lineID: lineA)
        #expect(R.parse(raw) == .derived(lineID: lineA))
    }

    @Test("Vacío o nil es «sin líneas»", arguments: [nil, ""] as [String?])
    func empty_isNone(raw: String?) {
        #expect(R.parse(raw) == .none)
    }

    @Test("Una versión posterior NO es ilegible: no se pisa", arguments: [
        #"{"v":2,"l":[{"i":"x","k":"z"}]}"#,
        #"{"v":2,"of":"no-es-un-uuid"}"#,
        #"{"v":9,"algo":"nuevo"}"#,
    ])
    func newerVersion_isNotUnreadable(raw: String) {
        #expect(R.parse(raw) == .newerVersion)
    }

    @Test("Lo que no se entiende es ilegible", arguments: [
        "no es json",
        #"{"l":[]}"#,                                                       // sin versión
        #"{"v":0,"l":[]}"#,                                                 // versión imposible
        #"{"v":1}"#,                                                        // ni receta ni marca
        #"{"v":1,"l":[]}"#,                                                 // receta vacía
        #"{"v":1,"of":"no-es-un-uuid"}"#,
        #"{"v":1,"of":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","l":[]}"#,     // las dos cosas a la vez
        #"{"v":1,"l":[{"i":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","k":"x","a":"10"}]}"#,   // tipo desconocido
        #"{"v":1,"l":[{"i":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","k":"e","a":"diez"}]}"#, // importe que no es número
        #"{"v":1,"l":[{"i":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","k":"e","a":"10","s":"x"}]}"#, // categoría rota
        #"{"v":1,"l":[{"i":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","k":"t","a":"10","d":"x"}]}"#, // cuenta rota
    ])
    func garbage_isUnreadable(raw: String) {
        #expect(R.parse(raw) == .unreadable)
    }

    @Test("Una línea guardada sin categoría se LEE (la regla la para al guardar, no al leer)")
    func lineWithoutSubcategory_isReadable() {
        let raw = #"{"l":[{"a":"10","i":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","k":"e"}],"v":1}"#
        #expect(R.parse(raw) == .recipe([.expense(id: lineA, amount: 10, subcategoryID: nil)]))
    }

    @Test("El texto guardado es estable: mismas líneas, mismo texto (claves ordenadas)")
    func encoding_isStable() {
        #expect(R.encode(piaLines) == R.encode(piaLines))
        #expect(R.encode(piaLines)?.hasPrefix(#"{"l":"#) == true)
    }
}
