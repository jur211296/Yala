//
//  GroupSplitLinesEditorLogicTests.swift
//  YalaTests
//
//  Lo que decide la tarjeta «Tu parte» y la hoja de una línea (Grupos B · card 4), sobre las reglas de
//  `GroupSplitLinesRecipe` (que tienen sus propios tests). Cuatro bloques:
//    1. LA CUENTA DESTINO — solo una que el puente acepta: tuya, no de sistema, sin archivar y en la divisa del gasto. Si
//       no, el puente dejaría tu parte en una línea sin avisar, así que «Guardar» se apaga.
//    2. EDITAR LA LISTA — empezar a partir, «Añadir línea» con lo que falta, sustituir y quitar (nunca la última).
//    3. LA HOJA — cambiar de tipo no pierde lo elegido y cada tipo se lleva solo lo suyo; cuándo se enciende «Guardar línea».
//    4. IMPORTE ↔ TEXTO — sin pasar por `Double`, con los separadores del idioma.
//

import Foundation
import Testing

@testable import Yala

fileprivate typealias E = GroupSplitLinesEditorLogic
private typealias R = GroupSplitLinesRecipe

private let sip = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
private let comisiones = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
private let lineA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
private let lineB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
private let posix = Locale(identifier: "en_US_POSIX")
private let peru = Locale(identifier: "es_PE")
private let germany = Locale(identifier: "de_DE")

private let sipOK = E.DestinationInfo(currencyCode: "PEN", isSystemAccount: false, isArchived: false)
private let piaLines: [R.Line] = [
    .transfer(id: lineA, amount: 500, destinationAccountID: sip),
    .expense(id: lineB, amount: 10, subcategoryID: comisiones),
]

// MARK: - 1 · La cuenta destino

@Suite("Tu parte en líneas · cuenta destino")
@MainActor
struct GroupSplitLinesDestinationTests {

    @Test("Una cuenta tuya, sin archivar y en la divisa del gasto sirve")
    func eligible() {
        #expect(E.isEligibleDestination(sipOK, currencyCode: "PEN"))
    }

    @Test("No sirven: de sistema, archivada, otra divisa o que no está en el aparato",
          arguments: [
            E.DestinationInfo(currencyCode: "PEN", isSystemAccount: true, isArchived: false),
            E.DestinationInfo(currencyCode: "PEN", isSystemAccount: false, isArchived: true),
            E.DestinationInfo(currencyCode: "USD", isSystemAccount: false, isArchived: false),
          ] as [GroupSplitLinesEditorLogic.DestinationInfo?] + [nil])
    func notEligible(_ info: GroupSplitLinesEditorLogic.DestinationInfo?) {
        #expect(!E.isEligibleDestination(info, currencyCode: "PEN"))
    }

    @Test("Una recarga a una cuenta que dejó de servir apaga «Guardar» aunque la receta cuadre")
    func unavailableDestinationBlocksSave() {
        let archived = E.DestinationInfo(currencyCode: "PEN", isSystemAccount: false, isArchived: true)
        #expect(R.canSave(piaLines, share: 510, currencyCode: "PEN"))
        #expect(E.linesWithUnavailableDestination(piaLines, destinations: [sip: archived], currencyCode: "PEN") == [lineA])
        #expect(!E.canSave(piaLines, share: 510, currencyCode: "PEN", destinations: [sip: archived]))
        #expect(!E.canSave(piaLines, share: 510, currencyCode: "PEN", destinations: [:]))
        // Control: con la cuenta buena, se guarda.
        #expect(E.canSave(piaLines, share: 510, currencyCode: "PEN", destinations: [sip: sipOK]))
    }

    @Test("Una recarga SIN cuenta no cuenta como destino caído: eso ya lo dice la receta")
    func transferWithoutDestinationIsTheRecipesProblem() {
        let lines: [R.Line] = [.transfer(id: lineA, amount: 510, destinationAccountID: nil)]
        #expect(E.linesWithUnavailableDestination(lines, destinations: [:], currencyCode: "PEN").isEmpty)
        #expect(!E.canSave(lines, share: 510, currencyCode: "PEN", destinations: [:]))
    }

