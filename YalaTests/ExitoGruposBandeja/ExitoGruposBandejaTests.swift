//
//  ExitoGruposBandejaTests.swift
//  YalaTests
//
//  El éxito minimalista de Grupos y de la Bandeja (encargo del 2026-11-24): qué filas lleva cada tarjeta y en qué orden,
//  qué va grande al aprobar varios, el color del check, los textos nuevos en los 16 idiomas y que las tres pantallas
//  siguen montadas sobre las piezas comunes sin perder los arreglos de antes (la oferta al guardar, la verdad del
//  puente, los ids que usan las pruebas).
//

import Foundation
import Testing
@testable import Yala

@Suite("Éxito minimalista · Grupos")
struct ExitoGruposTests {

    @Test("La tarjeta va en orden: grupo, quién pagó, fecha, categoría, cuenta y reparto")
    func fields_areInOrder() {
        let all = GroupExpenseSuccessFieldOrder.fields(hasSubcategory: true, hasAccount: true, outcome: .none)
        #expect(all == [.group, .paidBy, .date, .subcategory, .account, .split])
    }

    @Test("Sin categoría ni cuenta, esas filas no salen")
    func fields_withoutOptionals() {
        let fields = GroupExpenseSuccessFieldOrder.fields(hasSubcategory: false, hasAccount: false,
                                                          outcome: .shareAsGroupExpense(amount: 40))
        #expect(fields == [.group, .paidBy, .date, .split])
    }

    @Test("Si el bloque ya dice «−S/ X en Cuenta», la fila de la cuenta no lo repite")
    func accountRow_hiddenWhenChargedToAccount() {
        let charged = GroupExpenseSuccessFieldOrder.fields(hasSubcategory: true, hasAccount: true,
                                                           outcome: .chargedToAccount(accountName: "Soles"))
        #expect(!charged.contains(.account))
        #expect(GroupExpenseSuccessFieldOrder.showsAccountRow(hasAccount: true, outcome: .waitingInInbox))
        #expect(!GroupExpenseSuccessFieldOrder.showsAccountRow(hasAccount: false, outcome: .none))
    }

    @Test("El check y el monto van en el color de un gasto, o de un ingreso si es venta")
    func tint_followsSale() {
        #expect(GroupExpenseSuccessLogic.tint(isSale: false) == .expense)
        #expect(GroupExpenseSuccessLogic.tint(isSale: true) == .income)
    }

    @Test("La línea de tu parte: te deben, debes o nada pendiente")
    func debtTone() {
        #expect(GroupExpenseSuccessLogic.debtTone(.theyOweMe(80)) == .owedToMe)
        #expect(GroupExpenseSuccessLogic.debtTone(.iOwe(40)) == .iOwe)
        #expect(GroupExpenseSuccessLogic.debtTone(.settled) == .settled)
    }
}

@Suite("Éxito minimalista · Bandeja")
struct ExitoBandejaTests {

    @Test("Aprobar uno: fecha, cuenta y categoría; sin categoría, solo fecha y cuenta")
    func singleFields() {
        #expect(InboxApproveSuccessLogic.fields(hasCategory: true) == [.date, .account, .category])
        #expect(InboxApproveSuccessLogic.fields(hasCategory: false) == [.date, .account])
    }

    @Test("Varios con una sola moneda: lo grande es el total")
    func bulk_totalWhenSameCurrency() {
        #expect(InboxApproveSuccessLogic.bulkFigure(total: 60.5, currencyCode: "PEN", approvedCount: 2)
                == .total(60.5, currencyCode: "PEN"))
    }

    @Test("Varios con monedas distintas (sin total): lo grande es cuántos")
    func bulk_countWhenMixedCurrencies() {
        #expect(InboxApproveSuccessLogic.bulkFigure(total: nil, currencyCode: nil, approvedCount: 3) == .count(3))
    }

    @Test("Nada guardado: ni total ni check; es un aviso con el cero")
    func bulk_nothingSaved() {
        #expect(InboxApproveSuccessLogic.bulkFigure(total: 0, currencyCode: "PEN", approvedCount: 0) == .count(0))
        #expect(!InboxApproveSuccessLogic.bulkSavedSomething(approvedCount: 0))
        #expect(InboxApproveSuccessLogic.bulkSavedSomething(approvedCount: 1))
    }
}

@Suite("Éxito minimalista · textos")
struct ExitoGruposBandejaTextosTests {

    static let locales = ["es-419", "es", "es-AR", "es-ES", "en", "en-GB", "pt-BR", "pt-PT", "pt", "fr", "de", "it",
                          "ja", "nl", "pl", "zh-Hans"]

