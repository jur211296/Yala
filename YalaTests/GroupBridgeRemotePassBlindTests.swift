//
//  GroupBridgeRemotePassBlindTests.swift
//  YalaTests
//
//  Bug del 2026-11-09 (Jürgen, cuenta en la nube, un solo iPhone): gastos de grupo que pagó con cuenta dejaron, días
//  después, un borrador «Jür registró este gasto… Elige cuenta» en la Bandeja (en S/ aunque el gasto era USD) y el
//  «Préstamo a grupos» repetido en Registros.
//
//  Lo medido: con el puente real, la pasada local y la remota convergen en cualquier orden (`ordenNormal_*`). El bug
//  necesita una pasada REMOTA que no vea el registro real ni el préstamo que ya existen —aquí, con las dos patas sin
//  cuenta un instante, como las deja el canal personal al re-aplicar su eco—; y después nadie lo arreglaba: la única
//  limpieza escuchaba solo a iCloud y solo quitaba el borrador.
//
//  Harness ON-DISK con los tres stores (molde `GroupJoinerBridgeReachesRealAccountTests`): el puente escribe en el
//  store personal leyendo del de grupos.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · borrador y préstamo de más tras una pasada ciega del puente", .serialized)
@MainActor
struct GroupBridgeRemotePassBlindTests {

