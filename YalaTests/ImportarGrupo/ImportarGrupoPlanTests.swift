//
//  ImportarGrupoPlanTests.swift
//  YalaTests
//
//  De los saldos del export a los saldos iniciales: el plan reproduce EXACTO el saldo de cada persona, el emparejamiento
//  solo crea lo que tiene a sus dos personas, y lo que espera sobrevive entre arranques y a un fallo a mitad.
//

import Foundation
import Testing
@testable import Yala

@Suite("Importar grupo · plan de saldos iniciales")
struct ImportarGrupoPlanTests {

    private func nonZero(_ balances: [String: [String: Int]]) -> [String: [String: Int]] {
        balances.mapValues { $0.filter { $0.value != 0 } }.filter { !$0.value.isEmpty }
    }

    @Test(arguments: [
        ImportarGrupoFixtures.splitwiseCusco, ImportarGrupoFixtures.splitwiseTwoCurrencies,
        ImportarGrupoFixtures.splitwiseSemicolonComma, ImportarGrupoFixtures.tricountPerPerson,
        ImportarGrupoFixtures.tricountList, ImportarGrupoFixtures.tricountShareInDefaultCurrency,
    ])
    func elPlan_dejaACadaPersonaConSuSaldo(_ fixture: String) throws {
        let snapshot = try ImportedGroupSnapshotBuilder.snapshot(fromCSV: fixture, fileName: nil)
        let debts = ImportedDebtPlanLogic.debts(from: snapshot.balances)
        #expect(nonZero(ImportedDebtPlanLogic.balances(after: debts)) == nonZero(snapshot.balances))
        // Como mucho una arista menos que personas con saldo, por moneda, y nunca dos para la misma pareja.
        for currency in snapshot.currencies {
            let edges = debts.filter { $0.currency == currency }
            let people = (snapshot.balances[currency] ?? [:]).filter { $0.value != 0 }.count
            #expect(edges.count <= max(0, people - 1))
            #expect(Set(edges.map { "\($0.debtor)>\($0.creditor)" }).count == edges.count)
            #expect(edges.allSatisfy { $0.cents > 0 })
        }
    }

