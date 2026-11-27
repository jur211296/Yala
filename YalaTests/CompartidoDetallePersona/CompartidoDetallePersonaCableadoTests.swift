//
//  CompartidoDetallePersonaCableadoTests.swift
//  YalaTests
//
//  Lote 2 de Compartido (26-nov-2026): lo que no es un cálculo del detalle de persona. La tarjeta guarda dónde está la
//  persona; Estadísticas junta a la persona y a ti entre grupos; los textos nuevos están en los 16 idiomas y traducidos;
//  y el detalle de GRUPO no pasa ninguna de las piezas nuevas, así que se ve como antes. Lee el código FUENTE.
//

import Foundation
import Testing
@testable import Yala

@Suite("Compartido · detalle de persona: cableado", .serialized)
@MainActor
struct CompartidoDetallePersonaCableadoTests {

    private static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                                  "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repo.appendingPathComponent(path), encoding: .utf8)
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = repo.appendingPathComponent("Yala/Resources/\(locale).lproj/Compartido.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
    }

    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let range = line.range(of: "//") else { return String(line) }
                return String(line[..<range.lowerBound])
            }
            .joined(separator: "\n")
    }

    // MARK: - Membresías

    @Test("La tarjeta de la persona guarda su fila en cada grupo, en el orden de la lista")
    func person_keepsItsMemberships() throws {
        typealias People = CompartidoPersonasLogic
        let me = People.Member(id: "yo", name: "Tú", accountKey: nil)
        let result = People.people(from: [
            People.GroupInput(
                groupKey: "cusco", groupName: "Viaje a Cusco",
                members: [me, People.Member(id: "b1", name: "Beto", accountKey: "u:beto")],
                myMemberIDs: ["yo"], debts: [Debt(fromMemberID: "b1", toMemberID: "yo", amount: 10, currencyCode: "PEN")],
                interactedMemberIDs: ["b1"]),
            People.GroupInput(
                groupKey: "dos", groupName: "Beto", isPerson: true,
                members: [me, People.Member(id: "b2", name: "Beto", accountKey: "u:beto")],
                myMemberIDs: ["yo"], debts: [Debt(fromMemberID: "yo", toMemberID: "b2", amount: 3, currencyCode: "PEN")],
                interactedMemberIDs: ["b2"]),
        ], noGroupLabel: "Sin grupo")
        let beto = try #require(result.active.first)
        #expect(beto.memberships == [
            .init(groupKey: "cusco", memberID: "b1", isPerson: false),
            .init(groupKey: "dos", memberID: "b2", isPerson: true),
        ])
    }

    // MARK: - Estadísticas

    @Test("Con alias, «¿Quién puso más?» y «Mi parte» juntan a cada uno entre grupos")
    func stats_aliasesMergeMembersAcrossGroups() {
        let yo1 = SplitMember(groupZoneID: "g1", displayName: "Lucía", isCurrentUser: true)
        let beto1 = SplitMember(groupZoneID: "g1", displayName: "Beto")
        let yo2 = SplitMember(groupZoneID: "g2", displayName: "Lucía", isCurrentUser: true)
        let beto2 = SplitMember(groupZoneID: "g2", displayName: "Beto")
        let e1 = SplitExpense(groupZoneID: "g1", amount: 100, currencyCode: "PEN", paidByMemberID: beto1.id.uuidString)
        let e2 = SplitExpense(groupZoneID: "g2", amount: 60, currencyCode: "PEN", paidByMemberID: beto2.id.uuidString)
        let e3 = SplitExpense(groupZoneID: "g2", amount: 40, currencyCode: "PEN", paidByMemberID: yo2.id.uuidString)
        let shares = [
            SplitShare(expenseID: e1.id, memberID: yo1.id.uuidString, amount: 50),
            SplitShare(expenseID: e1.id, memberID: beto1.id.uuidString, amount: 50),
            SplitShare(expenseID: e2.id, memberID: yo2.id.uuidString, amount: 30),
            SplitShare(expenseID: e2.id, memberID: beto2.id.uuidString, amount: 30),
            SplitShare(expenseID: e3.id, memberID: yo2.id.uuidString, amount: 20),
            SplitShare(expenseID: e3.id, memberID: beto2.id.uuidString, amount: 20),
        ]
        let aliases = [
            yo2.id.uuidString: yo1.id.uuidString, yo1.id.uuidString: yo1.id.uuidString,
            beto2.id.uuidString: beto1.id.uuidString, beto1.id.uuidString: beto1.id.uuidString,
        ]
        let model = GroupStatsViewModel()
        model.loadStats(
            expenses: [e1, e2, e3], shares: shares, members: [yo1, beto1, yo2, beto2], settlements: [],
            currentUserMemberID: yo1.id.uuidString, currencyCode: "PEN", memberAliases: aliases)

        #expect(model.memberSpending.count == 2)
        #expect(model.memberSpending.first?.id == beto1.id.uuidString)
        #expect(model.memberSpending.first?.totalPaid == 160)
        #expect(model.memberSpending.last?.totalPaid == 40)
        #expect(model.myPortion == 100)
    }

    @Test("Sin alias, Estadísticas del grupo cuenta como siempre: cada fila es ella misma")
    func stats_withoutAliases_unchanged() {
        let yo = SplitMember(groupZoneID: "g", displayName: "Lucía", isCurrentUser: true)
        let beto = SplitMember(groupZoneID: "g", displayName: "Beto")
        let e1 = SplitExpense(groupZoneID: "g", amount: 100, currencyCode: "PEN", paidByMemberID: beto.id.uuidString)
        let model = GroupStatsViewModel()
        model.loadStats(
            expenses: [e1], shares: [SplitShare(expenseID: e1.id, memberID: yo.id.uuidString, amount: 50)],
            members: [yo, beto], settlements: [], currentUserMemberID: yo.id.uuidString, currencyCode: "PEN")
        #expect(model.memberSpending.map(\.totalPaid) == [100])
        #expect(model.myPortion == 50)
    }

    // MARK: - El detalle de grupo, igual

    @Test("El detalle de grupo no pasa ninguna pieza nueva: Gastos, Saldos y Estadísticas se ven como antes")
    func groupDetail_passesNoneOfTheNewPieces() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Groups/GroupDetailView.swift"))
        for piece in ["header:", "rowTag:", "currentMemberIDForExpense:", "memberAliases:", "filterAccessory:",
                      "extraSection:", "heroTitle:"] {
            #expect(!code.contains(piece), "GroupDetailView pasa «\(piece)»")
        }
    }

    @Test("La tarjeta de Personas empuja el detalle de la persona")
    func peopleCard_opensThePersonDetail() throws {
        let container = Self.codeOnly(try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift"))
        #expect(container.contains("onOpen: { openedPerson = $0 }"))
        #expect(container.contains(".compartidoPersonDestination("))
        let pieces = Self.codeOnly(try Self.source("Yala/App/Views/Compartido/CompartidoPersonDetailPieces.swift"))
        #expect(pieces.contains("CompartidoPersonDetailView("))
        #expect(pieces.contains(".id(opened.id)"))
    }

    @Test("Saldar con un grupo elegido va por el formulario de siempre, y «Saldar todo» por el mismo servicio")
    func settling_usesTheExistingPaths() throws {
        let view = Self.codeOnly(try Self.source("Yala/App/Views/Compartido/CompartidoPersonDetailView.swift"))
        #expect(view.contains("SettlementFormView("))
        #expect(view.contains("GroupExpenseService.shared.createSettlement("))
        #expect(view.contains("SettlementSaldar23Logic.confirmsOnRecord("))
        #expect(view.contains("GroupBalancesView("))
        #expect(view.contains("GroupRecordsView("))
        #expect(view.contains("GroupStatsView("))
        #expect(view.contains("GroupExpenseComposerView("))
    }

    // MARK: - Textos

    @Test("Los textos del detalle están en los 16 idiomas, con los mismos huecos que el español")
    func detailStrings_inEveryLanguage() throws {
        let spanish = try Self.table("es").filter { $0.key.hasPrefix("compartido.detail.") }
        #expect(spanish.count == 29)
        func holes(_ text: String) -> Int {
            text.components(separatedBy: "%").count - 1
        }
        for locale in Self.locales {
            let table = try Self.table(locale)
            for (key, value) in spanish {
                let translated = try #require(table[key], "\(locale) sin \(key)")
                #expect(!translated.isEmpty, "\(locale) \(key) vacío")
                #expect(holes(translated) == holes(value), "\(locale) \(key): huecos distintos")
            }
        }
    }

    @Test("Los textos están traducidos, no copiados del español")
    func detailStrings_areTranslated() throws {
        let spanish = try Self.table("es")
        for locale in ["en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt", "pt-BR", "pt-PT", "zh-Hans"] {
            let table = try Self.table(locale)
            #expect(table["compartido.detail.filter.all"] != spanish["compartido.detail.filter.all"], "\(locale)")
            #expect(table["compartido.detail.settle.all"] != spanish["compartido.detail.settle.all"], "\(locale)")
        }
    }

    @Test("Los textos nuevos viven en la tabla de Compartido, no en Localizable")
    func detailStrings_notInLocalizable() throws {
        let url = Self.repo.appendingPathComponent("Yala/Resources/es.lproj/Localizable.strings")
        let localizable = try String(contentsOf: url, encoding: .utf8)
        #expect(!localizable.contains("compartido.detail."))
    }
}