    @Test("Si no cuadra, no se guarda aunque las cuentas sirvan")
    func unbalancedBlocksSave() {
        #expect(!E.canSave(piaLines, share: 520, currencyCode: "PEN", destinations: [sip: sipOK]))
    }
}

// MARK: - 2 · Editar la lista

@Suite("Tu parte en líneas · editar la lista")
@MainActor
struct GroupSplitLinesListEditingTests {

    @Test("Partir empieza con una línea de gasto por tu parte entera, redondeada a la divisa, y ya cuadra")
    func initialLines() {
        let share = Decimal(511) / Decimal(3) // 170.333…
        let lines = E.initialLines(share: share, subcategoryID: comisiones, currencyCode: "PEN")
        #expect(lines.count == 1)
        #expect(lines[0].kind == .expense)
        #expect(lines[0].amount == Decimal(string: "170.33"))
        #expect(lines[0].subcategoryID == comisiones)
        #expect(R.balance(of: lines, share: share, currencyCode: "PEN") == .balanced)
    }

    @Test("«Añadir línea» abre con lo que falta; nada si cuadra o sobra")
    func amountForNewLine() {
        #expect(E.amountForNewLine(piaLines, share: 520, currencyCode: "PEN") == 10)
        #expect(E.amountForNewLine(piaLines, share: 510, currencyCode: "PEN") == nil)
        #expect(E.amountForNewLine(piaLines, share: 500, currencyCode: "PEN") == nil)
    }

    @Test("Guardar una línea que ya existe la sustituye en su sitio; una nueva va al final")
    func upserting() {
        let edited = R.Line.transfer(id: lineA, amount: 490, destinationAccountID: sip)
        let replaced = E.upserting(edited, into: piaLines)
        #expect(replaced.map(\.id) == [lineA, lineB])
        #expect(replaced[0].amount == 490)

        let added = R.Line.expense(amount: 10, subcategoryID: comisiones)
        #expect(E.upserting(added, into: replaced).map(\.id) == [lineA, lineB, added.id])
    }

    @Test("Se quita una línea si quedan otras; la última no se quita")
    func removing() {
        #expect(E.canRemove(from: piaLines))
        #expect(E.removing(lineA, from: piaLines).map(\.id) == [lineB])
        let single = [piaLines[1]]
        #expect(!E.canRemove(from: single))
        #expect(E.removing(lineB, from: single) == single)
    }
}

// MARK: - 3 · La hoja de una línea

@Suite("Tu parte en líneas · hoja de una línea")
@MainActor
struct GroupSplitLineDraftTests {

    @Test("Una línea nueva es un gasto con lo que falta escrito")
    func newDraft() {
        let draft = E.Draft(id: lineB, suggestedAmount: 10, currencyCode: "PEN", locale: posix)
        #expect(draft.kind == .expense)
        #expect(draft.amountText == "10")
        #expect(E.Draft(suggestedAmount: nil, currencyCode: "PEN", locale: posix).amountText == "")
    }

    @Test("Editar una línea devuelve la misma línea si no se toca nada")
    func roundTrip() {
        for line in piaLines {
            let draft = E.Draft(line: line, currencyCode: "PEN", locale: peru)
            #expect(draft.line(locale: peru) == line)
        }
    }

    @Test("Cambiar de tipo no pierde lo elegido, y al guardar cada tipo se lleva solo lo suyo")
    func switchingKindKeepsBothPicks() {
        var draft = E.Draft(line: piaLines[0], currencyCode: "PEN", locale: posix)
        draft.kind = .expense
        draft.subcategoryID = comisiones
        let asExpense = draft.line(locale: posix)
        #expect(asExpense.kind == .expense)
        #expect(asExpense.subcategoryID == comisiones)
        #expect(asExpense.destinationAccountID == nil)

        draft.kind = .transfer
        let asTransfer = draft.line(locale: posix)
        #expect(asTransfer.destinationAccountID == sip)
        #expect(asTransfer.subcategoryID == nil)
    }