    private static var resources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Yala/Resources")
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = resources.appendingPathComponent("\(locale).lproj/ExitoGruposBandeja.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String], "\(locale) no es una tabla de textos")
    }

    private static func placeholders(_ text: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: "%(lld|@|d)")
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    @Test("Las 16 tablas tienen las mismas claves y los mismos huecos que es-419", arguments: locales)
    func parity(locale: String) throws {
        let base = try Self.table("es-419")
        let other = try Self.table(locale)
        #expect(Set(other.keys) == Set(base.keys), "\(locale) no tiene las mismas claves")
        for (key, value) in base {
            let translated = try #require(other[key])
            #expect(!translated.isEmpty, "\(locale) · \(key) vacío")
            #expect(try Self.placeholders(translated) == Self.placeholders(value), "\(locale) · \(key) cambia los huecos")
        }
    }

    @Test("es-419 dice lo que se pidió, sin signos de exclamación")
    func neutralSpanish() throws {
        let es = try Self.table("es-419")
        #expect(es["exitoGB.group.title.expenseCreated"] == "Gasto agregado")
        #expect(es["exitoGB.group.title.saleCreated"] == "Venta agregada")
        #expect(es["exitoGB.group.paidByMe"] == "Pagaste tú")
        #expect(es.values.allSatisfy { !$0.contains("¡") && !$0.contains("!") })
    }

    @Test("Una venta lo dice en el título (lo que mira GroupSaleUITests)")
    func saleTitle_saysSale() throws {
        let es = try Self.table("es-419")
        #expect(try #require(es["exitoGB.group.title.saleCreated"]).localizedCaseInsensitiveContains("venta"))
        #expect(try #require(es["exitoGB.group.title.saleUpdated"]).localizedCaseInsensitiveContains("venta"))
    }
}

@Suite("Éxito minimalista · cableado (source-scan)")
struct ExitoGruposBandejaCableadoTests {

    private static func code(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        return text.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    static let views = ["Yala/App/Views/Groups/GroupExpenseSuccessView.swift",
                        "Yala/App/Views/Inbox/InboxApproveSuccessView.swift",
                        "Yala/App/Views/Inbox/InboxBulkApproveSuccessView.swift"]

    @Test("Las tres pantallas montan el esqueleto y el pie comunes, sin confeti ni círculo grande", arguments: views)
    func usesTheMinimalParts(file: String) throws {
        let code = try Self.code(file)
        #expect(code.contains("MinimalSuccessLayout("))
        #expect(code.contains("MinimalSuccessFooter("))
        #expect(code.contains("MinimalSuccessTitle("))
        #expect(!code.contains("ConfettiView"))
        #expect(!code.contains("RadialGradient"))
    }

    @Test("Grupos: la línea del dinero sigue saliendo de lo que el puente confirmó, y conserva sus ids")
    func groups_keepsTruthAndIds() throws {
        let code = try Self.code(Self.views[0])
        #expect(code.contains("switch data.personalOutcome"))
        for id in ["group_expense_success_edit", "group_expense_success_accept", "group_expense_success_add_another",
                   "group_expense_success_title", "group_expense_success_debt_line", "group_expense_success_money_line",
                   "group_expense_success_split"] {
            #expect(code.contains("\"\(id)\""), "Falta el id \(id)")
        }
        let form = try Self.code("Yala/App/Views/Groups/GroupExpenseFormView.swift")
        #expect(form.contains("GroupExpenseSuccessLogic.confirmedOutcome("), "El formulario ya no confirma contra el puente.")
    }

    @Test("Bandeja: las dos pantallas siguen pidiendo la oferta al guardar y conservan sus ids")
    func inbox_keepsTrialMomentAndIds() throws {
        let single = try Self.code(Self.views[1])
        let bulk = try Self.code(Self.views[2])
        #expect(single.contains("TrialOfferMoments.noteRecordSaved()"))
        #expect(bulk.contains("if savedSomething { TrialOfferMoments.noteRecordSaved() }"))
        #expect(single.contains("\"inbox_success_accept\""))
        for id in ["inbox_bulk_success_back", "inbox_bulk_success_records", "inbox_bulk_success_summary",
                   "inbox_bulk_success_leftover", "inbox_bulk_success_duplicates"] {
            #expect(bulk.contains("\"\(id)\""), "Falta el id \(id)")
        }
    }

    @Test("Los botones del pie van lado a lado y, si no caben, uno debajo del otro")
    func footer_fallsBackToAStack() throws {
        let parts = try Self.code("Yala/App/Views/Shared/MinimalSuccessParts.swift")
        let footer = try #require(parts.range(of: "struct MinimalSuccessFooter"))
        let body = parts[footer.upperBound...]
        #expect(body.contains("ViewThatFits(in: .horizontal)"))
    }
}