    @Test func cusco_aristasConcretas() throws {
        let snapshot = try ImportedGroupSnapshotBuilder.snapshot(fromCSV: ImportarGrupoFixtures.splitwiseCusco, fileName: nil)
        let debts = ImportedDebtPlanLogic.debts(from: snapshot.balances)
        #expect(debts == [
            ImportedDebt(debtor: "Pia", creditor: "Jürgen", currency: "PEN", cents: 9_000),
            ImportedDebt(debtor: "Ana", creditor: "Jürgen", currency: "PEN", cents: 2_000),
        ])
    }

    @Test func mismoExport_mismasAristas() {
        let balances = ["USD": ["A": 500, "B": 500, "C": -500, "D": -500]]
        #expect(ImportedDebtPlanLogic.debts(from: balances) == ImportedDebtPlanLogic.debts(from: balances))
        #expect(ImportedDebtPlanLogic.debts(from: balances).map(\.debtor) == ["C", "D"])
    }

    @Test func elIdDeUnaArista_noChocaConNombresQueLlevanSeparadores() {
        let a = ImportedDebt(debtor: "A|B", creditor: "C", currency: "USD", cents: 1)
        let b = ImportedDebt(debtor: "A", creditor: "B|C", currency: "USD", cents: 1)
        #expect(a.id != b.id)
    }

    @Test func aplicables_soloConLasDosPersonasActivas_yDistintas() {
        let debts = [
            ImportedDebt(debtor: "Ana", creditor: "Yo", currency: "PEN", cents: 100),
            ImportedDebt(debtor: "Luis", creditor: "Yo", currency: "PEN", cents: 200),
            ImportedDebt(debtor: "Pia", creditor: "Yo", currency: "PEN", cents: 300),
        ]
        let ready = ImportedDebtPlanLogic.applicable(
            debts: debts,
            mapping: ["Yo": "m1", "Ana": "m2", "Luis": "m-inactivo", "Pia": "m1"],
            applied: [],
            activeMemberIDs: ["m1", "m2"])
        #expect(ready.map(\.debt.debtor) == ["Ana"])
        #expect(ready.first?.debtorMemberID == "m2")
        #expect(ready.first?.creditorMemberID == "m1")

        let none = ImportedDebtPlanLogic.applicable(
            debts: debts, mapping: ["Yo": "m1", "Ana": "m2"], applied: [debts[0].id], activeMemberIDs: ["m1", "m2"])
        #expect(none.isEmpty)
    }

    @Test func pendientes_enElOrdenDelExport() {
        let debts = [
            ImportedDebt(debtor: "Pia", creditor: "Yo", currency: "PEN", cents: 1),
            ImportedDebt(debtor: "Ana", creditor: "Yo", currency: "PEN", cents: 1),
        ]
        let people = ["Yo", "Ana", "Luis", "Pia"]
        // Sin nadie emparejado: los dos de la arista que espera.
        #expect(ImportedDebtPlanLogic.pendingPeople(debts: debts, applied: [debts[0].id], people: people, mapping: [:])
                == ["Yo", "Ana"])
        // «Yo» ya emparejado no sale aunque su arista espere a Ana.
        #expect(ImportedDebtPlanLogic.pendingPeople(debts: debts, applied: [debts[0].id], people: people,
                                                    mapping: ["Yo": "m1"]) == ["Ana"])
        // Emparejado con un miembro que ya no está activo, vuelve a faltar.
        #expect(ImportedDebtPlanLogic.pendingPeople(debts: debts, applied: [debts[0].id], people: people,
                                                    mapping: ["Yo": "m1", "Ana": "m2"], activeMemberIDs: ["m1"]) == ["Ana"])
    }

    @Test func propuestas_soloConUnaCoincidenciaClara() {
        let members = [("m1", "Ana María"), ("m2", "luis"), ("m3", "Pía"), ("m4", "Pia")]
            .map { (id: $0.0, name: $0.1) }
        let suggested = ImportedDebtPlanLogic.suggestedMatches(
            people: ["Yo", "Luis", "Pia", "Ana"], members: members, alreadyMapped: ["Yo": "m9"])
        // Luis casa sin mayúsculas; Pia tiene dos miembros con su nombre (con y sin tilde): no se propone; Ana no casa.
        #expect(suggested == ["Luis": "m2"])
    }
}

@MainActor
@Suite("Importar grupo · lo que espera y su aplicación", .serialized)
struct ImportarGrupoPendienteTests {

    private func tempStore() -> (PendingGroupImportStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appending(path: "GroupImportsTests-\(UUID().uuidString)")
        return (PendingGroupImportStore(directory: dir), dir)
    }