    // MARK: - Montaje

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemotePassBlind-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "RPB-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "RPB-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "RPB-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private struct Escena {
        let group: SplitGroup
        let expense: SplitExpense
        let cuenta: Account
    }

    /// Lo de Jürgen: «Google One» 10,84 USD, pagado por él con su Sapphire en USD, a partes iguales con Pia, con
    /// categoría (por eso el borrador pide solo la cuenta).
    private func montar(_ context: ModelContext) throws -> Escena {
        let category = Category(name: "Personal", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
        context.insert(category)
        let sub = Subcategory(name: "Suscripciones de utilidad", isDefaultSeed: false, category: category)
        context.insert(sub)
        let group = SplitGroup(name: "Jurpi", currencyCode: "PEN")
        context.insert(group)
        let yo = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Jür", isCurrentUser: true)
        let pia = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Pia")
        context.insert(yo)
        context.insert(pia)
        let cuenta = Account(name: "Sapphire", currencyCode: "USD", colorHex: "#111111",
                             iconName: "creditcard", type: "credit")
        context.insert(cuenta)
        let expense = SplitExpense(groupZoneID: group.cloudKitZoneID, amount: 10.84, currencyCode: "USD",
                                   expenseDescription: "Google One", paidByMemberID: yo.id.uuidString,
                                   subcategoryName: sub.name)
        context.insert(expense)
        for m in [yo, pia] {
            context.insert(SplitShare(expenseID: expense.id, memberID: m.id.uuidString, amount: 5.42,
                                      groupZoneID: group.cloudKitZoneID))
        }
        try context.save()
        return Escena(group: group, expense: expense, cuenta: cuenta)
    }

    private func entorno(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let previa = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            context.rollback()
            SessionState.shared.hasPrivateSession = previa
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
            GroupTransactionBridge.shared._testClearContext()
        }
        try body()
    }

    private struct Foto: Equatable {
        var reales: Int
        var prestamos: [Double]
        var borradoresDeCuenta: Int
    }

    private func foto(_ context: ModelContext, _ e: SplitExpense) throws -> Foto {
        let id = e.id.uuidString
        let txs = try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == id }))
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitExpenseID == id }))
        return Foto(
            reales: txs.filter { $0.account?.isSystemAccount == false }.count,
            prestamos: txs.filter { $0.account?.isSystemAccount == true }.map(\.amount).sorted(),
            borradoresDeCuenta: drafts.filter {
                $0.status == .pending && $0.needsUserInput.contains(DraftInputRequirement.account)
            }.count)
    }

    private func altaLocal(_ s: Escena) throws {
        _ = try GroupTransactionBridge.shared.bridgeExpense(
            s.expense, in: s.group, accountForCurrentUser: s.cuenta, isRemoteSync: false, shouldSave: false)
    }

    /// El estado del teléfono de Jürgen: alta local con cuenta, una pasada remota que no ve las dos patas (las dos sin
    /// cuenta en ese instante) y luego las patas recuperan su cuenta.
    private func reproducir(_ context: ModelContext, _ s: Escena) throws {
        try altaLocal(s)
        try context.save()
        let id = s.expense.id.uuidString
        let patas = try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == id }))
        let cuentas = patas.map(\.account)
        for pata in patas { pata.account = nil }
        try context.save()
        _ = try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [s.expense.id])
        for (pata, cuenta) in zip(patas, cuentas) { pata.account = cuenta }
        try context.save()
    }

    // MARK: - El orden normal converge (control)

    @Test("Control: alta local con cuenta y luego la pasada remota → un registro, un préstamo, ningún borrador")
    func ordenNormal_localLuegoRemota() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        try entorno(context) {
            let s = try montar(context)
            try altaLocal(s)
            try context.save()
            _ = try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [s.expense.id])
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42], borradoresDeCuenta: 0))
        }
    }

    @Test("Control: la pasada remota antes que la local también converge")
    func ordenNormal_remotaLuegoLocal() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        try entorno(context) {
            let s = try montar(context)
            _ = try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [s.expense.id])
            try altaLocal(s)
            try context.save()
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42], borradoresDeCuenta: 0))
        }
    }

    // MARK: - La reproducción

    @Test("Una pasada remota que no ve las patas deja el borrador «Elige cuenta» y el préstamo repetido")
    func pasadaCiega_dejaLosDosSintomas() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        try entorno(context) {
            let s = try montar(context)
            try reproducir(context, s)
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42, 5.42], borradoresDeCuenta: 1))
            // El borrador es el de las capturas: «Jür registró este gasto en Jurpi».
            let id = s.expense.id.uuidString
            let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitExpenseID == id })).first)
            #expect(draft.originReasonKey == DraftOriginReason.remoteCreate.rawValue)
            #expect(draft.originActorName == "Jür")
            #expect(draft.account == nil)
        }
    }

    // MARK: - La divisa del borrador

    @Test("La Bandeja pinta el borrador sin cuenta en la divisa del gasto, no en la de por defecto")
    func borradorSinCuenta_seVeEnLaDivisaDelGasto() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        try entorno(context) {
            let s = try montar(context)
            try reproducir(context, s)
            let id = s.expense.id.uuidString
            let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitExpenseID == id })).first)
            #expect(draft.displayCurrencyCode == nil)  // el porqué del bug: sin cuenta, sin divisa propia
            let vm = InboxViewModel()
            vm.setContext(context)
            #expect(vm.displayCurrencyCode(for: draft, fallback: "PEN") == "USD")
        }
    }

    // MARK: - La convergencia

    @Test("Con el registro real a la vista, la limpieza quita el borrador y deja un solo préstamo")
    func convergencia_quitaLoQueSobra() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        try entorno(context) {
            let s = try montar(context)
            try reproducir(context, s)
            let arreglados = try GroupBridgeRaceCleaner.removeLeftovers(in: context, since: nil)
            #expect(arreglados == 1)
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42], borradoresDeCuenta: 0))
            // El registro real no se toca: su cuenta y su importe.
            let id = s.expense.id.uuidString
            let real = try #require(try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID == id })).first { $0.account?.isSystemAccount == false })
            #expect(real.account?.name == "Sapphire")
            #expect(real.amount == -10.84)
        }
    }

    @Test("Idempotente: repetirla, re-sincronizar el gasto y el reintento del arranque no vuelven a ensuciar")
    func convergencia_idempotente() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        try entorno(context) {
            let s = try montar(context)
            try reproducir(context, s)
            try GroupBridgeRaceCleaner.removeLeftovers(in: context, since: nil)
            #expect(try GroupBridgeRaceCleaner.removeLeftovers(in: context, since: nil) == 0)
            // Otra vuelta del canal de Grupos (el eco del gasto).
            _ = try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [s.expense.id])
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42], borradoresDeCuenta: 0))
            // El reintento del arranque (`retryPendingBridges`) puentea igual, sin cuenta y en remoto.
            _ = try GroupTransactionBridge.shared.bridgeExpense(
                s.expense, in: s.group, accountForCurrentUser: nil, isRemoteSync: true, shouldSave: false)
            try context.save()
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42], borradoresDeCuenta: 0))
            #expect(try GroupBridgeRaceCleaner.removeLeftovers(in: context, since: nil) == 0)
        }
    }

    @Test("En la ventana ciega (patas sin cuenta) no decide nada: no hay registro real que lo pruebe")
    func ventanaCiega_noTocaNada() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        try entorno(context) {
            let s = try montar(context)
            try reproducir(context, s)
            let id = s.expense.id.uuidString
            let patas = try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == id }))
            for pata in patas { pata.account = nil }
            try context.save()
            #expect(try GroupBridgeRaceCleaner.removeLeftovers(in: context, since: nil) == 0)
        }
    }

    @Test("Solo lo nuevo: la limpieza automática no toca lo que nació antes del arreglo; el aviso sí lo ve")
    func automatica_soloLoNuevo() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        try entorno(context) {
            let s = try montar(context)
            try reproducir(context, s)
            let since = Date.now.addingTimeInterval(60)  // el arreglo se instaló DESPUÉS de lo que ya había
            #expect(try GroupBridgeRaceCleaner.autoRemoveLeftovers(in: context, isQuiet: true, since: since) == 0)
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42, 5.42], borradoresDeCuenta: 1))
            // Lo que el aviso de la Bandeja cuenta (sin fecha de corte).
            #expect(try GroupBridgeRaceCleaner.leftovers(in: context, since: nil).plan.expenseIDs == [s.expense.id.uuidString])
            // Con el almacén a medias no toca nada, aunque sea nuevo.
            let antes = Date.now.addingTimeInterval(-60)
            #expect(try GroupBridgeRaceCleaner.autoRemoveLeftovers(in: context, isQuiet: false, since: antes) == 0)
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42, 5.42], borradoresDeCuenta: 1))
            // Y lo que nace después del sello, quieto, la automática sí lo quita.
            #expect(try GroupBridgeRaceCleaner.autoRemoveLeftovers(in: context, isQuiet: true, since: antes) == 1)
            #expect(try foto(context, s.expense) == Foto(reales: 1, prestamos: [5.42], borradoresDeCuenta: 0))
        }
    }

    @Test("El sello de «desde cuándo» se pone una vez y no se mueve")
    func sello_unaVez() {
        let defaults = makeIsolatedDefaults(prefix: "leftoverSince")
        let primero = Date(timeIntervalSince1970: 1_000)
        #expect(GroupBridgeRaceCleaner.leftoverAutoSince(defaults: defaults, now: primero) == primero)
        #expect(GroupBridgeRaceCleaner.leftoverAutoSince(defaults: defaults, now: Date(timeIntervalSince1970: 9_000)) == primero)
    }
}