    @Test("«Guardar línea»: importe válido y lo que pide su tipo, con una cuenta que sirve")
    func canSaveDraft() {
        var draft = E.Draft(id: lineA, suggestedAmount: 500, currencyCode: "PEN", locale: posix)
        #expect(!E.canSave(draft, currencyCode: "PEN", locale: posix, destinations: [sip: sipOK])) // gasto sin categoría

        draft.kind = .transfer
        #expect(!E.canSave(draft, currencyCode: "PEN", locale: posix, destinations: [sip: sipOK])) // recarga sin cuenta
        draft.destinationAccountID = sip
        #expect(E.canSave(draft, currencyCode: "PEN", locale: posix, destinations: [sip: sipOK]))
        // La misma cuenta, en otra divisa que el gasto: no.
        let usd = E.DestinationInfo(currencyCode: "USD", isSystemAccount: false, isArchived: false)
        #expect(!E.canSave(draft, currencyCode: "PEN", locale: posix, destinations: [sip: usd]))

        for bad in ["", "0", "abc", "1.005"] {
            draft.amountText = bad
            #expect(!E.canSave(draft, currencyCode: "PEN", locale: posix, destinations: [sip: sipOK]), "importe «\(bad)»")
        }
    }

    @Test("Un importe con decimales en una divisa sin decimales no se guarda")
    func yenHasNoDecimals() {
        var draft = E.Draft(id: lineA, suggestedAmount: nil, currencyCode: "JPY", locale: posix)
        draft.kind = .expense
        draft.subcategoryID = comisiones
        draft.amountText = "100.5"
        #expect(!E.canSave(draft, currencyCode: "JPY", locale: posix, destinations: [:]))
        draft.amountText = "100"
        #expect(E.canSave(draft, currencyCode: "JPY", locale: posix, destinations: [:]))
    }
}

// MARK: - 4 · Importe ↔ texto

@Suite("Tu parte en líneas · importe y texto")
@MainActor
struct GroupSplitLinesAmountTextTests {

    @Test("500 + 10 tecleados dan 510 exacto, sin pasar por Double")
    func exactSum() throws {
        let a = try #require(E.decimal(from: "0.1", locale: posix))
        let b = try #require(E.decimal(from: "0.2", locale: posix))
        #expect(a + b == Decimal(string: "0.3"))
    }

    @Test("Lee los separadores del idioma",
          arguments: [
            ("1,234.50", posix, "1234.5"),
            ("1.234,50", germany, "1234.5"),
            ("10,5", germany, "10.5"),
            ("10.5", germany, "105"), // en alemán el punto es de miles, como lo trata `AmountInputHelper`
            ("500", peru, "500"),
          ])
    func separators(_ text: String, _ locale: Locale, _ expected: String) {
        #expect(E.decimal(from: text, locale: locale) == Decimal(string: expected, locale: posix))
    }

    @Test("Vacío, letras o dos decimales no son un número", arguments: ["", "  ", "abc", "1.2.3", "-5"])
    func notANumber(_ text: String) {
        #expect(E.decimal(from: text, locale: posix) == nil)
    }

    @Test("El texto del campo: sin decimales si es entero, con los de la divisa si no")
    func fieldText() {
        #expect(E.fieldText(for: 500, currencyCode: "PEN", locale: posix) == "500")
        #expect(E.fieldText(for: Decimal(string: "10.5")!, currencyCode: "PEN", locale: posix) == "10.50")
        #expect(E.fieldText(for: 1234, currencyCode: "PEN", locale: germany) == "1.234")
        #expect(E.fieldText(for: Decimal(string: "1234.5")!, currencyCode: "PEN", locale: germany) == "1.234,50")
    }
}