    private func removeDirectory(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            print("ImportarGrupoPendienteTests: Error: \(error)")
        }
    }

    private func cusco() throws -> ImportedGroupSnapshot {
        try ImportedGroupSnapshotBuilder.snapshot(fromCSV: ImportarGrupoFixtures.splitwiseCusco, fileName: nil)
    }

    @Test func alCrear_yoQuedaEmparejado_yNadaMasSeCrea() throws {
        let (store, dir) = tempStore()
        defer { removeDirectory(dir) }
        var created: [String] = []
        let outcome = PendingGroupImportApplier.start(
            snapshot: try cusco(), me: "Jürgen", zoneID: "SplitGroup-1", ownerMemberID: "owner",
            activeMemberIDs: ["owner"], store: store, now: Date(timeIntervalSince1970: 0)
        ) { debtor, creditor, _, _ in created.append("\(debtor)>\(creditor)") }
        #expect(created.isEmpty)
        #expect(outcome.stillPending == ["Ana", "Pia"])
        #expect(!outcome.isComplete)
        #expect(store.pending(for: "SplitGroup-1")?.mapping == ["Jürgen": "owner"])
        // Sobrevive a un arranque: otra tienda sobre el mismo directorio lo lee.
        #expect(PendingGroupImportStore(directory: dir).pending(for: "SplitGroup-1")?.debts.count == 2)
    }

    @Test func sinAristas_noApuntaNada() throws {
        let (store, dir) = tempStore()
        defer { removeDirectory(dir) }
        let settled = ImportedGroupSnapshot(
            source: .tricount, suggestedName: nil, people: ["A", "B"], expenseCount: 1, paymentCount: 1,
            firstDate: nil, lastDate: nil, balances: ["EUR": ["A": 0, "B": 0]])
        PendingGroupImportApplier.start(
            snapshot: settled, me: "A", zoneID: "z", ownerMemberID: "o", activeMemberIDs: ["o"], store: store
        ) { _, _, _, _ in }
        #expect(store.pending(for: "z") == nil)
    }

    @Test func emparejarPorPartes_hastaCompletar_yLaTiendaSeVacia() throws {
        let (store, dir) = tempStore()
        defer { removeDirectory(dir) }
        var created: [(String, String, Double, String)] = []
        let create: PendingGroupImportApplier.CreateOpeningBalance = { created.append(($0, $1, $2, $3)) }
        PendingGroupImportApplier.start(
            snapshot: try cusco(), me: "Jürgen", zoneID: "z", ownerMemberID: "owner", activeMemberIDs: ["owner"],
            store: store, create: create)

        // Se une Pia.
        let first = PendingGroupImportApplier.apply(
            zoneID: "z", mapping: ["Jürgen": "owner", "Pia": "m-pia"], activeMemberIDs: ["owner", "m-pia"],
            store: store, create: create)
        #expect(first.created == 1)
        #expect(created.count == 1)
        #expect(created[0].0 == "m-pia" && created[0].1 == "owner" && created[0].2 == 90 && created[0].3 == "PEN")
        #expect(first.stillPending == ["Ana"])

        // Repetir con lo mismo no vuelve a crear.
        let again = PendingGroupImportApplier.apply(
            zoneID: "z", activeMemberIDs: ["owner", "m-pia"], store: store, create: create)
        #expect(again.created == 0)

        // Se une Ana: completo, y lo que esperaba se borra.
        let last = PendingGroupImportApplier.apply(
            zoneID: "z", mapping: ["Jürgen": "owner", "Pia": "m-pia", "Ana": "m-ana"],
            activeMemberIDs: ["owner", "m-pia", "m-ana"], store: store, create: create)
        #expect(last.created == 1)
        #expect(last.stillPending.isEmpty)
        #expect(last.isComplete)
        #expect(created.count == 2)
        #expect(created[1].2 == 20)
        #expect(store.pending(for: "z") == nil)
        #expect(PendingGroupImportStore(directory: dir).pending(for: "z") == nil)
    }

    @Test func unFalloAMitad_conservaLoCreado_yNoLoRepite() throws {
        let (store, dir) = tempStore()
        defer { removeDirectory(dir) }
        struct Boom: Error {}
        var calls = 0
        let flaky: PendingGroupImportApplier.CreateOpeningBalance = { _, _, _, _ in
            calls += 1
            if calls == 2 { throw Boom() }
        }
        PendingGroupImportApplier.start(
            snapshot: try cusco(), me: "Jürgen", zoneID: "z", ownerMemberID: "o", activeMemberIDs: ["o"],
            store: store, create: flaky)
        let mapping = ["Jürgen": "o", "Pia": "p", "Ana": "a"]
        let outcome = PendingGroupImportApplier.apply(
            zoneID: "z", mapping: mapping, activeMemberIDs: ["o", "p", "a"], store: store, create: flaky)
        #expect(outcome.failed)
        #expect(outcome.created == 1)
        #expect(store.pending(for: "z")?.applied.count == 1)

        var retried: [String] = []
        let retry = PendingGroupImportApplier.apply(
            zoneID: "z", activeMemberIDs: ["o", "p", "a"], store: store
        ) { debtor, _, _, _ in retried.append(debtor) }
        #expect(!retry.failed)
        #expect(retried == ["a"])
        #expect(store.pending(for: "z") == nil)
    }

    @Test func noEstoyEnElGrupo_nadieEmparejado() throws {
        let (store, dir) = tempStore()
        defer { removeDirectory(dir) }
        PendingGroupImportApplier.start(
            snapshot: try cusco(), me: nil, zoneID: "z", ownerMemberID: "o", activeMemberIDs: ["o"], store: store
        ) { _, _, _, _ in }
        #expect(store.pending(for: "z")?.mapping.isEmpty == true)
    }
}