// MARK: - La regla, sin contexto

@Suite("Grupos · qué le sobra al puente (lógica)")
struct GroupBridgeLeftoverLogicTests {

    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func real(_ expense: String = "E") -> GroupBridgeLeftoverLogic.Leg {
        .init(expenseID: expense, accountKey: "sapphire", accountIsSystem: false, isLoanToGroups: false,
              isManagedApart: false, amount: -10.84, currencyCode: "USD", createdAt: t0, tiebreak: "r")
    }

    private func loan(_ expense: String = "E", amount: Double = 5.42, at offset: TimeInterval = 0,
                      tiebreak: String = "a", account: String? = "grupos-usd") -> GroupBridgeLeftoverLogic.Leg {
        .init(expenseID: expense, accountKey: account, accountIsSystem: true, isLoanToGroups: true,
              isManagedApart: false, amount: amount, currencyCode: "USD", createdAt: t0.addingTimeInterval(offset),
              tiebreak: tiebreak)
    }

    private func draft(_ expense: String? = "E", optIn: Bool = false, needsAccount: Bool = true,
                       pending: Bool = true, at offset: TimeInterval = 0) -> GroupBridgeLeftoverLogic.Draft {
        .init(expenseID: expense, isPending: pending, isGroupExpense: true, isOptIn: optIn,
              needsAccount: needsAccount, createdAt: t0.addingTimeInterval(offset))
    }

