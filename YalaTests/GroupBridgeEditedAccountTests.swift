//
//  GroupBridgeEditedAccountTests.swift
//  YalaTests
//
//  Card 8933 (2026-11-02) · al EDITAR un gasto de grupo que pagaste y elegir otra cuenta, el registro pasa a esa cuenta.
//  Hasta ese día el puente («preserve+update» del Caso A) no tocaba nunca la cuenta: la pastilla del formulario decía
//  «Cuenta B» y el dinero seguía saliendo de la A. Con otra moneda, el registro se borraba y quedaba un borrador en la
//  Bandeja aunque la cuenta elegida ya fuera de esa moneda.
//
//  Cada caso lleva su control con `isRemoteSync: true`: un cambio que baja de otro teléfono sigue sin mover la cuenta.
//  Montaje: el de `GroupJoinerBridgeReachesRealAccountTests` (on-disk, tres stores, `shouldSave: false`), con
//  `autosaveEnabled = false` y el contexto del singleton soltado al salir (regla de `testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · editar la cuenta de un gasto que pagaste mueve tu registro", .serialized)
@MainActor
struct GroupBridgeEditedAccountTests {

    // MARK: - La decisión, pura

    @Test("la decisión: solo la cuenta elegida al editar, de la moneda del gasto, mueve o rehace el registro")
    func decisionTable() {
        let a = UUID(), b = UUID()
        typealias L = GroupBridgeEditedAccountLogic
        // Misma moneda.
        #expect(L.decide(isRemoteSync: false, recordAccountID: a, recordCurrency: "USD",
                         chosenAccountID: a, chosenAccountCurrency: "USD", expenseCurrency: "USD") == .keep)
        #expect(L.decide(isRemoteSync: false, recordAccountID: a, recordCurrency: "USD",
                         chosenAccountID: b, chosenAccountCurrency: "USD", expenseCurrency: "USD") == .move)
        #expect(L.decide(isRemoteSync: true, recordAccountID: a, recordCurrency: "USD",
                         chosenAccountID: b, chosenAccountCurrency: "USD", expenseCurrency: "USD") == .keep)
        #expect(L.decide(isRemoteSync: false, recordAccountID: a, recordCurrency: "USD",
                         chosenAccountID: nil, chosenAccountCurrency: nil, expenseCurrency: "USD") == .keep)
        // Una cuenta de otra moneda no mueve nada (el formulario no la deja elegir; el puente tampoco).
        #expect(L.decide(isRemoteSync: false, recordAccountID: a, recordCurrency: "USD",
                         chosenAccountID: b, chosenAccountCurrency: "PEN", expenseCurrency: "USD") == .keep)
        // Moneda nueva.
        #expect(L.decide(isRemoteSync: false, recordAccountID: a, recordCurrency: "USD",
                         chosenAccountID: b, chosenAccountCurrency: "PEN", expenseCurrency: "PEN") == .recreateInChosenAccount)
        #expect(L.decide(isRemoteSync: true, recordAccountID: a, recordCurrency: "USD",
                         chosenAccountID: b, chosenAccountCurrency: "PEN", expenseCurrency: "PEN") == .currencyDraft)
        #expect(L.decide(isRemoteSync: false, recordAccountID: a, recordCurrency: "USD",
                         chosenAccountID: nil, chosenAccountCurrency: nil, expenseCurrency: "PEN") == .currencyDraft)
    }

    // MARK: - Montaje

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditedAccount-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupBridgeEditedAccountTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "EA-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "EA-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "EA-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private struct Escena {
        let group: SplitGroup
        let expense: SplitExpense
        let efectivo: Account   // USD
        let banco: Account      // USD
        let soles: Account      // PEN
    }

    private func cuenta(_ nombre: String, _ moneda: String, _ context: ModelContext) -> Account {
        let account = Account(name: nombre, currencyCode: moneda, colorHex: "#111111", iconName: "banknote", type: "cash")
        context.insert(account)
        return account
    }

    /// Caso A: lo pago yo, mitad y mitad con Ana, y el registro ya está en «Efectivo».
    private func montar(_ context: ModelContext) throws -> Escena {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        context.insert(group)
        let yo = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(yo)
        context.insert(ana)
        let efectivo = cuenta("Efectivo", "USD", context)
        let banco = cuenta("Banco", "USD", context)
        let soles = cuenta("Soles", "PEN", context)
        let expense = SplitExpense(groupZoneID: group.cloudKitZoneID, amount: 100, currencyCode: "USD",
                                   expenseDescription: "Cena", paidByMemberID: yo.id.uuidString)
        context.insert(expense)
        for (miembro, monto) in [(yo, 50.0), (ana, 50.0)] {
            context.insert(SplitShare(expenseID: expense.id, memberID: miembro.id.uuidString,
                                      amount: monto, groupZoneID: group.cloudKitZoneID))
        }
        try context.save()
        return Escena(group: group, expense: expense, efectivo: efectivo, banco: banco, soles: soles)
    }

    private func conPuente(_ context: ModelContext, _ body: () throws -> Void) throws {
        GroupTransactionBridge.shared.setContext(context)
        let sesiónPrivadaPrevia = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.hasPrivateSession = sesiónPrivadaPrevia
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
            GroupTransactionBridge.shared._testClearContext()
        }
        try body()
    }

    private func puentear(_ e: Escena, cuenta: Account?, remoto: Bool, _ context: ModelContext) throws {
        let atendido = try GroupTransactionBridge.shared.bridgeExpense(
            e.expense, in: e.group, accountForCurrentUser: cuenta, isRemoteSync: remoto, shouldSave: false)
        #expect(atendido)
        try context.save()
    }

    private func registrosReales(_ e: Escena, _ context: ModelContext) throws -> [TransactionItem] {
        let id = e.expense.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == id }))
            .filter { $0.account?.isSystemAccount == false }
    }

    /// Solo los borradores «cambió la moneda»: el de clasificar la categoría (Enfoque B) puede salir igual, sin categoría.
    private func borradoresDeMoneda(_ e: Escena, _ context: ModelContext) throws -> Int {
        let id = e.expense.id.uuidString
        let reason = DraftOriginReason.currencyChanged.rawValue
        return try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitExpenseID == id }))
            .filter { $0.originReasonKey == reason }.count
    }

    // MARK: - Misma moneda

    @Test("misma moneda: editar con otra cuenta mueve el registro; el control remoto lo deja donde estaba")
    func sameCurrency_moveToTheChosenAccount() throws {
        for remoto in [false, true] {
            let dir = try freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let e = try montar(context)
            try conPuente(context) {
                try puentear(e, cuenta: e.efectivo, remoto: false, context)
                let antes = try #require(try registrosReales(e, context).first)
                #expect(antes.account?.shortcutID == e.efectivo.shortcutID)
                antes.note = "nota mía"

                // La persona edita el gasto (importe nuevo) y elige «Banco».
                e.expense.amount = 120
                try context.save()
                try puentear(e, cuenta: e.banco, remoto: remoto, context)

                let despues = try registrosReales(e, context)
                #expect(despues.count == 1, "un solo registro real, no uno por cuenta")
                let registro = try #require(despues.first)
                #expect(registro.account?.shortcutID == (remoto ? e.efectivo : e.banco).shortcutID,
                        "remoto=\(remoto): la cuenta del registro no es la esperada")
                #expect(registro.amount == -120)
                #expect(registro.note == "nota mía", "mover la cuenta no puede llevarse la nota del registro")
            }
        }
    }

    // MARK: - Moneda nueva

    @Test("moneda nueva con una cuenta de esa moneda: el registro se rehace en ella, sin borrador en la Bandeja")
    func newCurrency_recreatesInTheChosenAccount() throws {
        for remoto in [false, true] {
            let dir = try freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let e = try montar(context)
            try conPuente(context) {
                try puentear(e, cuenta: e.efectivo, remoto: false, context)
                #expect(try borradoresDeMoneda(e, context) == 0)
                try #require(try registrosReales(e, context).first).note = "nota mía"

                e.expense.currencyCode = "PEN"
                try context.save()
                try puentear(e, cuenta: e.soles, remoto: remoto, context)

                let despues = try registrosReales(e, context)
                if remoto {
                    // Control: lo de antes — el registro se va y queda el borrador «cambió la moneda».
                    #expect(despues.isEmpty)
                    #expect(try borradoresDeMoneda(e, context) == 1)
                } else {
                    let registro = try #require(despues.first)
                    #expect(despues.count == 1)
                    #expect(registro.account?.shortcutID == e.soles.shortcutID)
                    #expect(registro.currencyCode == "PEN")
                    #expect(registro.amount == -100)
                    #expect(try borradoresDeMoneda(e, context) == 0, "con la cuenta ya elegida no hay nada que pedir")
                    #expect(registro.note == "nota mía", "rehacer el registro es cambiarlo de cuenta, no empezar de cero")
                }
            }
        }
    }
}