    @Test("Se queda el préstamo más NUEVO (el que conserva la última pasada); empate, el menor desempate — en cualquier orden")
    func superviviente_determinista() {
        let legs = [loan(at: 0, tiebreak: "b"), loan(at: 10, tiebreak: "z"), real(), loan(at: 10, tiebreak: "c")]
        let plan = GroupBridgeLeftoverLogic.plan(legs: legs, drafts: [], onlyCreatedSince: nil)
        #expect(plan.legIndices == [0, 1])  // sobrevive el índice 3 («c», el menor de los dos más nuevos)
        let invertido = Array(legs.reversed())
        let plan2 = GroupBridgeLeftoverLogic.plan(legs: invertido, drafts: [], onlyCreatedSince: nil)
        #expect(Set(plan2.legIndices.map { invertido[$0].tiebreak }) == ["b", "z"])
    }

    @Test("Las patas que el puente gestiona aparte, las de sistema que no son préstamo y otra divisa no se funden")
    func exclusiones() {
        func leg(isLoan: Bool = true, apart: Bool = false, currency: String = "USD", tiebreak: String) -> GroupBridgeLeftoverLogic.Leg {
            .init(expenseID: "E", accountKey: "grupos", accountIsSystem: true, isLoanToGroups: isLoan, isManagedApart: apart,
                  amount: 5.42, currencyCode: currency, createdAt: t0, tiebreak: tiebreak)
        }
        // Una línea derivada o cobrada junto al préstamo: no es un préstamo repetido.
        #expect(GroupBridgeLeftoverLogic.plan(legs: [leg(tiebreak: "a"), leg(apart: true, tiebreak: "b")],
                                              drafts: [], onlyCreatedSince: nil).isEmpty)
        // Una pata de sistema con otra subcategoría (saldo inicial, por cobrar): tampoco.
        #expect(GroupBridgeLeftoverLogic.plan(legs: [leg(tiebreak: "a"), leg(isLoan: false, tiebreak: "b")],
                                              drafts: [], onlyCreatedSince: nil).isEmpty)
        // Dos préstamos en divisas distintas (el gasto cambió de moneda): no se adivina cuál sobra.
        #expect(GroupBridgeLeftoverLogic.plan(legs: [leg(tiebreak: "a"), leg(currency: "PEN", tiebreak: "b")],
                                              drafts: [], onlyCreatedSince: nil).isEmpty)
        // Control: los dos iguales sí.
        #expect(GroupBridgeLeftoverLogic.plan(legs: [leg(tiebreak: "a"), leg(tiebreak: "b")],
                                              drafts: [], onlyCreatedSince: nil).legIndices == [1])
    }

    @Test("Préstamos con importes distintos no se tocan: no se adivina cuál es el viejo")
    func importesDistintos_noSeTocan() {
        let plan = GroupBridgeLeftoverLogic.plan(
            legs: [loan(amount: 5.42), loan(amount: 6.00, tiebreak: "b")], drafts: [], onlyCreatedSince: nil)
        #expect(plan.isEmpty)
    }

    @Test("El borrador sobra solo con registro real a la vista, pendiente, del puente y pidiendo cuenta")
    func borrador_soloElQueSobra() {
        let conReal = GroupBridgeLeftoverLogic.plan(legs: [real()], drafts: [
            draft(), draft(optIn: true), draft(needsAccount: false), draft(pending: false), draft("OTRO"), draft(nil)
        ], onlyCreatedSince: nil)
        #expect(conReal.draftIndices == [0])
        let sinReal = GroupBridgeLeftoverLogic.plan(legs: [loan()], drafts: [draft()], onlyCreatedSince: nil)
        #expect(sinReal.isEmpty)
    }

    @Test("Una pata sin cuenta no prueba nada: ni registro real ni préstamo")
    func pataSinCuenta_noCuenta() {
        var ciego = real(); ciego = .init(expenseID: "E", accountKey: nil, accountIsSystem: false, isLoanToGroups: false,
                                          isManagedApart: false, amount: -10.84, currencyCode: "USD", createdAt: t0,
                                          tiebreak: "r")
        let plan = GroupBridgeLeftoverLogic.plan(
            legs: [ciego, loan(account: nil), loan(tiebreak: "b", account: nil)], drafts: [draft()], onlyCreatedSince: nil)
        #expect(plan.isEmpty)
    }

    @Test("Con fecha de corte, solo lo nacido desde ella")
    func corte_soloLoNuevo() {
        let since = t0.addingTimeInterval(5)
        let plan = GroupBridgeLeftoverLogic.plan(
            legs: [real(), loan(at: 0, tiebreak: "a"), loan(at: 9, tiebreak: "b"), loan(at: 10, tiebreak: "c")],
            drafts: [draft(at: 0), draft(at: 9)], onlyCreatedSince: since)
        #expect(plan.legIndices == [2])   // «c» sobrevive; «a» es de antes del corte y se queda para el aviso
        #expect(plan.draftIndices == [1])
    }

    @Test("La divisa de la fila: la propia, si no la del gasto, si no la de por defecto")
    func divisaDeLaFila() {
        #expect(InboxDraftDisplayCurrencyLogic.currency(draftCurrency: "EUR", groupExpenseCurrency: "USD", fallback: "PEN") == "EUR")
        #expect(InboxDraftDisplayCurrencyLogic.currency(draftCurrency: nil, groupExpenseCurrency: "USD", fallback: "PEN") == "USD")
        #expect(InboxDraftDisplayCurrencyLogic.currency(draftCurrency: nil, groupExpenseCurrency: nil, fallback: "PEN") == "PEN")
    }
}

// MARK: - Cableado

@Suite("Grupos · la limpieza escucha también a la nube (source-scan)")
struct GroupBridgeLeftoverWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("Tras una sincronización de la nube y de iCloud corre la limpieza automática, y la Bandeja usa la divisa del gasto")
    func cableado() throws {
        let boot = try Self.source("Yala/App/AppBootstrapper.swift")
        let hook = try #require(boot.components(separatedBy: "private func observeTransactionsImportedFromSync()").dropFirst().first)
        let body = hook.components(separatedBy: "\n    private ").first ?? hook
        #expect(body.contains("forName: .cloudSyncAppliedRemoteChanges"))
        #expect(body.components(separatedBy: "GroupBridgeRaceCleaner.convergeAfterSync(in: context)").count == 3)
        #expect(body.contains("GroupBridgeRaceCleaner.leftoverAutoSince()"))

        // La automática pasa por la ruta probada, con la quiescencia y el sello: nunca `since: nil`.
        let cleaner = try Self.source("Yala/Services/Groups/GroupBridgeRaceCleaner.swift")
        let converge = try #require(cleaner.components(separatedBy: "static func convergeAfterSync(in context: ModelContext) {").dropFirst().first)
        let convergeBody = converge.components(separatedBy: "\n    }\n").first ?? converge
        #expect(convergeBody.contains("autoRemoveLeftovers(in: context, isQuiet: quiet, since: leftoverAutoSince())"))
        #expect(convergeBody.contains("case .cloudEngine: quiet = SyncQuiescenceCoordinator.shared.isQuiescentForEngineSaves"))
        #expect(convergeBody.contains("case .icloudImport: quiet = iCloudSyncService.shared.isImportQuiescent"))
        #expect(!convergeBody.contains("since: nil"))
        #expect(!cleaner.contains("context.rollback()"))

        // Las hojas que abren estos borradores no los leen borrados (la limpieza puede llegar con la hoja abierta).
        for sheet in ["GroupExpenseAccountFinalizationSheet", "GroupExpenseAccountAndSubcategoryFinalizationSheet"] {
            let src = try Self.source("Yala/App/Views/Inbox/\(sheet).swift")
            #expect(src.contains("if draft.isDeleted || draft.modelContext == nil {"), "\(sheet) lee el borrador sin mirar si sigue vivo")
        }

        let inbox = try Self.source("Yala/App/Views/Inbox/InboxView.swift")
        #expect(inbox.contains("viewModel.displayCurrencyCode(for: draft, fallback: appPreferences.defaultCurrencyCode.rawValue)"))
        #expect(!inbox.contains("currencyCode: draft.displayCurrencyCode ?? appPreferences.defaultCurrencyCode.rawValue"))
        #expect(inbox.contains("GroupBridgeLeftoversNotice(count: viewModel.groupLeftoverCount)"))
    }
}
